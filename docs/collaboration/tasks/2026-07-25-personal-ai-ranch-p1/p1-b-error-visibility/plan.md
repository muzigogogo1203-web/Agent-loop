# P1-B Level-3 Leaf Plan — Error Visibility and Application-Layer Seams

> Status: **CANDIDATE 03 REVISION 17 FROZEN — implementation paused until immutable Review21 records APPROVED with zero P0/P1**
>
> Date: 2026-08-15
>
> Branch / planning entry: `codex/personal-ai-ranch-p0` / dirty accepted A1–A4 working tree
>
> Authority: accepted master spec; canonical P1 Stage §7, §18.3, §20 P1-B,
> and §22; canonical P1 Plan §4 and §10; accepted P1-A4 `acceptance.md`

## 1. Entry, objective, and execution boundary

P1-A1a, A1b, A2, A3, and A4 are independently accepted. R-01 through
R-04 are closed. A4 Review03 is `APPROVED — 0 P0 / 0 P1 / 0 P2`, A4
acceptance is `ACCEPTED`, and the only newly open route is bounded P1-B
Level-3 planning.

P1-B closes three accepted risks:

- R-05: App and workflow reads/writes use `try?` or equivalent fallbacks that
  turn failures into empty data, absence, false, or success;
- R-06: MCP and knowledge dependencies silently disappear from execution
  context;
- R-07: AppStore combines composition, domain operations, and UI projection,
  making failure behavior hard to test without launching SwiftUI.

The slice result is not a generic rewrite. It is one traceable failure path
from a top-level operation through Core persistence, a small non-UI
`AgentLoopApplication` layer, App projection, and an isolated preview:

```text
OperationTrace created before the operation
  -> typed dependency or workflow error
  -> FailureReporter sanitizes and persists/logs the same trace
  -> WorkflowLoadState.failed(UserVisibleFailure)
  -> App keeps the last successfully loaded value
  -> UI renders safe text + the same full stable trace ID
```

Review01 is immutable history and concluded
`CHANGES REQUIRED — 0 P0 / 6 P1 / 2 P2`. Review02 is also immutable history
and concluded `CHANGES REQUIRED — 0 P0 / 7 P1 / 1 P2` against Candidate 03
Revision 01. Review03 is immutable history and concluded
`CHANGES REQUIRED — 0 P0 / 6 P1 / 2 P2` against frozen Revision 02. This
bounded Revision 03 may change only this plan, the inventory, and `blocked.md`
to close Review03 and its mechanically necessary transitive consistency
closure. Implementation remains prohibited until Revision 03 is frozen and a
fresh responsibility-isolated review returns `APPROVED` with zero P0/P1.
Immutable Review04 subsequently returned `APPROVED — 0 P0 / 0 P1`, and
implementation opened against the frozen Revision 03 hashes. During the first
authoritative-suite convergence, the unchanged historical
`CodingRanchTests.swift` source gates proved incompatible with the reviewed
Input controller boundary: they still require direct App database and
Orchestrator calls that §§6.3 and 6.6 explicitly prohibit. Revision 04 is
therefore restricted to this one transitive test-authority correction, its
exact path/manifest arithmetic, and the same three planning files. No product
architecture, production scanner path, descriptor, seam, migration, or test
declaration count changes. Implementation remains paused until Revision 04 is
frozen and immutable Review05 returns `APPROVED` with zero P0/P1.
The first unfiltered suite after that approved correction then exposed B-02:
two public `Orchestrator.startMission` compatibility assertions still require
the pre-P1-B `KernelHaltedError`, while the accepted public wrapper correctly
throws `UserVisibleOperationError(failure:)`; a durable-rumination source gate
still requires the Adapter itself to own `db.pool.write`, while the reviewed
Input controller boundary owns the transaction. Revision 05 is restricted to
the two existing affected test paths, their exact assertion ownership, and the
mechanically necessary pathname/manifest arithmetic. It preserves the
package-level confirmed-proposal `KernelHaltedError` assertion, all runtime
matrices, every production/scanner/migration count, and the 714-test/
47-declaration contract. Implementation remains paused until Revision 05 is
frozen and immutable Review06 returns `APPROVED` with zero P0/P1.
Review06 did approve that bounded B-02 correction, and its three targeted
tests passed. The subsequent authoritative suite established B-03: both
Revision05 test paths are members of both frozen 206-row A3/A4 manifests.
`ScheduleMath.swift` is instead an A3 historical-exclusion member and does not
occur in the A4 manifest. Revision06 corrects only those test-gate facts in the
already allowlisted `DurablePlanningTests.swift`: exact66 becomes 66 in the
code gate; A3 becomes 49 raw / 43 successor / 156 live; A4 becomes 46 P1-B
members / 160 unaffected / 10 new paths.
The independent cancellation-ignoring-provider shutdown failure is a red
root-cause gate, not solved by weakening its one-second bound. The attempted
Revision12 fixture-only correction proved invalid because returning an
`AsyncThrowingStream` promptly changes the intended cancellation-ignoring
semantic. With explicit user authorization, Revision14 adds exactly
`DurableWorkSupervisor.swift` and `Planner.swift` to the implementation
allowlist: the durable Planner path awaits synchronous `streamTurn`
construction from an off-executor, non-cancellation-reactive continuation,
while the Supervisor retains cancellation and deadline ownership.
The strict one-second assertion, expected uncooperative work ID, production
failure semantics, scanner/manifest bytes, and test declaration count remain
unchanged. No other production, migration, scanner, manifest-byte, or
Acceptance20 found that `RuntimeProfileWorkflowController.swift` directly
imports `Security` and `CryptoKit`, violating the fixed Application/Core
boundary. Revision17 changes only the two already-allowlisted paths:
`OpenAIOAuthSession.swift` owns secure random-secret generation and PKCE
SHA-256/base64url derivation; the Application controller calls that Core API
and imports only Foundation and AgentLoopCore. No behavior, timeout, test
declaration, scanner, manifest, or allowlist-count change is authorized before
fresh Review21.
An unknown failure, required unlisted path, unresolved decision, red test not
explained by the intended failure-first step, or non-empty Open Questions is a
stop condition and must be recorded in `blocked.md` before any further source
change.

This plan does not authorize commit, push, merge, release, normal/destructive
user-data operations, Keychain writes outside isolated tests, payment, public
communication, external actions, or real-user operations. Internal fingerprints
are evidence only; no user hash echo is an execution gate.

## 2. Exact source allowlist and scope reconciliation

### 2.1 Implementation paths

The proposed implementation allowlist is exactly the following 66 paths.
Canonical Plan §4.1 supplies 33; thirty-one additions are required by the same
accepted contracts and are justified below.

#### Core production (26)

1. `Sources/AgentLoopCore/Database/AppDatabase.swift`
2. `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
3. `Sources/AgentLoopCore/Work/PlanningProviderResolver.swift`
4. `Sources/AgentLoopCore/Mcp/McpServerManager.swift`
5. `Sources/AgentLoopCore/Mcp/McpToolBridge.swift`
6. `Sources/AgentLoopCore/Database/KnowledgeStore.swift`
7. `Sources/AgentLoopCore/Knowledge/MemoryDistillService.swift`
8. `Sources/AgentLoopCore/Knowledge/Distiller.swift`
9. `Sources/AgentLoopCore/Rumination/RuminationService.swift`
10. `Sources/AgentLoopCore/Chat/GuideChatService.swift`
11. `Sources/AgentLoopCore/Support/KeychainStore.swift`
12. `Sources/AgentLoopCore/Provider/OpenAIOAuthSession.swift`
13. `Sources/AgentLoopCore/Provider/ProfileScopedDefaults.swift`
14. `Sources/AgentLoopCore/Provider/ModelCatalogService.swift`
15. `Sources/AgentLoopCore/Database/RuntimeProfileStore.swift`
16. `Sources/AgentLoopCore/Product/RuntimeProfileBootstrap.swift`
17. `Sources/AgentLoopCore/Product/NewcomerUnlockPolicy.swift`
18. `Sources/AgentLoopCore/Database/ScheduleStore.swift`
19. `Sources/AgentLoopCore/Chat/ChatService.swift`
20. `Sources/AgentLoopCore/Product/MissionDraftFactory.swift`
21. `Sources/AgentLoopCore/Product/ProductBootstrapService.swift`
22. new `Sources/AgentLoopCore/Observability/FailureRecord.swift`
23. new `Sources/AgentLoopCore/Observability/FailureReporter.swift`
24. new `Sources/AgentLoopCore/Observability/ContextDependencyLoader.swift`
25. `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`
26. `Sources/AgentLoopCore/Kernel/Planner.swift`

#### Application target (5)

27. new `Sources/AgentLoopApplication/WorkflowLoadState.swift`
28. new `Sources/AgentLoopApplication/MissionWorkflowController.swift`
29. new `Sources/AgentLoopApplication/InputWorkflowController.swift`
30. new `Sources/AgentLoopApplication/RuntimeProfileWorkflowController.swift`
31. new `Sources/AgentLoopApplication/McpWorkflowController.swift`

#### App projection (14)

32. `Sources/AgentLoopApp/AppStore.swift`
33. `Sources/AgentLoopApp/McpStore.swift`
34. `Sources/AgentLoopApp/MissionScheduler.swift`
35. `Sources/AgentLoopApp/ScheduledMissionNotifications.swift`
36. `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
37. `Sources/AgentLoopApp/CodingRanchContracts.swift`
38. `Sources/AgentLoopApp/Views/RootView.swift`
39. `Sources/AgentLoopApp/Views/RuntimeProfileViews.swift`
40. `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchHomeView.swift`
41. `Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift`
42. `Sources/AgentLoopApp/Views/Components/McpStationSection.swift`
43. `Sources/AgentLoopApp/Views/Components/NoteListPane.swift`
44. `Sources/AgentLoopApp/Views/CompanionEditorView.swift`
45. `Sources/AgentLoopApp/Views/ScheduleManagerView.swift`

#### Tests (18)

46. new `Sources/AgentLoopTestSuite/ApplicationWorkflowTests.swift`
47. new `Sources/AgentLoopTestSuite/FailureVisibilityTests.swift`
48. `Sources/AgentLoopTestSuite/McpTests.swift`
49. `Sources/AgentLoopTestSuite/McpManagerSpikeTest.swift`
50. `Sources/AgentLoopTestSuite/KnowledgeStoreTests.swift`
51. `Sources/AgentLoopTestSuite/KnowledgeGoldenPathTests.swift`
52. `Sources/AgentLoopTestSuite/MemoryDistillTests.swift`
53. `Sources/AgentLoopTestSuite/DistillerTests.swift`
54. `Sources/AgentLoopTestSuite/RuntimeProfileTests.swift`
55. `Sources/AgentLoopTestSuite/ModelCatalogPolicyTests.swift`
56. `Sources/AgentLoopTestSuite/OpenAIOAuthSessionTests.swift`
57. `Sources/AgentLoopTestSuite/ScheduleTests.swift`
58. `Sources/AgentLoopTestSuite/GuideChatTests.swift`
59. `Sources/AgentLoopTestSuite/DatabaseTests.swift`
60. `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`
61. `Sources/AgentLoopTestSuite/CodingRanchTests.swift`
62. `Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift`
63. `Sources/AgentLoopTestSuite/DurableWorkTests.swift`

#### Package and matrix infrastructure (3)

64. `Package.swift`
65. `Sources/P1MigrationMatrixRunner/main.swift`
66. `scripts/verify-p1-migrations-sqlite-matrix.sh`

### 2.2 Why the thirty-one additions are mandatory

- `McpToolBridge.swift`: its failed MCP call currently uses a business `try?`
  to append the diagnostic event. P1-B cannot claim MCP failure traceability
  while leaving the event write silent.
- `McpManagerSpikeTest.swift`: it directly calls `assembledTools`; the accepted
  throws/typed-result change cannot compile without updating this existing
  direct conformance probe.
- `CompanionEditorView.swift`: it directly reads a Companion with `try?` while
  consuming MCP tool-list state. A failed read currently leaves a stale/default
  editor with no error, so the MCP/UI workflow cannot be truthfully closed
  without giving this view the same typed load state.
- `ScheduleManagerView.swift`: its template editor reparses a validated
  `MissionTemplateRecord` with `try? ... ?? ""`, its save catch exposes a raw
  error description, and its 200 ms best-effort sleep guesses when an
  asynchronous schedule mutation has committed. The view must consume the
  typed schedule presentation/draft boundary and await the real mutation
  receipt before refreshing; the sleep is deleted rather than approved as a
  fifth cleanup residual.
- `P1MigrationMatrixRunner/main.swift` and the matrix script hard-code v12 as
  final and only seven predecessors. Without them, canonical Plan §10's
  through-v13 dual-SQLite gate is impossible.
- `DatabaseTests.swift` hard-codes A4 as the last migration and 29/60/4. Its
  A4 test must migrate explicitly only through v12 and remain an immutable
  historical checkpoint while the new v13 test owns the final state.
- `DurablePlanningTests.swift` contains live A3/A4 source manifests. It may add
  exact P1-B successor exclusions, but may not delete, weaken, or reinterpret
  the historical evidence.
- `CodingRanchTests.swift` contains four pre-P1-B source-owner assertions that
  require AppStore/Adapter to call AppDatabase and Orchestrator directly. Those
  assertions became false when the reviewed Input controller moved the exact
  preparation/start/cancel owners into `InputWorkflowPorts.live`. Revision 04
  changes only those four existing declarations: it preserves every runtime
  matrix and behavioral assertion, replaces the obsolete App direct-call
  tokens with controller/port ownership tokens, adds no declaration, and does
  not weaken diagnostics, restart recovery, phase identity, or durable-state
  checks.
- `HaltAndCooldownTests.swift` retains its public direct-mission and
  package-level confirmed-proposal behavioral matrices. Revision 05 changes
  only the two public `Orchestrator.startMission` catch assertions: each must
  require `UserVisibleOperationError`, its exact supplied trace ID,
  `.missionStart` operation, and `.fixed(.missionIndex)` scope. The existing
  package `startConfirmedProposal` assertion remains `KernelHaltedError` and
  is byte-for-byte outside this replacement.
- `DurableWorkTests.swift` retains its active-rumination discard/delete/archive
  race matrix. Revision 05 changes only its stale Adapter ownership source
  gate: the Adapter must call `inputWorkflowController.delete`, the live Input
  port must call `database.deleteIngestionAtomically`, and that Core method
  alone must prove `pool.write`, active-work counting, non-ruminating status,
  zero active count, and the existing deletion-scope switch. The test may not
  restore an App-side database transaction or weaken any race assertion.
- `OpenAIOAuthSession.swift` and `OpenAIOAuthSessionTests.swift`: refresh writes
  access/refresh/ID/account credentials sequentially and can currently expose
  a partially updated credential set after a later write fails. P1-B's
  Keychain write-failure guarantee would be false if it fixed only AppStore's
  initial callback and left the production refresh owner unchanged.
- `ProfileScopedDefaults.swift`, `RuntimeProfileBootstrap.swift`,
  `RuntimeProfileStore.swift`, and `ModelCatalogService.swift`: the synchronous
  bootstrap/default-switch/catalog/reconciliation route currently cannot
  distinguish a missing setting from a wrong-typed/corrupt UserDefaults value;
  bootstrap also reads those values internally after it may create a new
  profile. A controller preflight would duplicate the algorithm and remain
  racy. These four transitive owners must use the same throwing strict read
  contract, and ModelCatalogService must reduce non-2xx/JSON failures before a
  raw body can escape. `ModelCatalogPolicyTests.swift` directly compiles the
  existing nonthrowing defaults/catalog surface and therefore must move with
  its intentional removal.
- `NewcomerUnlockPolicy.swift`: the Input Camp one-snapshot bundle must reuse
  the policy's SQL, but its five `SELECT EXISTS` reads currently turn an
  impossible nil scalar into `false`. Making the one Database-parameter helper
  package-visible and throwing is the only single-source fix; copying its SQL
  into AppDatabase would leave the accepted policy path silently divergent.
- `Distiller.swift` and `DistillerTests.swift`: closeout currently catches
  provider/parse failure and returns a deterministic note marked as success.
  Orchestrator receives no original error and cannot recover its trace. The
  helper must become throwing/typed and its three direct test callsites must
  compile that contract; keeping a nonthrowing compatibility wrapper would
  preserve the exact silent fallback P1-B is closing.
- `PlanningProviderResolver.swift`: strict defaults/catalog APIs make its
  catalog-selection routes throwing. It currently owns nine catches and calls
  the nonthrowing model canonicalizer; excluding it would either break
  compilation or preserve a silent provider-dispatch fallback behind the new
  Runtime controller. Existing DurablePlanning tests already own its direct
  behavior.
- `MissionScheduler.swift`, `ScheduledMissionNotifications.swift`, and
  `ScheduleTests.swift`: scheduler refresh/start/replay/broadcast currently
  catch and return, while OS authorization/submission logs and returns Void.
  AppStore cannot observe the post-commit schedule outcomes required by §5.2
  unless both production owners return typed receipts and their direct tests
  move with the signatures.
- `GuideChatService.swift` and `GuideChatTests.swift`: the service catches
  member/proposal DB failures, formats `localizedDescription` into model-facing
  tool results, and continues. A later App/Application wrapper cannot recover
  that swallowed error, so the Core owner and its direct tests are required.
- `ScheduleStore.swift`, `ChatService.swift`, and `MissionDraftFactory.swift`:
  the newly required aggregate boundaries must have one persistence source of
  truth. ScheduleStore currently owns the schedule queries plus an invalid-
  payload `try?` and ignored delete results; ChatService owns the user-message
  commit and a stream catch/TurnResult fallback; MissionDraftFactory owns draft
  decoding. Excluding them would force AppDatabase to copy those algorithms or
  would leave Chat history/draft/Schedule notification split across snapshots.
  They move to Database-parameter helpers or delegate to the aggregate methods
  while preserving every existing public signature. No new test path is
  required because ScheduleTests, the Application tables, and existing direct
  Chat/MissionDraft callers already compile and exercise the adapters.
- `ProductBootstrapService.swift`: Coding Ranch bootstrap currently commits
  `ensureDefaultCamp()` in one transaction and guide/base-cow/event work in a
  second. P1-B cannot classify every thrown bootstrap as not committed while
  that partial durable state remains possible. The root service must reuse
  `AppDatabase.ensureDefaultCamp(_:)` inside its one owning `pool.write` so the
  complete Camp/guide/base-cow/event unit is atomic.

No other path is implied. In particular, `Package.resolved`,
`Sources/RunTests/main.swift`, `Sources/AgentLoopCore/Database/EventKind.swift`,
`Sources/AgentLoopCore/Database/Records.swift`,
`Sources/AgentLoopCore/Database/McpDatabase.swift`, `BoardCardTransactions.swift`,
`CampHomeView.swift`, package dependencies, v14+
schema, and P1-C+ sources remain closed. Existing App call signatures that
would otherwise force those views to change must be preserved by the App
projection layer; Core callers use the new typed APIs directly.
`Sources/AgentLoopApp/AgentLoopApp.swift` is likewise outside the allowlist:
its existing `.onOpenURL { url in store.handleOAuthCallback(url) }` remains
byte-for-byte and the retained AppStore URL façade implements the new direct
custom-scheme ingress. Any implementation need to edit that file reopens scope
and stops this slice.

### 2.3 Task artifacts and dirty-entry partition

This task directory may contain only:

- `plan.md`, `try-question-mark-inventory.md`, `blocked.md`;
- `entry-source-manifest.sha256`;
- `red-tests.log`, `red-migration-matrix.log`, `targeted-tests.log`;
- `migration-matrix.log`, `build.log`, `source-gates.log`, `verify.log`;
- `preview.log`, `evidence/preview-normal.png`,
  `evidence/preview-failure.png`, `evidence/preview-db-correlation.txt`;
- `impl-report.md`, `reviews/`, and `acceptance.md`.

The entry manifest is captured from the accepted dirty A1–A4 tree, not HEAD.
It is NUL-safe and records path, file type, symlink state, and byte digest.
Final partition permits changes only to the 66 paths above and this task
directory. The ten new source/test files must be absent at entry and regular,
non-symlink files at final. Any outside byte/type/path drift stops the slice.

## 3. Package and dependency graph

`Package.swift` changes are exact:

1. add internal target `AgentLoopApplication`, depending only on
   `AgentLoopCore`;
2. make `AgentLoopApp` depend on Core + Application;
3. make `AgentLoopTestSuite` depend on Core + Application;
4. leave `P1MigrationMatrixRunner` depending only on Core + GRDB;
5. add no product and no external dependency;
6. leave `AgentLoopCoreTests`, `RunTests`, resources, CLT workarounds, and
   `Package.resolved` unchanged.

Application may import only Foundation and AgentLoopCore. It must not import
SwiftUI, AppKit, Observation, Security, GRDB, or an App target. Core must not import
Application. UI-only effects remain App protocols/closures composed by
AppStore. Debug and release symbol/import gates enforce both directions.

## 4. v13 observability migration

### 4.1 Exact registration and checkpoint

`AppDatabase.migrator` registers `v13-p1-observability` immediately after
`v12-p1-schedule-fire` and executes Stage §18.3's exact SQL bytes. It adds no
`IF EXISTS`, `IF NOT EXISTS`, backfill, trigger, extra CHECK, or v14 object.

The exact final checkpoint is:

```text
31 tables / 65 indexes / 4 triggers
```

It contains exactly two new tables (`failure_record`,
`context_degradation`), three named indexes, and their two SQLite primary-key
autoindexes. Both new tables are empty after every predecessor migration.

### 4.2 Eight real predecessor fixtures

The fixed order is:

```text
fresh
v7
v8-coding-ranch
v9-evercamp
v10-runtime-profiles
v11-cli-kinds
v12-durable
v12-schedule
```

`v12-schedule` is created only by the real migrator `upTo:
"v12-p1-schedule-fire"`; it is not hand-copied final schema. Before close it
stores a valid non-empty graph containing Camp/Squad/Mission/template/schedule,
one started schedule fire and cursor, and one running durable work/open
attempt/claimed event. The runner records the canonical logical predecessor
snapshot, closes/reopens, migrates to v13 twice, and proves:

- all predecessor rows are byte/logically unchanged;
- both v13 tables begin empty;
- the second migration changes neither schema nor data;
- inherited durable and schedule gates still run against this fixture.

It emits exact sentinels:

```text
fixture.v12-schedule.predecessor_snapshot=pass
fixture.v12-schedule.final_idempotent_snapshot=pass
fixture.v12-schedule.replay=pass
fixture.v12-schedule.fk=pass
fixture.v12-schedule.integrity=pass
fixture.v12-schedule.ddl=pass
fixture.v12-schedule.append_only=pass
```

Any inherited absolute row-count assertion is converted to a captured-baseline
delta assertion; no upstream test is skipped for the seeded fixture.

### 4.3 Real and literal lanes

For both the system SQLite 3.51 lane and Homebrew SQLite 3.52 lane, the script
must run:

- the real GRDB runner dynamically linked to that exact lane;
- the literal SQLite CLI starting from the runner-produced, closed/reopened
  **v11-cli-kinds** logical baseline and applying the exact Stage §18.1,
  §18.2, then §18.3 fences once each and in order. A v12 baseline may not be
  used for this lane because that would replay §18.1 against objects it already
  owns.

The script keeps the existing §18.1/§18.2 line/hash gates and adds §18.3's
49-line fence with planning-entry SHA-256
`a0fe7c90723220a8e5a1402cc9f9b1997e04cf2d8a45de6474e8e5f9b599f087`.
The runner gains `--literal-observability-schema`; it retains
`--literal-schema` for v12. Runner and CLI version/source-ID mismatch fails
before accepting any schema result.

The through-v13 runner/script sentinel set is exact. In addition to every
accepted v12 sentinel, both SQLite lanes must emit:

```text
observability_contract.real.fresh=pass
observability_contract.real.v7=pass
observability_contract.real.v8-coding-ranch=pass
observability_contract.real.v9-evercamp=pass
observability_contract.real.v10-runtime-profiles=pass
observability_contract.real.v11-cli-kinds=pass
observability_contract.real.v12-durable=pass
observability_contract.real.v12-schedule=pass
fixture.v12-schedule.observability.predecessor_snapshot=pass
fixture.v12-schedule.observability.failure_record=pass
fixture.v12-schedule.observability.context_degradation=pass
fixture.v12-schedule.observability.rollback=pass
fixture.v12-schedule.observability.replay=pass
fixture.v12-schedule.observability.fk=pass
fixture.v12-schedule.observability.integrity=pass
fixture.v12-schedule.observability.ddl=pass
fixture.v12-schedule.observability.append_only=pass
fixture.v12-schedule.observability.final_checkpoint=31/65/4
literal_observability_schema_shape=bound
observability_contract.literal=pass
rollback.real_v13_observability=pass
rollback.literal_v13_observability=pass
literal.v13.observability.rollback=pass
literal.v13.observability.replay=pass
literal.v13.observability.final_checkpoint=31/65/4
```

Missing, duplicate, out-of-order, or differently named sentinels fail the
matrix; the shell script does not infer success from exit zero alone.

### 4.4 Rollback, replay, and exact constraints

Three rollback proofs remain mandatory:

1. the accepted v12 schedule rollback remains unchanged;
2. a real v13 mid-migration failure from a true v12-schedule checkpoint leaves
   schema/data/migration records byte-logically unchanged and no partial v13
   object. The injection is fixed: create and seed the v12-schedule fixture,
   close/reopen it, create a conflicting sentinel index named
   `context_degradation_mission` on `mission(id)`, then snapshot schema/data/
   migration rows including that sentinel. Run the
   real migrator. Its v13 transaction must first create `failure_record`, its
   indexes, and `context_degradation`, then fail when it reaches the conflicting
   named index. After the error, the before/after logical snapshot is identical,
   the sentinel still points to `mission(id)`, the v13 migration row is absent,
   and every v13 table/index other than that pre-existing sentinel is absent;
3. a literal `BEGIN IMMEDIATE` + exact §18.3 + forced missing-table failure
   rolls back to the exact v12-schedule logical checkpoint.

The v13 contract runs in a rollback transaction for every real fixture and
both literal scopes. It verifies exact columns, FK actions, index column order,
DDL/CHECK shape, numeric date round-trip, 1000/1001 boundaries, all legal
camp/global/open/resolved `failure_record` shapes, the one legal redacted shape
(Camp + `[deleted]` + `{}`), and explicit rejection of global redaction; all legal
mission/card/both and required/optionalApproved `context_degradation` shapes,
and rejects every Stage-invalid enum/nullability/redaction/FK combination.
It must not add an XOR between mission and card or any constraint absent from
Stage §18.3.

`DatabaseTests.scheduleFireMigrationMatrixAndExactDDL` is changed only to
migrate `upTo: "v12-p1-schedule-fire"`, retain 29/60/4, and assert v13 objects
are absent. New `FailureVisibilityTests` owns final v13 assertions.

Revision06 corrects the actual immutable-manifest membership. Both Revision05
test paths occur in both 206-row A3/A4 manifests at their frozen entry hashes.
The A4 gate therefore has 45 exact P1-B members and compares the remaining 161
type/symlink/hash tuples. Its absent-at-entry P1-B set remains 10: the two
Revision05 tests are both manifest members, so adding them does not change the
already-absent set.
The A3 gate retains its seven A4 exclusions and adds 42 exact P1-B successor
exclusions, leaving 157 live entries: its 48 raw intersections include six
already-historical A4 overlaps. Every set operation is pathname-exact over the
unchanged manifest bytes; an exclusion is never edit authority. The final
implementation delta remains restricted to the exact 66-path allowlist plus
this task directory. Revision14 supersedes the historical Supervisor and
Planner external anchors only for the synchronous-provider isolation described
in §1; both remain regular non-symlink files and no other prior-owner or
manifest authority is changed:

```text
decfbc90e891580acc55c8f6ab03d4014bf6667a7fa486d6a959150cc4de7095  Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift
0412b01bef7657f5305760d225bdcc6322dca1661395b8749e6c2dfeaec6ff43  Sources/AgentLoopCore/Kernel/Planner.swift
```

Any byte, type, symlink, or pathname drift outside the exact allowed isolation
fails before tests; neither manifest subtraction nor an equivalent-occurrence
relation may authorize it.
Revision 05 instead permits only the two existing test rows below, each with
its frozen entry hash and no production/scanner contribution:

```text
576dbd8c8f44cebe0eba952550633c760aa84ed176d44616d14707fb10363ec0  Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift
818dfc5f897a0258b3113902f175d65bdf917732652ca44c08bd86fd0a2f0dd7  Sources/AgentLoopTestSuite/DurableWorkTests.swift
```

The preceding Revision05 membership/arithmetic assertion is superseded by
Revision06: both paths are members of both immutable manifests. Their only
permitted body changes remain the exact assertions in §2.2, while
`DurablePlanningTests.swift` updates the documented A3/A4 gate arithmetic;
any other byte change fails before tests.
New/previously excluded paths are not double-counted.
`CodingRanchTests.swift` is absent from the A3 206-row manifest but was one of
its four separately frozen live hashes; Revision 04 moves it into the legal
successor delta without changing the A3 46/40/159 manifest arithmetic. A3's
remaining frozen hash set is exactly `Package.resolved`, `EventKind.swift`, and
`RunTests/main.swift`; the now-legally changed `Package.swift`,
`CodingRanchStoreAdapter.swift`, `CodingRanchTests.swift`, and
`MissionDraftFactory.swift` anchors move out of that live successor gate.
Historical files and outcomes remain immutable.

## 5. Frozen failure model

### 5.1 Operation trace and user-visible failure

`OperationTrace` is a `Sendable`, `Equatable` value created before every
top-level operation and contains `traceId`, closed `FailureOperation`, typed `FailureScope`,
and `startedAt`. New operations use an injected UUID generator, while an entry
that already owns an A1/A2 durable trace adopts that exact opaque trace rather
than inventing a second identity. Adopted IDs must satisfy the bounded safe
trace grammar (1...128 ASCII letters/digits plus `._:-`), which retains
accepted short fixtures such as `trace`; they are preserved,
not normalized.

`UserVisibleFailure` contains the full trace ID, operation, and sanitized final
message. `message` itself is already the only UI-ready formatter and ends with
the full stable trace:

```text
操作失败：<sanitized message>\n追踪 ID：<full traceId>
```

Views may not reformat, truncate, or omit it. An empty operation/message or
invalid trace fails construction.

The cross-target surface is exact; consumers can read but cannot forge a
formatted failure:

```swift
public struct OperationTrace: Sendable, Equatable {
    public let traceId: String
    public let operation: FailureOperation
    public let scope: FailureScope
    package let traceScope: FailureTraceScope
    public let startedAt: Date
    fileprivate init(validatedTraceId: String, operation: FailureOperation,
                     traceScope: FailureTraceScope, startedAt: Date)
}
package struct OperationTraceFactory: Sendable {
    package static let live: OperationTraceFactory
    package init(makeID: @escaping @Sendable () -> UUID,
                 now: @escaping @Sendable () -> Date)
    package func generated(operation: FailureOperation,
                           scope: FailureTraceScope) -> OperationTrace
    package func adopting(_ durableTraceId: String,
                          operation: FailureOperation,
                          scope: FailureTraceScope) throws -> OperationTrace
}
public struct UserVisibleFailure: Sendable, Equatable {
    public let traceId: String
    public let operation: FailureOperation
    public let scope: FailureScope
    public let message: String
    fileprivate init(validatedTrace trace: OperationTrace, message: String)
}
public struct UserVisibleOperationError: Error, LocalizedError, Sendable, Equatable {
    public let failure: UserVisibleFailure
    public var errorDescription: String? { failure.message }
    package init(failure: UserVisibleFailure)
}
package enum OperationCommitOutcome<Value: Sendable>: Sendable {
    case notCommitted(UserVisibleFailure)
    case committed(Value)
    case committedWithVisibilityFailure(value: Value,
                                         failure: UserVisibleFailure)
}
```

`OperationTraceFactory` is the sole non-DEBUG constructor. `generated` is
nonthrowing because its injected UUID and `FailureTraceScope` are already
validated. Nonthrowing legacy/App façades obtain a fixed trace scope with
`FailureTraceScope.fixed(_:)`; that exhaustive factory cannot fail and is the
only route available before a record has been loaded. Dynamic record scopes
are created by the throwing typed factories below before the operation's first
business action. `adopting` validates the exact durable ID and throws
`FailureMetadataValidationError.invalidTraceId` to already-throwing start/
recovery owners before any write. Neither route truncates or normalizes an ID.
`traceScope` is the exact validated capability from which the public read-only
`scope` was derived. Package code may retain it across an explicitly typed
split cleanup such as MCP deletion, but may not reconstruct one from
`FailureScope` columns or raw IDs.
Only the closed `FailureRecordFactory` in the same file can construct
`UserVisibleFailure`; ordinary Core/Application consumers have no initializer.
FailureReporter and the dedicated pre-composition
`ApplicationBootstrapFailureBoundary` frozen in §5.3 are its only callers and
both apply the one formatter in §5.3.

### 5.2 Records, scope, and ownership

`FailureRecord.swift` owns the exact v13-domain values plus the closed,
module-internal `ValidatedFailureClassification`, `FailureClassifier`, and
`FailureRecordFactory` construction boundary:

- `FailureSeverity`: `info|warning|error|critical`;
- closed `FailureOperation`, `FailureScopeType`, `FailureFixedCoordinate`,
  validated `FailureRecordID`, typed `FailureTraceScope`, and public read-only
  `FailureScope`; there is no arbitrary
  operation/scope String initializer;
- `FailureRecord`: the exact 16 §18.3 columns;
- `ContextDependencyPolicy`: `required|optionalApproved`;
- `ContextDegradationRecord`: the exact ten §18.3 columns;
- `UserVisibleFailure` and `OperationTrace`;
- `UserVisibleOperationError: Error, LocalizedError, Sendable, Equatable` with
  one public read-only `failure`, exact `errorDescription == failure.message`,
  and package initializer, used only by compatibility
  throwing wrappers;
- `OperationCommitOutcome<Value: Sendable>` with exactly
  `.notCommitted(UserVisibleFailure)`, `.committed(Value)`, and
  `.committedWithVisibilityFailure(value: Value, failure: UserVisibleFailure)`.

`FailureRecord` and `ContextDegradationRecord` use explicit GRDB `Row`
decoders, are `FetchableRecord`, `Sendable`, and `Equatable`, and do not expose
generic update/delete ownership. They do not synthesize `Codable`: scope
columns are decoded by the read-only persisted-row validator described in
§5.4, which can prove grammar and coordinate shape but never claims database
record provenance. All write/upsert
SQL remains in `AppDatabase.swift`. Ordinary failure writes are owned only by
`FailureReporter`; ContextDependencyLoader and McpToolBridge may call only the
two package atomic AppDatabase operations frozen in §6.6, never raw
failure-record SQL.

`OperationCommitOutcome` is the mandatory boundary whenever a mutation can
commit before a notification/event/reload fails. Only `.notCommitted` may
offer/reuse the original mutation action. `.committedWithVisibilityFailure`
updates any known committed identity, displays `已完成，但状态刷新失败` plus the
trace, and offers refresh/reconcile only; it must never automatically repeat
the mutation. The owner records the commit point explicitly—callers may not
infer it from an arbitrary thrown error.

The inventory's split-commit sites map exactly as follows:

| Operation | Commit point | Failure after that point |
|---|---|---|
| answer user request | `answerUserRequest` transaction commits | mission-ID reread/event/reconcile failure is committed-with-visibility-failure; answer UI clears and may only refresh |
| confirm squad proposal | mission planning enqueue returns a durable mission ID | attach/event failure keeps proposal confirmed, never reverts to pending, returns the mission ID with visibility failure, and offers link reconciliation only; failures before mission enqueue may revert pending |
| proposal revert | pending restoration commits | original command is not committed; restoration failure returns one critical composite outcome preserving both stable codes, never hides either |
| rate-limit cooldown | actor `cooldownUntil` changes | event-write failure keeps cooldown active and is committed-with-visibility-failure; retry may append the event only, never call the provider |
| budget exhausted notification | durable event commits | `budgetNotified` is set only after commit; event failure is not committed and the next reconcile may retry the event only |
| mission cancel/harvest | mission/card transaction commits | App reload/event-delivery failure is committed-with-visibility-failure; canceled tasks/runs are never restarted by retry |
| mission closeout/accept | accepted status/events transaction commits and is emitted before post-commit effects | report-write, real-distillation, and per-companion cowork failures keep accepted and return `MissionAcceptanceOutcome.committedWithVisibilityFailures`; its nonempty opaque repair set offers only the matching report/distill/cowork actions and never repeats acceptance |
| profile/default/reconciliation | owning DB transaction commits | verification reload failure returns the committed profile/default identity plus visibility failure |
| API-key save + required default-profile attachment | Keychain set commits first; attachment is a second required mutation | a default-profile read/CAS failure is `RuntimeCredentialSetOutcome.attachmentPending`, never generic visibility success; its opaque retry performs only resolve/attach/reload and zero Keychain writes; only failure after both required mutations commit is refresh-only committed visibility |
| OAuth credential bundle | all required bundle mutations commit atomically in the coordinator | UI/profile reload failure is committed-with-visibility-failure; bundle commit failure is not committed only after successful rollback |
| Camp rename, memory edit/delete/pin, MCP enable/secret | owning DB/Keychain command commits | reload/toast failure is committed-with-visibility-failure; App updates known receipt and offers refresh only |
| DM/guide memory distillation | captured watermark plus note/event transaction commits and Service returns `.created(record)` | the record is permanently created; a subsequent `.memoryNoteLoad` or `.campKnowledgeLoad` refresh failure is committed-with-visibility-failure and retry reloads only, never calls the provider or distillation persistence again |
| Feed submit + optional auto-rumination | Feed transaction returns `FeedSubmission` | rumination enqueue failure returns the committed Feed ID plus visibility failure; retry starts rumination only and never submits the Feed again |
| scheduled mission notification | OS notification submission returns success | later projection refresh failure is committed-with-visibility-failure; all mission/squad/event reads occur before submission and are not-committed failures |

For proposal rollback failure the safe body is fixed to
`操作未完成，且恢复原状态失败。`; diagnostics contain the two stable classifier
codes in ordered keys `primaryCode` and `rollbackCode`, never either raw
description.

### 5.3 FailureReporter exact behavior

`FailureReporter` is a `Sendable` Core value over injected
`FailureRecordWriting` and `FailureLogSink` seams. `capture(error, trace:)`
accepts an already-created trace and a typed or unknown `Error`.
`prepare(error, trace:)` performs the same classification/scrub without a DB
write and is package-only for ContextDependencyLoader and McpToolBridge atomic
multi-row transactions. `persistPrepared(_:)` is the one package-only isolated
persistence fallback; it attempts exactly one upsert of the already scrubbed
record and returns only stored/unavailable metadata.
`complete(prepared:persistence:)` is package-only, writes the one terminal
stored/unavailable log record, and returns the prepared UserVisibleFailure; it
performs no DB mutation. Ordinary callers may not use prepare/persist/complete.
`capture` is exactly prepare → persistPrepared → complete.

The two atomic owners are exactly prepare → their named multi-row AppDatabase
transaction. On commit they complete `.stored`. On *any* transaction rollback,
including an event/degradation/Card statement after the failure upsert, the
owner invokes `persistPrepared` exactly once on the original PreparedFailure,
then completes with that result. It never captures a second database error,
changes trace/errorCode/message, retries the auxiliary statement, continues an
optional dependency, or dispatches provider/backend/tool work. Thus an
auxiliary rollback does not erase the original failure while the isolated
failure table remains writable; logger-only evidence is used only when that
bounded isolated upsert also fails. Capture then:

```swift
package enum FailureRecordState: String, Sendable, Equatable {
    case open, resolved
}
package struct FailureRecord: FetchableRecord, Sendable, Equatable {
    package let id: String
    package let operation: FailureOperation
    package let scope: FailureScope
    package let severity: FailureSeverity
    package let errorCode: FailureCode
    package let userMessage: String
    package let diagnosticJson: String
    package let state: FailureRecordState
    package let firstSeenAt: Date
    package let lastSeenAt: Date
    package let occurrenceCount: Int64
    package let resolvedAt: Date?
    package let redactedAt: Date?
    fileprivate init(validated classification: ValidatedFailureClassification,
                     trace: OperationTrace, diagnosticJson: String, now: Date)
    package init(row: Row) throws
}
package struct ContextDegradationRecord: FetchableRecord, Sendable, Equatable {
    package let id: String
    package let missionId: String?
    package let cardId: String?
    package let dependencyType: ContextDependencyType
    package let dependencyId: String
    package let policy: ContextDependencyPolicy
    package let traceId: String
    package let detail: String
    package let createdAt: Date
    package let redactedAt: Date?
    package init(id: String, missionId: String?, cardId: String?,
                 dependencyType: ContextDependencyType, dependencyId: String,
                 policy: ContextDependencyPolicy, traceId: String,
                 detail: String, createdAt: Date, redactedAt: Date?) throws
    package init(row: Row) throws
}
package struct PreparedFailure: Sendable {
    package let record: FailureRecord
    package let visible: UserVisibleFailure
    package init(record: FailureRecord, visible: UserVisibleFailure)
}
struct ValidatedFailureClassification: Sendable, Equatable {
    let code: FailureCode
    let severity: FailureSeverity
    let userBody: String
    let diagnostics: FailureDiagnostics
    fileprivate init(code: FailureCode, severity: FailureSeverity,
                     userBody: String, diagnostics: FailureDiagnostics)
}
enum FailureClassifier {
    static func classify(_ error: any Error,
                         trace: OperationTrace)
        -> ValidatedFailureClassification
}
enum FailureRecordFactory {
    static func prepared(
        classification: ValidatedFailureClassification,
        trace: OperationTrace,
        now: Date
    ) -> PreparedFailure
    static func bootstrapVisible(
        stage: ApplicationBootstrapStage,
        trace: OperationTrace
    ) -> UserVisibleFailure
}
package enum FailurePersistence: Sendable, Equatable {
    case stored
    case unavailable(reason: FailurePersistenceUnavailability)
}
package enum FailurePersistenceUnavailability: String, Sendable, Equatable {
    case failureRecordWriteFailed = "failure_record_write_failed"
}
package struct FailureLogEntry: Sendable, Equatable {
    package let traceId: String
    package let operation: FailureOperation
    package let scope: FailureScope
    package let errorCode: FailureCode
    package let persistence: FailurePersistence
    package init(traceId: String, operation: FailureOperation,
                 scope: FailureScope, errorCode: FailureCode,
                 persistence: FailurePersistence)
}
package protocol FailureRecordWriting: Sendable {
    func persistFailureRecord(_ record: FailureRecord) throws
}
package protocol FailureLogSink: Sendable {
    func write(_ entry: FailureLogEntry)
}
package struct SystemFailureLogSink: FailureLogSink, Sendable {
    package static let shared: SystemFailureLogSink
    package func write(_ entry: FailureLogEntry)
}
public struct FailureReporter: Sendable {
    public init(database: AppDatabase)
    package init(writer: any FailureRecordWriting,
                 logSink: any FailureLogSink)
    public func capture(_ error: any Error,
                        trace: OperationTrace) -> UserVisibleFailure
    package func prepare(_ error: any Error,
                         trace: OperationTrace) -> PreparedFailure
    package func persistPrepared(_ prepared: PreparedFailure)
        -> FailurePersistence
    package func complete(_ prepared: PreparedFailure,
                          persistence: FailurePersistence)
        -> UserVisibleFailure
}
package enum ApplicationBootstrapStage: String, Error, Sendable, Equatable {
    case previewUserDefaults
    case stateDirectory
    case databaseOpen
}
package struct ApplicationBootstrapFailureBoundary: Sendable {
    package init(traceFactory: OperationTraceFactory,
                 logSink: any FailureLogSink)
    package func makeTrace() -> OperationTrace
    package func capture(stage: ApplicationBootstrapStage,
                         trace: OperationTrace) -> UserVisibleFailure
    package func terminate(stage: ApplicationBootstrapStage,
                           trace: OperationTrace) -> Never
}
package struct ApplicationPostDatabaseBootstrapBoundary: Sendable {
    package init(reporter: FailureReporter)
    package func ensureCodingRanchBootstrap(
        trace: OperationTrace,
        _ body: @Sendable () throws -> CodingRanchBootstrapResult
    )
        -> OperationCommitOutcome<CodingRanchBootstrapResult>
}
```

`ValidatedFailureClassification`, `FailureClassifier`, and
`FailureRecordFactory` are module-internal declarations in
`FailureRecord.swift`; the validated/trusted initializers they use are
`fileprivate`, so neither AgentLoopApplication nor AgentLoopApp can name or
construct them.
`FailureClassifier` is the only constructor of the validated classification.
It exhaustively maps every error to already-valid closed fields rather than
calling a throwing metadata initializer. `FailureDiagnostics.canonicalJSON`
is a nonthrowing fixed-key renderer over those validated enum/integer fields;
it emits lexicographically sorted keys, omits nil fields, and has no arbitrary
String input or general-purpose encoder failure. The two
`FailureRecordFactory` functions are therefore nonthrowing because they accept
only a validated classification or the closed bootstrap stage plus an
already-valid trace; in the same file they call the `fileprivate` trusted
initializers of `FailureRecord`, `FailureDiagnostics`, and
`UserVisibleFailure` directly.
`FailureReporter.prepare` calls only `FailureClassifier` followed by
`FailureRecordFactory.prepared`; `ApplicationBootstrapFailureBoundary.capture`
calls only `FailureRecordFactory.bootstrapVisible`. No other production caller
is permitted. Compile-negative fixtures prove AgentLoopApplication and
AgentLoopApp cannot name those internal/fileprivate types or construct either closed
factory input from raw Strings. This keeps both nonthrowing boundaries legal
without adding a catch, force-try, optional suppression, or trap.

`AppDatabase` conforms to `FailureRecordWriting` only through its package
`persistFailureRecord` method. Production uses `public init(database:)` with
`SystemFailureLogSink.shared`; tests use the package initializer with a
throwing writer and a recording sink. Neither protocol is public API, and the
log sink receives only the already-scrubbed closed `FailureLogEntry`—never an
`Error`, diagnostic blob, path, credential, external body, or display name.

The pre-composition boundary exists because no database-backed reporter can
exist before process-local preview defaults, state-directory lock, and database
open. AppStore constructs this one boundary and calls `makeTrace` before
`makeUserDefaults` or any other fallible composition action. `makeTrace` always
uses `.applicationBootstrap` plus the fixed application coordinate. `capture`
accepts no `Error`, path, URL, suite name, or arbitrary text. It requires that
exact trace, selects only the fixed body
`应用预览偏好存储不可用。`/`应用状态目录不可用。`/`应用数据库无法打开。`, uses
`unexpected_failure`/`unexpected_failure`/`database_read_failed` respectively, constructs the safe
full-trace message, and writes exactly one `FailureLogEntry` with
`.unavailable(.failureRecordWriteFailed)`. AppStore then terminates with that
same message. `AppStore.makeUserDefaults()` returns the closed
`Result<UserDefaults, ApplicationBootstrapStage>` and never traps; its only
failure is `.previewUserDefaults`, selected when the DEBUG process-local suite
cannot be created. AppStore exhaustively switches that result and delegates the
failure to this same boundary. Tests invoke the actual boundary for all three
stages with a recording sink; source gates prove the two later AppStore catch
arms discard the raw Error and that the earlier defaults failure also delegates
here. Production AppStore delegates all three failures only to
`terminate(stage:trace:)`. That method calls `capture` exactly once, then its
sole next statement is `preconditionFailure(failure.message)`; this is the one
fixed safe pre-composition `Never` primitive. Pre-composition AppStore contains
no independent trap or process-exit choice; the later DEBUG-only preview-audit
failure exit is a different, exactly inventoried post-composition terminal.
After AppDatabase and FailureReporter exist,
`ApplicationPostDatabaseBootstrapBoundary.ensureCodingRanchBootstrap` owns
`ensureCodingRanchBootstrap`: success returns the exact committed
`CodingRanchBootstrapResult`; a failure is captured with the same
application-bootstrap trace, returns not-committed, keeps dispatch halted, and
permits a visible retry. It never discards the result, terminates, or constructs
an empty ranch. That terminal is truthful because
`ProductBootstrapService.swift` now owns one and only one `pool.write`:

```swift
@discardableResult
public func ensureCodingRanchBootstrap() throws
    -> CodingRanchBootstrapResult {
    try pool.write { database in
        let camp = try Self.ensureDefaultCamp(database)
        // guide upgrade, existing-base/expert checks, base-cow insert, and
        // base_cow_provisioned event all use this same database handle.
    }
}
```

The public `ProductBootstrapService.ensureBootstrap()` and
`AppDatabase.ensureCodingRanchBootstrap()` signatures stay unchanged. The
bootstrap must reuse the existing `AppDatabase.ensureDefaultCamp(_:)` helper;
it may not call the public `ensureDefaultCamp()`, start a nested transaction or
savepoint, invent compensation, classify a throw as committed, or add a
retry-after-commit API. Thus any throw rolls back the complete
Camp/guide-upgrade/base-cow/event unit, and a visible retry reruns one
idempotent transaction. The boundary implements the already-inventoried
`N[.codingRanchBootstrapCapture]` with `Result(catching:)` followed by an
exhaustive success/failure switch, not a new lexical `catch`; the equivalent
ledger classifies this exact final-only `nonthrowingResultWrapper`; the
fourteen-row planned-catch manifest therefore keeps its exact count. Any other
`Result(catching:)` or `Result { try ... }` wrapper in scope is unclassified
and fails the negative gate. Its callable carries
`// P1-B-SEAM applicationPostDatabaseBootstrap`; the pre-database boundary
alone carries `// P1-B-SEAM applicationBootstrap`.

AppStore owns the exact Ranch and Runtime projections plus one
`ApplicationStartupGate`; it has no second start-once Boolean. Before `self` is
available, composition invokes the exact Runtime and Ranch boundaries once into
two closed local terminals, constructs every downstream object without starting
it, and initializes the two projections and the gate from those terminals. The
initializer never claims the gate and never starts downstream work. After the
fully initialized AppStore is installed in the SwiftUI environment, RootView's
existing `onAppear` calls the synchronous
`activatePostBootstrapDispatchIfReady()` entry before its ordinary reload. That
entry is repeat-safe and is the sole initial caller of `claimStartIfReady`.
This preserves the Runtime snapshot needed to construct Orchestrator without
calling an instance method on partially initialized `self` or opening dispatch
before initialization returns. The visible RootView retry methods are
`runCodingRanchBootstrap()` and `runRuntimeBootstrap()`; each reuses the same
stored boundary dependencies and is accepted only from its exact failed state.
Ranch attempts mint `.applicationBootstrap + .fixed(.application)`; Runtime
attempts mint `.runtimeBootstrap + .fixed(.runtimeBootstrap)`. The real Ranch boundary emits only
`.notCommitted` or `.committed`; a fixture-only
`.committedWithVisibilityFailure(result,failure)` is handled as committed plus
displayed refresh evidence and enters the same joint gate. `.notCommitted` and
Runtime `.failed` store the exact failure and start zero Runtime reload,
listener, startup recovery, scheduler, provider, or Kernel dispatch. A Ranch
`.committed(result)` installs the result then calls
`acceptCodingRanchLoaded`; a Runtime `.loaded(snapshot)` installs the snapshot
then calls `acceptRuntimeLoaded`. Only `.startNow` invokes all existing
post-bootstrap dispatch. RootView calls only the activation entry and these two
retry methods, never the database, bootstrap objects, ProductBootstrapService,
or downstream start sequence directly.

The Ranch outcome-to-state switch is exhaustive and identical for initial and
retry paths: `.notCommitted(failure)` becomes `.failed(failure)`;
`.committed(result)` becomes `.loaded(result)`; and the fixture-only
`.committedWithVisibilityFailure(value: result, failure: failure)` becomes
`.loaded(result)` while installing that same `failure` as independent visible
refresh evidence. Only the latter two produce a typed gate acceptance. Initial
composition performs this switch into locals before `self`; after all stored
properties are initialized, no constructor work remains. Retry performs the
same switch in its one no-await terminal-apply segment. There is no default,
Void discard, fabricated result, or path that treats not-committed as ready.

The pre-self local pipeline is exact. After AppDatabase and FailureReporter
exist, composition constructs and retains one
`ApplicationPostDatabaseBootstrapBoundary` and one
`ProductBootstrapService`. It then creates separate fresh Runtime and Ranch
traces, evaluates the binary Runtime capture, constructs
`localRuntimeProjection = WorkflowProjection(initial: runtimeResult)`, invokes
the Ranch boundary exactly once around
`productBootstrapService.ensureBootstrap()`, and exhaustively derives
`localCodingRanchState` plus optional fixture visibility evidence. Finally it
constructs
`localStartupGate = ApplicationStartupGate(runtime:
localRuntimeProjection.state, codingRanch: localCodingRanchState)`. These three
locals are assigned to the three non-defaulted stored carriers exactly once
during initialization. The retained Runtime bootstrap/request and retained
Ranch boundary/service are the only dependencies their matching retry method
may call. No retry reconstructs AppDatabase, Reporter, ProductBootstrapService,
or a boundary, and no initial path starts downstream work.

```swift
@MainActor
final class AppStore {
    private var applicationStartupGate: ApplicationStartupGate
    private let synchronousRuntimeBootstrap: SynchronousRuntimeBootstrap
    private let runtimeBootstrapRequest: RuntimeBootstrapRequest
    private let codingRanchBootstrapBoundary:
        ApplicationPostDatabaseBootstrapBoundary
    private let productBootstrapService: ProductBootstrapService
    func activatePostBootstrapDispatchIfReady()
    func runCodingRanchBootstrap()
    func runRuntimeBootstrap()
    private func applyStartupGateDecision(
        _ decision: ApplicationStartupGateDecision
    )
}
```

Each retry method sets only its matching projection `.loading`, creates its
trace, synchronously invokes its frozen boundary, and applies the terminal in
one MainActor segment. Runtime uses `captureSynchronousLoad` around its retained
bootstrap/request. A retry tap is accepted only from the matching exact
`.failed` state; loading/loaded taps are zero-work. Runtime-failed + Ranch-loaded and Ranch-failed +
Runtime-loaded both remain halted; recovery of the missing peer starts once.
Both-loaded in either order starts once, and repeats return `.alreadyStarted`
with zero downstream calls.

`activatePostBootstrapDispatchIfReady()` performs no bootstrap, trace, DB,
Keychain, listener, or provider work of its own. In one no-await MainActor
segment it claims the stored gate and passes the closed decision to
`applyStartupGateDecision`. Each successful bootstrap terminal first installs
its exact loaded projection, then passes the corresponding typed `accept...`
decision to that same private decision applier. The applier exhaustively maps
`.waitingForOther` and `.alreadyStarted` to zero work and `.startNow` to the one
existing downstream start sequence. RootView has no other downstream-start
edge, and repeated window appearances cannot start twice.

The AppStore initializer contains zero calls to `reload` and
`startKernelEventListener`; its former initial reload is the existing RootView
`onAppear` reload, ordered immediately after activation. The sole
`startKernelEventListener(recoverKernel:)` call site is the `.startNow` arm of
`applyStartupGateDecision`, so the listener consumer, startup recovery, and
scheduler cannot be reached from construction, reload, or either non-start
decision.

The only write entry points are exact package AppDatabase methods:

```swift
package enum ContextFailureCardDisposition: Sendable, Equatable {
    case leaveReady
    case block
}
extension AppDatabase {
    // P1-B-SEAM databaseKernelEventWrite
    public func appendKernelErrorEvent(
        missionId: String,
        message: String
    ) throws
    package func persistFailureRecord(_ record: FailureRecord) throws
    package func failureRecord(id: String) throws -> FailureRecord?
    package func contextDegradations(missionId: String?, cardId: String?,
                                     limit: Int = 200) throws
        -> [ContextDegradationRecord]
    package func resolveFailureRecord(id: String, resolvedAt: Date) throws
        -> FailureRecord
    package func persistContextFailure(
        _ prepared: PreparedFailure,
        degradation: ContextDegradationRecord,
        cardId: String,
        disposition: ContextFailureCardDisposition
    ) throws
    package func persistMcpConnectionDown(
        _ prepared: PreparedFailure,
        missionId: String,
        cardId: String,
        serverId: String
    ) throws
}
```

The latter two each open exactly one `pool.write` and call the same private
static failure-upsert helper. Context block uses existing Card transition/event
helpers with reason `context_unavailable` and the already-safe full trace
message; leaveReady performs no Card write. MCP appends the existing
`mcp_server_down` event with payload exactly `serverId`, `errorCode`, and
`traceId`; no server/tool display name or detail. There is no public writer,
generic PersistableRecord ownership, or Bridge/Loader access to raw SQL.

`appendKernelErrorEvent` is the sole retained public event façade and is now
throwing. Its old internal catch/logger is deleted; it inserts only the
existing `kernel_error` event and propagates a DB failure to the top-level
owner that already has the operation trace. It never creates a second trace or
calls FailureReporter. P1-B callers may pass only fixed domain text or an
already-scrubbed `UserVisibleFailure.message`. The source gate requires one
declaration, explicit `try` at every call, and zero nonthrowing overload,
`try?`, `try!`, raw/reflected message, or ignored result. The injected owner
case proves synchronous throw, zero event/logger/second trace, and one capture
by the original owner.

The read/resolve surface is equally closed. `failureRecord(id:)` validates the
trace grammar and returns nil only for a genuinely absent row.
`contextDegradations` requires at least one non-nil Mission/Card filter and a
limit in `1...200`; it ORs the supplied exact-ID filters and orders
`createdAt ASC, id ASC`. It is the sole cold-UI degradation query.
`resolveFailureRecord` opens one `pool.write`: an absent ID throws
`RecordNotFoundError`, a redacted row throws `FailureRecordRedactedError`, an
open row changes only `state='resolved'` and `resolvedAt`, and an already-
resolved row returns byte-identically. It never infers resolution from another
operation or changes last-seen/count/diagnostics. Every returned row uses the
explicit persisted-row validator; corruption throws instead of disappearing.

`capture` and `persistPrepared` are deliberately nonthrowing only at the
observability boundary: they do not hide the business error (the caller still returns/throws the resulting
typed failure), and it guarantees that a failure-table outage cannot erase the
safe UI/log result. The writer seam itself throws; `capture` converts only that
secondary persistence result to `.unavailable`. `prepare` validates trace and
record invariants with preconditions already guaranteed by OperationTrace
construction; it never performs I/O. `complete` accepts no arbitrary Error and
therefore cannot accidentally log raw persistence detail. `persistPrepared`
accepts no Error and performs no recursive capture; its catch arm emits no
raw/reflected persistence detail and is one of the explicitly classified
equivalent-fallback residuals in the inventory appendix.

1. maps only known typed errors into a stable category/errorCode/safe user
   message/diagnostic allowlist;
2. maps unknown errors to `unexpected_failure` and a fixed safe message without
   persisting `localizedDescription`, reflection, raw SQL, raw provider/MCP
   response, path, prompt, credential, account, callback, or secret;
3. encodes diagnostic JSON with sorted keys and exact typed keys limited to
   a stable classifier category, optional GRDB result code, OSStatus/HTTP status,
   attempt, dependency type/policy, retryable, a stable non-user domain, and the
   composite-only stable `primaryCode`/`rollbackCode` pair;
4. budgets the sanitized body so the final `操作失败…\n追踪 ID：<trace>`
   `userMessage` is at most 1000 SQLite `length(TEXT)` units. For a valid Swift
   string this is Unicode scalar/code-point count, not grapheme-cluster count or
   UTF-8 byte count. The formatter counts the fixed prefix, newline, fixed trace
   label, and full trace suffix, then takes the longest body prefix whose
   `unicodeScalars.count` fits. The exact formatted Swift string must insert
   byte-identically without a second truncation. Diagnostic JSON remains a
   separate fixed 4096 UTF-8-byte ceiling before database access;
5. inserts one open failure with `firstSeenAt == lastSeenAt`, count 1, nil
   resolution/redaction;
6. for the same trace only, permits an occurrence increment when operation,
   scope, severity, errorCode, and userMessage match; it updates lastSeen,
   count, and latest scrubbed diagnostics and reopens a resolved row. Identity
   mismatch, overflow, or malformed persisted data throws a typed integrity
   error and never overwrites the old row;
7. writes the same full trace and safe errorCode to `os.Logger` whether the DB
   write succeeds or fails;
8. returns `UserVisibleFailure` with the original trace even when persistence
   fails.

No recursive capture is attempted when the failure table itself cannot be
written. P1-B provides an explicit typed resolve store API (used only by an
owning workflow after verified recovery); it does not infer resolution from an
unrelated success. There is no redact UI/API; later lifecycle slices own it.

An existing row whose `redactedAt` is non-nil is an immutable tombstone.
Insert/upsert, occurrence increment, reopen, resolve, or diagnostic refresh for
that trace throws `FailureRecordRedactedError`; it never changes occurrence,
timestamps, resolution, `[deleted]`, or `{}`. Reporter completes the current
operation as persistence-unavailable and writes only the safe same-trace log.
This rule is tested with a pre-redacted row and is not deferred to a future UI.

Stable codes cover `database_read_failed`, `database_write_failed`,
`projection_decode_failed`; Keychain read/write/delete/value-invalid; OAuth
state/token/commit/rollback; runtime profile read/write/delete/reconcile;
mission read/write/state transition; rumination read/start/cancel; MCP registry,
missing server/secret, secret read, start/list/required-tool/call; knowledge
read; memory read/provider/write/race; notification projection,
cleanup-integrity, and `unexpected_failure`. Typed classifier coverage includes
GRDB/database, non-not-found
`KeychainError`, MCP registry/config/secret/start/list/call errors,
MemoryDistill errors, context dependency failures, record/state transition
errors, cancellation, and generic unknown. `errSecItemNotFound` never enters
the error classifier because `KeychainStore.get` returns `nil` only for that
status.

Unknown errors never record a reflected Swift type. Their diagnostic JSON is
exactly the stable category/domain pair plus the operation-owned retryable bit;
`localizedDescription`, `String(describing:)`, and
`String(reflecting: type(of:))` are forbidden inputs.

### 5.4 Frozen classifier and scope map

The registry is closed and compiled, rather than accepting free-form metadata:

```swift
public enum FailureOperation: String, Codable, Sendable, CaseIterable {
    case applicationBootstrap = "application.bootstrap"
    case runtimeBootstrap = "runtime.bootstrap"
    case runtimeLoad = "runtime.load"
    case runtimeProviderResolve = "runtime.provider.resolve"
    case runtimeSearchResolve = "runtime.search.resolve"
    case runtimeProfileSave = "runtime.profile.save"
    case runtimeProfileDelete = "runtime.profile.delete"
    case runtimeProfileSwitch = "runtime.profile.switch"
    case runtimeCatalogRefresh = "runtime.catalog.refresh"
    case runtimeProviderTest = "runtime.provider.test"
    case runtimeCredentialSet = "runtime.credential.set"
    case runtimeCredentialDelete = "runtime.credential.delete"
    case oauthAuthorization = "oauth.authorization"
    case oauthCallbackExchange = "oauth.callback.exchange"
    case oauthRefreshCommit = "oauth.refresh.commit"
    case oauthUnauthorizedDelete = "oauth.unauthorized.delete"
    case missionIndexLoad = "mission.index.load"
    case missionDetailLoad = "mission.detail.load"
    case missionStart = "mission.start"
    case missionCancel = "mission.cancel"
    case missionHarvest = "mission.harvest"
    case missionAccept = "mission.accept"
    case missionAnswer = "mission.answer"
    case missionConfirmProposal = "mission.proposal.confirm"
    case missionRetryContext = "mission.context.retry"
    case missionReturnForRework = "mission.rework"
    case missionAddBudget = "mission.budget.add"
    case missionBudgetEvent = "mission.budget.event"
    case missionRateLimitEvent = "mission.rate_limit.event"
    case missionRetryCard = "mission.card.retry"
    case missionClearReview = "mission.card.review.clear"
    case missionAutonomyWrite = "mission.autonomy.write"
    case missionProposalDismiss = "mission.proposal.dismiss"
    case missionReportEnsure = "mission.report.ensure"
    case missionReportOpen = "mission.report.open"
    case missionRunFinish = "mission.run.finish"
    case inputCampLoad = "input.camp.load"
    case inputReviewLoad = "input.review.load"
    case inputFeedSubmit = "input.feed.submit"
    case inputRuminationStart = "input.rumination.start"
    case inputRuminationCancel = "input.rumination.cancel"
    case inputReviewSave = "input.review.save"
    case inputMaterialize = "input.materialize"
    case inputDelete = "input.delete"
    case inputMissionDraft = "input.mission_draft.create"
    case inputCowUnlock = "input.cow.unlock"
    case campRename = "camp.rename"
    case campCreate = "camp.create"
    case campArchive = "camp.archive"
    case campWritableRead = "camp.writable.read"
    case campNoteSave = "camp.note.save"
    case campNoteDelete = "camp.note.delete"
    case campNotePin = "camp.note.pin"
    case campKnowledgeLoad = "camp.knowledge.load"
    case companionEditorLoad = "companion.editor.load"
    case companionEditorSave = "companion.editor.save"
    case memoryDMDistill = "memory.dm.distill"
    case memoryGuideDistill = "memory.guide.distill"
    case memoryNoteLoad = "memory.note.load"
    case memoryNoteSave = "memory.note.save"
    case memoryNoteDelete = "memory.note.delete"
    case memoryNotePin = "memory.note.pin"
    case mcpRegistryLoad = "mcp.registry.load"
    case mcpCampLoad = "mcp.camp.load"
    case mcpToolList = "mcp.tool.list"
    case mcpServerStart = "mcp.server.start"
    case mcpServerRestart = "mcp.server.restart"
    case mcpSecretPresence = "mcp.secret.presence"
    case mcpSecretSave = "mcp.secret.save"
    case mcpServerAdd = "mcp.server.add"
    case mcpSetEnabled = "mcp.server.enable"
    case mcpServerDelete = "mcp.server.delete"
    case mcpToolCall = "mcp.tool.call"
    case contextToolAccess = "context.tool_access"
    case contextSearch = "context.search"
    case contextMcpServer = "context.mcp.server"
    case contextMcpTool = "context.mcp.tool"
    case contextCampNotes = "context.camp_notes"
    case contextCompanionNotes = "context.companion_notes"
    case scheduleLoad = "schedule.load"
    case scheduleTemplateSave = "schedule.template.save"
    case scheduleTemplateDelete = "schedule.template.delete"
    case scheduleSave = "schedule.save"
    case scheduleEnable = "schedule.enable"
    case scheduleDelete = "schedule.delete"
    case scheduleNotification = "schedule.notification"
    case scheduleRefresh = "schedule.refresh"
    case scheduleFire = "schedule.fire"
    case scheduleReplay = "schedule.replay"
    case scheduleWake = "schedule.wake"
    case scheduleBroadcast = "schedule.broadcast"
    case haltRead = "halt.read"
    case haltPersist = "halt.persist"
    case dispatchResume = "dispatch.resume"
    case reconcile = "dispatch.reconcile"
    case startupRecovery = "startup.recovery"
    case chatLoad = "chat.load"
    case chatSend = "chat.send"
    case guideChatLoad = "guide_chat.load"
    case guideChatSend = "guide_chat.send"
    case projectionApply = "projection.apply"
    case previewRuntimeRead = "preview.runtime.read"
    public var accessibilityLabel: String {
        switch self {
        case .applicationBootstrap:
            return "应用启动"
        case .runtimeBootstrap, .runtimeLoad, .runtimeProviderResolve,
             .runtimeSearchResolve, .runtimeProfileSave,
             .runtimeProfileDelete, .runtimeProfileSwitch,
             .runtimeCatalogRefresh, .runtimeProviderTest,
             .runtimeCredentialSet, .runtimeCredentialDelete:
            return "运行供给线"
        case .oauthAuthorization, .oauthCallbackExchange,
             .oauthRefreshCommit, .oauthUnauthorizedDelete:
            return "网页登录"
        case .missionIndexLoad, .missionDetailLoad, .missionStart,
             .missionCancel, .missionHarvest, .missionAccept,
             .missionAnswer, .missionConfirmProposal,
             .missionRetryContext, .missionReturnForRework,
             .missionAddBudget, .missionBudgetEvent,
             .missionRateLimitEvent, .missionRetryCard,
             .missionClearReview, .missionAutonomyWrite,
             .missionProposalDismiss, .missionReportEnsure,
             .missionReportOpen, .missionRunFinish:
            return "任务执行"
        case .inputCampLoad, .inputReviewLoad, .inputFeedSubmit,
             .inputRuminationStart, .inputRuminationCancel,
             .inputReviewSave, .inputMaterialize, .inputDelete,
             .inputMissionDraft, .inputCowUnlock:
            return "资料处理"
        case .campRename, .campCreate, .campArchive, .campWritableRead,
             .campNoteSave, .campNoteDelete, .campNotePin,
             .campKnowledgeLoad:
            return "营地管理"
        case .companionEditorLoad, .companionEditorSave:
            return "伙伴设置"
        case .memoryDMDistill, .memoryGuideDistill, .memoryNoteLoad,
             .memoryNoteSave, .memoryNoteDelete, .memoryNotePin:
            return "记忆整理"
        case .mcpRegistryLoad, .mcpCampLoad, .mcpToolList,
             .mcpServerStart, .mcpServerRestart, .mcpSecretPresence,
             .mcpSecretSave, .mcpServerAdd, .mcpSetEnabled,
             .mcpServerDelete, .mcpToolCall:
            return "外部工具"
        case .contextToolAccess, .contextSearch, .contextMcpServer,
             .contextMcpTool, .contextCampNotes, .contextCompanionNotes:
            return "上下文准备"
        case .scheduleLoad, .scheduleTemplateSave,
             .scheduleTemplateDelete, .scheduleSave, .scheduleEnable,
             .scheduleDelete, .scheduleNotification, .scheduleRefresh,
             .scheduleFire, .scheduleReplay, .scheduleWake,
             .scheduleBroadcast:
            return "定时行动"
        case .haltRead, .haltPersist, .dispatchResume, .reconcile,
             .startupRecovery:
            return "牧场调度"
        case .chatLoad, .chatSend, .guideChatLoad, .guideChatSend:
            return "对话"
        case .projectionApply:
            return "界面状态更新"
        case .previewRuntimeRead:
            return "预览验证"
        }
    }
}

public enum FailureSeverity: String, Codable, Sendable, CaseIterable {
    case info, warning, error, critical
}
public enum FailureScopeType: String, Codable, Sendable, CaseIterable {
    case application, database, credential, oauth, camp, mission, card
    case ingestion, companion
    case runtimeProfile = "runtime_profile"
    case campNote = "camp_note"
    case companionNote = "companion_note"
    case mcpServer = "mcp_server"
    case mcpTool = "mcp_tool"
    case schedule, notification, projection
}
package enum FailureRecordKind: String, Sendable, Equatable {
    case camp, mission, card, ingestion, runtimeProfile, companion
    case campNote, companionNote, mcpServer, schedule
}
public struct FailureRecordID: Sendable, Equatable, Hashable {
    public let rawValue: String
    package let recordKind: FailureRecordKind
    private init(validatedRawValue: String, recordKind: FailureRecordKind)
    package static func camp(_ record: CampRecord) throws -> Self
    package static func mission(_ record: MissionRecord) throws -> Self
    package static func card(_ record: CardRecord) throws -> Self
    package static func ingestion(_ record: IngestionItemRecord) throws -> Self
    package static func runtimeProfile(_ record: RuntimeProfileRecord) throws -> Self
    package static func companion(_ record: CompanionRecord) throws -> Self
    package static func campNote(_ record: CampNoteRecord) throws -> Self
    package static func companionNote(_ record: CompanionNoteRecord) throws -> Self
    package static func mcpServer(_ record: McpServerRecord) throws -> Self
    package static func schedule(_ record: ScheduleRecord) throws -> Self
}
package enum FailureFixedCoordinate: String, Sendable, Equatable, CaseIterable {
    case application, database, runtime, runtimeBootstrap
    case credential, oauth, missionIndex, mcpRegistry, scheduleIndex
    case notification, projection, preview
    case memoryDM = "memory_dm"
    case memoryGuide = "memory_guide"
}
public struct FailureScope: Sendable, Equatable {
    public let campId: String?
    public let type: FailureScopeType
    public let id: String
    fileprivate init(campId: String?, type: FailureScopeType, id: String)
    package static func validatingPersistedRow(scopeType: String,
                                               scopeId: String,
                                               campId: String?) throws -> Self
}
package struct FailureTraceScope: Sendable, Equatable {
    fileprivate let value: FailureScope
    package static func fixed(_ coordinate: FailureFixedCoordinate) -> Self
    package static func global(recordId: FailureRecordID,
                               as type: FailureScopeType) throws -> Self
    package static func camp(campId: FailureRecordID,
                             recordId: FailureRecordID,
                             as type: FailureScopeType) throws -> Self
}
```

`FailureOperation.accessibilityLabel` is the exhaustive fixed Chinese switch
above. It never interpolates even a closed persisted raw. VoiceOver's exact terminal label
is `"\(failure.operation.accessibilityLabel)。\(failure.message)"`; the safe
message already contains the full trace exactly once. Raw-value decoding can
produce only a listed case. Operation raws are at most 64 ASCII bytes and scope
type raws at most 32. `FailureRecordID` accepts exactly 1...128 ASCII
`[A-Za-z0-9._:-]` characters. `FailureRecordID` also retains its private typed
record kind after factory construction; two equal raw IDs from different
record kinds are therefore not interchangeable. Package constructors enforce
the coordinate map: fixed coordinates map exhaustively to
`application/application`, `database/database`, `runtime_profile/runtime`,
`runtime_profile/runtime_bootstrap`, `credential/credential`, `oauth/oauth`,
`mission/mission_index`, `mcp_server/mcp_registry`,
`schedule/schedule_index`, `notification/notification`,
`projection/projection`, `projection/preview`, `application/memory_dm`, and
`application/memory_guide`; record IDs are
minted only by the ten typed record factories above; there is no raw-String
package/public initializer. `mcpTool` reuses a typed MCP-server coordinate and
notification reuses a typed Mission coordinate. A Camp scope requires both a
typed Camp coordinate and a compatible typed owner coordinate. Account
names, paths, prompts, callback values, server display names, MCP tool names,
external types/bodies, and arbitrary strings are rejected even if they match
the grammar. Production scope creators are source-gated to a record already
loaded by the owning read/command; operations before such a record exists use
one of the fixed global coordinates. MCP-tool failures use the opaque server record ID with type
`mcpTool`; the external tool name is never a coordinate.

`FailureRecordID`, `FailureTraceScope`, and `FailureScope` are deliberately not
`Codable`. This prevents synthesized or public decoding from forging loaded-
record provenance. `FailureRecord.init(row:)` and
`ContextDegradationRecord.init(row:)` read their primitive columns and call
`FailureScope.validatingPersistedRow`; that read-only path rechecks enum raws,
the 1...128 ASCII grammar, and the legal fixed/global/Camp column shape. It does
not create a `FailureTraceScope` and cannot be fed to `OperationTraceFactory`.
Unknown raws, malformed stored IDs, synthesized-memberwise bypass, or illegal
coordinates throw `FailureMetadataValidationError` before a row is projected.

Exact fixed coordinate pairs are the exhaustive mapping above. Global record
coordinates may use runtimeProfile, camp,
mission, card, ingestion, companion, mcpServer, mcpTool, schedule, or
notification with the corresponding loaded record ID. Camp coordinates may use
mission/card/ingestion/companion/campNote/companionNote/mcpServer/mcpTool/
schedule and require both loaded Camp ID and matching owner record ID. Every
other type/ID/camp combination throws `FailureMetadataValidationError` before
database/log/UI access.

The operation-owner manifest is exact. Each listed entry creates/adopts one
trace before its first fallible action; all nested literal/equivalent inventory
rows reuse it unless the context row explicitly requires a per-dependency
trace. Source carries `// P1-B-OP <case>` at each creator and the gate compares
the creator path/function/case triple, so a free-form operation cannot appear.

| FailureOperation cases | Exact top-level owner(s) |
|---|---|
| `applicationBootstrap` | AppStore synchronous state-directory/database/Coding-Ranch composition |
| `runtimeBootstrap`, `runtimeLoad` | SynchronousRuntimeBootstrap; Runtime controller load/reload façade |
| `runtimeProviderResolve`, `runtimeSearchResolve`, `runtimeProviderTest` | RuntimeCredentialResolver provider/search; settings provider test |
| `runtimeProfileSave`, `runtimeProfileDelete`, `runtimeProfileSwitch`, `runtimeCatalogRefresh` | matching Runtime controller commands only |
| `runtimeCredentialSet`, `runtimeCredentialDelete` | Runtime controller API/search credential commands |
| `oauthAuthorization`, `oauthCallbackExchange` | Runtime controller begin/resume authorization and callback façade; every controller-current accepted retry or asynchronous listener-failure job mints one fresh trace from the retained opaque scope, while a stale retry is rejected before trace creation and sub-stages inside one accepted invocation share only that invocation trace |
| `oauthRefreshCommit`, `oauthUnauthorizedDelete` | OpenAIOAuthSession refresh and permanent-unauthorized serialized commands; initial callback credential commit stays inside `oauthCallbackExchange` |
| `missionIndexLoad`, `missionDetailLoad` | Mission controller `loadIndex`/`loadDetail` |
| `missionStart`, `missionCancel`, `missionHarvest`, `missionAccept` | matching Mission controller/Orchestrator traced command |
| `missionAnswer`, `missionConfirmProposal`, `missionProposalDismiss` | answer/confirm/dismiss façade and traced Core command |
| `missionRetryContext`, `missionRetryCard`, `missionReturnForRework` | exact retry/rework command |
| `missionAddBudget`, `missionBudgetEvent`, `missionRateLimitEvent` | exact budget/cooldown owner; event-only retry never repeats provider/mutation |
| `missionClearReview`, `missionAutonomyWrite`, `missionReportEnsure`, `missionReportOpen`, `missionRunFinish` | matching App façade/Core run-finish command |
| `inputCampLoad`, `inputReviewLoad` | Input controller read bundles, including dashboard/inbox projections |
| `inputFeedSubmit`, `inputRuminationStart`, `inputRuminationCancel`, `inputReviewSave`, `inputMaterialize`, `inputDelete`, `inputMissionDraft`, `inputCowUnlock` | matching Input controller command |
| `campCreate`, `campArchive`, `campWritableRead`, `campRename` | matching Camp façade command |
| `campNoteSave`, `campNoteDelete`, `campNotePin`, `campKnowledgeLoad` | matching Camp knowledge command/load |
| `companionEditorLoad`, `companionEditorSave` | Application companion-editor projection helper/facade |
| `memoryDMDistill`, `memoryGuideDistill` | MemoryDistillService public entries |
| `memoryNoteLoad`, `memoryNoteSave`, `memoryNoteDelete`, `memoryNotePin` | matching memory drawer/controller operation |
| `mcpRegistryLoad`, `mcpCampLoad`, `mcpToolList` | matching MCP controller load |
| `mcpServerStart`, `mcpServerRestart`, `mcpServerAdd`, `mcpSetEnabled` | matching manager/controller command |
| `mcpSecretPresence`, `mcpSecretSave`, `mcpServerDelete`, `mcpToolCall` | matching credential/maintenance/Bridge command |
| `contextToolAccess` | one trace for invalid ToolAccess or CLI unsupported selection |
| `contextSearch`, `contextMcpServer`, `contextMcpTool`, `contextCampNotes`, `contextCompanionNotes` | one distinct trace immediately before each selected dependency attempt |
| `scheduleLoad`, `scheduleTemplateSave`, `scheduleTemplateDelete`, `scheduleSave`, `scheduleEnable`, `scheduleDelete`, `scheduleNotification`, `scheduleRefresh`, `scheduleFire`, `scheduleReplay`, `scheduleWake`, `scheduleBroadcast` | matching App schedule façade, scheduler, wake, replay, broadcast, and notifier operation |
| `haltRead`, `haltPersist`, `dispatchResume`, `reconcile`, `startupRecovery` | exact Orchestrator control command/recovery loop |
| `chatLoad`, `chatSend`, `guideChatLoad`, `guideChatSend` | matching chat façade operation |
| `projectionApply` | WorkflowProjection contract failure and companion-editor pure projection helper |
| `previewRuntimeRead` | DEBUG isolated failure-preview injected Runtime read only |

Every enum case appears in exactly one manifest row. The 133 literal-inventory
semantic cases and 134 `E[...]` cases point to these owner methods in the
inventory/test descriptor; cleanup-only/stale/rethrow rows create no new trace.
Here “cleanup-only rows” means the four inventory cancellation sleeps; the
explicit user-initiated MCP pending-cleanup retry is a new top-level
`mcpServerDelete` operation; its controller creates the trace from the retained
validated scope before the first flight/port action.
The test descriptor invokes the owner seam and checks the actual operation case
stored in `failure_record`, not a hard-coded expected-value echo.

`FailureCode` is likewise closed. The Swift case identifiers and persisted raws
are exact—implementation may not infer or rename them:

```swift
public enum FailureCode: String, Codable, Sendable, CaseIterable {
    case databaseReadFailed = "database_read_failed"
    case databaseWriteFailed = "database_write_failed"
    case recordNotFound = "record_not_found"
    case projectionDecodeFailed = "projection_decode_failed"
    case projectionContractFailed = "projection_contract_failed"
    case keychainReadFailed = "keychain_read_failed"
    case keychainWriteFailed = "keychain_write_failed"
    case keychainDeleteFailed = "keychain_delete_failed"
    case credentialValueInvalid = "credential_value_invalid"
    case oauthStateInvalid = "oauth_state_invalid"
    case oauthAuthorizationFailed = "oauth_authorization_failed"
    case oauthListenerFailed = "oauth_listener_failed"
    case oauthTokenExchangeFailed = "oauth_token_exchange_failed"
    case oauthCredentialCommitFailed = "oauth_credential_commit_failed"
    case oauthCredentialRollbackFailed = "oauth_credential_rollback_failed"
    case oauthCredentialDeleteFailed = "oauth_credential_delete_failed"
    case runtimeProfileReadFailed = "runtime_profile_read_failed"
    case runtimeProfileWriteFailed = "runtime_profile_write_failed"
    case runtimeProfileDeleteFailed = "runtime_profile_delete_failed"
    case runtimeReconcileFailed = "runtime_reconcile_failed"
    case runtimeProviderUnavailable = "runtime_provider_unavailable"
    case runtimeModelUnsupported = "runtime_model_unsupported"
    case runtimeEndpointInvalid = "runtime_endpoint_invalid"
    case missionReadFailed = "mission_read_failed"
    case missionWriteFailed = "mission_write_failed"
    case missionTransitionFailed = "mission_transition_failed"
    case missionVisibilityFailed = "mission_visibility_failed"
    case traceIdentityConflict = "trace_identity_conflict"
    case proposalRecoveryFailed = "proposal_recovery_failed"
    case ruminationReadFailed = "rumination_read_failed"
    case ruminationStartFailed = "rumination_start_failed"
    case ruminationCancelFailed = "rumination_cancel_failed"
    case mcpRegistryReadFailed = "mcp_registry_read_failed"
    case mcpServerNotFound = "mcp_server_not_found"
    case mcpConfigInvalid = "mcp_config_invalid"
    case mcpSecretMissing = "mcp_secret_missing"
    case mcpSecretReadFailed = "mcp_secret_read_failed"
    case mcpSecretWriteFailed = "mcp_secret_write_failed"
    case mcpSecretDeleteFailed = "mcp_secret_delete_failed"
    case mcpSecretRollbackFailed = "mcp_secret_rollback_failed"
    case mcpStartFailed = "mcp_start_failed"
    case mcpToolListFailed = "mcp_tool_list_failed"
    case mcpRequiredToolMissing = "mcp_required_tool_missing"
    case mcpConnectionDown = "mcp_connection_down"
    case mcpToolCallFailed = "mcp_tool_call_failed"
    case mcpServerMaintenance = "mcp_server_maintenance"
    case knowledgeReadFailed = "knowledge_read_failed"
    case contextDependencyRequiredFailed = "context_dependency_required_failed"
    case contextDependencyOptionalFailed = "context_dependency_optional_failed"
    case contextBackendCapabilityUnsupported = "context_backend_capability_unsupported"
    case memoryOwnerNotFound = "memory_owner_not_found"
    case memoryThreadInvariantFailed = "memory_thread_invariant_failed"
    case memoryReadFailed = "memory_read_failed"
    case memoryProviderFailed = "memory_provider_failed"
    case memoryWriteFailed = "memory_write_failed"
    case memoryRaceLost = "memory_race_lost"
    case notificationProjectionFailed = "notification_projection_failed"
    case schedulePlatformFailed = "schedule_platform_failed"
    case cleanupIntegrityFailed = "cleanup_integrity_failed"
    case operationCancelled = "operation_cancelled"
    case unexpectedFailure = "unexpected_failure"
}
```

The classifier is exhaustive over the P1-B call sites. “ID” below means the
validated already-known database identifier above, never an account name,
credential, path, prompt, callback, tool name, or external payload. All
messages are the body before the common full-trace suffix. Diagnostics are a
typed value, not `[String: Any]`:

```swift
package enum FailureDiagnosticCategory: String, Codable, Sendable, CaseIterable {
    case database, credential, oauth, runtime, mission, rumination, mcp
    case knowledge, context, memory, notification, projection, cancellation
    case integrity, unknown
}
package enum FailureDiagnosticDomain: String, Codable, Sendable, CaseIterable {
    case grdb, keychain, oauth, runtime, mission, rumination, mcp
    case knowledge, context, memory, notification, projection, cancellation
    case unknown
}
public struct ValidatedHTTPStatus: Sendable, Equatable {
    public let value: Int
    fileprivate init(validatedValue: Int)
    package init(_ value: Int) throws
    package static func recognizingDiagnostic(_ value: Int) -> Self?
}
package struct FailureDiagnostics: Codable, Sendable, Equatable {
    package let category: FailureDiagnosticCategory
    package let domain: FailureDiagnosticDomain
    package let retryable: Bool
    package let dependencyType: ContextDependencyType?
    package let policy: ContextDependencyPolicy?
    package let grdbResultCode: Int32?
    package let osStatus: Int32?
    package let httpStatus: Int?
    package let attempt: Int?
    package let primaryCode: FailureCode?
    package let rollbackCode: FailureCode?
    fileprivate init(validatedFor code: FailureCode,
                     category: FailureDiagnosticCategory,
                     domain: FailureDiagnosticDomain, retryable: Bool,
                     dependencyType: ContextDependencyType? = nil,
                     policy: ContextDependencyPolicy? = nil,
                     grdbResultCode: Int32? = nil, osStatus: Int32? = nil,
                     httpStatus: ValidatedHTTPStatus? = nil,
                     attempt: Int? = nil,
                     primaryCode: FailureCode? = nil,
                     rollbackCode: FailureCode? = nil)
    fileprivate var canonicalJSON: String { get }
}
```

`FailureClassifier` receives only the closed typed errors below and is total;
it admits an HTTP field only from `ValidatedHTTPStatus`, whose throwing
initializer accepts exactly 100...599, and admits an attempt only from a typed nonnegative attempt,
and admits primary/rollback only for final code `proposal_recovery_failed` or
`cleanup_integrity_failed`. Any raw external HTTP/attempt input is rejected by
the owning throwing domain-error initializer before `capture`, not defaulted
inside this nonthrowing boundary. Keys not permitted by the classifier row are
not representable in its exhaustive construction. `cleanup_integrity_failed` may use the pair
only for the exact closeout fallback composite or
`McpDeletionCleanupCompositeError`; every other cleanup row has both nil.
Encoding uses sorted keys and omits every nil field; it must stay within 4096
UTF-8 bytes. No arbitrary String diagnostic value exists. Unknown diagnostics
are exactly category/domain `unknown` plus `retryable`; all optional fields are
nil.

| Concrete typed source | Exact code(s) | Severity | Scope | Safe body | Diagnostic keys |
|---|---|---|---|---|---|
| GRDB read / `RecordNotFoundError` / projection decode | `database_read_failed`, `record_not_found`, `projection_decode_failed` | error | operation owner: `global(database,<operation>)` or `camp(campId,<record-kind>,ID)` | `数据读取失败。`, `所需记录不存在。`, `数据格式损坏。` | `category`, optional `grdbResultCode`, `retryable` |
| GRDB write / transition / cleanup-integrity | `database_write_failed`, `mission_transition_failed`, `cleanup_integrity_failed` | error; cleanup-integrity critical | owning global/Camp record ID | `数据保存失败。`, `状态变更失败。`, `清理未完整完成。` | `category`, optional `grdbResultCode`, `retryable` |
| Keychain read / write / delete / invalid value | `keychain_read_failed`, `keychain_write_failed`, `keychain_delete_failed`, `credential_value_invalid` | error | exact global credential/credential fixed coordinate | `凭据读取失败。`, `凭据保存失败。`, `凭据删除失败。`, `凭据格式无效。` | `category`, `osStatus`, `retryable` |
| OAuth authorization/listener/state/token/commit/rollback/delete | `oauth_authorization_failed`, `oauth_listener_failed`, `oauth_state_invalid`, `oauth_token_exchange_failed`, `oauth_credential_commit_failed`, `oauth_credential_rollback_failed`, `oauth_credential_delete_failed` | error except rollback critical | fixed OAuth scope | fixed authorization/listener/state/exchange/credential bodies | `category`, optional `httpStatus`, `retryable` |
| Runtime profile/provider | `runtime_profile_read_failed`, `runtime_profile_write_failed`, `runtime_profile_delete_failed`, `runtime_reconcile_failed`, `runtime_provider_unavailable`, `runtime_model_unsupported`, `runtime_endpoint_invalid` | error | profile record ID or fixed runtime/bootstrap | fixed read/save/delete/reconcile/provider/model/endpoint bodies | `category`, `retryable` |
| Mission read/write/transition/post-commit/trace | `mission_read_failed`, `mission_write_failed`, `mission_transition_failed`, `mission_visibility_failed`, `trace_identity_conflict`, `proposal_recovery_failed` | error; trace/composite critical | validated Mission/Card owner | fixed mission bodies; trace `操作追踪身份不一致。`; composite `操作未完成，且恢复原状态失败。` | `category`, `retryable`; composite-only `primaryCode`,`rollbackCode` |
| Rumination read/start/cancel | `rumination_read_failed`, `rumination_start_failed`, `rumination_cancel_failed` | error | `camp(campId,ingestion,ingestionId)` | `思绪读取失败。`, `思绪处理启动失败。`, `思绪处理取消失败。` | `category`, `retryable` |
| MCP registry/config/secret/start/list/call/maintenance | all closed `mcp_*` cases listed above, including secret write/delete/rollback, required-tool missing, and connection down; `McpMaintenanceCleanupError` maps `cleanup_integrity_failed` | error; secret rollback and maintenance cleanup critical | validated server record ID; tool failures use type mcpTool but the same server ID | fixed generic MCP bodies; cleanup `清理未完整完成。`; no server/tool display name | `category`, fixed `dependencyType`, `retryable`; deletion-cleanup composite only `primaryCode`,`rollbackCode` |
| Knowledge/context/backend capability | `knowledge_read_failed`, `context_dependency_required_failed`, `context_dependency_optional_failed`, `context_backend_capability_unsupported` | required/backend error; optional warning | owning Camp/Card plus validated record or fixed coordinate | required/optional bodies; unsupported `当前供给线无法提供所选必需能力。` | `category`, `dependencyType`, `policy`, `retryable` |
| Memory threshold/capture/owner/thread/read/decode/provider/write/race | invalid threshold or invalid empty/blank/duplicate capture -> `projection_contract_failed`; missing owner -> `memory_owner_not_found`; duplicate owner thread -> `memory_thread_invariant_failed`; owner/message read -> `memory_read_failed`; invalid persisted role or Distiller payload -> `projection_decode_failed`; provider -> `memory_provider_failed`; thread-create/persistence -> `memory_write_failed`; CAS loss -> `memory_race_lost` | error; thread invariant critical | exact fixed application Memory coordinate selected by DM/guide entry before owner read | fixed threshold/capture/owner/thread/read/decode/provider/write/race bodies | `category`, optional `grdbResultCode`/`httpStatus`, `retryable` |
| Schedule platform / notification/projection after commit | `schedule_platform_failed`, `notification_projection_failed` | error before commit; warning after commit | schedule/committed mission/profile/rumination owner | fixed platform body or `操作已完成，但通知或状态刷新失败。` | `category`, `retryable` |
| `CancellationError` not owned by supersession | `operation_cancelled` | warning | top-level operation scope | `操作已取消。` | `category`, `retryable` |
| Any other `Error` | `unexpected_failure` | error | top-level operation scope | `发生未预期的错误。` | exactly `category=unknown`, `domain=unknown`, `retryable` |

The trace creator supplies a `FailureTraceScope` before work begins. Classifier code may
select a more specific safe record ID already present in a typed error, but may
not discover scope by reading user content or formatting the unknown error.

The missing mappings are exact: `TraceIdentityConflictError` maps critical,
nonretryable `trace_identity_conflict`; `ProposalRecoveryCompositeError`
contains only its two already-classified codes and maps critical,
nonretryable `proposal_recovery_failed`;
`CloseoutFallbackCompositeError` maps critical, nonretryable
`cleanup_integrity_failed` with the closed primary/fallback-write pair;
`McpMaintenanceCleanupError.finishFailed` maps critical retryable
`cleanup_integrity_failed`, while `.invalidLease` maps the same code critical
and nonretryable; `McpDeletionCleanupCompositeError` maps one critical
`cleanup_integrity_failed`, derives `primaryCode` only by exhaustively
classifying its closed `McpCredentialDeletionError`, sets
`rollbackCode=cleanup_integrity_failed`, and never formats either Error;
CredentialBundle commit/rollback/
unauthorized-delete map to their three OAuth codes without account/value;
authorization-preparation's one atomic item commit maps
`oauth_authorization_failed` error and carries only the fixed mutation kind
and optional OSStatus; it has no rollback terminal;
`McpCredentialDeletionError.preimageRead` maps `mcp_secret_read_failed`,
`.commit(.secret,...)` maps `mcp_secret_delete_failed`,
`.commit(.databaseRow,...)` maps `database_write_failed`, and `.rollback`
maps `mcp_secret_rollback_failed` critical/nonretryable;
`ProjectionContractError.invalidPayload` maps decode,
while generation overflow/invalid terminal/already completed map critical
`projection_contract_failed`; `ScheduleStoreProjectionError.invalidScheduledOrigin`
maps `projection_decode_failed`, while duplicate cursor maps critical
`projection_contract_failed`; `BudgetArithmeticError.nonpositiveBudgetDelta`
and `.budgetOverflow` map nonretryable `mission_write_failed` with zero write,
while `.negativeRunUsage` and `.spendProjectionOverflow` map critical
`projection_contract_failed`; the named legacy saturation receipt is a
successful observed policy result and is never classified as a failure;
strict Chat/Guide history decode uses
`ProjectionContractError.invalidPayload`. Memory normalization is stage-total:
invalid threshold/capture maps `projection_contract_failed`; missing Companion
or Camp/guide maps `memory_owner_not_found`; more than one DM/guide owner thread
maps critical `memory_thread_invariant_failed`; owner/message database faults map
`memory_read_failed`; find-or-create thread database faults map
`memory_write_failed`; invalid persisted message role and
`DistillerError.invalidPayload` are first converted to
`MemoryDistillError.invalidPayload` and then map `projection_decode_failed`;
provider faults map `memory_provider_failed`; persistence database faults map
`memory_write_failed`; and the exact CAS mismatch maps `memory_race_lost`.
`CancellationError` retains the cancellation classifier and is never relabeled
provider failure. One explicit closed stage discriminator feeds the two public
Memory catch arms; no nested catch or unknown-stage default is permitted.
`ContextBackendCapabilityError` maps nonretryable backend-
capability-unsupported; success with invalid credential bytes maps
`credential_value_invalid`; runtime resolver catalog/model/endpoint/provider/
not-found and Keychain errors map to their explicit row and never fall through.
Unknown Error diagnostics remain exactly category/domain/retryable and contain
no reflected type.

`ValidatedHTTPStatus.recognizingDiagnostic` is the sole nonthrowing bridge for
an already-caught provider's optional diagnostic. It uses the same 100...599
predicate and the fileprivate trusted initializer, returning nil only for an
out-of-domain diagnostic while the owning failure still remains visible. It
never throws, traps, defaults the operation, or reads the response body.
Memory's provider-stage normalizer uses this bridge only for
`ProviderError.http(status:body:)`, discards `body`, and attaches nil for every
other provider case.

The Memory normalizer has no copy decision left to implementation. “Body” is
the exact safe body before the common trace suffix; every unlisted diagnostic
field is nil:

| Stage + caught source | Canonical typed error | Code / severity | Body | category / domain / retryable | Sole optional diagnostic |
|---|---|---|---|---|---|
| `.input` + nonpositive minimum | `.invalidMinimumMessages(value)` | `projection_contract_failed` / error | `记忆沉淀输入无效。` | `projection` / `memory` / false | none |
| `.input`, `.watermark`, or `.persistence` + empty/blank/duplicate capture | `.invalidCapturedMessages(exactViolation)` | `projection_contract_failed` / error | `记忆沉淀输入无效。` | `projection` / `memory` / false | none |
| `.ownerRead` + missing Companion or Camp/guide | `.ownerNotFound(exactKind)` | `memory_owner_not_found` / error | `找不到记忆沉淀对象。` | `memory` / `memory` / false | none |
| `.threadEnsure` + zero/multiple owner thread after the closed find-or-create rule | `.threadInvariant(exactKind)` | `memory_thread_invariant_failed` / critical | `记忆对话状态不一致。` | `integrity` / `memory` / false | none |
| `.ownerRead` or `.messageRead` + GRDB read | `.read(grdbResultCode: exactCodeOrNil)` | `memory_read_failed` / error | `记忆数据读取失败。` | `memory` / `memory` / true | `grdbResultCode` only |
| `.threadEnsure` + GRDB create/readback | `.write(grdbResultCode: exactCodeOrNil)` | `memory_write_failed` / error | `记忆对话准备失败。` | `memory` / `memory` / true | `grdbResultCode` only |
| `.messageRead` invalid persisted role or `.provider` `DistillerError.invalidPayload` | `.invalidPayload` | `projection_decode_failed` / error | `记忆数据格式损坏。` | `projection` / `memory` / false | none |
| `.provider` + provider failure | `.provider(httpStatus: recognizedStatusOrNil)` | `memory_provider_failed` / error | `记忆沉淀服务不可用。` | `memory` / `memory` / true | `httpStatus` only |
| `.watermark` + GRDB update | `.write(grdbResultCode: exactCodeOrNil)` | `memory_write_failed` / error | `记忆沉淀水位更新失败。` | `memory` / `memory` / true | `grdbResultCode` only |
| `.watermark` or `.persistence` + exact CAS mismatch | `MemoryDistillRaceLostError()` | `memory_race_lost` / error | `记忆沉淀状态已被其他操作更新。` | `memory` / `memory` / true | none |
| `.persistence` + note/event GRDB failure | `.write(grdbResultCode: exactCodeOrNil)` | `memory_write_failed` / error | `记忆沉淀保存失败。` | `memory` / `memory` / true | `grdbResultCode` only |
| any stage + `CancellationError` | unchanged cancellation source | `operation_cancelled` / warning | `操作已取消。` | `cancellation` / `cancellation` / true | none |
| any stage + every other Error or a known typed error at an impossible stage | unchanged unknown source | `unexpected_failure` / error | `发生未预期的错误。` | `unknown` / `unknown` / false | none |

Normalization first recognizes `CancellationError`; then exhaustively switches
the seven-stage enum and the permitted source types above. A known type at an
impossible stage is deliberately unexpected rather than reinterpreted. There
is no default stage, reflected type, raw body, owner value, message ID, or
provider body. The MD4–MD7 classifier fixture asserts every table field—not
only code/severity/scope—including exact body, category, domain, retryable, and
the sole permitted optional diagnostic. It covers nil/valid/invalid provider
status; an invalid status remains a visible provider failure with nil HTTP
diagnostic. Cancellation is repeated at each stage and is never provider/write.

The supporting typed errors are also frozen and carry no arbitrary detail:

```swift
public enum FailureMetadataValidationError: Error, Sendable, Equatable {
    case invalidTraceId
    case invalidRecordId
    case invalidCoordinate
    case invalidUserMessage
    case invalidDiagnostics
}
package struct TraceIdentityConflictError: Error, Sendable, Equatable {
    package init()
}
package struct ProposalRecoveryCompositeError: Error, Sendable, Equatable {
    package let primaryCode: FailureCode
    package let rollbackCode: FailureCode
    package init(primaryCode: FailureCode, rollbackCode: FailureCode)
}
package struct CloseoutFallbackCompositeError: Error, Sendable, Equatable {
    package let primaryCode: FailureCode
    package let fallbackWriteCode: FailureCode
    package init(primaryCode: FailureCode,
                 fallbackWriteCode: FailureCode)
}
package struct FailureRecordRedactedError: Error, Sendable, Equatable {
    package init()
}
package struct CredentialValueInvalidError: Error, Sendable, Equatable {
    package init()
}
package struct OAuthCredentialBundleUnavailableError:
    Error, Sendable, Equatable {
    package init()
}
package enum ContextBackendCapabilityError: Error, Sendable, Equatable {
    case search
    case mcp
}
package enum ProjectionContractError: Error, Sendable, Equatable {
    case invalidPayload
    case generationOverflow
    case invalidTerminal
    case alreadyCompleted
}
package struct RuntimeProfileReadError: Error, Sendable, Equatable {
    package init()
}
package enum SchedulePlatformFailure: Error, Sendable, Equatable {
    case registration
    case authorization
    case notificationSettings
    case notificationSubmission
    case documentPresentation
}
package enum RuntimeOAuthBoundaryError: Error, Sendable, Equatable {
    case randomGeneration
    case authorizationAlreadyActive
    case callbackMalformed
    case callbackDenied
    case stateMissing
    case stateMismatch
    case formEncoding
    case nonHTTPResponse
    case httpStatus(ValidatedHTTPStatus)
    case malformedTokenResponse
    case accountIDMissing
    case browserOpen
}
package enum RuntimeOAuthListenerFailure: Error, Sendable, Equatable {
    case invalidPort
    case bind
    case accept
    case malformedCallback
    case cancelled
}
```

`ProposalRecoveryCompositeError` stores only two already-classified closed
codes; equal codes are valid when both stages failed in the same domain. The
`CloseoutFallbackCompositeError` maps critical/nonretryable
`cleanup_integrity_failed`; the classifier serializes its
`fallbackWriteCode` in the existing `rollbackCode` diagnostic slot so the
schema remains closed. It accepts only `database_write_failed` for that second
field and the first field must be the already prepared distillation failure
code. On a `.fallbackMissing` retry, that first field comes only from the
receipt's internal exhaustive mapping `.provider -> memory_provider_failed` /
`.invalidPayload -> projection_decode_failed`. It never contains either Error
or note content. The
remaining empty errors intentionally expose no raw associated value; the
operation trace/scope already owns safe identity.

These platform/OAuth errors are declared in Core
`FailureRecord.swift`, not AgentLoopApplication, so FailureReporter can classify
them without a forbidden Core -> Application edge. Schedule cases map to
`schedule_platform_failed`; OAuth listener cases map to
`oauth_listener_failed`; random/form/browser preparation and
`authorizationAlreadyActive` map to `oauth_authorization_failed`; callback state/shape/account cases map to
`oauth_state_invalid`; and non-HTTP/status/token-payload cases map to
`oauth_token_exchange_failed`. `OAuthCredentialBundleUnavailableError` maps to
nonretryable error `oauth_credential_commit_failed` with one fixed safe
reauthorization body; it proves the configured bundle cannot be safely read
because its coordinates are invalid or an interrupted/malformed transaction
is quarantined, and never exposes coordinates, envelope, or credential values. The optional HTTP status is validated before it
enters diagnostics. None carries an underlying Error, URL, callback value, or
platform object.

`CredentialBundleError.preimageChanged(flow:)` is the distinct safe stale-HTTP
terminal: code `oauth_credential_commit_failed`, retryable true, no OSStatus,
and fixed message “OAuth credentials changed while this request was in flight.
Retry.” It is never classified as unauthorized, never invokes permanent-failure
cleanup, and is captured only on the stale refresh/delete command's own fresh
trace. All other `CredentialBundleError` cases retain their existing fixed
commit/rollback/delete mappings; no classifier reads or formats a credential
preimage or revision.

An exhaustive compile-time table pairs every `FailureOperation` case with one
owner and proves the fixed accessibility formula, and pairs every typed error
case with exactly one FailureCode/classifier row. The inventory's literal/equivalent semantic tags
pair to one operation-owned production seam; source gates reject string-literal
OperationTrace construction. Canary matrices independently place secret,
account, path, callback, external response, server display name, and tool name
values in every error associated value and prove none enters operation, scope,
body, diagnostics, event, logger, UI, or Accessibility.

## 6. Workflow state and Application target

### 6.1 Shared state machine

`WorkflowLoadState<Value>` has exactly:

```swift
package enum WorkflowLoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(UserVisibleFailure)
}
```

`WorkflowLoadState.swift` also owns the only reducer:

```swift
package struct WorkflowRequestGeneration: Sendable, Equatable {
    fileprivate let rawValue: UInt64
    fileprivate init(rawValue: UInt64) { self.rawValue = rawValue }
}

package struct WorkflowProjection<Value: Sendable>: Sendable {
    package private(set) var state: WorkflowLoadState<Value>
    package private(set) var lastLoadedValue: Value?
    package private(set) var generation: WorkflowRequestGeneration
    package init()
    package init(loaded value: Value)
    package init(initial result: SynchronousCaptureResult<Value>)
#if DEBUG
    package init(testingGenerationValue: UInt64)
#endif
    package mutating func beginRefresh() throws -> WorkflowRequestGeneration
    @discardableResult
    package mutating func applyTerminal(
        _ terminal: WorkflowLoadState<Value>,
        for generation: WorkflowRequestGeneration
    ) throws -> Bool
}
package enum SynchronousCaptureResult<Value: Sendable>: Sendable {
    case value(Value)
    case failed(UserVisibleFailure)
}
package enum WorkflowReadTerminal<Value: Sendable>: Sendable {
    case loaded(Value)
    case failed(UserVisibleFailure)
}
extension WorkflowReadTerminal: Equatable where Value: Equatable {}
package enum ApplicationStartupGateDecision: Sendable, Equatable {
    case waitingForOther
    case startNow
    case alreadyStarted
}
@MainActor
package struct ApplicationStartupGate {
    package private(set) var runtimeReady = false
    package private(set) var codingRanchReady = false
    package private(set) var didStart = false
    package init()
    package init(
        runtime: WorkflowLoadState<RuntimeWorkflowSnapshot>,
        codingRanch: WorkflowLoadState<CodingRanchBootstrapResult>
    )
    package mutating func claimStartIfReady()
        -> ApplicationStartupGateDecision
    package mutating func acceptRuntimeLoaded(
        _ snapshot: RuntimeWorkflowSnapshot
    ) -> ApplicationStartupGateDecision
    package mutating func acceptCodingRanchLoaded(
        _ result: CodingRanchBootstrapResult
    ) -> ApplicationStartupGateDecision
}
// P1-B-SEAM synchronousWorkflowLoad
package func captureSynchronous<Value: Sendable>(
    reporter: FailureReporter, trace: OperationTrace,
    _ body: () throws -> Value
) -> SynchronousCaptureResult<Value>
package func captureSynchronousLoad<Value: Sendable>(
    reporter: FailureReporter, trace: OperationTrace,
    _ body: () throws -> Value
) -> WorkflowLoadState<Value>
package func captureAsyncLoad<Value: Sendable>(
    reporter: FailureReporter, trace: OperationTrace,
    _ body: @Sendable () async throws -> Value
) async -> WorkflowLoadState<Value>
package func captureAsyncOperation<Terminal: Sendable>(
    reporter: FailureReporter, trace: OperationTrace,
    onFailure: @escaping @Sendable (UserVisibleFailure) -> Terminal,
    _ body: @Sendable () async throws -> Terminal
) async -> Terminal
package enum WorkflowStreamCommitDisposition: Sendable, Equatable {
    case notCommitted
    case committed
}
package enum WorkflowStreamTerminal: Sendable, Equatable {
    case finished(commit: WorkflowStreamCommitDisposition)
    case cancelled(commit: WorkflowStreamCommitDisposition)
    case failed(UserVisibleFailure, commit: WorkflowStreamCommitDisposition)
}
package func captureAsyncStream(
    reporter: FailureReporter, trace: OperationTrace,
    isOwnedCancellation: @escaping @Sendable () -> Bool,
    open: @escaping @Sendable () throws
        -> (@Sendable () async throws -> Void)
) async -> WorkflowStreamTerminal

package struct CancellationSleepPort: Sendable {
    package let sleep: @Sendable (Duration) async throws -> Void
    package init(
        sleep: @escaping @Sendable (Duration) async throws -> Void
    )
    package static let live: CancellationSleepPort
}
package enum WorkflowCancellationSleeps {
    // P1-B-SEAM recentCompletionSleep
    package static func recentCompletion(
        using port: CancellationSleepPort = .live
    ) async
    // P1-B-SEAM toastExpirySleep
    package static func toastExpiry(
        using port: CancellationSleepPort = .live
    ) async
    // P1-B-SEAM mcpPollingSleep
    package static func mcpPolling(
        using port: CancellationSleepPort = .live
    ) async
}

package struct RuminationPhaseProjectionBoundary: Sendable {
    package init(reporter: FailureReporter)
    // P1-B-SEAM ruminationPhaseProjection
    package func project(
        ingestionId: String,
        workId: String,
        attempt: Int,
        trace: OperationTrace
    ) -> SynchronousCaptureResult<RuminationPhaseIdentity>
}

#if DEBUG
package struct PreviewAuditPersistenceError:
    Error, Sendable, Equatable
{
    package init()
}
package struct PreviewAuditPersistenceBoundary: Sendable {
    package typealias Writer = @Sendable (Data, URL) throws -> Void
    package init(write: @escaping Writer)
    package static let live: PreviewAuditPersistenceBoundary
    // P1-B-SEAM previewAuditPersistence
    package func persist(
        _ data: Data,
        to url: URL
    ) -> Result<Void, PreviewAuditPersistenceError>
}
#endif

package enum ProductionFailureSeam: String, CaseIterable, Sendable {
    case applicationBootstrap, applicationPostDatabaseBootstrap
    case failureReporterPersistence
    case contextDependencyAttempt, contextAtomicPersistence
    case mcpDownAtomicPersistence
    case credentialInitialCommit, credentialRefreshCommit
    case credentialUnauthorizedDelete, credentialMcpDelete
    case synchronousWorkflowLoad, asynchronousWorkflowLoad
    case asynchronousWorkflowOperation, asynchronousWorkflowStream
    case previewAuditPersistence
    case keychainRead, profileDefaultsRead, modelCatalogResolve
    case modelCatalogRefreshCore, planningProviderResolve
    case runtimeBootstrapSeed, runtimeReconcileCore, newcomerProgress
    case databaseKernelEventWrite, databaseReturnCardForRework
    case databaseLatestReturnFeedback, databaseAnswerUserRequest
    case databasePendingUserRequests, databaseMissionSpend
    case databaseFinishRun, databaseRuminationReplay
    case knowledgeNoteMutation, knowledgeProposalMutation
    case memoryDistillDM, memoryDistillGuide, distillerCloseout
    case ruminationProviderTurn, guideChatCoreSend
    case orchestratorInit, orchestratorStartupRecovery
    case orchestratorReconcile, orchestratorEmergencyStop
    case orchestratorResume, orchestratorCardDispatch
    case orchestratorRateLimitEvent
    case orchestratorCancelMission, orchestratorHarvestMission
    case orchestratorAnswerRequest, orchestratorConfirmProposal
    case orchestratorCloseout, orchestratorRetryCard
    case orchestratorReturnForRework, orchestratorAddBudget
    case mcpManagerStart, mcpManagerCampTools, mcpManagerServerTools
    case mcpManagerCall, mcpManagerMaintenance
    case missionLoadDetail, missionLoadIndex, missionStart, missionCancel
    case missionHarvest, missionAccept, missionRetryContext, missionAnswer
    case missionConfirmProposal, missionRetryCard, missionReturnForRework
    case missionAddBudget, missionClearReview, missionSetAutonomy
    case missionDismissProposal, missionEnsureReport, missionOpenReport
    case scheduleLoad, scheduleOutcomeLoad
    case scheduleTemplateSave, scheduleTemplateDelete
    case scheduleSave, scheduleEnable, scheduleDelete, scheduleRefresh
    case schedulePostCommitRepair
    case scheduleFire, scheduleReplay, scheduleWake, scheduleBroadcast
    case scheduleAuthorization, scheduleNotification
    case inputLoadCamp, inputLoadReview, inputSubmitFeed
    case inputStartRumination, inputCancelRumination, inputSaveReview
    case inputMaterialize, inputDelete, inputCreateMissionDraft
    case inputUnlockTestCow, inputResolveCampNavigation
    case inputEnsureDefaultCamp, ruminationPhaseProjection
    case campCreate, campRename, campArchive, campWritableRead
    case campNoteLoad, campNoteSave, campNoteDelete, campNotePin
    case memoryNoteLoad, memoryNoteSave, memoryNoteDelete, memoryNotePin
    case chatLoad, chatSend, guideChatLoad, guideChatSend
    case runtimeBootstrap, runtimeLoad, runtimeProviderResolve
    case runtimeSearchResolve, runtimeProfileSave, runtimeProfileDelete
    case runtimeProfileSwitch, runtimeCredentialSet, runtimeCredentialDelete
    case runtimeCatalogRefresh, runtimeProviderTest
    case oauthRandomState, oauthAuthorizationPreparation, oauthListener
    case oauthAuthorizationOpen, oauthCallback, oauthCallbackCleanup
    case mcpLoadRegistry, mcpLoadCamp, mcpLoadTools, mcpSecretPresence
    case mcpAddServer, mcpStartServer, mcpRestartServer, mcpSetEnabled
    case mcpSaveSecret, mcpDeleteServer, mcpFinishServerCleanup
    case companionEditorLoad, companionEditorSave
    case orchestratorTickSleep, recentCompletionSleep
    case toastExpirySleep, mcpPollingSleep
}
```

`captureSynchronous` owns the one planned
`N[.synchronousWorkflowLoadCapture]` lexical catch and returns only `.value`
or `.failed`; `captureSynchronousLoad` is a catch-free mapping to
`WorkflowLoadState`. `RuminationPhaseProjectionBoundary.project` strictly
constructs `RuminationPhaseIdentity` through that binary primitive. The App
creates a `.projectionApply` trace before the call, maps `.value` to
`applyRuminationPhase`, and maps `.failed` to the typed global failure. It has
no nil/idle/loading/default arm. Its descriptor therefore records the frozen
nested edge `ruminationPhaseProjection -> synchronousWorkflowLoad`; both
invocation counters must be one.

`ApplicationStartupGate` is the sole post-composition start authority. Its
typed initializer derives initial readiness only from the two closed load
states and never treats failed/loading/idle as ready. Initial composition only
constructs the gate; it does not claim it. RootView's post-init
`activatePostBootstrapDispatchIfReady()` call is the sole initial claim after
the fully initialized AppStore is available. Its two
typed accept methods set their matching ready bit then share that same claim.
In one no-await MainActor segment the claim returns `.waitingForOther` when the
peer is absent, checked-sets `didStart` before returning `.startNow` when both
first become ready, and returns `.alreadyStarted` thereafter. No Boolean/raw
state overload exists, and a failed/loading/idle projection cannot be passed to
an accept method.
AppStore calls the runtime method only after installing an exact loaded
`RuntimeWorkflowSnapshot`, and calls the Ranch method only after installing an
exact committed `CodingRanchBootstrapResult`. Exactly `.startNow` invokes the
existing downstream Runtime/listener/startup-recovery/scheduler/provider/
Kernel start sequence. The two waiting/already-started cases invoke nothing.
Thus either bootstrap may finish or recover first, but neither can independently
open dispatch.

`WorkflowCancellationSleeps` is the only Application owner of the three App
cancellation delays. Its live port delegates only to `Task.sleep`; its methods
retain the exact adjacent cancellation-only comments from §10 and the exact
durations 3 seconds, 2.5 seconds, and 2 seconds respectively. AppStore and
McpStationSection replace their private `try? Task.sleep` calls with the
matching `P1-B-DELEGATE`. Tests inject a port that records one invocation then
throws `CancellationError`; no business closure or non-cancellation error can
enter this port. The fourth cleanup seam remains the Core
`Orchestrator.ensureTickStarted` sleep.

The DEBUG-only preview persistence boundary performs exactly one atomic Data
write. Its one planned catch is
`N[.previewAuditPersistenceFailure]`; it discards the Error and URL and returns
the closed value-only `PreviewAuditPersistenceError`. It never calls
FailureReporter, retries, or writes a secondary path. `P1BPreviewAudit` exits
the owned preview immediately after one fixed safe stderr line on failure, so
an incomplete audit JSON cannot be accepted as evidence. The type, error,
writer, App delegate, and internal owner case are absent from release objects;
the `ProductionFailureSeam.previewAuditPersistence` enum case remains.

The App owner is frozen, under one direct non-nested `#if DEBUG`, as
`@MainActor private final class P1BPreviewAudit` with exact method
`private func persist(_ data: Data, to url: URL)`. That method only switches on
`PreviewAuditPersistenceBoundary.persist(data,to:url)`: success returns;
failure emits one fixed safe stderr line and immediately calls
`exit(EXIT_FAILURE)`. It carries
the one derived `P1-B-DELEGATE <DE-id> previewAuditPersistence` marker from the
127-tuple ledger; no
retry, reporter call, URL/error formatting, or secondary writer exists.

The closed `ProductionFailureSeam` source set is exactly **153** cases. The six
new cases relative to the prior 147-case draft are
`applicationPostDatabaseBootstrap`, `scheduleOutcomeLoad`,
`inputEnsureDefaultCamp`, `ruminationPhaseProjection`, and
`orchestratorRateLimitEvent`, plus `schedulePostCommitRepair`. No new
`FailureOperation` case is added: the first four use `.applicationBootstrap`,
`.scheduleNotification`, `.inputCampLoad`, and `.projectionApply` respectively;
the rate-limit seam uses the already frozen `.missionRateLimitEvent`; and each
schedule repair uses the existing operation derived from its opaque committed
identity. `previewAuditPersistence` continues to use
`.previewRuntimeRead`; `databaseKernelEventWrite` adopts its caller's existing
operation and trace.

`WorkflowRequestGeneration` deliberately has no RawRepresentable conformance,
public/package generation initializer, decoder, or integer conversion. Only this file's
`WorkflowProjection` can construct or advance one; App and tests obtain the
opaque token from `beginRefresh` and may only pass/compare it. The DEBUG-only
projection seed does not expose a generation constructor and is absent from
release objects; it owns the checked-overflow fixture.
The four adapters each have one exact marked catch and do only one thing:
capture the original error with the supplied trace, then return the frozen
failure terminal. `captureAsyncOperation` is generic over that terminal and
invokes its required `onFailure` mapper; ordinary commands pass
`OperationCommitOutcome.notCommitted`, while the credential/OAuth/closeout
split-state commands pass their exact custom `.notCommitted` constructor. A
post-commit stage never throws into that outer mapper: it is converted to its
typed `Result`/receipt at the stage boundary and the body returns the exact
committed/pending terminal. `captureAsyncStream` treats cancellation as normal only when
the injected owner predicate is true; otherwise it captures
`operation_cancelled`. The adapter itself owns the two-stage boundary inside
that single catch: it calls `open()` while its local commit disposition is
`.notCommitted`; only a successful `open()` result flips the disposition to
`.committed`, after which it invokes the returned async consumer. The App
`open` closure calls the real `ChatService.send` or `GuideChatService.send` and
returns the sole closure that iterates that exact stream. Those services have
already persisted the user message before they successfully return a stream,
so provider/proposal/persistence failure, finish, and owned cancellation during
iteration all carry `.committed`; any synchronous open failure remains
`.notCommitted`. No caller-supplied Boolean can lie about this transition.
App treats a failed/cancelled committed stream as refresh-only and never
resends the user message. The adapter does not clear prior projection or
format an Error. Domain bodies must return committed/post-commit outcomes
themselves.

`captureAsyncStream` owns the eleventh of fourteen planned-new lexical catches.
The three later rows are the Runtime source-stage boundaries. Its first
nonempty body line is exactly
`// P1-B-CATCH capture N[.asyncWorkflowStreamCapture]`; it is distinct from and
does not move or replace entry descriptor `E[.chatServiceStreamRethrow]` in
`ChatService.swift`. Its exact `P1-B-RESOLVE PLANNED ...` line follows the catch
marker immediately, before the first executable statement; `P1-B-CATCH` is the
catch's sole semantic marker and no duplicate `P1-B-EQUIVALENT` marker is
allowed. The planned-N owner drives opening-failure,
iteration-failure, owned-cancellation, and non-owned-cancellation subcases
inside existing `A13`; the catch never consumes an entry `E[...]` tag.

`ProductionFailureSeam` is a callable registry, not an alias for
`FailureOperation` and not a list of generic reporter helpers. Every case names
one real Core/Application decision boundary. Descriptor tags, seam cases,
callable markers, and App delegate edges are different identities and are
never compared as one raw set.

The frozen inventory has 413 descriptor identities: 133 literal, 134 `E`, 130
existing equivalent-`N`, fourteen planned-`N`, and two execution-only. The two MCP
fake literal rows are a disjoint `TestHelperDescriptor` partition: they must
throw through the real fake transport and retain their literal/test ownership,
but cannot enter a production callable before their failure occurs and
therefore have no `ProductionFailureSeam` or App delegate. The remaining 411
production descriptors each freeze a tag, one primary seam, one owner, one or
more nonempty exact callable variants, and zero or more App delegate edges.
The second execution-only descriptor is
`MissionWorkflowController.retrySchedulePostCommit(_:)`, primary seam
`schedulePostCommitRepair`, owner A13. Its sole App delegate tuple is
`Sources/AgentLoopApp/AppStore.swift::AppStore.retrySchedulePostCommit(key:) => schedulePostCommitRepair`.
It adds no entry CandidateOccurrence or resolution relation.

The source/test representation is exact:

```swift
private struct SeamOccurrence: Hashable {
    let id: String
    let seam: ProductionFailureSeam
}
private struct SeamCallEdge: Hashable {
    let id: String
    let fromOccurrenceID: String
    let toOccurrenceID: String
}
private struct DescriptorInvocationVariant: Hashable {
    let id: String
    let rootOccurrenceIDs: [String]
    let primaryOccurrenceID: String
    let occurrenceSet: Set<SeamOccurrence>
    let edgeIDSet: Set<String>
}
```

The default variant ID is `<exact-descriptor-tag>#default`. Exactly four
descriptors replace that default with the following closed multi-variant sets:

```text
E[.oauthInflightRethrow]#permanentUnauthorizedDeleteFailureThenInflightCleanup
E[.oauthInflightRethrow]#nonUnauthorizedOriginalRethrow
E[.oauthListenerStart]#synchronousListenerStartFailure
E[.oauthListenerStart]#asynchronousListenerStateFailure
N[.contextDependencyAttempt]#required
N[.contextDependencyAttempt]#optionalApproved
N[.runtimeCredentialSourceFailure]#provider
N[.runtimeCredentialSourceFailure]#search
N[.runtimeCredentialSourceFailure]#presence
```

`N[.oauthAuthorizationStatePersistence]#default` remains one default variant,
not a fifth multi-variant descriptor. Its two entry candidates were the old
UserDefaults state write and separate Keychain verifier write; both resolve to
one final atomic `oauthAuthorizationPreparation` callable that writes the
versioned state+verifier envelope as one Keychain item. The default transcript
injects that single item write failure and expects exactly
`oauthAuthorizationPreparation: 1`, one trace, one captured not-committed
failure, and a byte-identical prior-or-absent item. The two entry resolution
relations remain distinct historical evidence, but they do not authorize two
final writes or two runtime occurrences. This changes neither descriptor,
variant, primary-seam, all-seam, nor delegate arithmetic.

No other descriptor has more than `#default`; there are therefore exactly 416
production variants. No dynamic or index-based ID exists. Every variant graph
is a closed DAG: roots have zero
in-degree; each non-root occurrence has exactly one incoming edge; every edge
endpoint is in the occurrence set; every occurrence is reachable from a root;
all occurrence/edge IDs are globally unique; and no declared edge is unused.
The primary occurrence's seam equals the descriptor primary and appears once.
An occurrence ID, rather than a seam raw value, distinguishes two calls to the
same capture adapter. Its expected counter multiset is
`Dictionary(grouping: occurrenceSet, by: \.seam).mapValues(\.count)`.

The owner clears all 153 counters, invokes the real variant, and requires the
actual per-case multiset to equal that expected multiset exactly; only cases
absent from the expected multiset must be zero. It then checks exact operation,
that invocation's trace (including the fresh recovery trace for a retry
variant), terminal, DB/log/UI result, and absence of a default/success
substitute. A failure-injection variant omits every occurrence after its
injection terminal. Thus a controller calling a shared adapter is not falsely
classified as an unrelated counter, and a same-seam two-stage operation such as
save-then-materialize is represented as two occurrences.

The 411 primary projection is exactly 152 cases:

```text
Set(all411ProductionDescriptors.map(\.primarySeam))
    == Set(ProductionFailureSeam.allCases)
       - {orchestratorRetryCard}
union(all416ProductionVariants.expectedCounterMultiset.keys)
    == Set(ProductionFailureSeam.allCases)  // exactly 153
```

Revision 03 freezes this planning-time mechanical projection transcript. The
parser joins the five inventory partitions by exact descriptor tag, rejects
duplicate tags, removes only the two named `TestHelperDescriptor` rows, and
reads the explicit primary-seam column without deriving a primary from nested
edges:

```text
descriptor rows                 133 + 134 + 130 + 14 + 2 = 413
nonproduction helper rows       2
production descriptor rows      411
unique primary seam values      152
allCases - primary              orchestratorRetryCard
multi-variant descriptor rows   4 (three two-variant + one three-variant)
production invocation variants 416
expected-counter seam union     153
DelegateEdge tuple union        127
```

The implementation gate runs this same relational projection from the frozen
tables before compiling source; a different count or set is a planning-drift
failure, not an opportunity to rewrite the expected value in test code.

`orchestratorRetryCard` is therefore the sole nested-only *case value*—meaning
it is never primary—not the only nested call edge. `inputSaveReview` remains
the first committed stage of the `E[.ruminationMaterializeView]` composed
variant, but is now also the primary of the strict review-provenance descriptor;
`orchestratorAddBudget` is primary for the arithmetic descriptor. The inventory
§10.1 registry freezes the three exact generic
callable families, all domain call edges, and the composed-variant exceptions.
No implementation may infer an extra edge or omit one because a set projection
still happens to contain 153 cases.

Every enum case has exactly one real production callable carrying
`// P1-B-SEAM <case>`; no callable carries two markers, no test fake satisfies a
marker, and no enum case is covered merely by set membership. Source enum and
callable-marker sets are 153. Debug callable/invocation set is 153. Release
keeps the 153-case enum but callable/object set is exactly
`153 - { previewAuditPersistence }`; every other callable exists in debug and
release. Tests for the DEBUG-only boundary are themselves guarded.

App delegate identity is separate. A `DelegateEdge` is the exact tuple
`(id, allowlistedPath, containingDeclaration, seam)`. The frozen inventory
tables supply the path/declaration and either the primary seam or their exact
`=> <seam-case>` override; their separately listed composed edges and §9.1
dagger appendix add non-primary App calls. Their union is exactly **127 unique
tuples**. The gate
sorts the unique tuples bytewise by `path + NUL + declaration + NUL + seam.rawValue`
and assigns the closed stable ID range `DE-001...DE-127` in that order. This
sorted frozen tuple set is the ledger; descriptors reference its resulting IDs. Source uses
only `// P1-B-DELEGATE <DE-id> <seam-case>` immediately adjacent to the one
App-to-Core/Application call. The scanner recovers pathname and containing
declaration, then requires exact tuple and ID multisets. Duplicate IDs/tuples,
one ID mapped to two tuples, combined `a/b` anchors, missing/unlisted markers,
or a marker beside an App reimplementation fail. Several descriptors may share
one edge; Core-only rows use none; delegate seam projection need not equal all
153 cases.

The grouped inventory tables are mechanically expanded by tag and joined to
the original pathname/tag tables. That relational join, the closed occurrence
rules, and the derived DelegateEdge ledger are the only descriptor source of
truth.

`applyTerminal` accepts only loaded/failed; idle/loading is a typed contract
error and leaves the projection unchanged. `beginRefresh` checked-increments
the UInt64 generation and throws on overflow before changing state. Refresh
changes state to loading but
does not clear `lastLoadedValue`. Success atomically replaces it then publishes
loaded. Failure captures the same operation trace, publishes failed, and leaves
the prior value byte-equal. A stale generation returns `false` without mutation;
the current generation applies exactly once and returns `true`. A superseded
load therefore cannot replace newer data or failure. Cancellation of a stale
request is discarded by generation. Cancellation of the current request is a
normal typed terminal failure unless the App façade itself resets an uncommitted
navigation-only load to idle; external/business cancellation is never presented
as loaded/empty.

`WorkflowProjection.init(initial:)` is the sole no-request construction path
for a captured startup read. It exhaustively maps `.value(value)` to
`state=.loaded(value)` plus the same `lastLoadedValue`, and `.failed(failure)`
to `state=.failed(failure)` plus nil `lastLoadedValue`; both begin at generation
zero. It accepts the binary `SynchronousCaptureResult`, never a raw
`WorkflowLoadState`, so initialization has no impossible idle/loading/default,
fatal, or throwing branch.

`MissionWorkflowController` is `@MainActor package final` because it adopts the
existing MainActor planning entry owner. Input, RuntimeProfile, and MCP
controllers are package actors. All use Sendable protocol/closure dependencies,
contain no SwiftUI/AppKit/Observation side effect, and expose typed command
results rather than toast strings. Controllers are stateless with respect to UI
load state: they return one terminal `.loaded` or `.failed` value and never own
`WorkflowProjection`, generation, last-loaded data, toasts, or retry flags.
AppStore/McpStore is the single owner of each projection and generation; it
calls `beginRefresh`, awaits the controller, and applies the terminal only with
the captured generation. Existing arrays are render caches derived only after a
successful current-generation apply, not a second source of truth.

Projection ownership keys are fixed: AppStore owns Mission detail by
missionId, Mission index global, Input Camp by campId, Input review by
ingestionId, and Runtime global; McpStore owns registry global, enabled state by
campId, tool list by serverId, and secret presence by serverId+key. The matching in-flight Task is owned at the
same key and canceled/superseded only by a newer generation at that key.

The macOS-14-compatible teardown preserves the existing pure-Swift
`@MainActor @Observable final class AppStore` header and `init()`; it adds no
NSObject inheritance, selector, relay, or superclass-delegation call. Each
consumer captures its pre-extracted `AsyncStream` value plus weak AppStore,
never the platform owner; this is required because an observer that retained a
consumer which retained the owner would recreate an owner/observer cycle. After
the two consumers are installed, App calls the owner-only termination-observer
installer once through an explicit typed Void binding. The observer closure
captures the MainActor owner weakly plus the two Sendable consumer Tasks, never
AppStore/controller. Delivery is fixed to `.main`; its only body is an explicit
typed Void binding to `MainActor.assumeIsolated`, inside which an `if let owner`
calls shutdown and then both consumer Tasks and the shared shell-process
registry are cancelled/terminated through typed Void bindings. There is no new
guard/default/catch/Result/bare call. The owner retains the returned observer
token and its one-shot shutdown removes/nils that token; because neither the
observer closure nor either consumer Task retains the owner, no
NotificationCenter/owner cycle exists before removal. The exact observer body
and token-removal prefix are:

```swift
fileprivate func installTerminationObserver(
    recoveryConsumer: Task<Void, Never>,
    callbackConsumer: Task<Void, Never>
) {
    terminationObserver = NotificationCenter.default.addObserver(
        forName: NSApplication.willTerminateNotification,
        object: nil,
        queue: .main
    ) { [weak owner = self, recoveryConsumer, callbackConsumer] _ in
        let _: Void = MainActor.assumeIsolated {
            if let owner {
                let _: Void = owner.shutdown()
            }
            let _: Void = recoveryConsumer.cancel()
            let _: Void = callbackConsumer.cancel()
            let _: Void = ShellProcessRegistry.shared.terminateAll()
        }
    }
}

// This is the mandatory first idempotent-shutdown prefix.
if let terminationObserver {
    self.terminationObserver = nil
    let _: Void = NotificationCenter.default.removeObserver(terminationObserver)
}
```

AppStore's projection/task carriers are exactly:

```swift
var globalVisibleFailure: UserVisibleFailure?
var missionIndexProjection = WorkflowProjection<MissionIndexSnapshot>()
var missionDetailProjectionByMissionId:
    [String: WorkflowProjection<MissionDetailSnapshot>] = [:]
var inputCampProjectionByCampId:
    [String: WorkflowProjection<InputCampSnapshot>] = [:]
var inputReviewProjectionByIngestionId:
    [String: WorkflowProjection<InputReviewSnapshot>] = [:]
var runtimeProjection: WorkflowProjection<RuntimeWorkflowSnapshot>
private(set) var codingRanchBootstrapState:
    WorkflowLoadState<CodingRanchBootstrapResult>
private var applicationStartupGate: ApplicationStartupGate
private let synchronousRuntimeBootstrap: SynchronousRuntimeBootstrap
private let runtimeBootstrapRequest: RuntimeBootstrapRequest
private let codingRanchBootstrapBoundary:
    ApplicationPostDatabaseBootstrapBoundary
private let productBootstrapService: ProductBootstrapService
private var memoryKnowledgeProjection = MemoryKnowledgeProjectionCoordinator()
var memoryNotes: [CompanionNoteRecord] {
    memoryKnowledgeProjection.visibleMemoryNotes
}
var campNotes: [CampNoteRecord] {
    memoryKnowledgeProjection.visibleCampNotes
}
var memoryNotesState: WorkflowLoadState<[CompanionNoteRecord]> {
    memoryKnowledgeProjection.visibleMemoryState
}
var campNotesState: WorkflowLoadState<[CampNoteRecord]> {
    memoryKnowledgeProjection.visibleCampState
}
var memoryDistillationVisibilityCards:
    [MemoryDistillationVisibilityCard] {
    memoryKnowledgeProjection.visibilityCards
}
var runtimeCredentialAttachmentPending:
    RuntimeCredentialAttachmentPending?
var proposalVisibilityRepairByMessageId:
    [String: ProposalVisibilityRepairReceipt] = [:]
var acceptedMissionReportRepairByMissionId:
    [String: AcceptedMissionReportRepairReceipt] = [:]
var acceptedMissionDistillationRepairByMissionId:
    [String: AcceptedMissionDistillationRepairReceipt] = [:]
var coworkDistillationRepairsByMissionId:
    [String: [CoworkDistillationRepairReceipt]] = [:]
var reportPresentationPlanByKey:
    [MissionReportPresentationKey: ExistingReportPresentationPlan] = [:]
private enum ScheduleMutationKey: Hashable {
    case template(String)
    case schedule(String)
}
private struct SchedulePostCommitRepairCarrier {
    let generation: UInt64
    let identity: ScheduleMutationCommittedIdentity
    let receipt: SchedulePostCommitRepairReceipt
}
private var scheduleMutationGenerationByKey:
    [ScheduleMutationKey: UInt64] = [:]
private var schedulePostCommitRepairByKey:
    [ScheduleMutationKey: SchedulePostCommitRepairCarrier] = [:]
private enum ScheduleCommandFlightPurpose: Equatable {
    case mutation
    case repair(startingReceipt: SchedulePostCommitRepairReceipt)
}
private struct ScheduleCommandFlight {
    let attempt: UUID
    let generation: UInt64
    let purpose: ScheduleCommandFlightPurpose
    let task: Task<Void, Never>
}
private var scheduleCommandFlightByKey:
    [ScheduleMutationKey: ScheduleCommandFlight] = [:]
private struct OAuthQueuedRejection: Sendable, Equatable {
    let attempt: UUID
    let requestedFlow: OAuthCredentialFlow
    let trace: OperationTrace
}
private enum OAuthCallbackAppOrigin: Sendable, Equatable {
    case active(RuntimeOAuthAuthorizationReceipt)
    case authorizationRecovery(RuntimeOAuthAuthorizationRecoveryPending)
}
private struct OAuthCallbackClaimCandidate: Sendable, Equatable {
    let lifecycleAttempt: UUID
    let reservation: RuntimeOAuthAuthorizationReservation
    let origin: OAuthCallbackAppOrigin
    let listenerLease: RuntimeOAuthListenerLease
    let physicalCallbackAttempt: UUID
    let command: RuntimeOAuthCallbackCommand
    let trace: OperationTrace
}
private var oauthCallbackClaimCandidateByFlow:
    [OAuthCredentialFlow: OAuthCallbackClaimCandidate] = [:]
private struct OAuthCustomSchemeCallbackIngress: Sendable, Equatable {
    let attempt: UUID
    let command: RuntimeOAuthCustomSchemeCallbackCommand
    let trace: OperationTrace
}
private var oauthCustomSchemeCallbackIngress:
    OAuthCustomSchemeCallbackIngress?
private var oauthCustomSchemeCallbackIngressTask:
    Task<Void, Never>?
private enum OAuthLifecycleAppState: Sendable, Equatable {
    case reserving(attempt: UUID, queuedRejection: OAuthQueuedRejection?)
    case preparing(
        attempt: UUID,
        reservation: RuntimeOAuthAuthorizationReservation
    )
    case active(
        attempt: UUID,
        reservation: RuntimeOAuthAuthorizationReservation,
        authorization: RuntimeOAuthAuthorizationReceipt
    )
    case authorizationRecovery(
        attempt: UUID,
        reservation: RuntimeOAuthAuthorizationReservation,
        pending: RuntimeOAuthAuthorizationRecoveryPending
    )
    case callbackProcessing(
        attempt: UUID,
        reservation: RuntimeOAuthAuthorizationReservation,
        origin: OAuthCallbackAppOrigin
    )
}
@MainActor
fileprivate enum OAuthListenerRecoveryApplyRemainder {
    case none
    case callbackQueued(callbackAttempt: UUID)
    case callbackProcessing(callbackAttempt: UUID)
    case callbackFinished(callbackAttempt: UUID)
}
@MainActor
fileprivate enum OAuthListenerSlotPhase {
    case starting(startAttempt: UUID)
    case live
    case failureClaimed(failureAttempt: UUID)
    case callbackClaimed(callbackAttempt: UUID)
    case callbackProcessing(callbackAttempt: UUID)
    case callbackAndFailureClaimed(
        callbackAttempt: UUID,
        failureAttempt: UUID
    )
    case callbackProcessingAndFailureClaimed(
        callbackAttempt: UUID,
        failureAttempt: UUID
    )
    case recoveryAppliedAwaitingApp(
        failureAttempt: UUID,
        remainder: OAuthListenerRecoveryApplyRemainder
    )
    case callbackFinishedAwaitingFailure(
        callbackAttempt: UUID,
        failureAttempt: UUID
    )
    case callbackFailureAppliedAwaitingConsumer(callbackAttempt: UUID)
    case callbackProcessingAfterFailure(callbackAttempt: UUID)
}
@MainActor
fileprivate struct OAuthListenerSlot {
    let authorization: RuntimeOAuthAuthorizationReceipt
    let lease: RuntimeOAuthListenerLease
    let listener: NWListener
    var phase: OAuthListenerSlotPhase
    var startContinuation:
        CheckedContinuation<RuntimeOAuthListenerStartOutcome, any Error>?
    var failureTask: Task<Void, Never>?
    var retireAfterClaimDrain: Bool
    var claimDrainContinuation:
        CheckedContinuation<RuntimeOAuthListenerStopOutcome, Never>?
}
fileprivate struct OAuthListenerRecoveryEvent: Sendable {
    let authorization: RuntimeOAuthAuthorizationReceipt
    let lease: RuntimeOAuthListenerLease
    let failureAttempt: UUID
    let outcome: RuntimeOAuthAuthorizationRecoveryOutcome
}
fileprivate struct OAuthListenerCallbackEvent: Sendable {
    let authorization: RuntimeOAuthAuthorizationReceipt
    let lease: RuntimeOAuthListenerLease
    let callbackAttempt: UUID
    let callbackURL: URL
}
fileprivate extension AppStore {
    @MainActor static func startOpenAIAuthCallbackListener() throws
        -> NWListener
}
@MainActor
fileprivate final class OAuthListenerPlatformOwner {
    fileprivate let recoveryEvents: AsyncStream<OAuthListenerRecoveryEvent>
    fileprivate let callbackEvents: AsyncStream<OAuthListenerCallbackEvent>
    private let recoveryContinuation:
        AsyncStream<OAuthListenerRecoveryEvent>.Continuation
    private let callbackContinuation:
        AsyncStream<OAuthListenerCallbackEvent>.Continuation
    private var slotByFlow: [OAuthCredentialFlow: OAuthListenerSlot] = [:]
    private var isShutdown = false
    private var terminationObserver: NSObjectProtocol?

    fileprivate init()
    nonisolated fileprivate func makePort(
        failureSink: RuntimeOAuthListenerFailureSink
    ) -> RuntimeOAuthPlatformPort
    fileprivate func consumeRecoveryIfCurrent(
        _ event: OAuthListenerRecoveryEvent
    ) -> Bool
    fileprivate func acknowledgeRecoveryApplyIfCurrent(
        _ event: OAuthListenerRecoveryEvent
    )
    fileprivate func beginCallbackClaimIfCurrent(
        _ event: OAuthListenerCallbackEvent
    ) -> Bool
    fileprivate func acknowledgeCallbackPromotionIfCurrent(
        _ event: OAuthListenerCallbackEvent
    ) -> Bool
    fileprivate func finishCallbackIfCurrent(
        authorization: RuntimeOAuthAuthorizationReceipt,
        lease: RuntimeOAuthListenerLease,
        callbackAttempt: UUID,
        restoresAuthorization: Bool
    )
    fileprivate func installTerminationObserver(
        recoveryConsumer: Task<Void, Never>,
        callbackConsumer: Task<Void, Never>
    )
    fileprivate func shutdown()
}
private extension AppStore {
    @MainActor func consumeOAuthCallbackEvent(
        _ event: OAuthListenerCallbackEvent
    ) async
}
private var oauthLifecycleStateByFlow:
    [OAuthCredentialFlow: OAuthLifecycleAppState] = [:]
private let oauthListenerPlatformOwner: OAuthListenerPlatformOwner
private var oauthListenerRecoveryConsumerTask: Task<Void, Never>? = nil
private var oauthListenerCallbackConsumerTask: Task<Void, Never>? = nil
deinit {
    let owner = oauthListenerPlatformOwner
    let recoveryConsumer = oauthListenerRecoveryConsumerTask
    let callbackConsumer = oauthListenerCallbackConsumerTask
    let _: Task<Void, Never> = Task { @MainActor in
        let _: Void = owner.shutdown()
        if let recoveryConsumer {
            let _: Void = recoveryConsumer.cancel()
        }
        if let callbackConsumer {
            let _: Void = callbackConsumer.cancel()
        }
    }
}
private var missionIndexTask: Task<Void, Never>?
private var missionDetailTaskByMissionId: [String: Task<Void, Never>] = [:]
private var inputCampTaskByCampId: [String: Task<Void, Never>] = [:]
private var inputReviewTaskByIngestionId: [String: Task<Void, Never>] = [:]
private var runtimeTask: Task<Void, Never>?
private var runtimeCredentialRecoveryTask: Task<Void, Never>?
private var runtimeCredentialRecoveryAttempt: UUID?
private var proposalRepairTaskByMessageId: [String: Task<Void, Never>] = [:]
private var proposalRepairAttemptByMessageId: [String: UUID] = [:]
private var acceptedMissionReportRepairTaskByMissionId:
    [String: Task<Void, Never>] = [:]
private var acceptedMissionReportRepairAttemptByMissionId:
    [String: UUID] = [:]
private var distillationRepairTaskByMissionId: [String: Task<Void, Never>] = [:]
private var distillationRepairAttemptByMissionId: [String: UUID] = [:]
private var coworkDistillationRepairTaskByMissionId:
    [String: Task<Void, Never>] = [:]
private var coworkDistillationRepairAttemptByMissionId:
    [String: UUID] = [:]
private var reportPresentationTaskByKey:
    [MissionReportPresentationKey: Task<Void, Never>] = [:]
private var reportPresentationAttemptByKey:
    [MissionReportPresentationKey: UUID] = [:]
private var rateLimitEventRetryTaskByMissionId:
    [String: Task<Void, Never>] = [:]
private var oauthLifecycleTaskByFlow:
    [OAuthCredentialFlow: Task<Void, Never>] = [:]
private var oauthRejectedAttemptTaskByFlow:
    [OAuthCredentialFlow: Task<Void, Never>] = [:]
private var oauthRejectedAttemptByFlow: [OAuthCredentialFlow: UUID] = [:]
```

McpStore owns exactly:

```swift
struct McpSecretProjectionKey: Hashable, Sendable {
    let serverId: String
    let key: String
}
var registryProjection = WorkflowProjection<McpRegistrySnapshot>()
var campProjectionByCampId: [String: WorkflowProjection<McpCampSnapshot>] = [:]
var toolProjectionByServerId: [String: WorkflowProjection<McpToolSnapshot>] = [:]
var secretProjectionByKey:
    [McpSecretProjectionKey: WorkflowProjection<Bool>] = [:]
var visibleFailure: UserVisibleFailure?
var pendingServerCleanupByServerId: [String: McpPendingServerCleanup] = [:]
private var registryTask: Task<Void, Never>?
private var campTaskByCampId: [String: Task<Void, Never>] = [:]
private var toolTaskByServerId: [String: Task<Void, Never>] = [:]
private var secretTaskByKey: [McpSecretProjectionKey: Task<Void, Never>] = [:]
private var serverCleanupTaskByServerId: [String: Task<Void, Never>] = [:]
private var serverCleanupAttemptByServerId: [String: UUID] = [:]
```

`McpSecretProjectionKey` is App-only and never enters evidence. Every
façade sequence is begin/capture generation → cancel the old same-key Task →
await terminal → apply with captured generation → update legacy render caches
only for applied `.loaded`. Failed/stale/canceled loads never clear caches.
Legacy CodingRanch dashboard/inbox copy the prior object and change only its
load-state projection; they never fabricate zero/empty data. Success clears a
global visible failure only when its FailureOperation matches the completing
operation.

The Runtime credential/OAuth carriers above are opaque session-local
capabilities, not reconstructed durable state. AppStore inserts one only from
its exact controller terminal. Before every retry it captures the byte-equal
pending value plus a fresh attempt UUID; terminal apply/removal requires both
the current opaque value and current attempt still match. An explicit newer
API-key save may replace an older API-key attachment capability only after its
own Keychain write commits; Search-key save/delete never reads, replaces, or
clears that capability. A failed API-key delete preserves it, while a committed
API-key delete compare-clears it before any stale retry can attach a deleted
account. `OAuthListenerPlatformOwner.slotByFlow` is the sole concrete
platform-resource registry, not a second lifecycle source of truth. The owner
contains only the current `NWListener`, opaque controller-minted lease, phase,
that lease's one failure Task, and its two transport continuations. A slot may
neither synthesize a receipt/pending value nor decide a Runtime recovery stage.
The owner creates both `.unbounded` `AsyncStream` values and continuations in
its initializer before any factory/controller exists. That buffering policy is
lossless transport rather than lifecycle authority: App installs the sole two
consumer Tasks before `AppStore.init()` returns and before any listener can be
started. Per lease, one failure claim and one callback-delivery claim bound the
producer side before either event is yielded; any duplicate connection/failure
is rejected before enqueue. Those claims are orthogonal only in the one closed
case where listener failure follows a callback claim: the slot changes to
`.callbackAndFailureClaimed(callbackAttempt:failureAttempt:)`, preserving both
identities without a second event of either kind. A `.callbackClaimed` or
`.callbackAndFailureClaimed` phase means that the yielded physical callback has
not yet completed its controller claim/App-promotion handshake. The callback
consumer first calls `beginCallbackClaimIfCurrent`; that is only an exact
lease+attempt proof and does not advance the phase or resume a drain. For an
eligible active/recovery origin the sole consumer then awaits the controller's
non-I/O `claimOAuthCallback`. Only after `.claimed` returns may one
non-suspending MainActor segment call
`acknowledgeCallbackPromotionIfCurrent`, change the phase to
`.callbackProcessing` or `.callbackProcessingAndFailureClaimed`, cancel the
exact old lifecycle Task, and install the capability-based logical callback
Task. That transition acknowledges physical delivery. A sealed claim reject or
abandon is acknowledged only after controller/App ownership has been left in a
closed stable state; a purely local preparing/invalid-state reject may finish
synchronously. Thus replacement cannot pass a callback drain before the
controller has either claimed the callback or definitively rejected it. The
processing phase retains the logical attempt only so a later failure or finish
can rejoin it, and is not itself an outstanding physical callback claim. The
recovery consumer calls
`consumeRecoveryIfCurrent`, performs its exact guarded App transition, then
calls `acknowledgeRecoveryApplyIfCurrent` in one non-suspending MainActor
segment. Only the recovery acknowledgement removes
an ordinary dead slot or resumes its waiter, so G2 cannot publish between
physical event consumption and App apply. A retired lease or mismatched attempt
is discarded with zero lifecycle/controller/codec work. The callback stream is
consumed serially: it never spawns sibling claim Tasks, so a later event remains
in the lossless stream until the prior short claim/promotion/abandon handshake
has terminated. Neither stream consumer reconstructs an opaque value or owns
controller state.

OAuth is stricter: one flow has exactly one authoritative
`OAuthLifecycleAppState`, and no second authorization receipt may be generated
until the first callback cleanup has reached its cleaned terminal. In one
MainActor synchronous segment, a nil-flow tap writes
`.reserving(attempt:queuedRejection:nil)` and registers the sole lifecycle Task
before that Task's first await. The Task first calls
`reserveOAuthAuthorizationAttempt`; only its returned opaque reservation may
move the byte-equal App state to `.preparing(attempt:reservation:)` and then be
passed to `prepareOAuthAuthorization(_:reservation:)`. Preparation never opens
the browser. A successful `.prepared(authorization)` controller terminal means
only that listener plus the atomic state/verifier envelope committed and the controller now
owns the same opaque post-preparation authorization. In one MainActor
synchronous segment, and only while the captured preparation attempt,
reservation, and phase are still byte-equal, App mints a fresh browser-open
attempt, changes `.preparing` to
`.active(attempt:openAttempt,reservation:reservation,
authorization:authorization)`, compare-clears the
exact preparation Task, constructs
`RuntimeOAuthAuthorizationOpenCommand.prepared(_:reservation:)`, and installs
the sole new lifecycle Task before yielding. That Task alone calls
`openOAuthAuthorization(_:)`. No platform browser call can precede the App
`.active` state. A preparation `.recoveryPending` instead atomically installs
the returned opaque pending with a fresh App attempt, compare-clears the exact
preparation Task, and performs no browser call; only the explicit closed
authorization-recovery action may satisfy its retained listener/browser stage.

The browser-open terminal applies only to the byte-equal active open attempt,
reservation, authorization, and Task. `.opened` compare-clears that Task and
retains active authorization; `.retainedRecovery` installs the controller-
returned pending without displaying a second failure; `.recoveryPending`
installs its pending and exact failure; and `.superseded` may clear no current
active carrier. A current command cannot return `.superseded` while its exact
active App owner remains unchanged—such a pair is an invariant failure in the
controller/App matrix. A callback or listener transition that supersedes the
open attempt first replaces/cancels only that exact Task, so its late open
terminal is stale and cannot clear the newer callback/recovery Task. Every
later active, authorization-recovery, and callback-processing App state retains
the same reservation, and terminal apply/removal requires
the attempt, reservation, and phase value all remain byte-equal. Every recovery
retry replaces only the `attempt` while retaining the opaque reservation/value,
so a late terminal cannot change a newer state. Ordinary lifecycle terminals
use that strict byte-equal rule. Listener-handler terminals use only the
following closed MainActor transition table. Every row requires the handler
slot's exact lease+failure-attempt and
`lease.belongs(to: currentReservation)`; a row carrying a pending additionally
requires its flow/authorization and `ownsListenerLease(_:)` to match:

1. `deferredToPreparation` may display its already captured failure only while
   the exact preparation Task/attempt remains current; it leaves that Task and
   `.preparing` state unchanged.
2. `listenerPendingSupersedesMatchingPreparationOrigin` accepts a pending
   bound to that preparation's reservation/authorization when App is still the
   exact `.preparing`, or has just applied that same preparation into matching
   `.active`/`.authorizationRecovery`. It cancels and compare-clears only the
   old preparation/browser-open/recovery lifecycle Task if present, installs
   the returned pending with a fresh App attempt, and makes every late
   preparation/open terminal unable to apply or clear the new carrier. When
   this row replaces a matching active/recovery attempt that already has a
   callback candidate, it also executes the shared candidate-retarget tail
   below.
3. `listenerPendingSupersedesMatchingActiveOrRecovery` changes a matching
   `.active` to the returned pending, or replaces a matching stable/in-flight
   recovery. For an active browser-open or in-flight recovery it first cancels
   and compare-clears the exact Task/attempt, then installs the pending with a
   fresh attempt. The retry control is enabled only when this flow has no
   callback claim candidate; a candidate-retarget transition keeps it disabled.
   A requested listener restart after the candidate closes remains pending
   behind any same-lease claim drain and cannot publish G2/success early. The
   late old open/retry cannot clear it.

Rows two and three share one atomic candidate-retarget tail. Whenever either
row installs the returned pending over an exact `.active` or
`.authorizationRecovery` lifecycle attempt and
`oauthCallbackClaimCandidateByFlow` still contains the exact candidate bound
to that old attempt/reservation/authorization/lease, the same MainActor segment
replaces that candidate with a copy equal in every field except that
`lifecycleAttempt` becomes the fresh pending attempt and `origin` becomes
`.authorizationRecovery(returnedPending)`. Command, trace, physical callback
attempt, reservation, authorization, and listener lease remain exact. This
retargeting neither acknowledges the callback nor releases its drain. It is
required both while the non-I/O actor claim result is suspended and after the
controller has sealed `.claimed` but before the callback consumer's MainActor
continuation resumes. If the pending applies before candidate capture, the
later candidate naturally captures the new pending; a mismatched candidate or
newer owner receives zero candidate mutation.

An authorization-recovery retry is enabled only while App holds the exact
`.authorizationRecovery` owner and
`oauthCallbackClaimCandidateByFlow[flow] == nil`. The retry action rechecks
both facts in one non-suspending MainActor segment before minting a fresh
lifecycle attempt or installing a Task. A stale tap after exact candidate
insertion or retarget performs zero App mutation and zero controller, port,
Reporter, browser, or trace-factory work; it is not queued and does not mint a
retry trace. Candidate-first therefore preserves its guarded attempt/Task until
promotion, abandon, sealed reject, or local reject removes the candidate and
physically acknowledges the callback. Retry-first completes its attempt/Task
installation before a later candidate captures that current attempt, after
which the ordinary callback-takes-over-in-flight-retry table applies. Rows two
and three may install/display their pending while the control stays disabled;
retargeting never re-enables retry. Once the handshake removes the candidate,
an exact remaining recovery owner may re-enable one retry. A direct controller
retry that races after claim phase installation is `.superseded` with that
phase byte-equal and zero I/O.

4. While App still has matching `.active`/`.authorizationRecovery` and
   `oauthCallbackClaimCandidateByFlow` contains the exact lease+reservation+
   authorization whose controller claim already won, `.deferredToCallback`
   may display only its captured failure. It neither replaces the old App
   carrier nor clears the candidate or physical drain; the later promotion
   retains `claim.origin` as the App restoration witness. The capability
   method's first CAS reads the claim phase's current merged listener stage, so
   its eventual recovery outcome—not the immutable claim value—carries that
   post-claim merge. A returned pending in this window is an invariant failure
   only when it was produced after the controller entered the claim phase. A
   pending already sealed before claim instead follows row two or row three and
   retargets the candidate, regardless of whether its MainActor apply runs
   while the actor claim result is suspended or after the controller seals
   `.claimed` but before the callback consumer's MainActor continuation
   resumes.
5. While the exact App phase is `.callbackProcessing`, both an actor-returned
   `.pending` and `.deferredToCallback` may display only their exact already
   captured failure. They never cancel/clear the callback Task and never change
   lifecycle state. The capability Task enters only
   `handleOAuthCallback(claim)`; its first actor CAS advances the exact already-
   claimed owner to callback processing and reads any retained merged stage. It
   never performs a second claim. Its sealed terminal is the only terminal that
   may synchronize App. If credentials are already committed, the same display-
   only rule preserves the controller-private cleanup owner while App stays in
   the exact callback-processing carrier.
6. After exact abandon has installed its returned authorization-recovery
   pending and cleared the candidate, a late same-lease
   `.deferredToCallback` event may display its already captured failure while
   App holds that same-reservation/same-authorization pending whose
   `ownsListenerLease(_:)` accepts the event lease. It changes no lifecycle
   state or Task. The physical failure-attempt join makes this display exactly
   once; it is not a second capture. This is the only post-abandon exception.
7. `superseded` and every lease, failure-attempt, reservation, authorization,
   flow, or phase mismatch perform zero slot-Task mutation: they never cancel
   or clear a claimed failure Task/tombstone and never alter lifecycle state,
   the callback carrier, or a newer slot. Only `consumeRecoveryIfCurrent` may
   compare-clear its exact failure Task and enter the awaiting-App tombstone;
   only the immediately following exact guarded App apply plus
   `acknowledgeRecoveryApplyIfCurrent` may remove that tombstone/resume a claim
   drain.

The package pure comparison methods expose no receipt, stage, or lease ID and
perform no I/O; App cannot name any fileprivate field. Rows two and three are
the complete listener state-changing cross-phase exception family; rows four
through six are explicitly display-only. No listener terminal may replace/cancel a callback lifecycle
Task, and no other terminal may cross an App phase or replace/cancel a
lifecycle Task.

An incoming callback is also a single-flight lifecycle phase, not a free Task.
The sole callback-stream consumer serializes the short claim handshake. In one
MainActor segment it first proves the exact physical lease+callback attempt and
captures an `OAuthCallbackClaimCandidate`; it does not yet mutate
`OAuthLifecycleAppState`, cancel/clear the browser-open or recovery Task, or
advance the physical callback phase. An eligible candidate exists only for an
exact `.active` or `.authorizationRecovery` value. It constructs the command
only through `.authorization(_:reservation:listenerLease:callbackURL:)` or
`.recovery(_:reservation:listenerLease:callbackURL:)`, passing the App-held
reservation and event lease without reading pending-private state, then awaits
`claimOAuthCallback(command,trace:)` on that same serial consumer.

`claimOAuthCallback` is an actor hop whose body has no suspension, Reporter,
codec, preparation-envelope read, exchange, credential, browser, listener, or other business
I/O. It validates operation, reservation, opaque authorization, and exact
controller-current listener lease and atomically installs one
`.callbackClaimAwaitingApp(claimId,reservation,authorization,lease,
controllerCurrentOrigin,retainedStage,command,trace)` owner. It invalidates an
exact browser-open/recovery attempt but performs no callback work. Its opaque
  claim exposes only flow, the controller-current ready/recovery origin, and pure
  reservation/authorization/lease comparisons; App cannot read its claim ID or
  owned fields. The exact candidate remains in
  `oauthCallbackClaimCandidateByFlow` until sealed rejection or
  promotion/abandon plus physical acknowledgement, allowing the independent
  listener consumer to recognize the claim-awaiting-App window without reading
  controller-private state. A lease-mismatched G1 command after G2 installation returns
`.superseded` with zero mutation and zero business I/O, leaving the existing
App lifecycle Task untouched.

After `.claimed`, one non-suspending MainActor promotion segment first rereads
`currentCandidate = oauthCallbackClaimCandidateByFlow[flow]`; it may not use
the pre-await local candidate's `lifecycleAttempt` or `origin`. It proves the
map-current candidate's immutable reservation, command, trace, listener lease,
and physical callback attempt equal the submitted pre-await candidate and
physical event. It separately requires `claim.flow` to match and calls only
the claim's pure `belongs(to:)`, `ownsAuthorization(_:)`, and
`ownsListenerLease(_:)` proofs. It then revalidates
`currentCandidate.lifecycleAttempt` and `currentCandidate.origin` against the
current same-reservation/same-authorization App state/Task. It calls
`acknowledgeCallbackPromotionIfCurrent`, then and only then cancels and
compare-clears the exact browser-open/recovery Task, changes the App state to
`.callbackProcessing` with a fresh attempt and `claim.origin`, and installs the
sole Task that calls `handleOAuthCallback(claim)`. No await occurs inside that
promotion. `handleOAuthCallback` accepts only the exact
`.callbackClaimAwaitingApp` capability, atomically changes it to the ordinary
controller callback-processing owner, and only then performs parsing, state,
exchange, credential, and cleanup work. Callback terminal apply requires the
fresh App attempt, reservation, and claim origin all remain byte-equal.

If controller claim returns `.superseded`, App leaves its lifecycle state and
Task byte-identical, clears only the exact candidate, and non-restoring-finishes
only that exact physical claim.
If a claim succeeds but App/physical promotion is no longer possible, the
consumer first calls `abandonOAuthCallbackClaim(claim)` while the physical
claim remains drain-bearing. That exact actor CAS converts the abandoned claim
to an opaque authorization recovery: ready gains `.listenerRestart`,
browser-reopen gains `.listenerThenBrowser`, and any existing listener stage is
merged without capture or I/O. Only after that stable owner exists does App
non-restoring-finish the physical claim and guardedly adopt the returned pending
when its reservation is still current. It never restores ready with a consumed
listener and never leaves `.callbackClaimAwaitingApp` stranded. Consumer Task
cancellation is not an exit: an already claimed capability must be promoted or
abandoned before the loop may terminate. Abandon apply is one closed outcome-
by-current-owner matrix. For `.authorizationRecovery(pending)`, if App still
holds any same-reservation/same-authorization active or recovery owner, it
cancels/compare-clears only that exact current Task if present and installs the
returned pending with a fresh attempt; if App already holds the byte-equal
pending it is a no-op. A different/newer reservation or removed flow is left
unchanged. For `.superseded(sealedOwner)`, a byte-equal same-reservation sealed
ready/recovery owner is adopted as a whole (or left unchanged when
already present), `.none` is accepted only after the flow was removed, and a
different/newer reservation is left unchanged. `.transientAuthorizationOwner`
while the captured reservation remains App-current, or callback processing
under that same reservation after abandon success, is an invariant failure. The
consumer then clears only the exact candidate and finishes the physical claim.
Thus it never overwrites a newer authorization and never leaves an old same-
reservation carrier as the sole representation of an abandoned controller
owner.

A callback event while exact `.preparing` has no App-visible prepared owner and
is rejected locally with zero controller/business I/O. Only when its event
lease belongs to that preparation reservation may the exact plain claim be
restored to live. `.reserving`, callback-processing, empty,
owner/flow/authorization-mismatched, and stale-attempt states non-restoring-
finish the exact physical claim and install no logical Task; a failed initial
physical join performs no finish or App mutation. Preparation itself cannot
have opened the browser. Duplicate/hostile callbacks therefore perform zero
controller/platform/codec/Keychain work.

A pre-commit callback failure returns `.notCommitted` only after capability
processing began; controller and App restore the claim's exact controller-
current origin when no new listener obligation exists, while a retained/merged
obligation returns the exact opaque pending. A committed callback moves only
through controller-private cleanup to a cleaned terminal. A later
`.superseded(owner)` terminal compare-clears only
the exact promoted Task and adopts the sealed same-flow owner as a whole; App
never queries/reconstructs controller state or clears a listener-installed
recovery.

Controller recovery has a matching explicit in-flight owner. Before the first
recovery await it atomically records reservation, authorization, recovery
attempt, starting pending, and current remaining stage. In
`.listenerThenBrowser`, successful listener restart changes current remaining
stage to `.browserReopen` before awaiting browser open; a listener-only success
changes it to no remaining stage before the ready terminal. An incoming
callback whose command carries the same reservation, opaque authorization, and
current physical lease may be claimed even when the App-captured pending's old
stage no longer equals controller progress. The non-I/O claim CAS marks the
recovery attempt superseded and transfers the exact current remaining stage
into `.callbackClaimAwaitingApp`; App promotion and capability processing are
the only next steps. It never reruns a completed listener sub-stage. A
pre-commit callback failure restores the exact adopted remaining pending, or
ready when none remains; credential commit moves only to cleanup. Every late
recovery terminal observes the stale attempt and is zero-I/O/no-apply. A
different reservation/authorization/lease remains `.superseded`. This is the
only callback takeover of an in-flight recovery and does not grant a listener
terminal any authority over the claim/App carrier.

AppStore's `openProviderAuth()` switches the globally sole nonempty state.
`.authorizationRecovery` retries its exact authorization only when the same flow has no callback claim
candidate. Authorization preparation has no repair branch: state and verifier
are one atomic Keychain envelope, so a failed write is genuinely not committed
and a successful write has no compensation capability. A candidate-present
authorization-recovery tap is a synchronous zero-mutation/no-I/O no-op and is
not queued. `.active`, `.preparing`, or
`.callbackProcessing` rejects attempted B through the retained reservation,
and an empty global state dictionary alone begins reservation. A tap while
`.reserving` cannot call the actor yet: it stores exactly one
`OAuthQueuedRejection` in that same state, and further taps are disabled. Once
A's reservation returns and still matches App Task/attempt ownership, App
publishes `.preparing` first and launches queued B through the separate
rejected-attempt Task/UUID carrier with that exact reservation. The queued value
retains the flow selected at the rejected tap; that Task must use the stored
`requestedFlow` and may not reread a mutable profile/API-format selection after
A's reservation returns. Direct B taps
in `.preparing`/`.active`/`.callbackProcessing` do the same. The rejected Task never cancels,
replaces, or adopts `oauthLifecycleTaskByFlow` or its attempt. The reject-only
controller method has no edge to RNG, listener/preparation/state/Keychain/
codec/browser/platform/business work: if the supplied reservation is still
controller-current, it performs one reporter capture and returns `.rejected`;
if A has terminated or the reservation differs, it returns `.superseded` with
zero reporter/UI/business I/O. There is no actor-job FIFO assumption, no
flow-only reject overload, and no fixed nonfailure shortcut in App. A late
failure, stale listener callback, or stale cleanup cannot clear, overwrite,
reopen, or report against a later attempt. App never reads the retained trace,
state, URL, verifier, attachment target, or callback fields.

App permits at most one rejected-attempt Task per flow. It captures the exact
reservation-bearing `OAuthLifecycleAppState` plus its rejection UUID before
launch. Its terminal may update the B failure banner only when both the
rejection UUID and current reservation-bearing state remain byte-equal to that
capture. Whether
applied or stale, the rejection terminal compare-clears only its own rejection
carrier and never touches A's task, state, receipt, recovery, or cleanup. A's
late terminal therefore applies
normally. `reserveOAuthAuthorizationAttempt` is the sole
`P1-B-SEAM oauthAuthorizationPreparation` marker owner. Preparation,
and reject-only calls are its source-gated opaque-reservation continuations; the
existing `openProviderAuth` delegate tuple is reused and no
seam/descriptor/delegate count changes.

`pendingServerCleanupByServerId` is not a second durable deletion state: it is
the session-local owner of either exact opaque cleanup sum case returned by the
controller. McpStore inserts `.rollback` only from
`notCommittedCleanupPending` and `.deleted` only from
`committedCleanupPending`; it never reconstructs one from registry absence or
a raw server ID. The dictionary key is always the associated pending value's
derived `serverId`; a mismatched external key is never accepted. While a server
has a pending value, another full delete is
disabled and only cleanup retry is offered.

The retained App cleanup façade is exactly
`func retryServerCleanup(serverId: String)`. It accepts no token or trace,
loads only `pendingServerCleanupByServerId[serverId]`, and delegates through
the single-flight/guard below to
`McpWorkflowController.finishServerCleanup(_:)`. Its sole marker is
the derived `P1-B-DELEGATE <DE-id> mcpFinishServerCleanup` entry in the same
127-tuple ledger.

Cleanup retry is per-server single-flight. McpStore starts one Task only when
both task and attempt dictionaries are empty for that ID, captures the exact
pending Equatable value plus a fresh attempt UUID, then records both before the
first await. It applies a terminal only if the current attempt UUID and current
pending value still equal those captured values, as decided by the pure
Application `McpCleanupApplyGuard.mayApply` callable; McpStore does not restate
that comparison. `deletionRetryReady` and
`deletionCommitted` compare-and-remove the pending value; `.pending` may update
the visible failure but leaves the same value in place and never re-inserts a
stale token. Task/attempt removal is itself conditional on the captured UUID.
Thus two clicks cannot let an older failed await overwrite a newer successful
cleanup. On process restart the Manager has no inherited process handle, so
the in-memory map and task dictionaries correctly start empty.

Closed view protocols continue to consume the existing
`CodingRanchLoadState.failed(String)` and other legacy render carriers. AppStore
maps only `UserVisibleFailure.message` into those Strings after a typed
WorkflowProjection terminal; no Application type changes the closed view
protocol, and no legacy String is ever used as the Core error source.

### 6.2 MissionWorkflowController

Mission detail and Mission index are the two exact snapshots in §6.6. Each is
assembled off-state and published atomically: detail contains selected Mission,
cards, artifacts, pending requests, Squad/member IDs/companions, events and
spend; index contains mission list, Camps, missions-by-Camp, and artifact
ledger. Malformed `memberIdsJson` is a typed parse failure, not fallback to
assignees. Start, cancel, reload, and current acceptance compatibility seams
return typed outcomes. P1-B does not add AcceptanceWorkflowController or new
acceptance semantics.

AppStore delegates `reloadMission`, `reloadMissionList`, mission start/cancel,
and the current accept call boundary to this controller, then maps only loaded
snapshots. A refresh failure preserves all prior mission arrays/maps and puts
the visible failure in `missionWorkflowState`/`feedNotice`; it never clears the
board.

Mission/user-request answer, proposal confirmation, schedule notification,
and any mission write followed by a read/event use `OperationCommitOutcome`.
If the domain transaction/mission creation already committed, a later
mission-ID refresh, proposal-confirmed event, guide notification, or App
projection failure is `.committedWithVisibilityFailure`, not a retryable
generic failure.

### 6.3 InputWorkflowController

The Input Camp snapshot owns the persisted Camp/ingestion/active-rumination
data already read by `codingRanchPersistedSnapshot` plus every secondary
Adapter read enumerated in §6.6; the separate review snapshot owns decoded
RuminationResult. Operations cover dashboard/inbox/review load and current
feed/rumination start/cancel seams.
The controller owns no provider task and does not bypass DurableWorkSupervisor.

`CodingRanchStoreAdapter` maps only loaded snapshots. On refresh failure it
keeps the prior dashboard/inbox/cache entries and changes their load state to
the existing `.failed(failure.message)` String case while AppStore separately
retains the typed `WorkflowLoadState.failed(UserVisibleFailure)`. This preserves
the closed-scope `CodingRanchLiveHosts`/CowRoster callers and does not change the
legacy enum associated type. It does not synthesize a blank dashboard or
`items: []`. Start/cancel failure exposes the same final safe trace message in
the existing String action surface while retaining the typed outcome in the
controller/AppStore.

Revision 04 freezes the corresponding historical-test ownership migration.
The four existing `CodingRanchTests` declarations named below keep their full
runtime assertions and declaration identities, but their source gates follow
the reviewed owner instead of demanding the deleted App-side implementation:

- `ruminationSanitizesPersistedAndVisibleDiagnostics` checks the Adapter's
  action boundary plus `AppStore.executeRuminationCommand`'s typed
  `InputWorkflowController.startRumination` outcome; neither range may expose
  `localizedDescription`, `String(describing:)`, raw provider detail, or a
  second capture;
- `ruminationAdapterDelegatesStartRetryCancelWithoutUnownedTask` requires
  AppStore/Adapter to delegate start and cancel only to the Input controller.
  The exact `readInputCampBundle -> prepareRuminationStart -> replay/new ->
  RuminationStartCommand -> Orchestrator.startRumination` sequence and direct
  `Orchestrator.cancelRumination` call are asserted solely inside
  `InputWorkflowPorts.live`, where those production ports now belong;
- `ruminationUnknownRestartRendersRecoveringWithoutInventingReading` preserves
  the unknown/recovering UI and persisted-owner checks. A missing App ingestion
  map is recovered only by a typed `InputWorkflowController.loadReview`, then a
  typed `loadCamp`; failure remains the same traceable failed projection and
  never defaults to `.reading` or an empty snapshot; and
- `ruminationPhaseProjectionUsesOnlyMatchingSupervisorEvents` requires phase
  and projection events to resolve the Camp through those controller loads,
  validate the loaded active-work identity, and atomically map the loaded Camp
  snapshot. It forbids `FeedService`, `AppDatabase`,
  `codingRanchPersistedSnapshot`, and direct Orchestrator I/O in the Adapter.

These are source-owner corrections, not behavior waivers. The existing
46-cell authorization matrix, persisted before/after equality, sanitization,
durable projection, and late-command assertions remain byte-for-byte. No
compatibility dead branch, masked token, duplicate fallible read, or
test-only production overload is permitted.

### 6.4 RuntimeProfileWorkflowController

The Runtime snapshot contains profiles, default profile, companions, camps,
and four credential-presence values. Credential reads are injected through a
throwing store and distinguish `.absent` only from nil returned for
`errSecItemNotFound`; every other OSStatus is failed.

The actor is not used as a synchronous composition service. The new synchronous
Runtime resolver uses a distinct closed Core error declared in the planned-new
`Sources/AgentLoopCore/Observability/FailureRecord.swift`.
`PlanningProviderResolutionError`, its fileprivate construction, its private
failure enum, and all Strict/durable consumers remain the existing independent
contract; Runtime is not aliased into it and cannot expand its downstream state
machine. Application can construct only the closed Runtime Kind and cannot
invent a raw code, message, or OSStatus/code combination:

```swift
package struct RuntimeCredentialResolutionError:
    LocalizedError, Sendable, Equatable
{
    package enum Kind: Sendable, Equatable {
        case runtimeProfileReadFailed
        case defaultProfileNotFound
        case companionNotFound
        case selectedProfileNotFound
        case modelCatalogUnavailable
        case runtimeModelUnsupported
        case credentialAccountMissing
        case credentialValueInvalid
        case credentialReadFailed
        case keychainReadFailed(osStatus: Int32)
        case oauthAccountIdNotFound
        case endpointInvalid
    }

    package let kind: Kind
    package init(_ kind: Kind) { self.kind = kind }

    package var code: String {
        switch kind {
        case .runtimeProfileReadFailed:
            return "runtime_profile_read_failed"
        case .defaultProfileNotFound:
            return "runtime_default_profile_not_found"
        case .companionNotFound:
            return "runtime_companion_not_found"
        case .selectedProfileNotFound:
            return "runtime_selected_profile_not_found"
        case .modelCatalogUnavailable:
            return "model_catalog_unavailable"
        case .runtimeModelUnsupported:
            return "runtime_model_unsupported"
        case .credentialAccountMissing:
            return "credential_account_missing"
        case .credentialValueInvalid:
            return "credential_value_invalid"
        case .credentialReadFailed:
            return "credential_read_failed"
        case .keychainReadFailed:
            return "keychain_read_failed"
        case .oauthAccountIdNotFound:
            return "oauth_account_id_not_found"
        case .endpointInvalid:
            return "endpoint_invalid"
        }
    }

    package var failureCode: FailureCode {
        switch kind {
        case .runtimeProfileReadFailed:
            return .runtimeProfileReadFailed
        case .defaultProfileNotFound, .companionNotFound,
             .selectedProfileNotFound, .modelCatalogUnavailable,
             .credentialAccountMissing, .oauthAccountIdNotFound:
            return .runtimeProviderUnavailable
        case .runtimeModelUnsupported:
            return .runtimeModelUnsupported
        case .credentialValueInvalid:
            return .credentialValueInvalid
        case .credentialReadFailed, .keychainReadFailed:
            return .keychainReadFailed
        case .endpointInvalid:
            return .runtimeEndpointInvalid
        }
    }

    package var retryable: Bool {
        switch kind {
        case .runtimeProfileReadFailed, .modelCatalogUnavailable,
             .credentialReadFailed, .keychainReadFailed:
            return true
        case .defaultProfileNotFound, .companionNotFound,
             .selectedProfileNotFound, .runtimeModelUnsupported,
             .credentialAccountMissing, .credentialValueInvalid,
             .oauthAccountIdNotFound, .endpointInvalid:
            return false
        }
    }

    package var osStatus: Int32? {
        switch kind {
        case let .keychainReadFailed(osStatus):
            return osStatus
        case .runtimeProfileReadFailed, .defaultProfileNotFound,
             .companionNotFound, .selectedProfileNotFound,
             .modelCatalogUnavailable, .runtimeModelUnsupported,
             .credentialAccountMissing, .credentialValueInvalid,
             .credentialReadFailed, .oauthAccountIdNotFound,
             .endpointInvalid:
            return nil
        }
    }

    package var diagnosticCategory: FailureDiagnosticCategory {
        switch kind {
        case .credentialValueInvalid, .credentialReadFailed,
             .keychainReadFailed, .oauthAccountIdNotFound:
            return .credential
        case .runtimeProfileReadFailed, .defaultProfileNotFound,
             .companionNotFound, .selectedProfileNotFound,
             .modelCatalogUnavailable, .runtimeModelUnsupported,
             .credentialAccountMissing, .endpointInvalid:
            return .runtime
        }
    }

    package var diagnosticDomain: FailureDiagnosticDomain {
        switch kind {
        case .credentialValueInvalid, .credentialReadFailed,
             .keychainReadFailed, .oauthAccountIdNotFound:
            return .keychain
        case .runtimeProfileReadFailed, .defaultProfileNotFound,
             .companionNotFound, .selectedProfileNotFound,
             .modelCatalogUnavailable, .runtimeModelUnsupported,
             .credentialAccountMissing, .endpointInvalid:
            return .runtime
        }
    }

    package var safeMessage: String {
        switch kind {
        case .runtimeProfileReadFailed:
            return "无法读取供给线配置。"
        case .defaultProfileNotFound:
            return "默认供给线不存在。"
        case .companionNotFound:
            return "所选伙伴不存在。"
        case .selectedProfileNotFound:
            return "所选供给线不存在。"
        case .modelCatalogUnavailable:
            return "供给线的模型目录不可用。"
        case .runtimeModelUnsupported:
            return "所选模型不受当前供给线支持。"
        case .credentialAccountMissing:
            return "供给线缺少凭据账户配置。"
        case .credentialValueInvalid:
            return "凭据格式无效。"
        case .credentialReadFailed, .keychainReadFailed:
            return "无法读取供给线凭据。"
        case .oauthAccountIdNotFound:
            return "ChatGPT 账户标识不存在。"
        case .endpointInvalid:
            return "供给线的 API 端点无效。"
        }
    }

    package var errorDescription: String? { safeMessage }
}
```

There is no raw-String initializer, untyped associated error, generic
`unexpectedFailure` projection, or trap in this construction path. The
classifier reads only `failureCode`, `diagnosticCategory`, `diagnosticDomain`,
`retryable`, and `osStatus`: Runtime cases use category/domain `runtime`;
`credentialValueInvalid`, `credentialReadFailed`, `keychainReadFailed`, and
`oauthAccountIdNotFound` use category `credential` and domain `keychain`;
the central classifier switches exhaustively on
`RuntimeCredentialResolutionError.kind` and copies only these closed computed
properties. It never derives category/domain from `failureCode`, because
`.credentialAccountMissing` and `.oauthAccountIdNotFound` intentionally share
a final FailureCode but not a diagnostic domain. Only
`.keychainReadFailed(osStatus:)` emits the optional OSStatus. Severity is
error, and the final safe body remains the fixed `FailureCode` row rather than
formatting an underlying error.

Construction is exhaustive. Runtime DB read failure becomes
`.runtimeProfileReadFailed`; missing default, Companion, or selected profile
becomes its matching not-found case; a catalog source throw or strict corrupt
payload becomes `.modelCatalogUnavailable`, while the exact legal nil/empty
states continue through existing
`N[.trustedCatalogLegalNil]` / `N[.resolvedCatalogNamedFallback]` without
entering this error; an unsupported model becomes
`.runtimeModelUnsupported`; a missing or blank credential-account coordinate
becomes `.credentialAccountMissing`; a successful credential read whose bytes
are invalid or whose decoded value is blank becomes
`.credentialValueInvalid`; a non-not-found Keychain failure becomes
`.keychainReadFailed(osStatus:)`; an injected credential-port failure without
an OSStatus becomes `.credentialReadFailed`. A nil profile base uses the
already validated injected `defaultBaseURL`; a present blank or invalid profile
base, or an invalid injected default, becomes `.endpointInvalid`. The separate
`N[.defaultsAPIBaseMissingOrBlank]` contract owns only the named
ProfileScopedDefaults value and never authorizes a blank persisted profile
field. For ChatGPT OAuth the resolver obtains one locked, envelope-validated
four-field OAuth snapshot in order access, refresh, ID, account-ID. After that
snapshot returns, true access item-not-found is the provider's one credential-
absence terminal. When access is present, true account-ID item-not-found
throws `.oauthAccountIdNotFound`, while every other Keychain/read failure uses
the same status-preserving rules above. The Runtime route uses the existing nonthrowing
`LLMProviderFactory.make`, so it has no Runtime provider-factory failure lane;
`.providerConstructionFailed` belongs only to the strict Planning resolver's
real throwing factory port. Legal absence is frozen per callable rather
than as a shared three-lane shortcut. `provider(model:companionId:)` returns
nil only for a selected CLI profile or when the exact selected credential read
returns true `errSecItemNotFound`. `searchKey()` returns nil only when its one
Search-key read returns true `errSecItemNotFound`; it has no profile/CLI or
preview branch. Live `presence(interactionPolicy:)` reads API, Search, and one
strict OAuth snapshot; it projects the four public bits from API/Search/access/
account-ID and sets each false only when that exact credential is absent.
Refresh and ID are validated quarantine evidence but have no public presence
bit; profile kind never changes a bit. DEBUG preview does
not call any of these three resolver methods: `RuntimeCredentialPresencePort.preview`
is an explicit all-false port value that bypasses the resolver and credential
store entirely. Every other nil, blank, invalid byte sequence, or fallible
Runtime read/resolution failure throws this typed error.

`presence(interactionPolicy:)` has one exact fail-fast read order: API key,
Search key, preparation envelope, OAuth access, refresh, ID, then account-ID,
each with the same caller-supplied interaction policy. It calls exactly one
`SynchronizedCredentialAccess.readRuntimeCredentialPresence(...)`. The gate
acquires its one NSLock once, performs the underlying `CredentialStore.get`
calls in array order, stops on the first throw, and releases once; it never
re-enters the single-account method and no bundle mutation can interleave. The
whole batch call is wrapped once by `mapCredentialSourceFailure`; successful
optionals are interpreted only after that helper returns. A successful nil sets
only that coordinate false and continues; a successful nonblank value sets it
true and continues. A result-count mismatch, blank/invalid bytes, or a throw
maps through the credential rules above and returns no partial presence.
Failure at positions one through seven performs one batch-lock acquisition and
exactly 1...7 store reads respectively, with zero later reads. The
`#presence` planned descriptor injects only position one; the retained
seven-position read-order matrix owns all prefix-count/error-mapping
cases.

`StrictPlanningProviderResolver` retains its accepted closed error shape,
fileprivate failure construction, source/factory mappings, and initializer.
It neither catches nor aliases `RuntimeCredentialResolutionError`, and Runtime
does not catch/alias `PlanningProviderResolutionError`. Runtime maps each
fallible synchronous concrete DB/catalog/credential call to its owning Runtime
Kind; it only passes the already traced Session refresh closure into the
provider and neither executes nor maps that later async failure. Refresh and
unauthorized-delete capture/typed terminals belong exclusively to
`OpenAIOAuthSession` and never reuse the provider-resolution trace/Kind. Runtime
gains no invented factory/source protocol solely for a test. Compile/source
negative fixtures prove neither closed error can be smuggled through the other
owner and that no raw/error-description mapping exists.

For an API profile, the Strict resolver's post-profile order is exact: reject
CLI at the existing kind switch; validate `profile.baseURL` once with
`ProviderEndpoint.normalizedBaseURL` and retain that URL; only then read the
catalog, read the API credential, and invoke the throwing factory. An invalid
or missing base throws the existing `.endpointInvalid` with zero catalog,
credential, or factory calls. The retained URL is passed to the factory;
`ModelCatalogService.isOfficialCatalogProfile` therefore cannot preempt or
relabel the Planning endpoint terminal. OAuth uses model-catalog -> one
envelope-validated four-field credential snapshot -> factory. All other retained
Planning source/factory mappings remain byte-for-byte unchanged.

The strict resolver initializer remains the existing four-argument declaration:

```swift
package init(
    profiles: any PlanningRuntimeProfileSource,
    catalogs: any PlanningModelCatalogSource,
    credentials: any PlanningCredentialSource,
    factory: any PlanningProviderFactory
)
```

The credential protocol adds one source-compatible requirement with a default
fixture implementation:

```swift
package protocol PlanningCredentialSource: Sendable {
    func planningCredential(account: String) throws -> String?
    func planningOAuthCredentials(
        accounts: OAuthCredentialAccounts
    ) throws -> OAuthCredentialReadSnapshot
}
package extension PlanningCredentialSource {
    func planningOAuthCredentials(
        accounts: OAuthCredentialAccounts
    ) throws -> OAuthCredentialReadSnapshot
}
```

The default calls the existing fixture method for access, refresh, ID, and
account-ID in that order and constructs the snapshot with strict nonblank
`SecretValue` optionals. It preserves all existing Durable/Schedule test
conformers without changing their files. `AppPlanningCredentialSource` is the
only production conformance and must override the requirement by delegating to
the injected shared `SynchronizedCredentialAccess.readOAuthCredentials`; it no
longer owns a standalone `KeychainStore`. The Strict OAuth resolver invokes
only `planningOAuthCredentials`, then interprets access/account-ID; it never
falls back to two raw `planningCredential` calls.

Only API-profile resolution reads `profile.credentialAccount`. ChatGPT OAuth
resolution reads `OAuthCredentialAccounts.live.access` and
`OAuthCredentialAccounts.live.accountID`; the old
static `oauth-chatgpt-account-id` String and any profile-derived OAuth access
coordinate are deleted. `OAuthCredentialAccounts.live` is the only production
literal owner; the Strict resolver refers to that value directly and gains no
new initializer field, default parameter, or compatibility overload. App nests
that same value in `RuntimeCredentialAccounts`; fixture bundles remain confined
to tests of Runtime/OAuth consumers and cannot change the Strict production
coordinate. `DurableWorkSupervisor` and its error mapping remain byte-for-byte
outside P1-B scope.

The actor is not used as a synchronous composition service. This file also
defines a synchronous `Sendable` value:

```swift
package struct RuntimeCredentialAccounts: Sendable, Equatable {
    package let apiKey: String
    package let searchKey: String
    package let oauth: OAuthCredentialAccounts
    package init(apiKey: String, searchKey: String,
                 oauth: OAuthCredentialAccounts)
}
package struct RuntimeCredentialResolver: Sendable {
    package init(database: AppDatabase, defaults: ProfileScopedDefaults,
                 credentialAccess: SynchronizedCredentialAccess,
                 accounts: RuntimeCredentialAccounts, defaultBaseURL: String,
                 tokenRefresher: (@Sendable () async throws -> String)?)
    package func provider(model: String, companionId: String?) throws
        -> (any LLMProvider)?
    package func searchKey() throws -> String?
    package func presence(
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> RuntimeCredentialPresence

    private static func mapProfileSourceFailure<Value>(
        _ body: () throws -> Value
    ) throws -> Value
    private static func mapCatalogSourceFailure<Value>(
        _ body: () throws -> Value
    ) throws -> Value
    private static func mapCredentialSourceFailure<Value>(
        _ body: () throws -> Value
    ) throws -> Value
}

struct MissionReportPresentationKey: Hashable, Sendable {
    let missionId: String
    let kind: DocumentPresentationKind
}
```

The three stage helpers are the resolver's complete throwing-source boundary;
no caller-supplied Kind can select a different failure domain. Each `do`
returns `body()` unchanged and owns exactly one lexical catch in this existing
file. Its catch body begins with its exact `P1-B-CATCH typed N[...]` marker and
one adjacent planned-resolution line. `mapProfileSourceFailure` maps every
caught value to `.runtimeProfileReadFailed` and may wrap only the one DB
snapshot load. `mapCatalogSourceFailure` maps every caught value to
`.modelCatalogUnavailable` and may wrap only the Runtime provider's catalog
reads.
`mapCredentialSourceFailure` performs an exhaustive type-pattern switch:
`CredentialValueInvalidError` throws `.credentialValueInvalid`;
`KeychainError` throws `.keychainReadFailed(osStatus:)`; exact `case _` throws
`.credentialReadFailed`; the typed OAuth quarantine error intentionally enters
that closed generic credential-read lane and is never projected as nil. It may
wrap only a single-account `SynchronizedCredentialAccess.read`, one
`readOAuthCredentials`, or one `readRuntimeCredentialPresence`. API/Search use
single-account reads, OAuth provider uses one OAuth snapshot, and presence uses
one seven-position snapshot. None rethrows a caller-supplied Runtime or
Planning canonical error, reads `localizedDescription`, interprets a successful
optional result, or accepts a generic Kind parameter.

The synchronized read forms already represent true
`errSecItemNotFound` as successful nil. Each credential call site therefore
exhausts the returned optional outside the catch: API/Search/access-token/
presence nil is the exact absence lane frozen above, while required OAuth
account-ID nil throws `.oauthAccountIdNotFound`. Profile and catalog successful
optional payloads are interpreted only under their separate missing/catalog
contracts. These are three catch arms total, the twelfth through fourteenth
planned catches. Their exact tuple/tag/primary closure is frozen in inventory
§9.1a: `N[.runtimeProfileSourceFailure]` → `runtimeProviderResolve`,
`N[.runtimeCatalogSourceFailure]` → `modelCatalogResolve`, and
`N[.runtimeCredentialSourceFailure]` → `keychainRead`. The credential descriptor
has exactly three variants—`#provider`, `#search`, and `#presence`—rooted at
`runtimeProviderResolve`, `runtimeSearchResolve`, and `runtimeLoad`
respectively; the other two use only `#default`. The `#presence` failure
variant injects at the first API-key credential read, so the variant executes
exactly one `keychainRead` occurrence; failures at the other live-presence
coordinates remain covered by the existing Keychain read-order matrix and do
not create another descriptor variant. App delegate projection is explicit and
does not follow nested primaries: profile and catalog both use
`Sources/AgentLoopApp/AppStore.swift::AppStore.provider(model:companionId:) => runtimeProviderResolve`;
credential uses
`#provider Sources/AgentLoopApp/AppStore.swift::AppStore.provider(model:companionId:) => runtimeProviderResolve`,
`#search Sources/AgentLoopApp/AppStore.swift::AppStore.init() => runtimeSearchResolve`,
and
`#presence Sources/AgentLoopApp/AppStore.swift::AppStore.reload(keychainInteractionPolicy:) => runtimeLoad`.
Neither `modelCatalogResolve` nor `keychainRead` is synthesized as an App
delegate edge. Those tuples already exist in the 127-row delegate union, so
the new descriptors do not change that cardinality.

App inserts a proposal/distillation/report/cowork pending value only from the matching
typed committed-visibility terminal; it never reconstructs one from IDs, URL,
model, or trace. Each retry captures the exact opaque value plus attempt UUID,
uses the matching Task dictionary above, and compare-removes only that same
value after success. A late terminal cannot clear a newer repair. Cowork
receipts expose only Mission ID to App; all other fields and construction remain
Core-internal. Rate-limit-event receipts remain exclusively inside Orchestrator;
App's per-Mission retry passes only the ID and never receives or reconstructs
that receipt.

AppStore constructs exactly one `OAuthCredentialAccounts` value, nests that
exact value inside exactly one `RuntimeCredentialAccounts`, and constructs one
resolver with the exact initializer fields `database`, `defaults`, the shared
`SynchronizedCredentialAccess`, that account value, `defaultBaseURL`, and the
already traced Session `tokenRefresher`. It
injects the same resolver into the Runtime controller and Orchestrator and the
same Runtime account value separately into the Runtime controller and live
ports. OAuth provider/presence reads use the shared locked
`OAuthCredentialReadSnapshot`; authorization preparation,
callback, refresh, and cleanup mutations use that same nested
`credentialAccounts.oauth`. No API accepts a second OAuth account bundle, and
no access/account-ID literal or copied field pair may be reconstructed in a
consumer. Provider resolution loads default profile,
optional Companion, and exact selected profile inside one DB read snapshot.
Its post-snapshot decision order is exact: first interpret the three optional
record fields and the selected CLI terminal; next resolve and validate the
effective endpoint; only then resolve model/default/catalog, read the selected
credential(s), and construct the provider. A nil profile base uses the already
validated injected `defaultBaseURL`; a present blank/invalid profile base or an
invalid injected default throws `.endpointInvalid` with zero catalog and zero
credential reads. `ModelCatalogService.isOfficialCatalogProfile` treats a nil
base as legal nonofficial input and throws only for a present invalid base, so
catalog mapping cannot preempt the endpoint terminal.
Provider nil is allowed only for a selected CLI profile or a true Keychain
item-not-found on the selected API credential or OAuth access token; a missing
OAuth account ID throws `.oauthAccountIdNotFound`. Search nil and each live presence false bit are allowed only
for their own true item-not-found. DEBUG preview absence belongs to the
separate presence port and never enters this resolver. Missing default/Companion/selected profile,
blank-but-present credentials, invalid base URL, unsupported model catalog, or
DB/Keychain failure throws a stable typed error. Thus AppStore initialization,
its synchronous `provider(model:)`/Adapter `canStart` check, and Orchestrator
dispatch stay synchronous while failure never becomes absence. AppStore's
all current synchronous provider consumers remain inside the 64-path scope
and individually capture/propagate the thrown result.

The private legacy helpers `storedProviderCredential`, `resolveProvider`,
`runtimeProfileCredential`, `attachAPIKeyToEmptyDefaultProfileIfNeeded`, and
`AppStore.makeProvider`, plus nested `AppStore.StoredCredential` and
`RuntimeProfileResolutionFailureHandler`, are deleted with zero declarations
or references. Retained `AppStore.provider(model:companionId:)` is the sole App
provider façade and delegates directly to the injected resolver; both retained
methods become throwing with these exact declarations:

```swift
func provider(model: String) throws -> (any LLMProvider)?
func provider(model: String, companionId: String?) throws
    -> (any LLMProvider)?
```

The one-argument form only forwards to the two-argument overload. Every
64-path caller handles the thrown typed failure through its owning controller
or traced façade; no caller maps it to nil. `saveAPIKey(_:)` delegates
to `RuntimeProfileWorkflowController.setCredential(slot:.apiKey,value:trace:)`
and owns the conditional attachment semantics below. Source/delegate gates
reject any reintroduced direct Keychain/DB/catalog provider resolution in App.

Orchestrator preserves every existing parameter label/order and initializer
visibility, changes only the two closure effects, and appends defaulted
reporter/loader parameters:

```swift
makeProvider: @escaping @Sendable
    (String, String?) throws -> (any LLMProvider)?
searchKeyProvider: @escaping @Sendable () throws -> String? = { nil }
failureReporter: FailureReporter? = nil
contextDependencyLoader: (any ContextDependencyLoading)? = nil
```

Existing nonthrowing closures remain valid throwing-closure arguments, so the
closed-scope construction call sites do not need source edits. The three
current `makeProvider` sites add typed handling; the Card site moves after
context `.ready`. Nil still
means a genuinely absent/unconfigured provider or credential; thrown means a
read/configuration failure and is captured. `failureReporter == nil` constructs
the default reporter from the supplied `db`, preserving every existing
initializer call. Orchestrator passes `searchKeyProvider` only into its default
ContextDependencyLoader construction; it never invokes it after loader
success. Only valid explicit-v2 `web_search` triggers the loader's one read;
missing/thrown credentials block as required, while legacy-inherited or
unselected search performs zero reads. Preview uses an injected resolver and
never reads the normal Keychain.

Both existing Orchestrator initializers append the two defaulted reporter/
loader parameters, preserving all closed calls. A supplied loader is used
verbatim for deterministic tests; nil constructs the live loader from db,
manager, throwing search closure, knowledge readers, and reporter. The loader
is stored as `any ContextDependencyLoading` and is the only Card-context path.

Profile save/delete/default switch/reconciliation and credential set/delete
are typed commands. A command publishes success only after every required DB
and Keychain step succeeds and the post-write reload verifies the result.
Both AppStore's initial OAuth callback and OpenAIOAuthSession refresh first
read every affected credential pre-image, apply updates in fixed order, and on
first failure restore every changed account in reverse order. A successful
rollback returns `oauth_credential_commit_failed`; any restoration failure
returns one final `oauth_credential_rollback_failed` critical failure. It does
not first occupy the trace with a different errorCode. Partial state is never
called connected. No credential value or Keychain account enters diagnostics.

The two owners do not implement separate locks. `OpenAIOAuthSession.swift`
defines `SynchronizedCredentialAccess`, one Core lock-backed synchronous gate
over the shared `CredentialStore`, plus one injected
`CredentialBundleCoordinator` actor using that same gate. AppStore constructs
exactly one gate and coordinator, and injects them into the resolver, Runtime
controller, and OpenAIOAuthSession. A bundle's entire pre-image/write/rollback
section runs under one non-suspending gate critical section; it never holds the
lock across `await`. Resolver reads use the same gate, so a synchronous provider
consumer cannot observe a half-written OAuth bundle. Callback and refresh also
cannot interleave or roll back each other's committed values.

Mutation shape is frozen:

- every initial callback is a complete replacement of the shared preferred-web
  credential bundle, never a fieldwise merge with a previous flow. The exact
  preparation envelope first advances from its exact `.prepared` or
  `.recoveryPrepared` phase to `.initialCommitting` so a crash cannot expose an
  intermediate bundle. Access is
  required and set; refresh is set when supplied and otherwise deleted. ChatGPT
  sets the required derived account ID, sets ID token when supplied and otherwise
  deletes it. Generic deletes ID and ChatGPT account unconditionally as
  inapplicable. The envelope is deleted last. Therefore ChatGPT → generic cannot
  retain ChatGPT ID/account, and generic → ChatGPT cannot retain a generic
  refresh or ID/account value;
- refresh: the envelope coordinate first becomes `.refreshCommitting`; access
  is set (required); refresh/ID/account are set only when supplied or derivable,
  otherwise preserve their pre-images; the envelope is deleted last;
- generic OAuth callback owns that complete replacement precisely because the
  five accounts are one shared active bundle; there are no “unrelated” live
  ChatGPT fields after the active flow changes;
- a permanent-unauthorized access-token delete is its own serialized bundle
  command; delete failure is explicit and cannot report a clean relogin state.

Non-2xx refresh responses are reduced to typed HTTP status/category before
leaving OpenAIOAuthSession; raw body/error_description never enters the thrown
error, reporter, event, log, or UI.

AppStore delegates bootstrap presence, `reload`, profile CRUD/reconciliation,
API/search credential writes, OAuth verifier/token bundle persistence, and
settings refresh to this controller. App retains only the platform-owned
NWListener and NSWorkspace closures plus raw callback-URL handoff. Runtime
controller/Application owns state/verifier generation, authorization URL and
callback codecs, HTTP exchange, credential commit, and cleanup. App neither
parses callback fields nor performs/duplicates OAuth token networking; source
and delegate gates enforce that ownership split.

Profile/reconciliation writes likewise distinguish a failed transaction from
a committed write whose verification reload failed. The latter preserves the
committed profile identity, publishes committed-with-visibility-failure, and
offers reload only.

### 6.5 McpWorkflowController

The MCP registry/Camp/tool/presence snapshots in §6.6 collectively contain
validated server records, enabled IDs by requested Camp, safe status summaries,
tool-list cache, and secret presence. The controller validates
stored args/env/secret-key JSON before publishing; malformed config is failed,
not an empty array.

Injected commands cover registry reload, enable/disable, secret presence,
secret set/delete, server delete, start/restart, and tool listing. Each command
uses one operation trace. Server deletion does not delete the DB row or show
success until every declared Keychain account has been deleted and the server
has stopped. Before the first mutation it validates config and reads every
secret pre-image; any read error is zero-write. It first obtains a Manager-owned
exclusive maintenance token for the server; Manager drains any start task,
stops the connection, generation-invalidates callbacks, and rejects concurrent
ensure/restart/list with typed `serverMaintenance` until the token is released.
It then deletes secrets in fixed order and deletes the DB row. No await occurs
while the synchronous credential gate is held. A secret or DB failure restores
all changed secrets in reverse order. Rollback failure is a critical final
failure; otherwise the authoritative row and original secret set remain and
the same command can be retried. On rollback, a successful token release leaves the server
stopped; if that release fails, the not-committed rollback token must be
cleaned before the command can retry. After successful row deletion it attempts
to remove the handle. A failed handle removal is an already-committed cleanup
terminal and transfers the still-live opaque token to McpStore's cleanup-only
retry path; it never re-enters credential or database deletion. McpStore remains the SwiftUI/NSOpenPanel
projection and keeps its
existing view-facing signatures by returning cached last-loaded values plus a
separate visible workflow failure; it does not convert a fresh failure to an
empty value.

### 6.6 Exact Application API appendix

All declarations below are package API unless an existing App-facing method is
already public. DTOs are `Sendable`; only DTOs whose existing Core members are
already Equatable adopt `Equatable`, so P1-B does not extend closed record/tool
types merely for test convenience. Tests compare the explicit fields. No DTO
contains SwiftUI view state or an error string.

“Package API” is literal in Candidate 03: every cross-target type is declared
`package`, every member that a consuming target is allowed to read is an
explicit `package let`/`package var`, and every cross-target callable is
explicitly `package`. Opaque capability/repair values are the deliberate
exception: their blocks spell internal or `fileprivate` payload fields and
constructors so a consuming target can retain/compare/pass the package value
but cannot reconstruct its identity. This applies to the Core proposal,
accepted-Mission, cowork, rate-limit, attachment, and OAuth receipts; the
Application Mission-draft/report-plan carrier; and the MCP deletion/cleanup
receipts. Every constructible DTO still has an explicit initializer at its
intended visibility; Swift's implicit memberwise initializer is never relied
upon. TestSuite obtains opaque values only through the real owning callable or
the expressly frozen DEBUG injection. Interface blocks below omit only
one-to-one assignment bodies; the listed signature/member surface is
exhaustive and is compiled by §13 fixtures, including compile-negative checks
for every opaque payload field/initializer from a consuming target.

Core owns the GRDB boundary in the already allowed `AppDatabase.swift`:

```swift
package struct MissionDetailReadBundle: Sendable {
    package let mission: MissionRecord
    package let cards: [CardRecord]
    package let artifacts: [ArtifactRecord]
    package let pendingRequests: [UserRequestRecord]
    package let squad: SquadRecord
    package let squadMemberIds: [String]
    package let companionsById: [String: CompanionRecord]
    package let events: [EventRecord]
    package let spend: MissionSpendBreakdown
    package init(mission: MissionRecord, cards: [CardRecord],
                 artifacts: [ArtifactRecord], pendingRequests: [UserRequestRecord],
                 squad: SquadRecord, squadMemberIds: [String],
                 companionsById: [String: CompanionRecord], events: [EventRecord],
                 spend: MissionSpendBreakdown)
}
package struct MissionIndexReadBundle: Sendable {
    package let missions: [MissionRecord]
    package let camps: [CampRecord]
    package let missionsByCamp: [String: [MissionRecord]]
    package let artifactLedger: [ArtifactLedgerItem]
    package init(missions: [MissionRecord], camps: [CampRecord],
                 missionsByCamp: [String: [MissionRecord]],
                 artifactLedger: [ArtifactLedgerItem])
}
package struct InputCampReadBundle: Sendable {
    package let camp: CampRecord
    package let guide: CompanionRecord
    package let ingestionItems: [IngestionItemRecord]
    package let activeRuminationByIngestion: [String: DurableWorkRecord]
    package let materializedNoteIdByIngestion: [String: String]
    package let missions: [MissionRecord]
    package let artifactCountByMission: [String: Int]
    package let campNotes: [CampNoteRecord]
    package let regularCompanions: [CompanionRecord]
    package let newcomerProgress: NewcomerProgress
    package init(camp: CampRecord, guide: CompanionRecord,
                 ingestionItems: [IngestionItemRecord],
                 activeRuminationByIngestion: [String: DurableWorkRecord],
                 materializedNoteIdByIngestion: [String: String],
                 missions: [MissionRecord], artifactCountByMission: [String: Int],
                 campNotes: [CampNoteRecord], regularCompanions: [CompanionRecord],
                 newcomerProgress: NewcomerProgress)
}
package struct InputReviewReadBundle: Sendable {
    package let ingestion: IngestionItemRecord
    package let result: RuminationResult
    package let baseCow: CompanionRecord?
    package init(ingestion: IngestionItemRecord, result: RuminationResult,
                 baseCow: CompanionRecord?)
}
package struct RuntimeWorkflowReadBundle: Sendable {
    package let profiles: [RuntimeProfileRecord]
    package let defaultProfile: RuntimeProfileRecord
    package let companions: [CompanionRecord]
    package let camps: [CampRecord]
    package init(profiles: [RuntimeProfileRecord], defaultProfile: RuntimeProfileRecord,
                 companions: [CompanionRecord], camps: [CampRecord])
}
package struct RuntimeProviderResolutionReadBundle: Sendable {
    package let defaultProfile: RuntimeProfileRecord?
    package let companion: CompanionRecord?
    package let selectedProfile: RuntimeProfileRecord?
    package init(defaultProfile: RuntimeProfileRecord?, companion: CompanionRecord?,
                 selectedProfile: RuntimeProfileRecord?)
}

`readRuntimeProviderResolutionBundle` throws only for database execution or
decode failure. Absence is data in its one snapshot: `defaultProfile == nil`
maps outside `mapProfileSourceFailure` to `.defaultProfileNotFound`; when the
input `companionId` is non-nil, `companion == nil` maps to
`.companionNotFound` (nil companion is valid only when no Companion was
requested); after applying the exact Companion/default selection rule,
`selectedProfile == nil` maps to `.selectedProfileNotFound`. The aggregate
never throws a not-found error and never fabricates one record from another,
so the source-stage catch remains reserved for real read failure.
package struct ScheduleWorkflowReadBundle: Sendable {
    package let campId: String
    package let templates: [MissionTemplateRecord]
    package let schedules: [ScheduleRecord]
    package init(campId: String, templates: [MissionTemplateRecord],
                 schedules: [ScheduleRecord])
}
package struct ScheduleRuntimeReadBundle: Sendable {
    package let enabled: [EnabledScheduleRecord]
    package let cursorByScheduleId: [String: ScheduleEvaluationCursorRecord]
    package let requestedTemplate: MissionTemplateRecord?
    package init(enabled: [EnabledScheduleRecord],
                 cursorByScheduleId: [String: ScheduleEvaluationCursorRecord],
                 requestedTemplate: MissionTemplateRecord?)
}
package struct ScheduledMissionNotificationReadBundle: Sendable {
    package let scheduleId: String
    package let templateId: String
    package let mission: MissionRecord
    package let squad: SquadRecord
    package let events: [EventRecord]
    package init(scheduleId: String, templateId: String,
                 mission: MissionRecord, squad: SquadRecord,
                 events: [EventRecord])
}
package enum ScheduleStoreProjectionError: Error, Sendable, Equatable {
    case invalidScheduledOrigin(eventId: String)
    case duplicateEvaluationCursor(scheduleId: String)
}
package struct InputMissionDraftReadBundle: Sendable {
    package let draft: CodingRanchMissionDraft
    package let sourceNote: CampNoteRecord
    package let baseCow: CompanionRecord?
    package init(draft: CodingRanchMissionDraft,
                 sourceNote: CampNoteRecord,
                 baseCow: CompanionRecord?)
}
package enum IngestionDeletionMode: Sendable, Equatable {
    case resultOnly
    case sourceAndResult
    case everythingIncludingProjection
}
package struct IngestionDeletionReceipt: Sendable, Equatable {
    package let ingestionId: String
    package let campId: String
    package let mode: IngestionDeletionMode
    package init(ingestionId: String, campId: String,
                 mode: IngestionDeletionMode)
}
package struct DefaultCampResolutionReceipt: Sendable {
    package let camp: CampRecord
    package let created: Bool
    package init(camp: CampRecord, created: Bool)
}
package struct ChatMessageProjection: Sendable, Equatable {
    package let id: String
    package let role: String
    package let text: String
    package let proposal: SquadProposalBlock?
    package let createdAt: Date
    package init(id: String, role: String, text: String,
                 proposal: SquadProposalBlock?, createdAt: Date)
}
package struct ChatHistoryReadBundle: Sendable {
    package let thread: ChatThreadRecord
    package let messages: [ChatMessageProjection]
    package init(thread: ChatThreadRecord,
                 messages: [ChatMessageProjection])
}
package struct DMChatTurnPreparation: Sendable {
    package let companion: CompanionRecord
    package let thread: ChatThreadRecord
    package let history: [APIMessage]
    package let pinnedNotes: [CompanionNoteRecord]
    package let recentNotes: [CompanionNoteRecord]
    package init(companion: CompanionRecord, thread: ChatThreadRecord,
                 history: [APIMessage],
                 pinnedNotes: [CompanionNoteRecord],
                 recentNotes: [CompanionNoteRecord])
}
package struct GuideChatTurnPreparation: Sendable {
    package let guide: CompanionRecord
    package let thread: ChatThreadRecord
    package let history: [APIMessage]
    package init(guide: CompanionRecord, thread: ChatThreadRecord,
                 history: [APIMessage])
}
extension AppDatabase {
    package static func pendingUserRequests(
        missionId: String, in database: Database
    ) throws -> [UserRequestRecord]
    package static func missionSpendBreakdown(
        missionId: String, in database: Database
    ) throws -> MissionSpendBreakdown
    package func readMissionDetailBundle(missionId: String) throws
        -> MissionDetailReadBundle
    package func readMissionIndexBundle(includeArchived: Bool) throws
        -> MissionIndexReadBundle
    package func readInputCampBundle(campId: String) throws -> InputCampReadBundle
    package func readInputReviewBundle(ingestionId: String) throws
        -> InputReviewReadBundle
    package func readRuntimeWorkflowBundle() throws -> RuntimeWorkflowReadBundle
    package func readRuntimeProviderResolutionBundle(companionId: String?) throws
        -> RuntimeProviderResolutionReadBundle
    package func readScheduleWorkflowBundle(campId: String) throws
        -> ScheduleWorkflowReadBundle
    package func readScheduleRuntimeBundle(templateId: String? = nil) throws
        -> ScheduleRuntimeReadBundle
    package func readScheduledMissionNotificationBundle(missionId: String) throws
        -> ScheduledMissionNotificationReadBundle?
    package func readInputMissionDraftBundle(candidateId: String) throws
        -> InputMissionDraftReadBundle
    package func readInputMissionDraftBundle(ingestionId: String) throws
        -> InputMissionDraftReadBundle
    package func deleteIngestionAtomically(
        id: String, mode: IngestionDeletionMode
    ) throws -> IngestionDeletionReceipt
    package func resolveDefaultCamp() throws
        -> DefaultCampResolutionReceipt
    package func loadOrCreateDMHistoryBundle(companionId: String) throws
        -> ChatHistoryReadBundle
    package func loadOrCreateGuideHistoryBundle(campId: String) throws
        -> ChatHistoryReadBundle
    package func prepareDMChatTurn(companionId: String,
                                   userText: String) throws
        -> DMChatTurnPreparation
    package func prepareGuideChatTurn(campId: String,
                                      userText: String) throws
        -> GuideChatTurnPreparation
}

// Declared in ScheduleStore.swift. Existing wrappers and aggregate bundles
// delegate to these Database-parameter implementations only.
extension AppDatabase {
    package static func missionTemplate(
        id: String, in database: Database
    ) throws -> MissionTemplateRecord?
    package static func missionTemplates(
        campId: String, in database: Database
    ) throws -> [MissionTemplateRecord]
    package static func schedules(
        campId: String, in database: Database
    ) throws -> [ScheduleRecord]
    package static func enabledSchedules(
        in database: Database
    ) throws -> [EnabledScheduleRecord]
    package static func scheduleEvaluationCursor(
        scheduleId: String, in database: Database
    ) throws -> ScheduleEvaluationCursorRecord?
    package static func scheduledOrigin(
        missionId: String, in database: Database
    ) throws -> (scheduleId: String, templateId: String)?
    package func deleteMissionTemplateWithPreimage(
        id: String
    ) throws -> (
        template: MissionTemplateRecord,
        deletedSchedules: [ScheduleRecord]
    )
    package func deleteScheduleWithPreimage(
        id: String
    ) throws -> ScheduleRecord
}

// Existing Chat/Knowledge façades and both turn preparations delegate to
// these Database-parameter implementations; no owner query is copied.
extension AppDatabase {
    package static func companion(
        id: String, in database: Database
    ) throws -> CompanionRecord?
    package static func guide(
        campId: String, in database: Database
    ) throws -> CompanionRecord?
    package static func findOrCreateDMThread(
        companionId: String, in database: Database
    ) throws -> ChatThreadRecord
    package static func findOrCreateGuideThread(
        campId: String, in database: Database
    ) throws -> ChatThreadRecord
    package static func chatMessages(
        threadId: String, in database: Database
    ) throws -> [ChatMessageRecord]
    package static func appendChatMessage(
        threadId: String, role: String, contentJson: String,
        in database: Database
    ) throws -> String
    package static func pinnedAndRecentCompanionNotes(
        companionId: String, recent: Int,
        in database: Database
    ) throws -> (pinned: [CompanionNoteRecord],
                 recent: [CompanionNoteRecord])
}

// Declared in MissionDraftFactory.swift beside both aggregate overloads.
extension AppDatabase {
    private static func inputMissionDraftBundle(
        candidateId: String, in database: Database
    ) throws -> InputMissionDraftReadBundle
}
```

Each read method opens exactly one `pool.read` and assembles/decodes everything
inside it, except the two load-or-create history methods, which each use one
`pool.write` transaction so thread creation and the returned message history
share one snapshot. `deleteIngestionAtomically` uses one `pool.write` and
returns its durable owner/mode receipt only after all selected deletes and
status transitions commit. `readMissionDetailBundle` evaluates its fallible
components in this exact order: Mission, Cards, Artifacts, pending requests,
Squad/member IDs, Companions, Events, spend. This order is part of the
descriptor occurrence ledger: a pending-request failure does not reach spend,
while a spend failure has already invoked pending requests. Detail keeps event
limit 200; index keeps global and per-Camp Mission limit 50. Squad
member/Rumination JSON corruption throws projection-decode.
Default profile must be exactly one; an explicitly pinned Companion profile may
not fall back to default when absent. Duplicate active Rumination rows,
duplicate materialization links, or orphan artifacts are integrity failures;
artifact-count maps contain an explicit zero for every returned Mission. Camp
Companions are exactly regular kind with campId equal to the request, NULL, or
empty legacy value. Existing spend/artifact/newcomer SQL is extracted to
private `Database`-parameter helpers and reused by old public methods; bundle
code never calls a helper that opens another snapshot.

`AppDatabase.pendingUserRequests(missionId:in:)` and
`AppDatabase.missionSpendBreakdown(missionId:in:)` are the sole SQL owners for
their projections and carry `P1-B-SEAM databasePendingUserRequests` and
`P1-B-SEAM databaseMissionSpend` respectively.
The existing public `pendingUserRequests(missionId:)` wrapper delegates to it
inside its own `pool.read`; the existing public
`missionSpendBreakdown(missionId:)` does the same for its helper.
`readMissionDetailBundle(missionId:)` calls both `Database`-parameter helpers
inside the aggregate read. The aggregate never calls either public wrapper or
opens a second snapshot.

Budget/spend arithmetic is closed and typed:

```swift
public enum BudgetArithmeticError: Error, Sendable, Equatable {
    case nonpositiveBudgetDelta(Int)
    case budgetOverflow
    case negativeRunUsage
    case spendProjectionOverflow
}
package struct LegacyRunSpendUpdate: Sendable, Equatable {
    package let value: Int
    package let saturated: Bool
    package init(value: Int, saturated: Bool)
}
```

`AppDatabase.addBudget` requires `tokens > 0` and uses checked addition before
the first write. A nonpositive delta or overflow throws with zero Mission/event
write; it never applies `max(0, ...)` or saturates to `Int.max`.
`finishRun` rejects negative usage and requires the exact Card/Mission owners.
For nonnegative legacy execution spend only, the historically accepted policy
is a named checked add that returns `LegacyRunSpendUpdate(value: Int.max,
saturated: true)` on positive overflow; Orchestrator emits one fixed safe
`legacy_execution_spend_saturated` diagnostic with the existing run trace.
That approval does not apply to budget, P1 planning usage, or read projection.
`missionSpendBreakdown` strictly decodes every planning-token payload and uses
checked sums/reductions; nil scalar, malformed payload, negative value, or
overflow fails the entire projection. It never substitutes zero, an empty
label, unchecked `+`, or saturation.
`AppDatabase.startRun` likewise replaces `RunRecord.fetchCount + 1` with one
checked increment before constructing/inserting the Run. Overflow is a typed
zero-insert `projection_contract_failed` terminal owned by the Card-dispatch
trace; it cannot trap or wrap an attempt identity. The already checked
rumination-attempt increment remains a closed typed-safe arithmetic anchor.

The three Schedule bundles are equally strict. `ScheduleStore.swift` owns
package `Database`-parameter helpers for template lists, Camp schedules,
enabled schedule/template pairs, cursor lookup, and scheduled-origin decode;
its existing public methods and the AppDatabase aggregate methods both call
those helpers. No query or payload parser is copied into a second file.
Workflow loading verifies the
Camp exists and returns its templates and schedules from the same snapshot.
Runtime loading reads every enabled schedule, its template, and at most one
cursor per schedule in one snapshot; a missing template, duplicate logical
cursor, or malformed schedule is a typed invariant failure. Notification
loading returns `nil` only when no `schedule_fired` origin exists. Once an
origin exists, a missing Mission/template relation, malformed origin payload,
or missing/broken Squad/Event projection throws; its nonoptional Squad and
events remain limited to the exact Mission owner and 200 events.
`scheduledOrigin` decodes with `try`, requires nonblank schedule/template IDs,
and throws `ScheduleStoreProjectionError.invalidScheduledOrigin` for an
existing malformed event. `deleteMissionTemplateWithPreimage` first requires
the exact template and fetches every dependent Schedule in stable
`(createdAt,id)` order, then deletes those rows and exactly one template in one
transaction and returns that frozen preimage only after commit;
`deleteScheduleWithPreimage` fetches the exact Schedule and requires exactly one
deleted row in one transaction. The existing public Void delete wrappers keep
their signatures, call these package owners, and explicitly bind/discard the
returned preimage. A zero affected-row result is `RecordNotFoundError`, never
success.
The cursor helper reads at most two rows and throws `duplicateEvaluationCursor`
instead of selecting one. Every loaded template/schedule runs its existing
validator. Template validation decodes the complete companion-ID array, trims
each element, and rejects the whole template when any element is blank; it
never filters a malformed member and accepts the remainder. The validated
nonempty IDs and positive budget are returned in `ScheduleTemplateProjection`,
so no App view reparses JSON or defaults a corrupt template to an empty
selection. The six existing public/package wrappers keep their exact signatures
and do only `pool.read { try Self.helper(..., in: $0) }`; aggregate methods call
the static helpers inside their own transaction, never a wrapper that opens a
second snapshot.

The two `readInputMissionDraftBundle` overloads share one private
`Database`-parameter implementation in `MissionDraftFactory.swift`. The
ingestion overload first requires exactly one mission ActionCandidate in the
same read; the candidate overload validates that exact candidate. Both join
its one
materialized source link, and exact source CampNote in one read and decodes the
draft there; it never substitutes `来源笔记`. `deleteIngestionAtomically`
requires an existing ingestion row, requires the active-rumination scalar to
be non-nil and zero, verifies affected row counts, and returns the original
Camp ID. `everythingIncludingProjection` remains the existing explicit
unsupported-state error until a later reviewed stage owns projection deletion.
The Application `InputDeletionScope` maps exhaustively to the Core
`IngestionDeletionMode`; Core never imports an Application DTO.
The private helper is declared in that same source file as
`inputMissionDraftBundle(candidateId:in:)`, so neither AppDatabase overload
needs cross-file private access. `MissionDraftFactory.draft(candidateId:)`
keeps its public signature and delegates only to the candidate overload's
`.draft`; it does not retain a second GRDB query/decoder. Zero candidate/link/
note rows are exact not-found errors; duplicate candidates/links, wrong
candidate type, Camp mismatch, or bad detail JSON are projection-contract
failures.
Both draft overloads also read `CowTemplate.baseCowId` in that same snapshot.
Its true absence is valid for an older expert-mode user and returns
`baseCow == nil`; DB corruption/read failure still throws. The Application
snapshot creates an opaque `InputMissionDraftStartCapability` only when that
exact Companion exists. Review projection may display `cow == nil`,
`isNewcomer == false`, and a fixed unavailable reason, but it never substitutes
the constant ID. Starting requires the retained capability and uses only its
Core-minted Companion identity to build `MissionStartRequest`; no App path may
use `draft.cow?.id ?? CowTemplate.baseCowId`. The review bundle likewise reads
the optional base cow in its one snapshot, so a suggested Mission cannot claim
`canStart == true` merely because a suggestion exists.

The two `prepare*ChatTurn` methods each use one `pool.write` transaction. They
strictly load the typed Companion/guide, find-or-create the one owner thread,
insert the user message, strictly decode every post-insert history row, and
return `[APIMessage]` from that same transaction; the DM method also returns
the pinned and recent Companion
notes from the same snapshot. Existing `findOrCreateDMThread`,
`findOrCreateGuideThread`, message insertion, and note-list methods delegate to
the same `Database`-parameter helpers, so no algorithm is copied. JSON encoding
is completed before the first write and uses sorted keys. Message ordering is
`createdAt,rowid`; find-or-create reads at most two owner threads and treats a
duplicate as `ProjectionContractError.invalidPayload` instead of picking one.
The source gate permits Chat owner SQL only inside these seven static helpers
and requires every legacy façade/preparation to call them.
`ChatService.send`
and `GuideChatService.send` keep their public signatures and consume only these
preparations before opening the stream. DM history accepts only roles
`user`/`companion`; Guide history accepts only `user`/`guide`. Decoding accepts
either an exact text object or, for Guide history only, a
valid `SquadProposalBlock`; malformed JSON, unknown roles, proposal-shaped text,
or a proposal in DM history throws before commit. `ChatHistoryReadBundle`
uses the same decoder and returns `ChatMessageProjection`, so P1-B App paths
never call the legacy nonthrowing `ChatMessageRecord.text`/`proposal` accessors.
An exact text object projects `text = payload.text, proposal = nil`; a valid
Guide proposal with role `guide` projects
`text = proposal.historyPlaceholder, proposal = proposal`. A proposal under
any other role is invalid; raw JSON or an empty substitute is never projected.
A successfully returned stream means
the user message is committed; every later provider, proposal, assistant-write,
or cancellation terminal is therefore committed and refresh-only. DM chat
requires exactly one authoritative `TurnResult` containing at least one
nonblank text block and no non-text blocks; multiple/missing turns, empty text,
non-text content, or a delta-only completion throw a typed malformed-stream error and never
persist a fabricated assistant reply. An empty pinned/recent note result after
a successful read is the one approved no-memory case.

Guide chat uses the same strict terminal rule. Tool-use turns may contain tool
blocks, but the final non-tool authoritative turn must contain at least one
nonblank text block and no non-text block; empty, non-text, missing,
multiple-authoritative, or delta-only completion throws the typed
malformed-stream terminal. The already committed user message and any earlier
valid proposal remain committed, so the UI refreshes and never resends the
message. `propose_squad` validates the complete `memberIds` array before any
lookup/write: it must contain at least one nonblank String, a non-String/blank
member rejects the whole tool call, and only exact duplicates are stably
deduped. A truly absent `budget` remains the accepted optional value `nil` and
confirmation uses the already captured positive default. A present null,
Boolean, String, fraction, nonpositive, or out-of-range budget is typed invalid;
`Orchestrator.confirmSquadProposal` also rejects a nonpositive/overflowing
fallback instead of clamping it. Invalid tool input writes no proposal and
returns only the safe `tool_result(isError:true)`, allowing a later Guide turn
to self-correct.

All persisted chat/distillation roles are strict. DM accepts only `user` and
`companion`; Guide accepts only `user` and `guide`, with proposal payloads
permitted only for Guide-role rows. Distiller's DM and Guide transcript
projectors use the same sets. An unknown role throws
`ProjectionContractError.invalidPayload`; chat preparation rolls back the new
thread/user message before provider contact, while distillation performs zero
provider call and does not advance its watermark. No ternary/default maps an
unknown persisted role to an assistant/guide role.

`KnowledgeStore.swift` adds only these exact read seams, each returning nil
solely for a genuinely absent row:

```swift
extension AppDatabase {
    package func campNote(id: String) throws -> CampNoteRecord?
    package func companionNote(id: String) throws -> CompanionNoteRecord?
}
```
Delete ports first load the typed note, execute the existing delete, require
one affected row, and return the loaded owner ID. Pin/save verification uses
these seams rather than a second App-side GRDB read.

`readInputCampBundle` requires exactly one guide Companion for the requested
Camp and returns it in the same snapshot; missing, duplicate, wrong-kind, or
wrong-Camp guide ownership is a projection-contract failure. AppStore assigns
`guideCompanion` only from the loaded snapshot. `resolveDefaultCamp` owns one
`pool.write`: it preserves the existing first-Camp selection, returns
`created == false` when that Camp already exists, and otherwise atomically
creates the Camp plus guide and returns `created == true`. It never returns a
Camp without its guide. `InputWorkflowController.ensureDefaultCamp` is the
sole Application command over this receipt and carries
`P1-B-SEAM inputEnsureDefaultCamp`; AppStore finishes that outcome before it
invokes ordinary `inputLoadCamp`. A post-create snapshot failure is visible as
a committed-Camp/read-failure sequence, and retry reloads that same Camp.

`readScheduleRuntimeBundle(templateId:)` reads enabled schedules, all their
evaluation cursors, and the optional exact requested template in one
transaction. A nonnil requested ID that is absent is a typed not-found; nil
means no catch-up title was requested. Application
`loadSchedulePresentation(templateId:now:timeZone:trace:)` maps this bundle to
enabled schedule/title/time data plus the requested catch-up title. Every
enabled schedule must produce one exact `nextFireDate`; a nil date is a typed
schedule-projection failure for the whole load, never an omitted row or
“暂无”. It is the
`scheduleLoad` presentation branch used by `scheduleCatchupTitle` and
`nextScheduleMenuTitle`; neither App method reads ScheduleStore directly.
Scheduled mission outcome reads remain the separate callable
`loadScheduledMissionOutcomePlans` and alone carry
`P1-B-SEAM scheduleOutcomeLoad`, never a broadcast/submission seam.

When a finished Card event is absent from the render cache, AppStore performs
no Card-only fallback read. If and only if a current Mission exists, it starts
the current-generation `missionLoadDetail`, applies that terminal, and handles
the event only when the loaded snapshot contains the Card. A read failure
publishes its trace and preserves prior Mission data; no current Mission is
genuine irrelevance and performs zero read. This is the exact replacement for
`R[.cardMissionLookup]`.

Under `#if DEBUG`, the following and only the following aggregate hooks exist:

```swift
#if DEBUG
extension AppDatabase {
    package func readMissionDetailBundleForTesting(
        missionId: String,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> MissionDetailReadBundle
    package func readMissionIndexBundleForTesting(
        includeArchived: Bool,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> MissionIndexReadBundle
    package func readInputCampBundleForTesting(
        campId: String,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> InputCampReadBundle
    package func readInputReviewBundleForTesting(
        ingestionId: String,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> InputReviewReadBundle
    package func readInputMissionDraftBundleForTesting(
        candidateId: String,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> InputMissionDraftReadBundle
    package func readInputMissionDraftBundleForTesting(
        ingestionId: String,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> InputMissionDraftReadBundle
    package func readRuntimeWorkflowBundleForTesting(
        afterAnchorRead: @Sendable () -> Void
    ) throws -> RuntimeWorkflowReadBundle
    package func readRuntimeProviderResolutionBundleForTesting(
        companionId: String?,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> RuntimeProviderResolutionReadBundle
    package func readScheduleWorkflowBundleForTesting(
        campId: String,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> ScheduleWorkflowReadBundle
    package func readScheduleRuntimeBundleForTesting(
        templateId: String? = nil,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> ScheduleRuntimeReadBundle
    package func readScheduledMissionNotificationBundleForTesting(
        missionId: String,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> ScheduledMissionNotificationReadBundle?
    package func prepareDMChatTurnForTesting(
        companionId: String,
        userText: String,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> DMChatTurnPreparation
    package func prepareGuideChatTurnForTesting(
        campId: String,
        userText: String,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> GuideChatTurnPreparation
}
#endif
```

The first eleven overloads call their hook exactly once after the first anchor
result and before the next statement in the same read transaction:

| DEBUG overload | first anchor | owning declaration / internal subcase |
|---|---|---|
| `readMissionDetailBundleForTesting` | required Mission | `workflowProjectionPreservesPriorValueOnRefreshFailure` / `wal.mission-detail` |
| `readMissionIndexBundleForTesting` | Mission list | same declaration / `wal.mission-index` |
| `readInputCampBundleForTesting` | required Camp | `inputRefreshFailurePreservesDashboardAndInbox` / `wal.input-camp` |
| `readInputReviewBundleForTesting` | required ingestion | same declaration / `wal.input-review` |
| candidate `readInputMissionDraftBundleForTesting` | required ActionCandidate | same declaration / `wal.input-mission-draft-candidate` |
| ingestion `readInputMissionDraftBundleForTesting` | required ingestion | same declaration / `wal.input-mission-draft-ingestion` |
| `readRuntimeWorkflowBundleForTesting` | profile list | `runtimeReconcileFailureNeverChangesDefault` / `wal.runtime-workflow` |
| `readRuntimeProviderResolutionBundleForTesting` | default-profile lookup, including absence | same declaration / `wal.runtime-provider-resolution` |
| `readScheduleWorkflowBundleForTesting` | required Camp | `databaseReadFailureIsFailedNotLoadedEmpty` / `wal.schedule-workflow` |
| `readScheduleRuntimeBundleForTesting` | enabled schedules | same declaration / `wal.schedule-runtime` |
| `readScheduledMissionNotificationBundleForTesting` | scheduled-origin lookup, including absence | same declaration / `wal.schedule-notification` |
| `prepareDMChatTurnForTesting` | required Companion after the write transaction begins | `databaseReadFailureIsFailedNotLoadedEmpty` / `writer.prepare-dm-chat` |
| `prepareGuideChatTurnForTesting` | required guide after the write transaction begins | same declaration / `writer.prepare-guide-chat` |

Each overload reuses its production body; copying SQL, decoders, or a
transaction is forbidden. The first eleven read overloads use a WAL hook that
may wait for a concurrent writer to commit, and the result must be wholly
pre-write or wholly post-write. The final two write overloads are tested as
writers. Their
`prepare*ChatTurnForTesting` hooks run after the required Companion/guide
anchor while the write transaction is owned; they may release a second writer
but never wait for it. The ordered ledger is exactly `anchor read < second
writer attempted < preparation committed < second writer committed`.
Deterministic abort triggers prove whole-transaction rollback.

`loadOrCreateDMHistoryBundle`, `loadOrCreateGuideHistoryBundle`, and
`deleteIngestionAtomically` have no `ForTesting` overload; their owner subcases
are `writer.load-or-create-dm-history`, `writer.load-or-create-guide-history`,
and `writer.delete-ingestion`. `campNote(id:)` and `companionNote(id:)` are
single-row seams and have no hook. All 13 definitions and the exact internal
test rows that reference them are enclosed in matching direct, non-nested
`#if DEBUG/#endif` blocks with no `#else` or `#elseif`; the 47 ordinary test
declarations remain available in release. All names are absent from release
objects.

Application maps these Core bundles only. Every Application source gate rejects
`import GRDB`, `.pool`, `DatabasePool`, `DatabaseQueue`, `DatabaseReader`,
`DatabaseWriter`, `Row`, and `Column`; it does not reject ordinary AppDatabase
parameter names.

```swift
package struct MissionDetailSnapshot: Sendable {
    package let mission: MissionRecord
    package let cards: [CardRecord]
    package let artifacts: [ArtifactRecord]
    package let pendingRequests: [UserRequestRecord]
    package let squad: SquadRecord
    package let squadMemberIds: [String]
    package let companionsById: [String: CompanionRecord]
    package let events: [EventRecord]
    package let spend: MissionSpendBreakdown
    package init(mission: MissionRecord, cards: [CardRecord],
                 artifacts: [ArtifactRecord], pendingRequests: [UserRequestRecord],
                 squad: SquadRecord, squadMemberIds: [String],
                 companionsById: [String: CompanionRecord], events: [EventRecord],
                 spend: MissionSpendBreakdown)
}
package struct MissionIndexSnapshot: Sendable {
    package let missions: [MissionRecord]
    package let camps: [CampRecord]
    package let missionsByCamp: [String: [MissionRecord]]
    package let artifactLedger: [ArtifactLedgerItem]
    package init(missions: [MissionRecord], camps: [CampRecord],
                 missionsByCamp: [String: [MissionRecord]],
                 artifactLedger: [ArtifactLedgerItem])
}
package struct MissionStartRequest: Sendable, Equatable {
    package let goal: String
    package let companionIds: [String]
    package let workspacePath: String?
    package let plannerModel: String
    package let runtimeProfileId: String
    package let budgetTokens: Int
    package let campId: String?
    package let autonomy: MissionAutonomy
    package let idempotencyKey: String
    package let durableTraceId: String
    package init(goal: String, companionIds: [String], workspacePath: String?,
                 plannerModel: String, runtimeProfileId: String, budgetTokens: Int,
                 campId: String?, autonomy: MissionAutonomy,
                 idempotencyKey: String, durableTraceId: String)
}
package enum MissionCancelDisposition: Sendable, Equatable {
    case cancelled
    case alreadyTerminal(MissionStatus)
}
package enum MissionHarvestDisposition: Sendable, Equatable {
    case harvested
    case notExecuting(MissionStatus)
}
// Core declarations in Orchestrator.swift.
package struct ProposalVisibilityRepairReceipt: Sendable, Equatable {
    package let missionId: String
    let repairId: UUID
    let messageId: String
    let proposalId: String
    let deterministicEventId: String
    let originalCreatedAt: Date
    let traceScope: FailureTraceScope
    init(repairId: UUID, messageId: String, proposalId: String,
         missionId: String, deterministicEventId: String,
         originalCreatedAt: Date, traceScope: FailureTraceScope)
}
package enum ProposalConfirmationAction: Sendable, Equatable {
    case begin(CapturedProposalMissionStart)
    case reconcile(ProposalVisibilityRepairReceipt)
}
package struct AcceptedMissionReportRepairReceipt: Sendable, Equatable {
    package let missionId: String
    let repairId: UUID
    let deterministicReportURL: URL
    let traceScope: FailureTraceScope
    init(repairId: UUID, missionId: String,
         deterministicReportURL: URL, traceScope: FailureTraceScope)
}
package struct AcceptedMissionDistillationRepairReceipt:
    Sendable, Equatable {
    package let missionId: String
    let repairId: UUID
    let campId: String
    let model: String
    let goal: String
    let cards: [Distiller.CardDigest]
    let deterministicFallbackNoteId: String
    let deterministicFallbackEventId: String
    let deterministicRealNoteId: String
    let deterministicRealEventId: String
    let phase: AcceptedMissionDistillationRepairPhase
    let originalPrimary: AcceptedMissionDistillationPrimaryFailure
    let traceScope: FailureTraceScope
    init(repairId: UUID, missionId: String, campId: String,
         model: String, goal: String, cards: [Distiller.CardDigest],
         deterministicFallbackNoteId: String,
         deterministicFallbackEventId: String,
         deterministicRealNoteId: String,
         deterministicRealEventId: String,
         phase: AcceptedMissionDistillationRepairPhase,
         originalPrimary: AcceptedMissionDistillationPrimaryFailure,
         traceScope: FailureTraceScope)
}
enum AcceptedMissionDistillationRepairPhase: Sendable, Equatable {
    case fallbackMissing
    case realRetryReady
}
enum AcceptedMissionDistillationPrimaryFailure: Sendable, Equatable {
    case provider
    case invalidPayload
}
package struct CoworkDistillationRepairReceipt: Sendable, Equatable {
    package let missionId: String
    let repairId: UUID
    let companionId: String
    let model: String
    let cards: [Distiller.CardDigest]
    let deterministicNoteId: String
    let deterministicEventId: String
    let traceScope: FailureTraceScope
    init(repairId: UUID, missionId: String, companionId: String,
         model: String, cards: [Distiller.CardDigest],
         deterministicNoteId: String, deterministicEventId: String,
         traceScope: FailureTraceScope)
}
package enum MissionAcceptanceAction: Sendable, Equatable {
    case accept(missionId: String, distillModel: String)
    case retryReport(AcceptedMissionReportRepairReceipt)
    case retryDistillation(AcceptedMissionDistillationRepairReceipt)
    case retryCowork(CoworkDistillationRepairReceipt)
}
package struct MissionAcceptanceRepairSet: Sendable, Equatable {
    package let report: AcceptedMissionReportRepairReceipt?
    package let distillation: AcceptedMissionDistillationRepairReceipt?
    package let cowork: [CoworkDistillationRepairReceipt]
    init(report: AcceptedMissionReportRepairReceipt?,
         distillation: AcceptedMissionDistillationRepairReceipt?,
         cowork: [CoworkDistillationRepairReceipt])
}
package enum MissionAcceptanceOutcome: Sendable {
    case notCommitted(UserVisibleFailure)
    case committed
    case committedWithVisibilityFailures(
        repairs: MissionAcceptanceRepairSet,
        failures: [UserVisibleFailure]
    )
}
struct RateLimitEventRepairReceipt: Sendable, Equatable {
    let repairId: UUID
    let missionId: String
    let deterministicEventId: String
    let originalCreatedAt: Date
    let cooldownGeneration: UInt64
    let retryAfterSeconds: Int
    let traceScope: FailureTraceScope
    init(repairId: UUID, missionId: String,
         deterministicEventId: String, originalCreatedAt: Date,
         cooldownGeneration: UInt64, retryAfterSeconds: Int,
         traceScope: FailureTraceScope)
}
package enum RateLimitEventRepairOutcome: Sendable {
    case noPending
    case repaired(hasMore: Bool)
    case failed(UserVisibleFailure)
}
package struct MissionWorkflowReads: Sendable {
    package let detail: @Sendable (String) throws -> MissionDetailReadBundle
    package let index: @Sendable (Bool) throws -> MissionIndexReadBundle
    package init(detail: @escaping @Sendable (String) throws -> MissionDetailReadBundle,
                 index: @escaping @Sendable (Bool) throws -> MissionIndexReadBundle)
    package static func live(database: AppDatabase) -> Self
}
package struct ScheduleWorkflowSnapshot: Sendable {
    package let campId: String
    package let templates: [ScheduleTemplateProjection]
    package let schedules: [ScheduleRecordProjection]
    package init(campId: String, templates: [ScheduleTemplateProjection],
                 schedules: [ScheduleRecordProjection])
}
package struct ScheduleTemplateProjection: Sendable {
    package let record: MissionTemplateRecord
    package let companionIds: [String]
    package let primaryCompanionId: String
    package let budgetTokens: Int
    package init(record: MissionTemplateRecord,
                 companionIds: [String], primaryCompanionId: String,
                 budgetTokens: Int)
}
package struct ScheduleRecordProjection: Sendable {
    package let record: ScheduleRecord
    package let validatedWeekday: Int?
    package init(record: ScheduleRecord, validatedWeekday: Int?)
}
package struct EnabledScheduleProjection: Sendable {
    package let record: EnabledScheduleRecord
    package let nextFireDate: Date
    package init(record: EnabledScheduleRecord, nextFireDate: Date)
}
package struct SchedulePresentationSnapshot: Sendable {
    package let enabled: [EnabledScheduleProjection]
    package let requestedTemplate: ScheduleTemplateProjection?
    package init(enabled: [EnabledScheduleProjection],
                 requestedTemplate: ScheduleTemplateProjection?)
}
package struct ScheduleTemplateDraftCommand: Sendable, Equatable {
    package let existingId: String?
    package let campId: String
    package let name: String
    package let goal: String
    package let companionId: String
    package let workspacePath: String
    package let budgetText: String
    package let autonomy: MissionAutonomy
    package init(existingId: String?, campId: String, name: String,
                 goal: String, companionId: String,
                 workspacePath: String, budgetText: String,
                 autonomy: MissionAutonomy)
}
package struct ScheduleDraftCommand: Sendable, Equatable {
    package let templateId: String
    package let frequency: ScheduleFrequency
    package let selectedTime: Date
    package let weekday: Int?
    package let enabled: Bool
    package init(templateId: String, frequency: ScheduleFrequency,
                 selectedTime: Date, weekday: Int?, enabled: Bool)
}
package struct ScheduleFireRequest: Sendable, Equatable {
    package let scheduleId: String
    package let context: ScheduleSlotContextV1
    package init(scheduleId: String, context: ScheduleSlotContextV1)
}
package struct ScheduleReplayRequest: Sendable, Equatable {
    package let originalFireId: String
    package init(originalFireId: String)
}
package enum ScheduleNotificationKind: String, Sendable, Equatable {
    case closeout, failure, budgetExhausted
}
package struct ScheduleNotificationRequest: Sendable, Equatable {
    package let notificationId: String
    package let missionId: String
    package let title: String
    package let body: String
    package let kind: ScheduleNotificationKind
    package init(notificationId: String, missionId: String, title: String,
                 body: String, kind: ScheduleNotificationKind)
}
package struct ScheduleActivityRegistration: Sendable, Equatable {
    package let scheduleId: String
    package let request: ScheduleFireRequest
    package init(scheduleId: String, request: ScheduleFireRequest)
}
package struct ScheduleRegistrationReceipt: Sendable, Equatable {
    package let registeredScheduleIds: [String]
    package init(registeredScheduleIds: [String])
}
package struct ScheduleRegistrationEvaluation: Sendable, Equatable {
    package let now: Date
    package let timeZone: TimeZone
    package init(now: Date, timeZone: TimeZone)
}
package struct ScheduleTemplateDeletionReceipt: Sendable, Equatable {
    package let template: MissionTemplateRecord
    package let deletedSchedules: [ScheduleRecord]
    package init(template: MissionTemplateRecord,
                 deletedSchedules: [ScheduleRecord])
}
package struct ScheduleDeletionReceipt: Sendable, Equatable {
    package let schedule: ScheduleRecord
    package init(schedule: ScheduleRecord)
}
package enum ScheduleMutationCommittedIdentity: Sendable, Equatable {
    case templateSaved(MissionTemplateRecord)
    case templateDeleted(ScheduleTemplateDeletionReceipt)
    case scheduleSaved(ScheduleRecord)
    case scheduleEnablementChanged(ScheduleRecord)
    case scheduleDeleted(ScheduleDeletionReceipt)
}
fileprivate enum SchedulePostCommitRepairKey: Hashable, Sendable {
    case template(String)
    case schedule(String)
}
fileprivate enum SchedulePostCommitRepairStage: Sendable, Equatable {
    case authorizationThenRegistration
    case registration
}
fileprivate enum SchedulePostCommitOwnerPhase: Sendable, Equatable {
    case performing
    case repair(SchedulePostCommitRepairReceipt)
    case globallyVisibleAwaitingTerminal(applicationCarrierId: UUID)
}
package struct SchedulePlatformEvidence: Sendable, Equatable {
    package let authorization: ScheduleAuthorizationReceipt?
    package let registration: ScheduleRegistrationReceipt?
    fileprivate init(authorization: ScheduleAuthorizationReceipt?,
                     registration: ScheduleRegistrationReceipt?)
}
package struct SchedulePostCommitRepairReceipt: Sendable, Equatable {
    fileprivate let repairId: UUID
    fileprivate let identity: ScheduleMutationCommittedIdentity
    fileprivate let stage: SchedulePostCommitRepairStage
    fileprivate let traceScope: FailureTraceScope
    fileprivate let ownedKeys: Set<SchedulePostCommitRepairKey>
    fileprivate let evidence: SchedulePlatformEvidence
    fileprivate init(repairId: UUID,
                     identity: ScheduleMutationCommittedIdentity,
                     stage: SchedulePostCommitRepairStage,
                     traceScope: FailureTraceScope,
                     ownedKeys: Set<SchedulePostCommitRepairKey>,
                     evidence: SchedulePlatformEvidence)
    package func isSameRepairOwner(
        as other: SchedulePostCommitRepairReceipt
    ) -> Bool {
        repairId == other.repairId
    }
}
package struct SchedulePostCommitApplicationReceipt: Sendable, Equatable {
    fileprivate let applicationId: UUID
    fileprivate init(applicationId: UUID)
}
package struct ScheduleCommittedTerminal: Sendable, Equatable {
    package let application: SchedulePostCommitApplicationReceipt
    fileprivate init(application: SchedulePostCommitApplicationReceipt)
}
package struct ScheduleVisibilityFailureTerminal: Sendable, Equatable {
    package let application: SchedulePostCommitApplicationReceipt
    fileprivate init(application: SchedulePostCommitApplicationReceipt)
}
package struct ScheduleRepairedTerminal: Sendable, Equatable {
    package let application: SchedulePostCommitApplicationReceipt
    fileprivate init(application: SchedulePostCommitApplicationReceipt)
}
package struct ScheduleStillPendingTerminal: Sendable, Equatable {
    package let application: SchedulePostCommitApplicationReceipt
    fileprivate init(application: SchedulePostCommitApplicationReceipt)
}
package enum SchedulePostCommitApplicationOperation: Sendable, Equatable {
    case project(ScheduleMutationCommittedIdentity)
    case authorizationEvidence(ScheduleAuthorizationReceipt)
    case registrationEvidence(ScheduleRegistrationReceipt)
    case clearRepair(SchedulePostCommitRepairReceipt)
    case installRepair(identity: ScheduleMutationCommittedIdentity,
                       repair: SchedulePostCommitRepairReceipt,
                       failure: UserVisibleFailure)
}
package struct SchedulePostCommitCanonicalProgram: Sendable, Equatable {
    package let operations: [SchedulePostCommitApplicationOperation]
    package let currentIdentity: ScheduleMutationCommittedIdentity
    fileprivate init(operations: [SchedulePostCommitApplicationOperation],
                     currentIdentity: ScheduleMutationCommittedIdentity)
}
package enum ScheduleMutationOutcome: Sendable, Equatable {
    case notCommitted(UserVisibleFailure)
    case committed(ScheduleCommittedTerminal)
    case committedSuperseded
    case committedWithVisibilityFailure(ScheduleVisibilityFailureTerminal)
}
package enum SchedulePostCommitRepairOutcome: Sendable, Equatable {
    case repaired(ScheduleRepairedTerminal)
    case stillPending(ScheduleStillPendingTerminal)
    case superseded
}
package struct SchedulePostCommitApplicationDecision: Sendable, Equatable {
    fileprivate enum Storage: Sendable, Equatable {
        case apply(SchedulePostCommitCanonicalProgram)
        case mutationSuperseded
        case alreadyConsumed
    }
    fileprivate let storage: Storage
    fileprivate init(storage: Storage)
    package func fold<Value>(
        apply: (SchedulePostCommitCanonicalProgram) -> Value,
        mutationSuperseded: () -> Value,
        alreadyConsumed: () -> Value
    ) -> Value
}
package enum ScheduleRegistrationRefreshOutcome: Sendable, Equatable {
    case refreshed(
        registration: ScheduleRegistrationReceipt,
        supersededRepairs: [SchedulePostCommitRepairReceipt]
    )
    case failed(UserVisibleFailure)
}
package struct ScheduleRegistrationPort: Sendable {
    package let replaceAll:
        @MainActor @Sendable ([ScheduleActivityRegistration]) async throws
            -> ScheduleRegistrationReceipt
    package init(replaceAll:
        @escaping @MainActor @Sendable
            ([ScheduleActivityRegistration]) async throws
            -> ScheduleRegistrationReceipt)
}
package enum ScheduleAuthorizationDisposition: String, Sendable, Equatable {
    case unavailable
    case alreadyRequested
    case granted
    case denied
}
package struct ScheduleAuthorizationReceipt: Sendable, Equatable {
    package let disposition: ScheduleAuthorizationDisposition
    package init(disposition: ScheduleAuthorizationDisposition)
}
package enum ScheduleNotificationDisposition: String, Sendable, Equatable {
    case unavailable
    case notAuthorized
    case submitted
}
package struct ScheduleNotificationReceipt: Sendable, Equatable {
    package let notificationId: String
    package let disposition: ScheduleNotificationDisposition
    package init(notificationId: String,
                 disposition: ScheduleNotificationDisposition)
}
package struct ScheduleBroadcastReceipt: Sendable, Equatable {
    package let effectKey: String
    package let campId: String
    package let messageId: String
    package init(effectKey: String, campId: String, messageId: String)
}
package struct ScheduledMissionOutcomePlan: Sendable, Equatable {
    package let effectKey: String
    package let missionId: String
    package let broadcastCampId: String?
    package let broadcastText: String?
    package let notification: ScheduleNotificationRequest
    package init(effectKey: String, missionId: String,
                 broadcastCampId: String?, broadcastText: String?,
                 notification: ScheduleNotificationRequest)
}
package struct ScheduleNotificationPort: Sendable {
    package let requestAuthorization:
        @MainActor @Sendable () async throws -> ScheduleAuthorizationReceipt
    package let submit:
        @MainActor @Sendable (ScheduleNotificationRequest) async throws
            -> ScheduleNotificationReceipt
    package init(
        requestAuthorization:
            @escaping @MainActor @Sendable () async throws
                -> ScheduleAuthorizationReceipt,
        submit:
            @escaping @MainActor @Sendable (ScheduleNotificationRequest)
                async throws -> ScheduleNotificationReceipt
    )
}
package enum DocumentPresentationKind: String, Sendable, Equatable {
    case open
    case reveal
}
package struct ExistingReportPresentationPlan: Sendable, Equatable {
    package let missionId: String
    package let kind: DocumentPresentationKind
    fileprivate let planId: UUID
    fileprivate let url: URL
    fileprivate let traceScope: FailureTraceScope
    fileprivate init(missionId: String, kind: DocumentPresentationKind,
                     planId: UUID, url: URL,
                     traceScope: FailureTraceScope)
    package func withURL<T>(_ body: (URL) throws -> T) rethrows -> T
}
package enum MissionReportPresentationAction: Sendable, Equatable {
    case generate(missionId: String, kind: DocumentPresentationKind)
    case presentExisting(ExistingReportPresentationPlan)
}
package struct DocumentPresentationReceipt: Sendable, Equatable {
    package let url: URL
    package let kind: DocumentPresentationKind
    package init(url: URL, kind: DocumentPresentationKind)
}
package struct DocumentPresentationPort: Sendable {
    package let present:
        @MainActor @Sendable (ExistingReportPresentationPlan) throws
            -> DocumentPresentationReceipt
    package init(present:
        @escaping @MainActor @Sendable
            (ExistingReportPresentationPlan) throws
            -> DocumentPresentationReceipt)
}
package struct MissionWorkflowPorts: Sendable {
    package let retryCard: @MainActor @Sendable (String) async throws -> Void
    package let returnForRework:
        @MainActor @Sendable (String, String) async throws -> Void
    package let addBudget:
        @MainActor @Sendable (String, Int) async throws -> Void
    package let clearReview: @Sendable (String) throws -> Void
    package let setAutonomy:
        @Sendable (String, MissionAutonomy) throws -> Void
    package let dismissProposal: @Sendable (String) throws -> Void
    package let ensureReport: @Sendable (String) throws -> URL
    package let loadSchedules:
        @Sendable (String) throws -> ScheduleWorkflowSnapshot
    package let loadSchedulePresentation:
        @Sendable (String?, Date, TimeZone) throws
            -> SchedulePresentationSnapshot
    package let saveTemplate:
        @Sendable (MissionTemplateRecord) throws -> Void
    package let deleteTemplate:
        @Sendable (String) throws -> ScheduleTemplateDeletionReceipt
    package let saveSchedule: @Sendable (ScheduleRecord) throws -> Void
    package let setScheduleEnabled:
        @Sendable (String, Bool) throws -> ScheduleRecord
    package let deleteSchedule:
        @Sendable (String) throws -> ScheduleDeletionReceipt
    package let fire:
        @MainActor @Sendable (ScheduleFireRequest, OperationTrace) async throws
            -> ScheduleFireCommitResult
    package let recordMissed:
        @MainActor @Sendable (ScheduleFireRequest, OperationTrace) async throws
            -> ScheduleFireCommitResult
    package let replay:
        @MainActor @Sendable (ScheduleReplayRequest, OperationTrace) async throws
            -> ScheduleFireCommitResult
    package let wake:
        @MainActor @Sendable (ScheduleFireCommitResult) async throws -> Void
    package let broadcastFire:
        @Sendable (ScheduleFireCommitResult) throws
            -> ScheduleBroadcastReceipt?
    package let broadcastOutcome:
        @Sendable (ScheduledMissionOutcomePlan) throws
            -> ScheduleBroadcastReceipt?
    package init(
        retryCard: @escaping @MainActor @Sendable (String) async throws -> Void,
        returnForRework:
            @escaping @MainActor @Sendable (String, String) async throws -> Void,
        addBudget:
            @escaping @MainActor @Sendable (String, Int) async throws -> Void,
        clearReview: @escaping @Sendable (String) throws -> Void,
        setAutonomy:
            @escaping @Sendable (String, MissionAutonomy) throws -> Void,
        dismissProposal: @escaping @Sendable (String) throws -> Void,
        ensureReport: @escaping @Sendable (String) throws -> URL,
        loadSchedules:
            @escaping @Sendable (String) throws -> ScheduleWorkflowSnapshot,
        loadSchedulePresentation:
            @escaping @Sendable (String?, Date, TimeZone) throws
                -> SchedulePresentationSnapshot,
        saveTemplate:
            @escaping @Sendable (MissionTemplateRecord) throws -> Void,
        deleteTemplate:
            @escaping @Sendable (String) throws
                -> ScheduleTemplateDeletionReceipt,
        saveSchedule: @escaping @Sendable (ScheduleRecord) throws -> Void,
        setScheduleEnabled:
            @escaping @Sendable (String, Bool) throws -> ScheduleRecord,
        deleteSchedule:
            @escaping @Sendable (String) throws -> ScheduleDeletionReceipt,
        fire: @escaping @MainActor @Sendable (ScheduleFireRequest, OperationTrace)
            async throws -> ScheduleFireCommitResult,
        recordMissed:
            @escaping @MainActor @Sendable (ScheduleFireRequest, OperationTrace)
                async throws -> ScheduleFireCommitResult,
        replay: @escaping @MainActor @Sendable (ScheduleReplayRequest, OperationTrace)
            async throws -> ScheduleFireCommitResult,
        wake: @escaping @MainActor @Sendable (ScheduleFireCommitResult)
            async throws -> Void,
        broadcastFire:
            @escaping @Sendable (ScheduleFireCommitResult) throws
                -> ScheduleBroadcastReceipt?,
        broadcastOutcome:
            @escaping @Sendable (ScheduledMissionOutcomePlan) throws
                -> ScheduleBroadcastReceipt?
    )
    package static func live(
        database: AppDatabase,
        orchestrator: Orchestrator,
        planningCoordinator: PlanningEntryCoordinator,
        reportStoreRoot: URL,
        selectRuntime:
            @escaping @MainActor @Sendable () throws
                -> PlanningEntryRuntimeSelection
    ) -> Self
}
@MainActor package final class MissionWorkflowController {
    private enum SchedulePostCommitApplicationStatus: Sendable, Equatable {
        case current
        case globallyVisible
    }
    private struct SchedulePostCommitApplicationState: Sendable, Equatable {
        let receipt: SchedulePostCommitApplicationReceipt
        let carrierId: UUID
    }
    private enum SchedulePostCommitApplicationCarrierLocation:
        Sendable, Equatable {
        case unpublished(ownerId: UUID)
        case published(receipt: SchedulePostCommitApplicationReceipt)
    }
    private struct SchedulePostCommitApplicationCarrier:
        Sendable, Equatable {
        let carrierId: UUID
        var ownedKeys: Set<SchedulePostCommitRepairKey>
        var program: SchedulePostCommitCanonicalProgram
        var visibilityStage: SchedulePostCommitRepairStage
        var status: SchedulePostCommitApplicationStatus
        var location: SchedulePostCommitApplicationCarrierLocation
    }
    private struct SchedulePostCommitApplicationTombstone:
        Sendable, Equatable {
        let receipt: SchedulePostCommitApplicationReceipt
    }
    fileprivate struct SchedulePostCommitOwnerState: Sendable, Equatable {
        let ownerId: UUID
        let identity: ScheduleMutationCommittedIdentity
        let ownedKeys: Set<SchedulePostCommitRepairKey>
        var evidence: SchedulePlatformEvidence
        var pendingSupersededRepairs: [SchedulePostCommitRepairReceipt]
        var applicationCarrierId: UUID
        var phase: SchedulePostCommitOwnerPhase
        var pendingApplicationId: UUID?
    }
    private var schedulePostCommitOwnerStateById:
        [UUID: SchedulePostCommitOwnerState] = [:]
    private var schedulePostCommitCurrentOwnerIdByKey:
        [SchedulePostCommitRepairKey: UUID] = [:]
    private var schedulePostCommitApplicationStateById:
        [UUID: SchedulePostCommitApplicationState] = [:]
    private var schedulePostCommitApplicationCarrierById:
        [UUID: SchedulePostCommitApplicationCarrier] = [:]
    private var schedulePostCommitCurrentCarrierIdByKey:
        [SchedulePostCommitRepairKey: UUID] = [:]
    private var schedulePostCommitApplicationTombstoneById:
        [UUID: SchedulePostCommitApplicationTombstone] = [:]
    private struct SchedulePostCommitRepairFlight {
        let attempt: UUID
        let startingReceipt: SchedulePostCommitRepairReceipt
        let applicationCarrierId: UUID
        let task: Task<SchedulePostCommitRepairOutcome, Never>
    }
    private var schedulePostCommitRepairFlightById:
        [UUID: SchedulePostCommitRepairFlight] = [:]
    package init(database: AppDatabase, orchestrator: Orchestrator,
                 planningCoordinator: PlanningEntryCoordinator,
                 reportStoreRoot: URL,
                 selectRuntime:
                    @escaping @MainActor @Sendable () throws
                        -> PlanningEntryRuntimeSelection,
                 reporter: FailureReporter,
                 traceFactory: OperationTraceFactory,
                 registrationEvaluation:
                    @escaping @Sendable () -> ScheduleRegistrationEvaluation,
                 reads: MissionWorkflowReads? = nil,
                 ports: MissionWorkflowPorts? = nil)
    package func loadDetail(missionId: String, trace: OperationTrace) async
        -> WorkflowLoadState<MissionDetailSnapshot>
    package func loadIndex(includeArchived: Bool, trace: OperationTrace) async
        -> WorkflowLoadState<MissionIndexSnapshot>
    package func start(_ request: MissionStartRequest, trace: OperationTrace) async
        -> OperationCommitOutcome<String>
    package func cancel(missionId: String, trace: OperationTrace) async
        -> OperationCommitOutcome<MissionCancelDisposition>
    package func harvest(missionId: String, trace: OperationTrace) async
        -> OperationCommitOutcome<MissionHarvestDisposition>
    package func accept(_ action: MissionAcceptanceAction,
                        trace: OperationTrace) async
        -> MissionAcceptanceOutcome
    package func retryContext(cardId: String, trace: OperationTrace) async
        -> OperationCommitOutcome<Void>
    package func answer(requestId: String, answerJSON: String, trace: OperationTrace) async
        -> OperationCommitOutcome<Void>
    package func confirm(_ action: ProposalConfirmationAction,
                         trace: OperationTrace) async
        -> OperationCommitOutcome<ProposalVisibilityRepairReceipt>
    package func retryCard(cardId: String, trace: OperationTrace) async
        -> OperationCommitOutcome<Void>
    package func returnForRework(cardId: String, feedback: String,
                                 trace: OperationTrace) async
        -> OperationCommitOutcome<Void>
    package func addBudget(missionId: String, tokens: Int,
                           trace: OperationTrace) async
        -> OperationCommitOutcome<Void>
    package func clearReview(cardId: String, trace: OperationTrace) async
        -> OperationCommitOutcome<Void>
    package func setAutonomy(missionId: String, autonomy: MissionAutonomy,
                             trace: OperationTrace) async
        -> OperationCommitOutcome<Void>
    package func dismissProposal(messageId: String, trace: OperationTrace) async
        -> OperationCommitOutcome<Void>
    package func ensureReport(missionId: String, trace: OperationTrace) async
        -> OperationCommitOutcome<URL>
    package func presentReport(_ action: MissionReportPresentationAction,
                               presentation: DocumentPresentationPort,
                               trace: OperationTrace) async
        -> OperationCommitOutcome<ExistingReportPresentationPlan>
    package func loadSchedules(campId: String, trace: OperationTrace) async
        -> WorkflowLoadState<ScheduleWorkflowSnapshot>
    package func loadSchedulePresentation(
        templateId: String?, now: Date, timeZone: TimeZone,
        trace: OperationTrace
    ) async -> WorkflowLoadState<SchedulePresentationSnapshot>
    package func saveTemplateDraft(
        _ draft: ScheduleTemplateDraftCommand,
        registration: ScheduleRegistrationPort,
        trace: OperationTrace
    ) async -> ScheduleMutationOutcome
    package func saveTemplate(_ template: MissionTemplateRecord,
                              registration: ScheduleRegistrationPort,
                              trace: OperationTrace) async
        -> ScheduleMutationOutcome
    package func deleteTemplate(id: String,
                                registration: ScheduleRegistrationPort,
                                trace: OperationTrace) async
        -> ScheduleMutationOutcome
    package func saveSchedule(_ schedule: ScheduleRecord,
                              registration: ScheduleRegistrationPort,
                              notifications: ScheduleNotificationPort,
                              trace: OperationTrace) async
        -> ScheduleMutationOutcome
    package func saveScheduleDraft(
        _ draft: ScheduleDraftCommand, calendar: Calendar,
        registration: ScheduleRegistrationPort,
        notifications: ScheduleNotificationPort,
        trace: OperationTrace
    ) async -> ScheduleMutationOutcome
    package func setScheduleEnabled(id: String, enabled: Bool,
                                    registration: ScheduleRegistrationPort,
                                    notifications: ScheduleNotificationPort,
                                    trace: OperationTrace) async
        -> ScheduleMutationOutcome
    package func deleteSchedule(id: String,
                                registration: ScheduleRegistrationPort,
                                trace: OperationTrace) async
        -> ScheduleMutationOutcome
    // P1-B-SEAM schedulePostCommitRepair
    package func retrySchedulePostCommit(
        _ receipt: SchedulePostCommitRepairReceipt,
        registration: ScheduleRegistrationPort,
        notifications: ScheduleNotificationPort
    ) async -> SchedulePostCommitRepairOutcome
    package func consumeSchedulePostCommitApplication(
        _ receipt: SchedulePostCommitApplicationReceipt
    ) -> SchedulePostCommitApplicationDecision
    package func refreshSchedules(
        registration: ScheduleRegistrationPort,
        trace: OperationTrace
    ) async -> ScheduleRegistrationRefreshOutcome
    package func loadStartupMissedFires(now: Date, timeZone: TimeZone,
                                        trace: OperationTrace) async
        -> WorkflowLoadState<[ScheduleFireRequest]>
    package func prepareRunNow(scheduleId: String, now: Date,
                               timeZone: TimeZone,
                               trace: OperationTrace) async
        -> WorkflowLoadState<ScheduleFireRequest>
    package func fireSchedule(_ request: ScheduleFireRequest,
                              trace: OperationTrace) async
        -> OperationCommitOutcome<ScheduleFireCommitResult>
    package func recordMissedSchedule(_ request: ScheduleFireRequest,
                                      trace: OperationTrace) async
        -> OperationCommitOutcome<ScheduleFireCommitResult>
    package func replaySchedule(_ request: ScheduleReplayRequest,
                                trace: OperationTrace) async
        -> OperationCommitOutcome<ScheduleFireCommitResult>
    package func publishScheduleWake(_ result: ScheduleFireCommitResult,
                                     trace: OperationTrace) async
        -> OperationCommitOutcome<ScheduleFireCommitResult>
    package func publishScheduleBroadcast(_ result: ScheduleFireCommitResult,
                                          trace: OperationTrace) async
        -> OperationCommitOutcome<ScheduleFireCommitResult>
    package func loadScheduledMissionOutcomePlans(
        missionId: String, trace: OperationTrace
    ) async -> WorkflowLoadState<[ScheduledMissionOutcomePlan]>
    package func publishScheduledMissionOutcomeBroadcast(
        _ plan: ScheduledMissionOutcomePlan, trace: OperationTrace
    ) async -> OperationCommitOutcome<ScheduledMissionOutcomePlan>
    package func requestScheduleAuthorization(
        notifications: ScheduleNotificationPort,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<ScheduleAuthorizationReceipt>
    package func submitScheduleNotification(
        _ request: ScheduleNotificationRequest,
        notifications: ScheduleNotificationPort,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<ScheduleNotificationReceipt>
}
```

`loadDetail` is one consistent off-state assembly: any failed component makes
the whole terminal failed. A missing Squad is a typed invariant failure;
malformed `memberIdsJson` is never
replaced by assignee IDs. `loadIndex` publishes no mixed old/new partial map.
`start` adopts `durableTraceId`; the explicit trace must match it or returns
not-committed `trace_identity_conflict` before writes.

`MissionWorkflowPorts.live` is the only production port constructor. It uses
the supplied Core database/orchestrator/coordinator and never imports AppKit,
SwiftUI, UserNotifications, or `NSBackgroundActivityScheduler`. App provides
only the three narrow platform ports—activity registration, notification, and
document presentation—at the owning façade call. MissionScheduler becomes the
`ScheduleRegistrationPort` adapter plus a callback into the controller; it no
longer reads AppDatabase, computes missed slots, starts/replays work, appends a
broadcast, or logs a business error itself. `replaceAll` fully constructs the
new scheduler set before invalidating the old one; a replacement failure keeps
the old registrations and throws. Although the injected port is `async throws`
so controlled doubles can create actor-state barriers, the production
`MissionScheduler` adapter closure contains no `await`, continuation, Task,
yield, callback, or other suspension edge: it calls one synchronous private
build-and-swap helper and returns in the same MainActor segment. Therefore two
production snapshots cannot reorder their swaps; MainActor invocation order is
swap order. A suspending test double has no shared scheduler state and may only
return a precomputed receipt/counter after release; it is not evidence that a
stale platform swap occurred. ScheduledMissionNotifier changes
authorization/submission to typed receipts. Each App platform adapter catches
its arbitrary Error exactly once, discards the raw value, and throws the
corresponding fixed `SchedulePlatformFailure`. No platform class logs or
returns raw detail.

Schedule mutation methods commit the database mutation first, then request
authorization when enabling, then refresh registration. All draft overloads
delegate to the same private mutation owner. A database failure is the closed
`.notCommitted` case with zero authorization/registration calls and leaves every
existing repair owner current. Template save/delete, disabled schedule save,
disable, and schedule delete commit their exact identities and then perform
registration only. Enabled schedule save and enable commit their exact record,
then perform authorization and registration in that order. Any nonthrowing
authorization receipt—`.unavailable`, `.alreadyRequested`, `.granted`, or
`.denied`—completes the authorization stage and proceeds to registration; the
exact disposition is retained in `SchedulePlatformEvidence` and rendered as
explicit UI evidence rather than being silently projected as delivery success.

Identity-to-repair ownership is closed. `templateSaved` owns
`.template(record.id)`; `templateDeleted` owns that template key plus every
`.schedule(id)` in its exact deletion preimage; and schedule save, enablement
change, or delete owns its exact schedule key. Immediately after a database
commit and before the first platform effect, the controller mints one internal
effect-owner ID and installs one `SchedulePostCommitOwnerState` in
`.performing` with `pendingApplicationId == nil`. In that same non-suspending
post-commit segment—before authorization, registration, Reporter, or any other
await—it mints one private application-carrier ID and installs an unpublished
`SchedulePostCommitApplicationCarrier`; the owner stores that carrier ID. The
carrier is the sole owner of a closed `SchedulePostCommitCanonicalProgram`.
That program begins with the exact inherited operations described below,
followed by `.project(thisJustCommittedIdentity)`, and its `currentIdentity` is
that final identity. Registration-only paths initialize
its visibility stage to `.registration`; authorization-requiring paths begin at
`.authorizationThenRegistration` and change the carrier to `.registration` in
the same guarded actor segment that records a nonthrowing authorization receipt,
before registration evaluation/await. Every effect reverse-map ID resolves
to one owner state and every carrier-key reverse-map ID resolves directly to
one unpublished or published carrier. It
atomically removes every predecessor owner whose complete `ownedKeys` set
intersects the committed set, removes all reverse mappings for that complete
owner, and installs the new owner ID for every committed key. The successor
inherits each predecessor's undelivered `pendingSupersededRepairs` plus its
opaque receipt when that predecessor was in `.repair`, de-duplicates by
`repairId`, and sorts by `repairId.uuidString` UTF-8 bytes. In the same commit
segment it atomically claims every intersecting application carrier, whether
unpublished or published. A published predecessor's whole state/reverse maps
are removed and its exact receipt receives one mutation-superseded tombstone;
for an unpublished predecessor, after transferring its carrier/program the
successor removes the old effect owner, every effect reverse-key mapping, and
the exact matching repair-flight entry. Cancellation is optional and never the
authority. The old initial/repair continuation then fails its owner/attempt/
all-keys guard and returns receipt-free committed-superseded/superseded with
zero reconstruction, capture, or state mutation. No `applicationTransferred`
owner phase exists; only global visibility may retain
`.globallyVisibleAwaitingTerminal(applicationCarrierId:)`.
Both forms transfer their complete canonical operation program and complete
owned-key set into the successor carrier. A globally-visible predecessor's
program has already been normalized in place to keep every `.project`,
`.authorizationEvidence`, and `.clearRepair` operation while removing every
`.registrationEvidence` and `.installRepair` operation. A current predecessor
keeps its whole program. The successor concatenates normalized predecessor
programs, appends its `.project` operation, appends the unique sorted
transferred `.clearRepair` operations, and only at its own terminal appends its
authorization/registration evidence plus any exact new `.installRepair`.
App reduces that array into a temporary projection and commits it once, so no
intermediate repair, evidence, or DB projection renders.
The successor reverse-maps the **union of inherited and new keys**, not merely
the new keys. Independently current
predecessor groups have disjoint complete key sets—any prior overlap would
already have composed them—so their projection operations commute. The
controller sorts those groups by the UTF-8 bytes of their smallest canonical
`template:<id>`/`schedule:<id>` owned-key spelling, preserves order inside each
group, concatenates them, and appends the new identity last; it never
deduplicates canonical operations. The sealed program's `currentIdentity` is
exactly that final identity and App uses it only for the current repair carrier.
Thus a multi-key delete followed by a
subset-key save still applies delete-template/delete-children first and the
save last, matching DB state rather than losing child deletions. A database
failure installs, removes, tombstones, and transfers nothing. Only a current
terminal drains the successor lists; a
superseded initial invocation or application terminal can neither return nor
clear it. Thus a direct stale receipt, in-flight old initial effect, or
controller-returned/App-not-yet-applied terminal cannot replay merely because
an App generation rejected or delayed its terminal.

Application publication is one uniform per-terminal capability, not a bit on a
repair owner. The private carrier is created at DB commit, rather than after a
platform await. Immediately before returning each terminal that may change
App's committed Schedule projection—initial `.committed` or
`.committedWithVisibilityFailure`, and repair `.repaired` or `.stillPending`—
the controller requires the exact unpublished carrier still to belong to that
owner/flight, seals the terminal effect into its program, mints one opaque
`SchedulePostCommitApplicationReceipt`, changes the same carrier location to
published, and in that same non-suspending actor segment installs exactly one
`SchedulePostCommitApplicationState`. If a successor already claimed the
carrier, the old terminal is receipt-free committed-superseded/superseded and
cannot reconstruct a program or token. The application state contains only
the receipt and exact carrier ID; the carrier continues to own the complete
program, owned keys, status, and location. Publication establishes a strict
bijection `applicationId -> state.carrierId -> carrier.location.published(the
same receipt)`. There is no duplicated published program. The terminal's
drained `supersededRepairs`, a repair terminal's starting receipt, and a newly
returned repair receipt are de-duplicated by private repair ID and appended as
ordered `.clearRepair`/`.installRepair` operations as specified above. A later repair invocation creates/uses a private
unpublished carrier before its first effect await and seals the repair terminal
into that same carrier, so every plan is nonempty and idempotently establishes
the current DB projection.
Publication changes neither the carrier ID nor the reverse map: every owned
key continues to map directly to that carrier ID. If a repair owner
remains, it also sets the owner's `pendingApplicationId`; a direct repair retry
is rejected before trace/I/O until that exact token is consumed. Joined callers
of one controller Task share the same terminal and application receipt. A pure
`.notCommitted`, `.committedSuperseded`, or `.superseded` terminal carries no
application receipt and has no App projection authority.

`consumeSchedulePostCommitApplication` is synchronous and accepts only the
opaque application receipt. It requires the exact state/carrier bijection,
removes that state, carrier, and every key reverse mapping equal to that
carrier ID,
compare-clears a matching repair owner's `pendingApplicationId`, and returns
exactly one sealed `.apply(carrier.program)` decision. A carrier marked
globally visible already owns the in-place normalized program, so consume has
no second reconstruction or payload source. An exact tombstone is consumed once
and returns a mutationSuperseded decision. An absent, mismatched, or already-
consumed receipt returns the alreadyConsumed decision with zero mutation. A
successful global registration replacement may change an eligible pending
carrier from current to globally visible, but it retains that carrier's
complete key reverse mappings so a later intersecting database commit can still
upgrade it to mutation-superseded. There is no published flag, repair-owner-wide
deduplication, forged receipt, optional token, or second application token for
one terminal. A later retry terminal always receives its own token, even when
its repair ID and stage are byte-equal to the prior terminal.

The four outcome cases carry distinct fileprivate-initialized terminal wrappers,
and each wrapper carries only that opaque receipt. Identity, evidence, projection,
failure, returned repair, and clearance witnesses exist only as operations in
the controller-owned carrier program returned by consume. The canonical
program and decision initializers are fileprivate; App can only read the
sealed operation array from the decision's closed three-arm `fold` and cannot
construct or relabel either value. A
package caller therefore cannot splice a real token onto another terminal's
raw associated values, and App may never trust the outcome case tag for payload
data.

A thrown post-commit platform failure returns
`.committedWithVisibilityFailure(ScheduleVisibilityFailureTerminal)`; its
controller-stored program ends in the nonoptional evidence and exact
`.installRepair(identity:repair:failure:)` operation.
A successful initial mutation returns `.committed(ScheduleCommittedTerminal)`;
repair success and failure return `.repaired(ScheduleRepairedTerminal)` and
`.stillPending(ScheduleStillPendingTerminal)`. No raw committed payload appears
in an outcome, and no package initializer can construct a sealed program or
decision.
Save identities are the validated saved records. Template deletion uses
only the stable `(createdAt,id)` preimage returned from the committing Core
transaction; schedule deletion uses its exact returned preimage. No identity is
reconstructed after commit. Authorization throw retains stage
`.authorizationThenRegistration`, evidence authorization/registration nil, and
performs zero registration. A nonthrowing authorization receipt is retained
even if registration later throws; that receipt transitions the same repair ID
to `.registration`. The repair ID is the existing effect-owner ID; a current
platform failure changes that same owner atomically from `.performing` to
`.repair(receipt)`, and its terminal application token becomes that owner's sole
pending application ID. Registration success retains the exact registration receipt.
For an initial mutation whose registration succeeds, the same no-await actor
segment first appends its terminal evidence and publishes the application
receipt, then removes the exact `.performing` effect owner and every effect
reverse-key mapping that still names it. The application carrier and its
reverse keys remain until consume or successor claim. Immediately after this
segment there are zero effect-owner/reverse entries for that initial command,
exactly one published carrier/state bijection, and no path by which consume can
leave an effect owner pointing at a removed carrier.

Every actual registration attempt calls the injected
`registrationEvaluation()` exactly once after any required authorization,
reloads one current consistent runtime bundle, computes registrations with that
fresh `now` and `timeZone`, and calls `replaceAll`. DB or authorization failure
calls the evaluation zero times. Production injects `Date()` and
`TimeZone.current` only through this closure; tests inject fixed values. The
port is deliberately `async throws`: production's adapter may complete without
suspension, while controlled tests with no shared scheduler state may suspend
before returning a precomputed receipt so actor-reentrant controller/global-
registration races are executable. Every call
uses `try await` exactly once. The replacement fully constructs the new scheduler set before swapping, so failure
preserves old registrations byte-for-byte and a retry never replays a stale
registration plan.

`retrySchedulePostCommit` accepts only the opaque receipt and no caller trace,
raw ID, stage, closure, mutation port, or Boolean. Before trace creation,
Reporter, database, authorization, registration, or evaluation work it requires
a byte-equal `.repair(receipt)` entry in `schedulePostCommitOwnerStateById` and
requires every owned key to map to that repair ID in
`schedulePostCommitCurrentOwnerIdByKey`, with `pendingApplicationId == nil`.
An unconsumed prior terminal therefore returns `.superseded` with zero work;
App cannot expose a retry control until it has consumed the application receipt
that installed the current repair carrier.
Concurrent byte-equal retries alone await the exact Task stored in the current
`schedulePostCommitRepairFlightById` value and capture/report at most once. A
new flight mints one attempt UUID plus one private unpublished application
carrier, stores its starting receipt, carrier ID, and Task before the first
await. That carrier begins with the repair owner's inherited canonical
operations followed by `.project(owner.currentIdentity)` when that operation is
not already the program tail, sets `currentIdentity` to that record, and owns
the exact complete key set; no terminal token exists yet. The Task body rechecks the byte-equal starting receipt, its
flight attempt, and all reverse keys before trace creation or platform work; a
flight removed before body entry is zero work. Every terminal compare-clears by
repair ID + flight attempt only; Swift `Task` equality is never required. Stale,
completed, replaced, wrong-stage, partial-key, or unknown receipts return
`.superseded` with zero work. Only after that guard accepts does the controller
mint one fresh trace from the retained scope. The exact operation mapping is
template save → `.scheduleTemplateSave`, template delete →
`.scheduleTemplateDelete`, schedule save → `.scheduleSave`, enablement change →
`.scheduleEnable`, and schedule delete → `.scheduleDelete`.

Both the success continuation and catch arm of an initial authorization await
first reload the exact `.performing` owner and prove every reverse key mapping
before registration evaluation/runtime load/replacement or Reporter/capture/
repair transition. If stale, authorization may already have run once but
registration, evaluation, Reporter, repair/map mutation, and successor cleanup
are zero; it returns receipt-free `.committedSuperseded`. A stale thrown
error is discarded as an owned stale terminal rather than captured. App may
conditionally clear only that exact old command flight and applies no old
identity, evidence, repair carrier, or transferred receipt list.

An authorization-stage repair retry attempts authorization first. Its success
continuation and catch arm each first reload the byte-equal `.repair(receipt)`
state, the exact flight attempt, and every reverse key mapping before any
registration/evaluation/Reporter/capture/stage transition or returned evidence.
If a new commit or global replacement superseded it during the await,
registration, evaluation, Reporter, repair/map mutation, and successor cleanup
are zero and it returns `.superseded`; a stale thrown Error is discarded as an
owned stale terminal. A current authorization throw alone captures once and
retains the same stage; a current nonthrowing receipt records evidence and
proceeds to registration. A registration throw
transitions the same repair ID and retained evidence to `.registration`. A
registration-stage retry has zero authorization calls. Success conditionally
removes the exact effect state and reverse mappings, installs the sealed
repaired application state, and returns `.repaired(ScheduleRepairedTerminal)`; failure
installs the sealed still-pending application state and returns
`.stillPending(ScheduleStillPendingTerminal)`. No branch automatically retries or invokes
save/update/delete/enable.

Every repair Task terminal executes one common flight tail after producing its
closed outcome: remove only a map entry whose repair ID and attempt still match,
regardless of repaired/still-pending/superseded result. An intersecting commit
removes and may cancel the predecessor flight only after it has removed the
complete predecessor owner/reverse mappings; cancellation is an optimization,
not authority, and the Task's post-await owner guards make every late branch
zero mutation. A transitioned receipt remains inside the same flight; callers
that already joined receive its terminal, while a later call holding the old
stage receipt is superseded.

A successful global `replaceAll` handles effect owners, unpublished carriers,
and published terminal applications separately. It removes every current `.registration`
repair and its effect-owner reverse mappings while preserving all
`.authorizationThenRegistration` repairs. If that owner has no pending
application token, its opaque repair receipt is returned exactly once in the
caller's `supersededRepairs`. If it has a pending token, the token's application
carrier—not the global caller—already owns every undelivered clearance witness;
the replacement normalizes that carrier program in place and changes its
status to `.globallyVisible`, removes the repair
owner, and does not duplicate those witnesses in the global return. If a
matching initial or repair flight has an unpublished carrier because its
registration continuation has not yet sealed a terminal, the global operation
may mark it globally visible only when `visibilityStage == .registration`; it
then removes the exact effect reverse mappings but retains the owner state only
as `.globallyVisibleAwaitingTerminal(applicationCarrierId:)`. It performs no
failure capture or repair installation and does not claim the carrier's
program. The original Task's next success **or catch** continuation accepts only
that exact owner phase + carrier + flight attempt, discards any now-stale raw
error, seals/publishes the same carrier in globally-visible form, then removes
the retained owner/flight. A later intersecting commit may instead claim the
carrier first, remove that retained phase, and make the old terminal receipt-
free superseded. An
authorization-stage unpublished carrier remains current and its owner remains.
Independently, the replacement normalizes and marks every published carrier
whose terminal is registration-complete or registration-failed; an
authorization-stage failure carrier remains current. Eligibility is derived
from that carrier's closed operation suffix plus `visibilityStage`, never from
an outcome case tag or a duplicate program. It never removes carrier-key
reverse mappings when marking visibility, so a
later intersecting DB commit can still claim the complete carrier/program and
win with mutation-superseded before publication.

Initial mutation and repair outcomes expose only an application receipt; a
globally visible late terminal still delivers its controller-owned clearance
list/program once while suppressing obsolete registration evidence/failure/new
repair. Published repair owners removed directly by the global operation are
returned through its ordinary list, allowing App to clear cross-key repair UI
without reading a private stage. Each returned receipt is a clearance witness for its
stable repair owner, not merely its current-stage bytes:
`isSameRepairOwner(as:)` compares only the two fileprivate repair IDs and
exposes neither ID nor stage. Thus an App carrier holding the earlier
authorization-stage receipt is cleared by the later registration-stage witness
for that same owner. Byte-equal `Equatable` remains the controller retry guard;
the pure same-owner proof is permitted only for App clearance and tests.
`.committedSuperseded` exposes no such list because it
was transferred to and may be drained only by the successor owner.
`refreshSchedules` uses the same injected `registrationEvaluation` and current
runtime-bundle computation; it accepts no caller `now`/`timeZone`. A successful
replace returns `ScheduleRegistrationRefreshOutcome.refreshed` with the exact
registration receipt and every published removed registration-stage repair not
owned by a pending application token, and App same-owner-clears those opaque
carriers. A pre-swap failure leaves registrations, application states, and all
repair owners byte-identical and returns `.failed`; it cannot silently
supersede a repair or application terminal whose effect was not made visible.

App owns exactly the generation-guarded carriers in §6.1. Initial mutation and
repair share `scheduleCommandFlightByKey`; its explicit attempt UUID, generation,
closed `.mutation`/`.repair(startingReceipt:)` purpose, and Task avoid any
impossible `Task` equality comparison. An entry first checked-increments the
primary key generation before DB/controller/effect work and installs the flight
before its first await. Overflow is the existing typed critical
`ProjectionContractError`, installs no flight, and performs zero controller/DB/
platform work. No consume/apply/clearance/tail changes a generation, so a
published one-shot receipt cannot be lost to later arithmetic failure. The Task
body then rechecks key + generation + attempt + purpose in one MainActor segment
immediately before calling the controller; a flight cleared before body entry
performs zero controller, trace, database, platform, or Reporter work. A retry
additionally captures the old opaque receipt; a second tap while a flight exists
performs no call. Key + generation + attempt + purpose and, for retry, old
receipt remain the sole flight-entry and compare-clear guards; they are not an
authority to discard a controller-confirmed current database postimage. A
not-committed newer mutation retains the older repair. `.notCommitted`,
`.committedSuperseded`, and `.superseded` carry no application receipt, require
their ordinary exact flight guard for any App mutation, and apply no committed
identity/evidence/clearance/failure/repair state.

Every terminal carrying `SchedulePostCommitApplicationReceipt` follows one
mandatory lifetime shape. Once the controller call begins, its Task holds a
strong App owner through receipt consume plus guarded App transition and ignores
cancellation until that non-suspending segment finishes; weak-self loss,
`Task.isCancelled`, `checkCancellation`, and branch-specific early return cannot
skip consume. The App invokes
`consumeSchedulePostCommitApplication` exactly once before reading the
terminal's App-flight guard, then exhaustively applies only the returned sealed
decision in the same no-await MainActor segment. It never reads identity,
evidence, failure, repair, or clearance from the outcome. Its matching flight tail still removes
only the exact old attempt; a stale tail never removes a newer flight.

The sealed canonical program is controller authority for the DB postimage and
its terminal UI effect. App folds its operation array into a temporary value in
order: `.project` mutates the Schedule projection,
`.authorizationEvidence`/`.registrationEvidence` update their exact typed
evidence, `.clearRepair` removes only the matching opaque owner, and
`.installRepair` installs that final current identity/receipt/failure. It then
commits the folded result once, even if its local generation/attempt is stale,
without canceling or replacing a newer mutation flight. `currentIdentity` is
used only for the current repair carrier and never comes from an outcome case
or App-local guess. A globally-visible carrier was normalized before consume,
so its program contains projection/authorization/clearance operations but no
obsolete registration evidence or repair installation.
`.mutationSuperseded` and `.alreadyConsumed` apply zero projection, evidence,
clearance, failure, or carrier. Duplicate joined delivery of one token is therefore harmless, while
two real retry terminals—even at the same stage—have distinct tokens and each
may be applied once. Because carrier-key reverse mappings survive global visibility
and every later DB commit tombstones intersecting tokens, there is neither an
R1-to-R2 publication gap nor a late success/repaired terminal that resurrects a
schedule after an overlapping template delete.

Applying a `supersededRepairs` list is one no-await MainActor segment. For each
App repair carrier whose receipt is the same opaque repair owner as one returned
witness, App clears that carrier exactly once. Decision application has no
throwing or failable step and never increments a generation. It may
cancel/remove a current flight only when that flight's purpose is
`.repair(startingReceipt:)` and the starting receipt is the same opaque repair
owner as the witness. A `.mutation` flight, or a repair flight for another
owner, remains byte-identical and its generation does not advance; clearing old
repair UI is never authority to invalidate a newer database mutation. The
current repair command's own starting witness never cancels/removes its own
still-running flight; its ordinary attempt tail performs the sole compare-clear
after apply. Any other matching old repair flight is removed by its explicit
attempt/purpose CAS, making its body/late terminal stale without a generation
change. The current terminal has already passed its decision handshake before
delivering any clearance/installing any successor repair and then runs its
ordinary flight tail. `refreshSchedules` has no
protected command key but follows the same purpose-sensitive rule. Task
cancellation is only an optimization; the purpose/attempt/generation CAS is
authority for flight entry/cleanup, while the application receipt is authority
for committed projection. This prevents a late old-stage
`.stillPending` terminal from reinstalling a registration-stage receipt without
making a newly queued mutation invisible.

Every App mutation/repair Task terminal has one unconditional compare-clear tail
keyed by mutation key + captured generation + explicit attempt + purpose; only
the still-matching flight is removed. A receipt-bearing outcome consumes and
applies its controller decision before that tail, independent of whether the
tail still matches. A receipt-free outcome has no committed apply authority.
A late terminal therefore cannot remove a newer flight, while
`.notCommitted`, `.committed`, visibility failure, `.committedSuperseded`,
repaired, still-pending, and superseded all leave no completed matching Task
carrier when their own flight still exists. No `defer` is required and no
outcome branch owns an ad hoc cleanup.

Every `.apply(program)` interprets its controller-sealed operation array in
order; a template-delete identity derives the template and child-
schedule keys only from its committed deletion preimage and clears their exact
superseded repair carriers.
For each child it invalidates/cancels only a matching `.repair` flight; an
already-installed `.mutation` flight and its generation remain untouched and
must pass its own task-body/controller/terminal guards. Late repair completions
therefore cannot clear or replace a newer carrier, while a mutation that really
commits after the delete cannot become an invisible side effect. App never
switches on repair stage and its repair action calls only
`retrySchedulePostCommit`.

Fire/replay first return the authoritative
`ScheduleFireCommitResult`; wake and broadcast are separate idempotent
post-commit methods so a failed effect can be retried without replaying the
fire. `recordMissedSchedule` is distinct from a normal fire; replay receives an
original fire ID and can never be reached through the normal-fire port.
Replayed results return nil from the broadcast port and never broadcast again.
`loadScheduledMissionOutcomePlans` consumes the one Core notification bundle
and completes every Mission/Squad/Event read before any broadcast or
notification call. App's once-set is updated only after a non-nil
`ScheduleBroadcastReceipt` or `.submitted` notification receipt. An
`.unavailable`, `.notAuthorized`, or `.denied` receipt is an explicit
non-delivery outcome, never displayed as sent. Notification submission success
is its commit point. `ScheduleTests` invokes the controller with throwing and
non-delivery registration/notification ports; existing MissionScheduler tests
keep their declaration IDs and replace logger assertions with exact typed
receipts/outcomes.

`ScheduleManagerView` consumes only `ScheduleWorkflowSnapshot` and
`ScheduleTemplateProjection`. Its `TemplateDraft` initializer accepts the
already-decoded projection and is nonthrowing; the legacy
`try? companionIds().first ?? ""` is deleted. The View's save action constructs
only `ScheduleTemplateDraftCommand`; `saveTemplateDraft` parses the budget,
constructs/validates the Core record, and delegates to the same private
persist-and-register helper used by `saveTemplate`. Invalid draft data is a
typed not-committed terminal with zero DB/platform call and safe trace text;
the View contains no catch or raw formatter. Save/enable/delete actions await
their real controller terminal, and only a committed terminal invokes
`refreshSchedules`. The former 200 ms `Task.sleep` polling helper is deleted;
there is no fifth cancellation residual and no time-based commit guess.

Both schedule loaders validate every template and Schedule before publishing a
snapshot. `ScheduleTemplateProjection` therefore carries a nonempty decoded ID
array, its safe first editor ID, and a positive concrete budget; neither the
list nor editor can render `0`, a global budget, or an empty Companion because
persisted data was malformed. `ScheduleRecordProjection` carries `nil` weekday
only for validated daily records and a concrete `1...7` weekday for weekly
records, so display never uses `weekday ?? 2`. Any invalid record fails the
whole load and preserves the prior snapshot.

New-form defaults remain explicit creation policy: one Companion is selected
only from a successfully loaded nonempty Camp list, budget starts at
`KernelDefaults.missionBudget`, weekday starts at Monday, and time starts at
local start-of-day plus nine hours (a nonoptional `Date`). The View passes the
chosen `Date` unchanged in `ScheduleDraftCommand`. `saveScheduleDraft` asks the
provided Calendar for hour and minute and requires both values; it validates
frequency/weekday and the Core record before the existing `saveSchedule`
helper. Missing Calendar components, invalid weekday, or missing Companion is a
traced not-committed terminal with the draft/sheet preserved and zero write.
The old `date(...) ?? Date()`, `hour ?? 9`, and `minute ?? 0` paths are deleted.
`setScheduleEnabled` must consume and return the exact updated record; App may
not discard it with `_ =`. Not-found stays not-committed, while a committed DB
change followed by authorization/registration failure retains the exact record
and retries only those post-commit effects.

Document presentation uses a truthful two-stage value. `.generate` ensures and
writes the report once, then constructs `ExistingReportPresentationPlan` with
the known URL/kind/scope before invoking the App port. A rejected
`NSWorkspace` Boolean or thrown platform error is
`.committedWithVisibilityFailure(value: plan, ...)`: it never forges the
success-only `DocumentPresentationReceipt`. `.presentExisting(plan)` validates
the same Mission scope, kind, and existing file, then invokes only the port;
it cannot call ensure/generate. A retry failure is `.notCommitted` for that
presentation-only action while App retains the already committed plan. The App
port must return a receipt whose URL/kind exactly equal the opaque plan or the
controller reports `projection_contract_failed`. App's retained open/reveal
façades share one private `presentReport(missionId:kind:)` owner; its pending
branch precedes generation, so the existing `missionOpenReport` delegate tuple
is replaced rather than duplicated.

The disposition enums live in Core as package API; existing public methods do
**not** change return type. Compatibility is frozen by distinct `trace:`
overloads, never by return-type-only overloading or “ignored result” assumptions:

```swift
// existing signatures remain byte-for-byte at the declaration boundary
public func startMission(
    goal: String,
    companionIds: [String],
    workspacePath: String?,
    plannerModel: String,
    runtimeProfileId: String,
    budgetTokens: Int,
    campId: String?,
    autonomy: MissionAutonomy,
    idempotencyKey: String,
    traceId: String
) async throws -> String
public func cancelMission(_ missionId: String) async -> Void
public func harvestMission(_ missionId: String) async -> Void
public func answerUserRequest(requestId: String, answerJson: String)
    async throws -> Void
package func confirmSquadProposal(_ captured: CapturedProposalMissionStart)
    async throws -> String
public func closeout(_ missionId: String, distillModel: String)
    async throws -> Void

// new controller-only boundaries
package func startMission(
    goal: String,
    companionIds: [String],
    workspacePath: String?,
    plannerModel: String,
    runtimeProfileId: String,
    budgetTokens: Int,
    campId: String?,
    autonomy: MissionAutonomy,
    idempotencyKey: String,
    trace: OperationTrace
) async -> OperationCommitOutcome<String>
package func cancelMission(_ missionId: String, trace: OperationTrace) async
    -> OperationCommitOutcome<MissionCancelDisposition>
package func harvestMission(_ missionId: String, trace: OperationTrace) async
    -> OperationCommitOutcome<MissionHarvestDisposition>
package func answerUserRequest(requestId: String, answerJson: String,
                               trace: OperationTrace) async
    -> OperationCommitOutcome<Void>
package func confirmSquadProposal(_ action: ProposalConfirmationAction,
                                  trace: OperationTrace) async
    -> OperationCommitOutcome<ProposalVisibilityRepairReceipt>
package func closeout(_ action: MissionAcceptanceAction,
                      trace: OperationTrace) async
    -> MissionAcceptanceOutcome
package func retryRateLimitEvent(missionId: String) async
    -> RateLimitEventRepairOutcome
package func retryCard(_ cardId: String, trace: OperationTrace) async
    -> OperationCommitOutcome<Void>
package func returnCardForRework(cardId: String, feedback: String,
                                 trace: OperationTrace) async
    -> OperationCommitOutcome<Void>
package func addBudget(missionId: String, tokens: Int,
                       trace: OperationTrace) async
    -> OperationCommitOutcome<Void>
package func captureScheduledMission(
    scheduleId: String,
    context: ScheduleSlotContextV1,
    selectRuntime:
        @MainActor () throws -> PlanningEntryRuntimeSelection,
    traceId: String
) throws -> SchedulePlanningStartCommand
package func captureMissedScheduledMission(
    scheduleId: String,
    context: ScheduleSlotContextV1,
    traceId: String
) -> SchedulePlanningStartCommand
package func captureScheduleReplay(
    originalFireId: String,
    selectRuntime:
        @MainActor () throws -> PlanningEntryRuntimeSelection,
    traceId: String
) throws -> ScheduleReplayStartCommand
```

The existing private
`Orchestrator.retryFailedStartupRecovery(transitionToken:)` keeps that exact
spelling and is the sole callable carrying
`P1-B-SEAM orchestratorStartupRecovery`; the executable descriptor enters it
through the retry branch of public `Orchestrator.resume()`. Its recovery-error
path replaces `setStartupRetryEligibilityAfterFailure`'s `try?` with an
explicit dispatch-mode read. A failed read leaves both retry-eligibility flags
false and the kernel halted, creates one distinct `.haltRead` trace with
`database_read_failed`, and emits/persists that failure before the original
`.startupRecovery` failure is emitted on its own trace. Neither failure
overwrites the other or enables retry. A successful read preserves the current
first-phase-versus-Card retry selection. The descriptor
`R[.startupRetryDispatchMode]` injects the second read failure through this
exact public-resume/private-retry chain and asserts both durable failures,
their distinct trace identities, zero resumed dispatch, and halted state.

The existing wrappers create/adopt the correct closed operation/scope trace and
call the traced body. `.committed` returns normally; a legacy String wrapper
also returns the committed ID for `.committedWithVisibilityFailure` while
synchronously emitting `.operationFailed(failure)`. Legacy Void/throwing
wrappers likewise emit the visibility failure without repeating the mutation.
`.notCommitted` in a throwing wrapper throws
`UserVisibleOperationError(failure:)`; nonthrowing cancel/harvest wrappers emit
the same failure and return Void. PlanningEntryCoordinator's existing
`startManual`, `startCandidate`, `startConfirmedProposal`, and scheduled String
signatures remain unchanged and continue using the legacy wrapper. Controllers
alone call traced overloads. A MissionStartRequest durable trace mismatch
returns `trace_identity_conflict` before writes.

The accepted manual-entry command identity keeps one deliberately named
normalization: `PlanningEntryCoordinator.normalizedManualBudget(_:)` returns
`max(1, capturedBudget)` before idempotency-key comparison. It is used only by
`prepareManual`; candidate, proposal, schedule, API, add-budget, and persisted
spend paths cannot call it. The equivalent ledger marks this one anchor as an
approved residual and tests both zero/negative normalization and the adjacent
strict proposal/schedule budget failures, so the policy cannot spread as a
generic clamp.

The legacy confirmed-proposal wrapper calls only
`.begin(captured)` and projects `receipt.missionId`; it never enters reconcile.
The legacy closeout wrapper calls only `.accept(missionId:distillModel:)` and
projects either committed or committed-visibility failures to Void. Only the
Application controller/App retry façades may pass `.reconcile(receipt)`,
`.retryReport(receipt)`, `.retryDistillation(receipt)`, or
`.retryCowork(receipt)`, so closed callers
cannot accidentally replay a post-commit repair.

Proposal confirmation has one common `orchestratorConfirmProposal` marker
owner over `ProposalConfirmationAction`. In `.begin`, compensation to pending
is legal only before `startMission` returns. Immediately after that durable
Mission ID exists, Orchestrator freezes `ProposalVisibilityRepairReceipt`
before the link/event attempt. `AppDatabase.reconcileConfirmedProposal(_:)`
owns one transaction: it requires the exact message/proposal still confirmed;
CASes a nil mission link to the retained ID, accepts only the same existing ID,
and rejects a different ID; then inserts the deterministic event ID/time/sorted
payload or validates every identity/payload byte of an existing event. Attach
and event commit atomically. Failure returns committed visibility with the
receipt and never reverts the proposal. `.reconcile(receipt)` executes only that
transaction—zero Mission capture/start—and is idempotent. AppStore's existing
`confirmProposal(messageId:)` checks its per-message retained receipt before
the begin path, uses one Task/attempt, and compare-removes only the same receipt
after success; no new delegate tuple is introduced.

Closeout likewise has one common `orchestratorCloseout` owner over
`MissionAcceptanceAction`. The accepted transaction and Mission-change event
complete before report generation, real Mission distillation, and the
per-companion cowork distillations. Every post-commit item uses a distinct
child trace under the accepted Mission scope, so independent failures never
attempt to own one failure row.
`MissionAcceptanceOutcome.committedWithVisibilityFailures` is legal only with
a nonempty `MissionAcceptanceRepairSet`; failures are ordered report then
distillation then cowork receipts sorted by companion ID, and their trace IDs
correspond one-to-one with the repair values. This custom outcome is required
because a single generic `OperationCommitOutcome` cannot truthfully carry
multiple independent committed-effect failures.

A report failure freezes `AcceptedMissionReportRepairReceipt` before the
write. `.retryReport` requires the Mission still accepted and invokes only the
same deterministic report writer and URL; an already byte-matching report is
success, a mismatched existing file is a typed integrity conflict, and the
retry never calls acceptance or distillation. A real-distillation
provider/parse failure freezes `AcceptedMissionDistillationRepairReceipt`
*before* fallback persistence, with the original Mission/Camp/model/goal/card
digests, fixed fallback/real note and event IDs, and phase
`.fallbackMissing`. It also retains the closed original-primary discriminator:
`.provider` maps only to `memory_provider_failed`, and `.invalidPayload` maps
only to `projection_decode_failed`; no arbitrary code/Error is retained. A
successful exact fallback note/event insert derives the
same identity in phase `.realRetryReady`; the initial visibility terminal
carries that receipt and the primary distillation failure. If fallback
persistence itself fails, the existing critical composite appears in the
failures array with the `.fallbackMissing` receipt. Thus the nonempty repair
set and ordered failures remain one-to-one even when this is the only
post-commit failure.

`.retryDistillation` first requires the Mission still accepted. For
`.fallbackMissing`, it performs only an idempotent fixed-ID/exact-byte fallback
note+event insert, then continues within that same repair invocation to the
real-distillation phase; another fallback failure returns the byte-identical
phase receipt with the composite failure. For `.realRetryReady`, it validates
the exact fallback without inserting it. In either phase, an already matching
real note/event succeeds without the provider; otherwise it invokes only real
Distiller over frozen input and atomically inserts the fixed real note/event.
If provider/parse fails after a fallback repair succeeded, the terminal carries
the derived `.realRetryReady` receipt and that retry's primary failure. It never
repeats acceptance, report generation, Camp/cowork work, or creates a second
fallback. Phase, IDs, and constructors remain Core-internal; App stores and
compares only the opaque receipt. A fallback write failure on either the initial
path or a later `.fallbackMissing` retry switches the closed retained
discriminator to its exact `FailureCode` and constructs the already-frozen
`CloseoutFallbackCompositeError(primaryCode:fallbackWriteCode:)` with fixed
`.databaseWriteFailed`; it never queries a prior failure row or guesses which
original branch failed.

Cowork participants remain the accepted M9 set: deduped nonnil assignee IDs of
done Cards. A done Card with `assigneeId == nil` is therefore an approved
nonparticipant; it remains present in the Camp closeout note. Implementation
builds participant groups by directly iterating sorted `(assigneeId, digests)`
pairs, so a looked-up key with a missing/empty digest array is not representable.
Every nonnil participant must resolve to an exact Companion. A missing
Companion, provider/parse failure, or note/event write failure records a safe
committed item failure, freezes one `CoworkDistillationRepairReceipt`, and
continues other companions without claiming complete cowork success. The only
approved no-note terminal is the Distiller's explicit typed `skip:true`; empty,
malformed, or provider-derived nil is never equivalent to that terminal.
The closed classifier uses `record_not_found` for a missing participant,
`memory_provider_failed` for provider failure, `projection_decode_failed` for
invalid output, and `memory_write_failed` for the atomic note/event write; no
new dynamic cowork code or Companion text enters evidence.

Each receipt binds the original accepted Mission scope, participant, model,
nonempty immutable card digests, and deterministic note/event identities.
`.retryCowork(receipt)` first validates the Mission remains accepted and the
receipt matches the current retained capability, then resolves that exact
Companion and retries only its cowork distillation plus one atomic fixed-ID
note/event insert. Exact existing bytes are idempotent success; mismatched bytes
are a typed integrity conflict. It performs zero acceptance, Camp-note/report/
Mission-distillation work, and never retries another companion. The
App retains only the opaque values emitted by the outcome; it cannot inspect or
reconstruct their companion/model/note/event/trace identity. Its retry façade
drains the exact retained values in stable order through `.retryCowork`,
compare-removing only each successfully repaired exact receipt. A partial retry
returns the remaining nonempty repair set and failures, not a generic completed
terminal.

AppStore's existing `closeoutCurrentMission()` consumes its retained report
and/or Mission-distillation receipt before the accept path. Its exact
`retryCoworkDistillation(missionId:)` consumes only the opaque cowork
capabilities retained under that Mission. Independent per-Mission single-flight/attempt
guards and byte-equal conditional application prevent a later terminal from
erasing another or newer repair. The cowork facade adds one exact delegate
tuple to the existing `orchestratorCloseout` seam; it accepts no receipt,
companion ID, model, note ID, or caller trace.

Rate-limit event repair is actor-owned because the initial cooldown transition
does not return through an App command. Before mutating `cooldownUntil`,
Orchestrator checks/increments `cooldownGeneration`, freezes a deterministic
event ID/time/payload receipt, and mutates the cooldown exactly once. The single
callable marked `P1-B-SEAM orchestratorRateLimitEvent` is
`Orchestrator.persistRateLimitEvent(_:)`; it inserts that exact event or
validates an exact existing row. Append failure retains the receipt in an
ordered per-Mission actor collection and emits committed visibility.
`retryRateLimitEvent(missionId:)` processes exactly the oldest actor-owned
receipt by `(originalCreatedAt, deterministicEventId)` per invocation, creates
one fresh `.missionRateLimitEvent` trace from that retained scope, and calls
only the marked persistence helper once. No pending receipt returns
`.noPending` with zero I/O. Success compare-removes only that exact receipt and
returns `.repaired(hasMore:)` computed from the actor collection after removal;
failure returns `.failed(failure)` and retains the byte-identical receipt. It
performs zero provider calls, reconcile, cooldown mutation, RNG, or time
generation. A later receipt cannot be removed by an earlier terminal. AppStore's
exact `retryRateLimitEvent(_:)` is the sole new delegate tuple; it accepts only
Mission ID and cannot construct a receipt. `hasMore` may expose an explicit
continue-repair action but never triggers an automatic provider/cooldown or
batch retry.

The existing public `retryCard`, `returnCardForRework`, and `addBudget`
declarations likewise remain byte-for-byte and delegate to the three traced
package overloads. Their legacy throwing wrappers throw only
`UserVisibleOperationError`; the Mission controller consumes the typed outcome
directly. No overload differs by return type alone.

The three `traceId:` schedule-capture overloads are additive: every existing
PlanningEntryCoordinator capture/start/replay signature remains unchanged.
MissionWorkflowController passes the already-created operation trace ID into
these overloads before the capture's first read. The returned command must
carry that exact ID or fail with `trace_identity_conflict` before its durable
transaction. Scheduler fire, missed-fire capture, and replay therefore never
mint a hidden second trace.

No closed AskUser/Budget/Halt test, function-value consumer, or view must add a
return binding, `try`, or Application import. AppStore's existing
`cancelMission(missionId:) async -> Void` façade remains exactly Void for
closed `CodingRanchLiveHosts` and `Task<Void, Never>` consumers. The current
standalone `markOpenRunsCanceled` write is folded into the same mission/card/
event transaction; otherwise partial run mutation could not truthfully return
not-committed.

Compatibility façades set their owning `globalVisibleFailure` before throwing
`UserVisibleOperationError`. Closed views that already display
`localizedDescription` therefore receive exactly `failure.message` with the
full trace, while closed views that only flip a Boolean still leave the App-
owned banner populated. This is the sole allowed `LocalizedError` bridge; raw
domain/provider errors never cross it.

```swift
package struct InputCampSnapshot: Sendable {
    package let camp: CampRecord
    package let guide: CompanionRecord
    package let ingestionItems: [IngestionItemRecord]
    package let activeRuminationByIngestion: [String: DurableWorkRecord]
    package let materializedNoteIdByIngestion: [String: String]
    package let missions: [MissionRecord]
    package let artifactCountByMission: [String: Int]
    package let campNotes: [CampNoteRecord]
    package let regularCompanions: [CompanionRecord]
    package let newcomerProgress: NewcomerProgress
    package init(camp: CampRecord, guide: CompanionRecord,
                 ingestionItems: [IngestionItemRecord],
                 activeRuminationByIngestion: [String: DurableWorkRecord],
                 materializedNoteIdByIngestion: [String: String],
                 missions: [MissionRecord], artifactCountByMission: [String: Int],
                 campNotes: [CampNoteRecord], regularCompanions: [CompanionRecord],
                 newcomerProgress: NewcomerProgress)
}
package struct InputReviewSnapshot: Sendable {
    package let ingestion: IngestionItemRecord
    package let result: RuminationResult
    package let baseCow: CompanionRecord?
    package init(ingestion: IngestionItemRecord, result: RuminationResult,
                 baseCow: CompanionRecord?)
}
package struct FeedSubmissionCommand: Sendable {
    package let campId: String
    package let rawText: String
    package let title: String?
    package let sourceURL: String?
    package let author: String?
    package let userIntent: String?
    package let sourceType: IngestionSourceType
    package let allowDuplicate: Bool
    package let startRumination: Bool
    package init(campId: String, rawText: String, title: String?, sourceURL: String?,
                 author: String?, userIntent: String?, sourceType: IngestionSourceType,
                 allowDuplicate: Bool, startRumination: Bool)
}
package struct InputWorkflowReads: Sendable {
    package let camp: @Sendable (String) throws -> InputCampReadBundle
    package let review: @Sendable (String) throws -> InputReviewReadBundle
    package init(camp: @escaping @Sendable (String) throws -> InputCampReadBundle,
                 review: @escaping @Sendable (String) throws -> InputReviewReadBundle)
    package static func live(database: AppDatabase) -> Self
}
package enum InputDeletionScope: Sendable, Equatable {
    case resultOnly
    case sourceAndResult
    case everythingIncludingProjection
}
package struct InputDeletionReceipt: Sendable, Equatable {
    package let ingestionId: String
    package let campId: String
    package let scope: InputDeletionScope
    package init(ingestionId: String, campId: String,
                 scope: InputDeletionScope)
}
package enum InputReviewCandidateKind: String, Sendable, Equatable {
    case keyPoint, requirement, todo
}
package struct InputReviewCandidateDraft: Sendable, Equatable {
    package let kind: InputReviewCandidateKind
    package let title: String
    package let detail: String
    package let confidence: Double?
    package let evidenceQuotes: [String]
    package init(kind: InputReviewCandidateKind, title: String,
                 detail: String, confidence: Double?,
                 evidenceQuotes: [String])
}
package struct InputReviewEditDraft: Sendable, Equatable {
    package let suggestedTitle: String
    package let summary: String
    package let accepted: [InputReviewCandidateDraft]
    package let suggestedMission: RuminationResult.SuggestedMission?
    package let uncertainties: [String]
    package init(suggestedTitle: String, summary: String,
                 accepted: [InputReviewCandidateDraft],
                 suggestedMission: RuminationResult.SuggestedMission?,
                 uncertainties: [String])
}
package enum InputReviewDraftError: Error, Sendable, Equatable {
    case missingKeyPointEvidence
    case missingRequirementConfidence
    case invalidRequirementConfidence
}
package struct InputReviewSaveCommand: Sendable, Equatable {
    package let ingestionId: String
    package let edited: InputReviewEditDraft
    package init(ingestionId: String, edited: InputReviewEditDraft)
}
package struct InputRuminationRuntimeSelection: Sendable, Equatable {
    package let model: String
    package let runtimeProfileId: String
    package init(model: String, runtimeProfileId: String)
}
package struct InputRuminationStartCommand: Sendable, Equatable {
    package let ingestionId: String
    package let expectedCampId: String
    package let runtime: InputRuminationRuntimeSelection
    package let durableTraceId: String
    package init(ingestionId: String, expectedCampId: String,
                 runtime: InputRuminationRuntimeSelection,
                 durableTraceId: String)
}
package struct InputMaterializationCommand: Sendable, Equatable {
    package let ingestionId: String
    package let edited: InputReviewEditDraft
    package let includeMissionDraft: Bool
    package init(ingestionId: String, edited: InputReviewEditDraft,
                 includeMissionDraft: Bool)
}
package struct InputMissionDraftSnapshot: Sendable {
    package let draft: CodingRanchMissionDraft
    package let sourceNote: CampNoteRecord
    package let baseCow: CompanionRecord?
    package let startCapability: InputMissionDraftStartCapability?
    package init(draft: CodingRanchMissionDraft, sourceNote: CampNoteRecord,
                 baseCow: CompanionRecord?,
                 startCapability: InputMissionDraftStartCapability?)
}
package struct InputMissionDraftStartCapability: Sendable, Equatable {
    let draft: CodingRanchMissionDraft
    let companionId: String
    init(draft: CodingRanchMissionDraft, companionId: String)
    package func makeMissionStartRequest(
        goal: String, workspacePath: String?, plannerModel: String,
        runtimeProfileId: String, budgetTokens: Int,
        autonomy: MissionAutonomy, idempotencyKey: String,
        durableTraceId: String
    ) -> MissionStartRequest
}
package struct InputMaterializationReceipt: Sendable {
    package let materialization: RuminationMaterialization
    package let missionDraft: InputMissionDraftSnapshot?
    package init(materialization: RuminationMaterialization,
                 missionDraft: InputMissionDraftSnapshot?)
}
package struct ChatHistorySnapshot: Sendable {
    package let thread: ChatThreadRecord
    package let messages: [ChatMessageProjection]
    package init(thread: ChatThreadRecord,
                 messages: [ChatMessageProjection])
}
package struct CampNavigationResolution: Sendable, Equatable {
    package let campId: String
    package let usedPreferredCamp: Bool
    package init(campId: String, usedPreferredCamp: Bool)
}
package struct InputNoteDeletionReceipt: Sendable, Equatable {
    package let noteId: String
    package let ownerId: String
    package init(noteId: String, ownerId: String)
}
package struct InputWorkflowPorts: Sendable {
    package let submitFeed:
        @Sendable (FeedSubmissionCommand) throws -> FeedSubmission
    package let ruminationRuntime:
        @Sendable () throws -> InputRuminationRuntimeSelection
    package let startRumination:
        @Sendable (InputRuminationStartCommand) async throws
            -> DurableWorkRecord
    package let cancelRumination:
        @Sendable (String) async throws -> Void
    package let saveReview:
        @Sendable (String, RuminationResult) throws -> Void
    package let materialize:
        @Sendable (String, RuminationResult) throws
            -> RuminationMaterialization
    package let delete:
        @Sendable (String, InputDeletionScope) throws
            -> InputDeletionReceipt
    package let missionDraft:
        @Sendable (String) throws -> InputMissionDraftSnapshot
    package let unlockTestCow: @Sendable (String) throws -> CompanionRecord
    package let ensureDefaultCamp:
        @Sendable () throws -> DefaultCampResolutionReceipt
    package let createCamp:
        @Sendable (String, String?) throws -> CampRecord
    package let renameCamp: @Sendable (String, String) throws -> Void
    package let setCampArchived: @Sendable (String, Bool) throws -> Void
    package let campWritable: @Sendable (String) throws -> Bool
    package let campNotes: @Sendable (String) throws -> [CampNoteRecord]
    package let saveCampNote: @Sendable (CampNoteRecord) throws -> Void
    package let deleteCampNote:
        @Sendable (String) throws -> InputNoteDeletionReceipt
    package let companionNotes:
        @Sendable (String) throws -> [CompanionNoteRecord]
    package let saveCompanionNote:
        @Sendable (CompanionNoteRecord) throws -> Void
    package let deleteCompanionNote:
        @Sendable (String, String) throws -> InputNoteDeletionReceipt
    package let chatHistory:
        @Sendable (String) throws -> ChatHistorySnapshot
    package let guideHistory:
        @Sendable (String) throws -> ChatHistorySnapshot
    package let chatStream:
        @Sendable (String, String, String) throws
            -> AsyncThrowingStream<ProviderEvent, Error>
    package let guideStream:
        @Sendable (String, String, String) throws
            -> AsyncThrowingStream<GuideChatEvent, Error>
    package let resolveCampNavigation:
        @Sendable (String, String?) throws -> CampNavigationResolution
    package init(
        submitFeed: @escaping @Sendable (FeedSubmissionCommand) throws
            -> FeedSubmission,
        ruminationRuntime: @escaping @Sendable () throws
            -> InputRuminationRuntimeSelection,
        startRumination: @escaping @Sendable (InputRuminationStartCommand)
            async throws -> DurableWorkRecord,
        cancelRumination: @escaping @Sendable (String) async throws -> Void,
        saveReview: @escaping @Sendable (String, RuminationResult) throws -> Void,
        materialize: @escaping @Sendable (String, RuminationResult) throws
            -> RuminationMaterialization,
        delete: @escaping @Sendable (String, InputDeletionScope) throws
            -> InputDeletionReceipt,
        missionDraft: @escaping @Sendable (String) throws
            -> InputMissionDraftSnapshot,
        unlockTestCow: @escaping @Sendable (String) throws -> CompanionRecord,
        ensureDefaultCamp:
            @escaping @Sendable () throws -> DefaultCampResolutionReceipt,
        createCamp: @escaping @Sendable (String, String?) throws -> CampRecord,
        renameCamp: @escaping @Sendable (String, String) throws -> Void,
        setCampArchived: @escaping @Sendable (String, Bool) throws -> Void,
        campWritable: @escaping @Sendable (String) throws -> Bool,
        campNotes: @escaping @Sendable (String) throws -> [CampNoteRecord],
        saveCampNote: @escaping @Sendable (CampNoteRecord) throws -> Void,
        deleteCampNote: @escaping @Sendable (String) throws
            -> InputNoteDeletionReceipt,
        companionNotes:
            @escaping @Sendable (String) throws -> [CompanionNoteRecord],
        saveCompanionNote:
            @escaping @Sendable (CompanionNoteRecord) throws -> Void,
        deleteCompanionNote: @escaping @Sendable (String, String) throws
            -> InputNoteDeletionReceipt,
        chatHistory: @escaping @Sendable (String) throws -> ChatHistorySnapshot,
        guideHistory: @escaping @Sendable (String) throws -> ChatHistorySnapshot,
        chatStream: @escaping @Sendable (String, String, String) throws
            -> AsyncThrowingStream<ProviderEvent, Error>,
        guideStream: @escaping @Sendable (String, String, String) throws
            -> AsyncThrowingStream<GuideChatEvent, Error>,
        resolveCampNavigation:
            @escaping @Sendable (String, String?) throws
                -> CampNavigationResolution
    )
    package static func live(database: AppDatabase,
                             orchestrator: Orchestrator,
                             resolver: RuntimeCredentialResolver,
                             defaults: ProfileScopedDefaults) -> Self
}
package enum MemoryKnowledgeOwner: Hashable, Sendable, Equatable {
    case companion(String)
    case guide(String)
}
package struct MemoryKnowledgeRefreshRequest: Sendable, Equatable {
    package let owner: MemoryKnowledgeOwner
    fileprivate let attempt: UUID
    fileprivate init(owner: MemoryKnowledgeOwner, attempt: UUID)
}
fileprivate enum MemoryDistillationCommittedRecord: Sendable {
    case companion(CompanionNoteRecord)
    case guide(CampNoteRecord)
}
package struct MemoryDistillationVisibilityCard: Identifiable, Sendable {
    package let id: UUID
    package let failure: UserVisibleFailure
    package var ownerKind: MemoryDistillOwnerKind { get }
    package var committedRecordCount: Int { committedRecordIds.count }
    package var committedRecordIds: [String] { get }
    fileprivate let owner: MemoryKnowledgeOwner
    fileprivate let committedRecords: [MemoryDistillationCommittedRecord]
    fileprivate init(id: UUID, failure: UserVisibleFailure,
                     owner: MemoryKnowledgeOwner,
                     committedRecords: [MemoryDistillationCommittedRecord])
}
@MainActor
package struct MemoryKnowledgeProjectionCoordinator {
    package private(set) var visibilityCards:
        [MemoryDistillationVisibilityCard] = []
    package var visibleMemoryNotes: [CompanionNoteRecord] { get }
    package var visibleCampNotes: [CampNoteRecord] { get }
    package var visibleMemoryState:
        WorkflowLoadState<[CompanionNoteRecord]> { get }
    package var visibleCampState: WorkflowLoadState<[CampNoteRecord]> { get }
    package init()
    package mutating func selectCompanion(
        _ companionId: String
    ) -> MemoryKnowledgeRefreshRequest
    package mutating func selectGuide(
        _ campId: String
    ) -> MemoryKnowledgeRefreshRequest
    package mutating func beginCompanionRefresh(
        companionId: String
    ) -> MemoryKnowledgeRefreshRequest
    package mutating func beginGuideRefresh(
        campId: String
    ) -> MemoryKnowledgeRefreshRequest
    package mutating func beginCommittedRefresh(
        _ record: CompanionNoteRecord
    ) -> MemoryKnowledgeRefreshRequest
    package mutating func beginCommittedRefresh(
        _ record: CampNoteRecord
    ) -> MemoryKnowledgeRefreshRequest
    package mutating func beginVisibilityRetry(
        cardId: UUID
    ) -> MemoryKnowledgeRefreshRequest?
    @discardableResult
    package mutating func apply(
        _ terminal: WorkflowReadTerminal<[CompanionNoteRecord]>,
        for request: MemoryKnowledgeRefreshRequest
    ) -> Bool
    @discardableResult
    package mutating func apply(
        _ terminal: WorkflowReadTerminal<[CampNoteRecord]>,
        for request: MemoryKnowledgeRefreshRequest
    ) -> Bool
}
package actor InputWorkflowController {
    package init(database: AppDatabase, orchestrator: Orchestrator,
                 resolver: RuntimeCredentialResolver,
                 reporter: FailureReporter, reads: InputWorkflowReads? = nil,
                 ports: InputWorkflowPorts? = nil)
    package func loadCamp(campId: String, trace: OperationTrace) async
        -> WorkflowLoadState<InputCampSnapshot>
    package func ensureDefaultCamp(trace: OperationTrace) async
        -> OperationCommitOutcome<DefaultCampResolutionReceipt>
    package func loadReview(ingestionId: String, trace: OperationTrace) async
        -> WorkflowLoadState<InputReviewSnapshot>
    package func submit(_ command: FeedSubmissionCommand, trace: OperationTrace) async
        -> OperationCommitOutcome<FeedSubmission>
    package func startRumination(ingestionId: String, expectedCampId: String,
                         model: String, runtimeProfileId: String,
                         trace: OperationTrace) async
        -> OperationCommitOutcome<DurableWorkRecord>
    package func cancelRumination(ingestionId: String, trace: OperationTrace) async
        -> OperationCommitOutcome<Void>
    package func saveReview(_ command: InputReviewSaveCommand,
                    trace: OperationTrace) async
        -> OperationCommitOutcome<Void>
    package func materialize(_ command: InputMaterializationCommand,
                             trace: OperationTrace) async
        -> OperationCommitOutcome<InputMaterializationReceipt>
    package func delete(ingestionId: String, scope: InputDeletionScope,
                        trace: OperationTrace) async
        -> OperationCommitOutcome<InputDeletionReceipt>
    package func createMissionDraft(ingestionId: String,
                                    trace: OperationTrace) async
        -> OperationCommitOutcome<InputMissionDraftSnapshot>
    package func unlockTestCow(campId: String, trace: OperationTrace) async
        -> OperationCommitOutcome<CompanionRecord>
    package func createCamp(name: String, guidePrompt: String?,
                            trace: OperationTrace) async
        -> OperationCommitOutcome<CampRecord>
    package func renameCamp(id: String, name: String,
                            trace: OperationTrace) async
        -> OperationCommitOutcome<Void>
    package func setCampArchived(id: String, archived: Bool,
                                 trace: OperationTrace) async
        -> OperationCommitOutcome<Void>
    package func campWritable(id: String, trace: OperationTrace) async
        -> WorkflowLoadState<Bool>
    package func loadCampNotes(campId: String, trace: OperationTrace) async
        -> WorkflowReadTerminal<[CampNoteRecord]>
    package func saveCampNote(_ note: CampNoteRecord,
                              trace: OperationTrace) async
        -> OperationCommitOutcome<CampNoteRecord>
    package func deleteCampNote(id: String, trace: OperationTrace) async
        -> OperationCommitOutcome<InputNoteDeletionReceipt>
    package func pinCampNote(_ note: CampNoteRecord,
                             trace: OperationTrace) async
        -> OperationCommitOutcome<CampNoteRecord>
    package func loadMemoryNotes(companionId: String,
                                 trace: OperationTrace) async
        -> WorkflowReadTerminal<[CompanionNoteRecord]>
    package func saveMemoryNote(_ note: CompanionNoteRecord,
                                trace: OperationTrace) async
        -> OperationCommitOutcome<CompanionNoteRecord>
    package func deleteMemoryNote(id: String, companionId: String,
                                  trace: OperationTrace) async
        -> OperationCommitOutcome<InputNoteDeletionReceipt>
    package func pinMemoryNote(_ note: CompanionNoteRecord,
                               trace: OperationTrace) async
        -> OperationCommitOutcome<CompanionNoteRecord>
    package func loadChat(companionId: String, trace: OperationTrace) async
        -> WorkflowLoadState<ChatHistorySnapshot>
    package func sendChat(
        companionId: String, text: String, model: String,
        onEvent: @escaping @MainActor @Sendable (ProviderEvent) -> Void,
        isOwnedCancellation: @escaping @Sendable () -> Bool,
        trace: OperationTrace
    ) async -> WorkflowStreamTerminal
    package func loadGuideChat(campId: String, trace: OperationTrace) async
        -> WorkflowLoadState<ChatHistorySnapshot>
    package func sendGuideChat(
        campId: String, text: String, model: String,
        onEvent: @escaping @MainActor @Sendable (GuideChatEvent) -> Void,
        isOwnedCancellation: @escaping @Sendable () -> Bool,
        trace: OperationTrace
    ) async -> WorkflowStreamTerminal
    package func resolveCampNavigation(missionId: String,
                                       preferredCampId: String?,
                                       trace: OperationTrace) async
        -> WorkflowLoadState<CampNavigationResolution>
}
```

`MemoryKnowledgeProjectionCoordinator` and its file-private
`MemoryDistillationCommittedRecord`/per-owner projection storage are colocated
with `InputWorkflowController.swift`; App never recreates that reducer. Each
owner keeps an independent last-loaded value, closed load state, current UUID
attempt, pending committed-record list, and optional stable card ID. Selecting
companion B first changes the visible owner and returns B's request; until B
loads, `visibleMemoryNotes` is `[]` with B's `.loading` state, never companion
A's cached list. A B failure becomes B's `.failed` state and preserves only a
previous B value. Camp/guide behaves identically. Thus preservation is
owner-local, not a global-array fallback.

With no selected companion/guide, the matching visible list is `[]` and state
is `.idle`. `selectCompanion`/`selectGuide` alone changes the visible owner and
then begins that owner's refresh. The `begin...Refresh`, committed-refresh, and
card-retry methods never change visible owner; they may refresh a nonvisible
owner without exposing it. Loading retains and renders only the same owner's
prior loaded value when one exists, otherwise `[]`. Visibility cards append on
their first exact failed terminal in terminal-arrival order and update in place
thereafter, so dictionary iteration is never UI/test ordering authority.

Every begin method installs a fresh attempt synchronously and returns its
opaque request. A committed refresh upserts the exact returned record by ID,
without reconstructing it, into that owner's pending list in service-terminal
arrival order before returning the request. `beginVisibilityRetry` returns nil
for an absent/stale card before trace creation; an exact card preserves its ID,
pending records, and current projection while installing a new attempt. Each
`apply` first compares exact owner+attempt; stale terminals are zero mutation.
The companion overload additionally requires `.companion` and the guide
overload `.guide`; a terminal/request kind mismatch returns `false` with zero
mutation rather than coercing one record type into the other.
An exact `.loaded` terminal replaces only that owner's cache/state and clears
its pending records/card. An exact `.failed` terminal preserves only that
owner's last-loaded value and creates or updates one stable card iff pending
committed records exist; otherwise the owner projection itself carries the
ordinary read failure. Card count/ID order are computed from the private exact
records and are not separately mutable. There is no fallible edge, Task, DB
port, Reporter, or callback after a closed terminal reaches `apply`.

The two note-load controller methods are the sole database owners. They call
their exact `InputWorkflowPorts` read through existing
`captureAsyncOperation`, returning only `.loaded(value)` or
`.failed(failure)`; this adds no catch. AppStore begins a coordinator request,
mints the request's fresh load trace, calls exactly one matching controller
method in one Task, then feeds its terminal back to the coordinator. It never
calls `AppDatabase.companionNotes`/`campNotes` or
`captureSynchronousLoad` for these projections. The same path owns initial
screen load, ordinary CRUD refresh, committed-distillation refresh, and card
retry. Cancellation is only an optimization; an already returned terminal is
always conditionally applied before the Task releases its strong bounded
AppStore reference.

`FeedSubmissionCommand` is the Core-safe persisted feed fields currently
consumed by the Adapter: Camp ID, source type, raw text, optional title/source
URL/author/user intent, duplicate policy, and start-rumination flag. It never
contains an App view type. The closed App `IngestionDeletionScope` is mapped
exhaustively to `InputDeletionScope`; there is no default branch. Materialize,
delete, mission-draft, Camp/note/memory, and chat decisions all cross the exact
ports above, so the App cannot perform a second fallible DB/provider decision.
The additional Camp snapshot fields
own Adapter's materialized-link, artifact-count, mission/note, companion, and
newcomer-progress reads; the App does not perform a second fallible read after
receiving a loaded Input snapshot. A committed Feed followed by failed
auto-rumination is committed-with-visibility-failure and retry starts only the
rumination work.

`InputWorkflowPorts.live` verifies delete row counts, active-work counts,
materialization links, mission-draft source notes, Camp ownership, and note
delete results instead of accepting nil/zero/false. `createMissionDraft`
requires a real source note; it never fabricates `来源笔记`. Navigation uses the
preferred Camp only when it exists and owns the Mission; otherwise the exact
Mission-owned Camp is returned or a typed not-found/invariant error is raised—
never the first Camp or empty string.

Before either `saveReview` or `materialize` reaches a port, the controller
strictly converts `InputReviewEditDraft` to `RuminationResult` once. Every
accepted key point requires at least one nonblank evidence quote and uses that
exact quote; every accepted requirement requires a finite confidence in
`0...1`, mapped by the existing high/medium/low thresholds. Missing/blank
evidence, missing/nonfinite/out-of-range confidence, or an unknown kind throws
`InputReviewDraftError` and performs zero save/materialization/mission-draft
write. The App mapping from `RuminationReviewViewState` is an exhaustive pure
field copy into the package DTO; it never fabricates `"用户确认"`, `0.5`, or a
replacement provenance label. `saveReview` and `materialize` share this one
converter and one result value, so a direct materialize cannot bypass the
save-time integrity rule.

Stream methods resolve the provider once,
then route the actual Core stream through `captureAsyncStream`; event closures
only project typed deltas. A current user cancellation returns `.cancelled`,
while any transport/provider/database failure returns `.failed` with the same
trace and preserves the previously loaded history.

The retained App façade changes to the exact asynchronous declaration
`func camp(forMission missionId: String) async -> String?`. It creates the
closed navigation trace and awaits
`InputWorkflowController.resolveCampNavigation(missionId:preferredCampId:trace:)`;
it returns an ID only from `.loaded`, records the typed failure otherwise, and
never substitutes `camps.first`. Both RootView call sites run that await in
their existing action `Task` before navigation, while
`CodingRanchStoreAdapter.loadReturnSummary` awaits the same façade. Thus every
caller of the signature change is already inside the 64-path allowlist and the
`N[.rootMissionCampFallback]` / `R[.campForMission]` delegate remains one real
async edge rather than a synchronous wrapper over an actor.

Materialization and mission-draft loading are deliberately two port calls.
After `materialize` returns its durable receipt, that receipt is the commit
point. If `includeMissionDraft` is false the controller returns it directly; if
true it then calls `missionDraft`. A draft lookup/decode/source-note failure
returns `.committedWithVisibilityFailure` containing the exact materialization
receipt and nil draft, so retry can load/create only the draft and can never
repeat materialization. A failure before the first receipt is
`.notCommitted`.

```swift
package struct RuntimeCredentialPresence: Sendable, Equatable {
    package let apiKeyPresent: Bool
    package let searchKeyPresent: Bool
    package let oauthAccessTokenPresent: Bool
    package let chatGPTAccountIdPresent: Bool
    package init(apiKeyPresent: Bool, searchKeyPresent: Bool,
                 oauthAccessTokenPresent: Bool, chatGPTAccountIdPresent: Bool)
}
package struct RuntimeWorkflowSnapshot: Sendable {
    package let profiles: [RuntimeProfileRecord]
    package let defaultProfile: RuntimeProfileRecord
    package let companions: [CompanionRecord]
    package let camps: [CampRecord]
    package let credentials: RuntimeCredentialPresence
    package let legacyRuminationSnapshot: LegacyRuminationStartupSnapshot
    package init(profiles: [RuntimeProfileRecord], defaultProfile: RuntimeProfileRecord,
                 companions: [CompanionRecord], camps: [CampRecord],
                 credentials: RuntimeCredentialPresence,
                 legacyRuminationSnapshot: LegacyRuminationStartupSnapshot)
}
package struct RuntimeProfileSwitchCommand: Sendable {
    package let profileId: String
    package let inheritCompanionIds: Set<String>
    package let resetSettingScopes: Set<String>
    package init(profileId: String, inheritCompanionIds: Set<String>,
                 resetSettingScopes: Set<String>)
}
package enum RuntimeCredentialSlot: Sendable, Equatable {
    case apiKey
    case searchKey
}
package struct RuntimeCredentialSetReceipt: Sendable, Equatable {
    package let slot: RuntimeCredentialSlot
    package let attachedProfileId: String?
    fileprivate let trace: OperationTrace
    fileprivate init(slot: RuntimeCredentialSlot, attachedProfileId: String?,
                     trace: OperationTrace)
}
fileprivate enum RuntimeCredentialAttachmentRecoveryStep: Sendable, Equatable {
    case resolveDefault
    case attach(RuntimeCredentialAttachmentTarget)
}
package struct RuntimeCredentialAttachmentPending: Sendable, Equatable {
    package let slot: RuntimeCredentialSlot
    fileprivate let committed: RuntimeCredentialSetReceipt
    fileprivate let step: RuntimeCredentialAttachmentRecoveryStep
    fileprivate init(committed: RuntimeCredentialSetReceipt,
                     step: RuntimeCredentialAttachmentRecoveryStep)
}
package enum RuntimeCredentialSetOutcome: Sendable {
    case notCommitted(UserVisibleFailure)
    case committed(RuntimeCredentialSetReceipt)
    case attachmentPending(RuntimeCredentialAttachmentPending,
                           failure: UserVisibleFailure)
    case committedWithVisibilityFailure(
        receipt: RuntimeCredentialSetReceipt,
        failure: UserVisibleFailure
    )
}
package enum RuntimeCredentialAttachmentRecoveryOutcome: Sendable {
    case recovered(RuntimeCredentialSetReceipt)
    case pending(RuntimeCredentialAttachmentPending,
                 failure: UserVisibleFailure)
    case recoveredWithVisibilityFailure(
        receipt: RuntimeCredentialSetReceipt,
        failure: UserVisibleFailure
    )
    case superseded
}
package struct RuntimeWorkflowReads: Sendable {
    package let load: @Sendable () throws -> RuntimeWorkflowReadBundle
    package init(load: @escaping @Sendable () throws -> RuntimeWorkflowReadBundle)
    package static func live(database: AppDatabase) -> Self
}
package struct RuntimeCredentialPresencePort: Sendable {
    package let load:
        @Sendable (KeychainInteractionPolicy) throws
            -> RuntimeCredentialPresence
    package init(load:
        @escaping @Sendable (KeychainInteractionPolicy) throws
            -> RuntimeCredentialPresence)
    package static func live(resolver: RuntimeCredentialResolver) -> Self
#if DEBUG
    package static func preview(
        _ presence: RuntimeCredentialPresence
    ) -> Self
#endif
}
package struct RuntimeBootstrapRequest: Sendable {
    package let apiFormat: ProviderAPIFormat
    package let apiBaseURL: String
    package let preferredSource: ProviderCredentialSource
    package let fallbackModelChoices: [String]
    package let interactionPolicy: KeychainInteractionPolicy
    package init(apiFormat: ProviderAPIFormat, apiBaseURL: String,
                 preferredSource: ProviderCredentialSource,
                 fallbackModelChoices: [String],
                 interactionPolicy: KeychainInteractionPolicy)
}
package struct SynchronousRuntimeBootstrap: Sendable {
    package init(database: AppDatabase, defaults: ProfileScopedDefaults,
                 resolver: RuntimeCredentialResolver, reporter: FailureReporter,
                 presence: RuntimeCredentialPresencePort,
                 reads: RuntimeWorkflowReads? = nil)
    package func run(_ request: RuntimeBootstrapRequest,
                     trace: OperationTrace) throws -> RuntimeWorkflowSnapshot
}
package struct RuntimeCatalogRefreshReceipt: Sendable, Equatable {
    package let profileId: String
    package let models: [String]
    package init(profileId: String, models: [String])
}
package struct RuntimeProviderTestReceipt: Sendable, Equatable {
    package let model: String
    package init(model: String)
}
package struct RuntimeOAuthConfiguration: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    package let authorizationEndpoint: URL
    package let tokenEndpoint: URL
    package let redirectURI: String
    package let clientID: String
    package let requiresAccountID: Bool
    package let requiresLocalListener: Bool
    package init(flow: OAuthCredentialFlow, authorizationEndpoint: URL,
                 tokenEndpoint: URL, redirectURI: String, clientID: String,
                 requiresAccountID: Bool, requiresLocalListener: Bool)
}
package struct RuntimeOAuthAuthorizationCommand: Sendable, Equatable {
    package let configuration: RuntimeOAuthConfiguration
    package init(configuration: RuntimeOAuthConfiguration)
}
fileprivate struct OAuthAuthorizationURL: Sendable, Equatable {
    let raw: URL
    init(_ raw: URL)
}
package struct RuntimeOAuthAuthorizationReceipt: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    fileprivate let configuration: RuntimeOAuthConfiguration
    fileprivate let url: OAuthAuthorizationURL
    fileprivate let expectedState: SecretValue
    fileprivate let trace: OperationTrace
    fileprivate let requiresLocalListener: Bool
    fileprivate init(configuration: RuntimeOAuthConfiguration,
                     url: OAuthAuthorizationURL,
                     expectedState: SecretValue,
                     trace: OperationTrace,
                     requiresLocalListener: Bool)
    package func withAuthorizationURL<T>(
        _ body: (URL) throws -> T
    ) rethrows -> T
}
package struct RuntimeOAuthListenerLease: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    fileprivate let reservationId: UUID
    fileprivate let leaseId: UUID
    fileprivate init(flow: OAuthCredentialFlow, reservationId: UUID,
                     leaseId: UUID)
    package func belongs(
        to reservation: RuntimeOAuthAuthorizationReservation
    ) -> Bool
}
fileprivate enum RuntimeOAuthAuthorizationRecoveryStage:
    Sendable, Equatable {
    case listenerRestart
    case browserReopen
    case listenerThenBrowser
}
package struct RuntimeOAuthAuthorizationRecoveryPending:
    Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    fileprivate let authorization: RuntimeOAuthAuthorizationReceipt
    fileprivate let stage: RuntimeOAuthAuthorizationRecoveryStage
    fileprivate let listenerLease: RuntimeOAuthListenerLease?
    fileprivate init(authorization: RuntimeOAuthAuthorizationReceipt,
                     stage: RuntimeOAuthAuthorizationRecoveryStage,
                     listenerLease: RuntimeOAuthListenerLease?)
    package func ownsAuthorization(
        _ receipt: RuntimeOAuthAuthorizationReceipt
    ) -> Bool
    package func sameAuthorization(
        as other: RuntimeOAuthAuthorizationRecoveryPending
    ) -> Bool
    package func ownsListenerLease(
        _ lease: RuntimeOAuthListenerLease
    ) -> Bool
}
package enum RuntimeOAuthAuthorizationOutcome: Sendable {
    case notCommitted(UserVisibleFailure)
    case prepared(RuntimeOAuthAuthorizationReceipt)
    case recoveryPending(RuntimeOAuthAuthorizationRecoveryPending,
                         failure: UserVisibleFailure)
    case superseded
}
package struct RuntimeOAuthAuthorizationOpenCommand: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    fileprivate let authorization: RuntimeOAuthAuthorizationReceipt
    fileprivate let reservation: RuntimeOAuthAuthorizationReservation
    package static func prepared(
        _ authorization: RuntimeOAuthAuthorizationReceipt,
        reservation: RuntimeOAuthAuthorizationReservation
    ) -> Self
}
package enum RuntimeOAuthAuthorizationOpenOutcome: Sendable {
    case opened(RuntimeOAuthAuthorizationReceipt)
    case retainedRecovery(RuntimeOAuthAuthorizationRecoveryPending)
    case recoveryPending(
        RuntimeOAuthAuthorizationRecoveryPending,
        failure: UserVisibleFailure
    )
    case superseded
}
package struct RuntimeOAuthAuthorizationReservation: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    fileprivate let reservationId: UUID
    fileprivate let trace: OperationTrace
    fileprivate init(flow: OAuthCredentialFlow, reservationId: UUID,
                     trace: OperationTrace)
}
package enum RuntimeOAuthAuthorizationReservationOutcome: Sendable {
    case reserved(RuntimeOAuthAuthorizationReservation)
    case rejected(UserVisibleFailure)
}
package enum RuntimeOAuthAuthorizationRejectionOutcome: Sendable {
    case rejected(UserVisibleFailure)
    case superseded
}
package enum RuntimeOAuthAuthorizationRecoveryOutcome: Sendable {
    case ready(RuntimeOAuthAuthorizationReceipt)
    case pending(RuntimeOAuthAuthorizationRecoveryPending,
                 failure: UserVisibleFailure)
    case deferredToCallback(failure: UserVisibleFailure)
    case deferredToPreparation(failure: UserVisibleFailure)
    case superseded
}
package enum RuntimeOAuthCallbackIngress: Sendable, Equatable {
    case localListener
    case customScheme
}
fileprivate enum RuntimeOAuthCallbackIngressSource: Sendable, Equatable {
    case localListener(RuntimeOAuthListenerLease)
    case customScheme
}
package struct RuntimeOAuthCustomSchemeCallbackCommand:
    Sendable, Equatable {
    package let callbackURL: URL
    package init(callbackURL: URL)
}
package struct RuntimeOAuthCallbackCommand: Sendable, Equatable {
    fileprivate enum Owner: Sendable, Equatable {
        case authorization(RuntimeOAuthAuthorizationReceipt)
        case recovery(RuntimeOAuthAuthorizationRecoveryPending)
    }
    fileprivate let owner: Owner
    fileprivate let reservation: RuntimeOAuthAuthorizationReservation
    fileprivate let listenerLease: RuntimeOAuthListenerLease
    package let callbackURL: URL
    fileprivate init(owner: Owner,
                     reservation: RuntimeOAuthAuthorizationReservation,
                     listenerLease: RuntimeOAuthListenerLease,
                     callbackURL: URL)
    package static func authorization(
        _ authorization: RuntimeOAuthAuthorizationReceipt,
        reservation: RuntimeOAuthAuthorizationReservation,
        listenerLease: RuntimeOAuthListenerLease,
        callbackURL: URL
    ) -> Self
    package static func recovery(
        _ pending: RuntimeOAuthAuthorizationRecoveryPending,
        reservation: RuntimeOAuthAuthorizationReservation,
        listenerLease: RuntimeOAuthListenerLease,
        callbackURL: URL
    ) -> Self
}
package enum RuntimeOAuthCallbackClaimOrigin: Sendable, Equatable {
    case ready(RuntimeOAuthAuthorizationReceipt)
    case authorizationRecovery(RuntimeOAuthAuthorizationRecoveryPending)
}
package struct RuntimeOAuthCallbackClaim: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    package let origin: RuntimeOAuthCallbackClaimOrigin
    fileprivate let claimId: UUID
    fileprivate let reservation: RuntimeOAuthAuthorizationReservation
    fileprivate let authorization: RuntimeOAuthAuthorizationReceipt
    fileprivate let ingressSource: RuntimeOAuthCallbackIngressSource
    fileprivate init(
        flow: OAuthCredentialFlow,
        origin: RuntimeOAuthCallbackClaimOrigin,
        claimId: UUID,
        reservation: RuntimeOAuthAuthorizationReservation,
        authorization: RuntimeOAuthAuthorizationReceipt,
        ingressSource: RuntimeOAuthCallbackIngressSource
    )
    package var ingress: RuntimeOAuthCallbackIngress { get }
    package func belongs(
        to reservation: RuntimeOAuthAuthorizationReservation
    ) -> Bool
    package func ownsAuthorization(
        _ authorization: RuntimeOAuthAuthorizationReceipt
    ) -> Bool
    package func ownsListenerLease(
        _ lease: RuntimeOAuthListenerLease
    ) -> Bool
}
package enum RuntimeOAuthCallbackClaimOutcome: Sendable {
    case claimed(RuntimeOAuthCallbackClaim)
    case currentAuthorizationRejected
    case superseded
}
package enum RuntimeOAuthCustomSchemeCallbackClaimOutcome: Sendable {
    case claimed(RuntimeOAuthCallbackClaim)
    case superseded
}
package enum RuntimeOAuthCallbackAbandonOutcome: Sendable {
    case ready(RuntimeOAuthAuthorizationReceipt)
    case authorizationRecovery(RuntimeOAuthAuthorizationRecoveryPending)
    case superseded(RuntimeOAuthCallbackSupersedingOwner)
}
package enum RuntimeOAuthCallbackPayload: Sendable, Equatable {
    case authorizationCode(code: SecretValue, returnedState: SecretValue)
    case credentialBundle(OAuthCredentialBundle,
                          returnedState: SecretValue)
}
package struct RuntimeOAuthCallbackCommitReceipt: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    fileprivate let authorization: RuntimeOAuthAuthorizationReceipt
    fileprivate let callbackTrace: OperationTrace
    fileprivate init(authorization: RuntimeOAuthAuthorizationReceipt,
                     callbackTrace: OperationTrace)
}
package enum RuntimeOAuthCallbackOutcome: Sendable {
    case notCommitted(UserVisibleFailure)
    case authorizationRecoveryPending(
        RuntimeOAuthAuthorizationRecoveryPending,
        failure: UserVisibleFailure
    )
    case committed(RuntimeOAuthCallbackCommitReceipt)
    case committedWithVisibilityFailure(
        receipt: RuntimeOAuthCallbackCommitReceipt,
        failure: UserVisibleFailure
    )
    case superseded(RuntimeOAuthCallbackSupersedingOwner)
}
package enum RuntimeOAuthCallbackSupersedingOwner: Sendable, Equatable {
    case none
    case transientAuthorizationOwner
    case ready(
        reservation: RuntimeOAuthAuthorizationReservation,
        authorization: RuntimeOAuthAuthorizationReceipt
    )
    case authorizationRecovery(
        reservation: RuntimeOAuthAuthorizationReservation,
        pending: RuntimeOAuthAuthorizationRecoveryPending
    )
}
package actor RuntimeOAuthListenerFailureSink {
    private weak var controller: RuntimeProfileWorkflowController?
    fileprivate init(controller: RuntimeProfileWorkflowController)
    package func handle(
        _ failure: RuntimeOAuthListenerFailure,
        authorization: RuntimeOAuthAuthorizationReceipt,
        lease: RuntimeOAuthListenerLease
    ) async -> RuntimeOAuthAuthorizationRecoveryOutcome
}
package enum RuntimeOAuthListenerStartOutcome: Sendable, Equatable {
    case started
    case ownerShuttingDown
}
package enum RuntimeOAuthListenerStopOutcome: Sendable, Equatable {
    case stopped
    case ownerShuttingDown
}
package struct RuntimeOAuthPlatformPort: Sendable {
    package let startListener:
        @MainActor @Sendable (
            RuntimeOAuthAuthorizationReceipt,
            RuntimeOAuthListenerLease
        )
            async throws -> RuntimeOAuthListenerStartOutcome
    package let stopListenerIfOwned:
        @MainActor @Sendable (
            RuntimeOAuthAuthorizationReceipt,
            RuntimeOAuthListenerLease
        ) async -> RuntimeOAuthListenerStopOutcome
    package let openAuthorization:
        @MainActor @Sendable (RuntimeOAuthAuthorizationReceipt) throws -> Void
    package init(
        startListener:
            @escaping @MainActor @Sendable
                (RuntimeOAuthAuthorizationReceipt,
                 RuntimeOAuthListenerLease)
                    async throws -> RuntimeOAuthListenerStartOutcome,
        stopListenerIfOwned:
            @escaping @MainActor @Sendable
                (RuntimeOAuthAuthorizationReceipt,
                 RuntimeOAuthListenerLease)
                    async -> RuntimeOAuthListenerStopOutcome,
        openAuthorization:
            @escaping @MainActor @Sendable
                (RuntimeOAuthAuthorizationReceipt) throws -> Void
    )
}
package struct RuntimeOAuthPlatformFactory: Sendable {
    package let make:
        @Sendable (RuntimeOAuthListenerFailureSink)
            -> RuntimeOAuthPlatformPort
    package init(
        make: @escaping @Sendable (RuntimeOAuthListenerFailureSink)
            -> RuntimeOAuthPlatformPort
    )
}
package struct RuntimeOAuthCodec: Sendable {
    package let randomSecret: @Sendable (Int) throws -> SecretValue
    package let authorizationURL:
        @Sendable (RuntimeOAuthConfiguration, SecretValue, SecretValue)
            throws -> URL
    package let callbackPayload:
        @Sendable (RuntimeOAuthConfiguration, URL) throws
            -> RuntimeOAuthCallbackPayload
    package let callbackStateMatches:
        @Sendable (RuntimeOAuthConfiguration, URL, SecretValue) -> Bool
    package let exchange:
        @Sendable (RuntimeOAuthConfiguration, SecretValue, SecretValue)
            async throws -> OAuthCredentialBundle
    package init(
        randomSecret: @escaping @Sendable (Int) throws -> SecretValue,
        authorizationURL:
            @escaping @Sendable
                (RuntimeOAuthConfiguration, SecretValue, SecretValue)
                throws -> URL,
        callbackPayload:
            @escaping @Sendable (RuntimeOAuthConfiguration, URL) throws
                -> RuntimeOAuthCallbackPayload,
        callbackStateMatches:
            @escaping @Sendable
                (RuntimeOAuthConfiguration, URL, SecretValue) -> Bool,
        exchange:
            @escaping @Sendable
                (RuntimeOAuthConfiguration, SecretValue, SecretValue)
                async throws -> OAuthCredentialBundle
    )
    package static let live: RuntimeOAuthCodec
}
package struct RuntimeWorkflowPorts: Sendable {
    package let refreshCatalog:
        @Sendable (String) async throws -> RuntimeCatalogRefreshReceipt
    package let testProvider:
        @Sendable (String, String?) async throws -> RuntimeProviderTestReceipt
    package let oauthPlatformFactory: RuntimeOAuthPlatformFactory
    package let oauthCodec: RuntimeOAuthCodec
    package init(
        refreshCatalog: @escaping @Sendable (String) async throws
            -> RuntimeCatalogRefreshReceipt,
        testProvider: @escaping @Sendable (String, String?) async throws
            -> RuntimeProviderTestReceipt,
        oauthPlatformFactory: RuntimeOAuthPlatformFactory,
        oauthCodec: RuntimeOAuthCodec
    )
    package static func live(
        database: AppDatabase,
        defaults: ProfileScopedDefaults,
        resolver: RuntimeCredentialResolver,
        coordinator: CredentialBundleCoordinator,
        credentialAccounts: RuntimeCredentialAccounts,
        oauthPlatformFactory: RuntimeOAuthPlatformFactory,
        oauthCodec: RuntimeOAuthCodec = .live
    ) -> Self
}
package actor RuntimeProfileWorkflowController {
    package init(database: AppDatabase, defaults: ProfileScopedDefaults,
                 resolver: RuntimeCredentialResolver,
                 credentialAccounts: RuntimeCredentialAccounts,
                 credentialCoordinator: CredentialBundleCoordinator,
                 reporter: FailureReporter, reads: RuntimeWorkflowReads? = nil,
                 ports: RuntimeWorkflowPorts,
                 traceFactory: OperationTraceFactory = .live)
    package func load(interactionPolicy: KeychainInteractionPolicy,
              trace: OperationTrace) async
        -> WorkflowLoadState<RuntimeWorkflowSnapshot>
    package func saveProfile(_ profile: RuntimeProfileRecord,
                     trace: OperationTrace) async
        -> OperationCommitOutcome<RuntimeProfileRecord>
    package func deleteProfile(id: String, trace: OperationTrace) async
        -> OperationCommitOutcome<Void>
    package func switchDefault(_ command: RuntimeProfileSwitchCommand,
                       trace: OperationTrace) async
        -> OperationCommitOutcome<RuntimeProfileRecord>
    package func setCredential(slot: RuntimeCredentialSlot, value: SecretValue,
                       trace: OperationTrace) async
        -> RuntimeCredentialSetOutcome
    package func retryCredentialAttachment(
        _ pending: RuntimeCredentialAttachmentPending
    ) async -> RuntimeCredentialAttachmentRecoveryOutcome
    package func deleteCredential(slot: RuntimeCredentialSlot,
                          trace: OperationTrace) async
        -> OperationCommitOutcome<Void>
    package func refreshCatalog(profileId: String,
                                trace: OperationTrace) async
        -> OperationCommitOutcome<RuntimeCatalogRefreshReceipt>
    package func testProvider(model: String, companionId: String?,
                              trace: OperationTrace) async
        -> OperationCommitOutcome<RuntimeProviderTestReceipt>
    package func reserveOAuthAuthorizationAttempt(
        flow: OAuthCredentialFlow,
        trace: OperationTrace
    ) async -> RuntimeOAuthAuthorizationReservationOutcome
    package func prepareOAuthAuthorization(
        _ command: RuntimeOAuthAuthorizationCommand,
        reservation: RuntimeOAuthAuthorizationReservation
    ) async -> RuntimeOAuthAuthorizationOutcome
    package func openOAuthAuthorization(
        _ command: RuntimeOAuthAuthorizationOpenCommand
    ) async -> RuntimeOAuthAuthorizationOpenOutcome
    package func rejectOAuthAuthorizationAttempt(
        _ reservation: RuntimeOAuthAuthorizationReservation,
        trace: OperationTrace
    ) async -> RuntimeOAuthAuthorizationRejectionOutcome
    package func handleOAuthListenerFailure(
        _ failure: RuntimeOAuthListenerFailure,
        authorization: RuntimeOAuthAuthorizationReceipt,
        lease: RuntimeOAuthListenerLease
    ) async -> RuntimeOAuthAuthorizationRecoveryOutcome
    package func retryOAuthAuthorization(
        _ pending: RuntimeOAuthAuthorizationRecoveryPending
    ) async -> RuntimeOAuthAuthorizationRecoveryOutcome
    package func claimOAuthCallback(
        _ command: RuntimeOAuthCallbackCommand,
        trace: OperationTrace
    ) async -> RuntimeOAuthCallbackClaimOutcome
    package func claimOAuthCustomSchemeCallback(
        _ command: RuntimeOAuthCustomSchemeCallbackCommand,
        trace: OperationTrace
    ) async -> RuntimeOAuthCustomSchemeCallbackClaimOutcome
    package func handleOAuthCallback(
        _ claim: RuntimeOAuthCallbackClaim
    ) async -> RuntimeOAuthCallbackOutcome
    package func abandonOAuthCallbackClaim(
        _ claim: RuntimeOAuthCallbackClaim
    ) async -> RuntimeOAuthCallbackAbandonOutcome
}
```

The platform factory plus the App-private `OAuthListenerPlatformOwner` are the
closed construction-cycle boundary. App composition constructs that owner and
its two streams first. It then constructs a `RuntimeOAuthPlatformFactory`
whose `@Sendable` closure captures only that owner and calls the owner's
`nonisolated makePort(failureSink:)`; the closure captures neither `AppStore`,
its controller property, nor any optional/late-bound controller cell.
Controller initialization stores the factory but no concrete port and no
optional/IUO controller reference. After all AppStore stored properties,
including the owner and controller, are initialized, App pre-extracts the two
`AsyncStream` values and synchronously installs one stream-value-plus-weak-self
recovery consumer Task and one stream-value-plus-weak-self callback consumer
Task before `AppStore.init()` returns. Neither consumer captures the owner. No
App initialization step starts, opens, or stops a listener.

On the actor, the first byte-equal reserved-to-preparing transition constructs
`RuntimeOAuthListenerFailureSink(controller:self)`, synchronously calls
`oauthPlatformFactory.make(sink)`, and stores that exact port before RNG,
receipt creation, or listener start. Later flows reuse the same port/sink; actor
serialization makes construction exactly once. The factory and owner method
may only construct the three `@MainActor` platform closures and cannot
start/open/stop anything while constructing them. Each physical listener
closure captures the already bound sink and the pre-existing owner. Its sole
failure Task calls `sink.handle(...)`, then yields the typed receipt+lease+
failure-attempt+outcome event; its connection path yields only the raw callback
URL plus the typed receipt+lease event. The sink delegates to the controller's
lease-validated handler. A sink whose weak controller has been deallocated may
return only `.superseded` and can exist only after the owning App/controller
lifecycle is gone; it never represents an unbound live composition.

Port closures held by the controller retain the platform owner intentionally;
all `NWListener` state/connection handlers and stored failure Tasks capture
only the exact typed continuations, already bound sink, receipt/lease, and
one-shot attempt—or capture the owner weakly for a MainActor slot join. No
slot/listener/Task closure strongly captures the owner, AppStore, or controller,
so owner → slot/listener/Task → owner and controller → port → sink → controller
cycles are impossible. App consumer Tasks capture AppStore weakly and their
pre-extracted stream value strongly, but never the owner. Because the
deployment floor is macOS 14, the plan does not use an availability-incompatible
`isolated deinit`, NSObject conversion, or selector relay. Instead, after both
consumers are installed, App calls
`oauthListenerPlatformOwner.installTerminationObserver(recoveryConsumer:
callbackConsumer:)` through one explicit typed Void binding. The owner registers
the existing `NSApplication.willTerminateNotification` block observer; the
block captures that owner weakly plus the two Sendable consumer Tasks, never
AppStore/controller. Main-queue delivery enters one typed
`MainActor.assumeIsolated` closure, then calls owner shutdown when still live,
cancels both consumers, and terminates the retained shell-process registry in
that order, using explicit Void bindings. There is no new guard/default/catch/
Result/bare call. The owner stores the returned observer token; its idempotent
shutdown nils/removes that exact token before finishing streams. Ordinary
nonisolated `deinit` copies only
the Sendable owner and two `Task` values into the exact typed
`Task<Void, Never> { @MainActor in ... }` fallback shown above; that Task
performs shutdown-then-cancel without capturing AppStore. The old block observer
is therefore replaced rather than duplicated, and no changed/new standalone-
call exclusion is needed.
The callback consumer may create one bounded transient strong AppStore local
after an event is dequeued. That local is never a Task capture and is released
after promotion/abandon/reject; cancellation cannot skip that closure. Therefore
the observer-held Task cannot retain AppStore/owner across the next stream wait,
and termination's synchronous owner shutdown plus consumer cancellation breaks
the transient handshake without relying on deinit.
`shutdown()`
uses the same explicit Void-binding shape for each new side-effect-only call,
finishes both stream continuations, advances/removes every slot before
cancelling its physical listener, resumes every outstanding start
continuation with `.ownerShuttingDown`, and resumes every claim-drain
continuation with `.ownerShuttingDown` exactly once so no suspended port call
can leak. This whole-owner terminal is the sole
exception to ordinary claimed-failure draining: it is legal only after the App
lifecycle owner is itself ceasing, launches no replacement/restart/reporter/UI
work, and cannot be used by a live-flow stop or replacement. A claimed failure
Task is not treated as a successful drain and is not cancelled by ordinary slot
logic; after shutdown its already bound weak sink may only finish against a
still-live controller or return `.superseded` with zero I/O.
After `isShutdown` becomes true, every owner entry point is closed: start/stop
return their `.ownerShuttingDown` case, recovery/callback consume and callback-
finish calls return false/no-op, and state/connection/receive callbacks cancel
their physical connection where any and yield nothing. No method may recreate a
continuation, slot, listener, event, or reset `isShutdown`.

Each consumer first binds its own `let events =
oauthListenerPlatformOwner.<stream>`. The recovery consumer has the exact
lifetime shape `Task { [weak self, events] in for await event in events {
let _: Void = await MainActor.run { [weak self] in if let self { let _: Void =
self.apply(event) } } } }`. The callback consumer instead has the exact shape
`Task { [weak self, events] in for await event in events { if let self { let _:
Void = await self.consumeOAuthCallbackEvent(event) } } }`. Its private
MainActor method retains AppStore only for that one bounded event handshake;
it serially performs physical begin, controller claim, promotion or abandon/
sealed/local reject, and physical acknowledgement, and it returns before the
next stream suspension. Once a claim is accepted, Task cancellation is only a
signal: the method must abandon or promote before returning. It never starts
callback business I/O itself; promotion installs the separate capability Task.
Typed bindings prevent new standalone final roots. Both Tasks retain only their
`AsyncStream` value, never the owner, and release any strong AppStore local
before the next `for await` suspension. Every listener
state handler, new-connection handler, and nested receive callback captures the
owner weakly. If that weak owner is nil, a state callback performs zero work and
a connection/receive callback cancels the accepted connection before returning;
neither calls the sink, yields an event, parses a URL, nor reaches controller/
codec I/O.

`RuntimeOAuthListenerFailureSink` has no public/package empty initializer or
bind method, and App cannot construct it. `OAuthListenerPlatformOwner` has no
controller/AppStore field, weak mutable bridge, bind method, or `lazy` recursive
initializer. Consequently an unbound listener failure is unrepresentable: the
lossless streams exist before the factory, the two App consumers exist before
any external action can reach the initialized store, and the concrete port does
not exist until the controller-bound sink exists. A failure outcome returning
before its consumer runs remains a typed stream element and still must pass the
owner's exact lease+failure-attempt consumption guard; it is never silently
dropped. This adds no catch, trap, descriptor, seam, delegate, or Test
declaration.

The controller stores the exact injected `RuntimeCredentialAccounts` and
`OperationTraceFactory`. Its credential account mapping is exhaustive and has
no literal/default branch: `.apiKey` set/delete and profile attachment use
`credentialAccounts.apiKey`; `.searchKey` set/delete use
`credentialAccounts.searchKey`; every controller OAuth state/verifier/callback
operation uses `credentialAccounts.oauth`, while the separately owned Session
refresh uses that same nested value. Attachment always commits that same
injected API-key account. Resolver, controller, live ports, coordinator, and
App composition tests assert field equality for the one Runtime bundle and its
one nested OAuth bundle; the controller/live-port API has no independent
`OAuthCredentialAccounts` parameter. A source gate rejects a second bundle,
copied account string, duplicated OAuth access/account-ID coordinate,
`switch default`, or slot/account override.

Every accepted explicit recovery call is a new top-level attempt, not another
failure occurrence on the original trace. Each retry entry first compares its
opaque capability with the exact controller-current owner; a mismatch returns
`.superseded` with zero trace-factory, Reporter, platform, state, or recovery
I/O. Only after that guard accepts does the controller use its injected factory
to generate a fresh trace with the recovery operation and the opaque pending/
receipt's retained `traceScope`, before recovery I/O. `retryCredentialAttachment`
uses `.runtimeCredentialSet`; `retryOAuthAuthorization` and asynchronous
`handleOAuthListenerFailure` use `.oauthAuthorization`. OAuth callback cleanup
has no user retry entry and retains the claim's original callback trace. The original trace
stored in a committed receipt remains immutable provenance and is never reused
for Reporter capture by a later invocation. All sub-stages within one recovery
invocation share that one fresh trace. This prevents two different error codes
from colliding on one `failure_record` identity while preserving exact public
scope. No retry accepts a caller trace or reconstructs a scope from public
coordinates.

`RuntimeProfileWorkflowController.setCredential(slot:value:trace:)` is also
the exact owner of the legacy API-key attachment branch. For `.apiKey` it
serializes the credential write first and immediately constructs the opaque
base `RuntimeCredentialSetReceipt(slot:.apiKey, attachedProfileId:nil,
trace:trace)`; `.searchKey` constructs the corresponding `.searchKey`/nil base
receipt, then verifies the Runtime snapshot and never mutates a profile.
`.apiKey` calls one private shared
`finishCredentialAttachment` helper: it strict-reads the current default,
conditionally commits the fixed API-key account through the Core CAS frozen
below, and performs one strict Runtime verification reload. A credential-write
failure is `.notCommitted`.

A default-profile read or required profile-attachment failure after the
Keychain write is **not** a generic visibility failure. It returns
`.attachmentPending` with the exact committed receipt, original provenance
trace, and an
opaque `.resolveDefault` or `.attach(target)` step; the pending value stores no
credential/account bytes and its `slot` invariant is exactly `.apiKey`—no
initializer or terminal can construct a Search-key attachment pending. App updates only the authoritative API-key-presence
bit, preserves its last loaded profile/default arrays, displays the fixed
prefix `凭据已保存，但默认供给线绑定尚未完成。` plus the safe failure and trace,
and retains the pending value. `retryCredentialAttachment(_:)` first generates
the fresh same-scope recovery trace frozen above, then invokes only the shared
read/CAS/reload helper and performs zero Keychain writes. A reload
failure after both required mutations returns
`.committedWithVisibilityFailure(receipt:failure:)` and is refresh-only.

The controller and App each keep one current pending/attempt generation.
Retry first requires byte-equal pending plus current attempt; a stale/double
retry returns `.superseded` before DB or Keychain I/O. Search-key save/delete
never reads or mutates this state. A new API-key save does not erase the older
pending when its Keychain write is not committed. Once that write commits, an
`.attachmentPending` terminal atomically replaces the old value; a fully
`.committed` or reload-only `.committedWithVisibilityFailure` terminal
compare-clears the captured old value because attachment is complete. A failed
API-key delete preserves the pending; a committed delete compare-clears it.
Every late retry terminal must still match both the captured pending and
attempt, so it cannot reinsert an old capability or attach after deletion.
Recovery-step transitions are closed. `.resolveDefault` performs one strict
`prepareDefaultAPIKeyAttachment`: nil means attachment is currently unnecessary
or already complete and proceeds only to verification reload; a returned
target receives exactly one CAS attempt. `.attach(target)` performs exactly one
CAS. `credentialAttachmentConflict` never resolves or writes a new profile in
that same retry; it returns a new pending over the same committed receipt with
step `.resolveDefault`. Any other write error retains the byte-identical
`.attach(target)` pending. The next explicit retry may then resolve the current
default; if it is a new eligible unattached profile it attaches that profile
once, while a noneligible/already-attached default completes without a write.
Every transition performs zero Keychain writes.

`RuntimeCredentialSetReceipt.attachedProfileId` is evidence only. It is
non-nil if and only if this set/retry invocation reached
`commitDefaultAPIKeyAttachment` and that Core CAS returned success either by
updating the exact target row or by its closed zero-row reread proving that the
same target already contains the same fixed API-key account. The value is
exactly the returned `RuntimeProfileRecord.id`. It is never the current-default
ID, an attempted target ID, a pending hint, or an ID learned only by the
verification reload, and it has zero use in pending identity, compare-clear,
retry routing, business branch conditions, or writes.

The receipt state machine is exact. Search-key committed and post-write
visibility-failure terminals keep the original Search/nil receipt. Every API-
key `.attachmentPending(.resolveDefault/.attach)` stores the original API/nil
base receipt byte-for-byte; read failure, CAS failure, conflict-to-resolve
transition, late failure, and retry handoff cannot synthesize an ID.
`prepareDefaultAPIKeyAttachment()==nil`—whether the default is noneligible or
already attached—completes with the same base/nil receipt, because that
invocation established no exact CAS target. Successful CAS update and same-
target/same-account idempotent CAS success each create one completed receipt by
copying the base slot/trace and setting `attachedProfileId` to the returned
record ID. Verification success returns that completed receipt; verification
failure returns `.committedWithVisibilityFailure` or
`.recoveredWithVisibilityFailure` carrying the byte-equal completed receipt.
Default A drifting to B retains an API/nil pending after the first conflict; a
later successful B CAS yields B's exact ID, while a B prepare-nil completion
remains nil. `.superseded` returns no receipt, and delete/pending application
never reconstructs or rewrites one. The final source gate permits a non-nil
receipt construction only in a branch lexically dominated by a successful
`commitDefaultAPIKeyAttachment` return; every other construction passes literal
nil.

App's dedicated pending retry action passes only the opaque value—never a
`SecretValue`, profile ID, account, or caller trace. The
`W[.attachCredentialAccount]` and `R[.reloadAfterCredentialAttach]`
descriptors inject these exact branches through the one
`runtimeCredentialSet` marker owner; no second seam or descriptor is added.

`RuntimeWorkflowPorts.live` is exhaustive: catalog refresh performs a typed
profile read, strict credential resolution, strict ModelCatalog refresh, and a
verification reload; provider test resolves once and consumes a minimal stream
until one authoritative turn. OAuth configuration is the only App input: App
may not supply state, verifier, expected state, a prebuilt authorization URL,
parsed callback parameters, or an already exchanged bundle.

Authorization is guarded by a controller-minted reservation independently of
the App façade. `reserveOAuthAuthorizationAttempt(flow:trace:)` validates the
operation/fixed OAuth scope and executes on the actor before its first
suspension, fallible action, RNG, or I/O. The controller stores one optional
global lifecycle owner across `.chatGPT` and `.generic`, not a dictionary keyed
by flow; every phase's reservation/authorization still carries its owning flow.
An empty global owner mints the opaque UUID reservation and installs
`.reserved(reservation)` atomically. Any nonempty
  reserved/preparing/post-preparation/browser-opening/ready/recovery/
callback-claim-awaiting-App/callback-processing/callback-cleanup owner,
regardless of requested flow, instead captures
`RuntimeOAuthBoundaryError.authorizationAlreadyActive` once on the new trace,
returns `.rejected`, and leaves A byte-identical. Reporter persistence/logger
fallback remains the ordinary §5.3 observability boundary rather than a hidden
failure constructor. Rejected B performs zero RNG, listener, state, verifier,
browser, codec, or credential work.

`prepareOAuthAuthorization(_:reservation:)` may CAS only a byte-equal current
`.reserved` owner to `.preparing`; a missing/different reservation returns
`.superseded` before reporter or business I/O. Every controller lifecycle case
retains that same reservation, every post-await transition rechecks it, and
only its byte-equal terminal may clear the global owner. Actor reentrancy and
actor-job ordering therefore cannot start a second candidate of either flow.
There is no stop-A/start-B replacement path: B may begin only after A's exact
not-committed preparation or cleaned callback terminal removes the global owner.

`rejectOAuthAuthorizationAttempt(_:trace:)` validates the B operation/scope
and the supplied reservation. It returns `.rejected` with one captured failure
only when that exact reservation still owns the flow; empty or different
ownership returns `.superseded` with zero reporter, lifecycle, or platform
I/O. The reject-only method cannot transition to normal preparation under any
timing and never installs a controller owner.

Authorization preparation executes exactly: generate state and verifier through
`RuntimeOAuthCodec.live` (SecRandom failure is typed; no UUID fallback); build
the strict URL and opaque authorization receipt. If a local listener is
required, the controller mints a fresh opaque `RuntimeOAuthListenerLease`
bound to the current reservation and, before the first listener await,
atomically installs that receipt+lease in its preparing owner. It then starts
the injected listener with both values. Immediately after listener start,
before the credential coordinator await, the controller retains the exact
receipt/reservation/lease, preparation attempt, and an optional closed
listener-restart obligation. That internal obligation is the exact
authorization+lease, `.listenerRestart` stage, fresh failure-claim attempt,
and byte-equal `UserVisibleFailure` already captured on that listener job's new
trace; it never stores a raw Error. App may remain the sealed
`.preparing(attempt:reservation:)` projection and display a
`.deferredToPreparation` failure; it never needs receipt access or replaces the
preparation Task. Then controller calls
`commitAuthorizationPreparation` with `.allow`. That coordinator encodes and
writes exactly one versioned state+verifier envelope to `accounts.verifier`
after its phase-selecting pre-read and returns the closed committed/failed
outcome. The controller switches all three cases without a default:
`.committed` continues; `.failed` maps the exact credential-bundle case; and
`.unavailable` maps the fixed `OAuthCredentialBundleUnavailableError`. Both
failure cases stop the exact listener, capture the typed not-committed
authorization failure once on the preparation trace, clear only the byte-equal
preparing owner, and return `.notCommitted`. Invalid coordinates reach
`.unavailable` before the coordinator lock/revision/store; the controller does
not revalidate or reinterpret them. A failed pre-read or Security set preserves the prior-or-absent item,
so the
controller stops only its exact owned listener, captures one ordinary
not-committed authorization failure, clears the byte-equal preparing owner, and
returns `.notCommitted`. `.ownerShuttingDown` cannot turn that failed write into
success; it still clears only the exact controller attempt and returns
`.superseded` after the physical owner has shut down. There is no rollback
phase, repair Task, retained preimage, or cross-process recovery promise. The
App port also cancels a candidate listener before throwing from a synchronous
start, so no unowned listener survives.

After the single envelope commits, `prepareOAuthAuthorization` performs no
browser I/O. With no listener obligation it atomically changes the controller
owner to
`.postPreparation(reservation,authorization,lease,preparationAttempt)` and
returns `.prepared(authorization)`. With a retained listener obligation it
instead creates the exact `.listenerThenBrowser` pending—browser opening has
not happened yet—changes to authorization recovery, and returns
`.recoveryPending(pending,failure:sameListenerFailure)`. It reuses the exact
already captured listener failure and never captures or reports it a second
time. A preparation terminal may not return `.prepared` while that obligation
exists.

`openOAuthAuthorization(_:)` is the sole initial browser-open owner. It accepts
only a command whose opaque reservation+authorization byte-equal the current
`.postPreparation` owner. Before its MainActor platform await it atomically
installs
`.browserOpening(reservation,authorization,lease,openAttempt)`; a same-owner
stable authorization recovery returns `.retainedRecovery` with zero platform
I/O, an already-ready same owner returns `.opened` with zero repeated platform
I/O, and every different/empty owner returns `.superseded` before platform or
Reporter work. Browser success CASes only the exact open attempt to `.ready`
and returns `.opened`. Browser false/error is captured once on the receipt's
retained `.oauthAuthorization` trace, creates exact `.browserReopen`, and
returns `.recoveryPending`; it never regenerates state/verifier/URL or starts a
second listener. A browser-only explicit recovery later invokes only
`openAuthorization(receipt)` for the same opaque receipt.

An asynchronous listener failure matching both receipt and current lease
during the credential-coordinator await atomically claims that lease once
inside the controller, generates its fresh listener trace, sets the preparing
owner's listener-restart obligation, and returns `.deferredToPreparation` with
that same byte-equal failure; it does not cancel or clear credential
preparation. Preparation failure/rollback stops the owned listener, clears the
deferred obligation with that failed attempt, and returns only the preparation
failure. After preparation commits but before App applies its terminal, a
matching failure changes `.postPreparation` to the exact
`.listenerThenBrowser` recovery pending and returns that pending to the App
preparation-origin transition. If App applies `.prepared` first, the same
failure either changes `.postPreparation` before the browser-open actor job or
changes `.browserOpening` while its MainActor platform call is suspended; both
paths install `.listenerThenBrowser`, never listener-only/browser-only. The
listener App terminal then replaces only the exact active browser-open Task, or
the open Task returns `.retainedRecovery`, according to the closed App table.

A browser terminal always CASes its exact open attempt. Listener-first makes
that attempt stale, so browser success cannot publish ready and browser failure
cannot overwrite the combined stage. The browser error is nevertheless
captured once before returning the controller-current combined pending; a stale
App open terminal cannot display it over a newer recovery, but the durable
failure record remains observable. Browser-first failure installs
`.browserReopen`, after which listener failure merges
`.listenerThenBrowser`; browser-first success installs ready, after which a
listener failure creates `.listenerRestart`. Duplicate/late listener,
preparation, and open terminals are generation guarded and perform no repeated
state/verifier/listener/browser work. The listener failure is never recaptured
or attributed to the authorization's original trace, while initial browser
opening remains a sub-stage of that one retained authorization trace.

`prepareOAuthAuthorization` requires a trace whose operation is exactly
`.oauthAuthorization`; the receipt retains it privately. The App listener
closure captures the receipt and lease, and `handleOAuthListenerFailure`
derives its flow and retained scope from that pair rather than accepting either
from the caller. Before reporter or recovery I/O the actor requires the exact
reservation+authorization+lease to remain current, records a fresh internal
failure-claim attempt, and only then generates a fresh authorization trace.
Every await and terminal rechecks the same phase+lease+claim attempt. A second
call for the same lease, a retired lease, or a different reservation returns
`.superseded` with zero reporter/platform/state/credential I/O. An asynchronous
bind/accept/cancel failure on `.postPreparation` or `.browserOpening` becomes
`.listenerThenBrowser`, because no successful browser terminal has yet been
sealed; the same failure on `.ready` becomes `.listenerRestart`. If the receipt
already owns `.browserReopen`, the controller atomically merges the obligation
into `.listenerThenBrowser`; it never overwrites or drops either stage. The
merge is identical whether browser-open failure or listener failure reaches
the actor first, and duplicate listener failures preserve the current closed
stage rather than creating an unbounded queue. Every nonempty controller phase
after receipt creation carries the current optional listener lease; recovery
pending values carry it opaquely so equal stages from different physical
generations cannot compare equal or accept one another's terminal.

Authorization recovery is one global-owner single flight with a byte-equal
pending value and attempt generation. Its controller phase records the exact
reservation, authorization, recovery attempt, starting pending, and mutable
closed remaining stage before the first await. Initial preparation has no
predecessor listener and mints its first lease directly. Every recovery stage
that includes listener restart instead first calls
`stopListenerIfOwned(authorization, oldLease)` while retaining the byte-equal
old lease, pending, stage, and recovery attempt; it does not mint or install G2
before that stop/drain returns. A queued eligible callback keeps the physical
drain pending through its controller claim and App promotion/abandon. Therefore
if that callback wins, the actor re-enters, installs the callback claim owner,
and only then releases the stop waiter; the recovery caller's mandatory
post-stop owner+attempt+old-lease recheck fails and G2 construction/start count
remains zero. A local/sealed reject or completed failure acknowledgement leaves
a closed controller owner before releasing the same waiter. Only a successful
`.stopped` plus byte-equal actor recheck may mint and atomically install G2 in
the recovery phase and call `startListener`.

The App port never performs controller rechecks and never replaces a nonempty
slot during start. A nonempty unexpected slot fails with the existing typed
`.accept` listener terminal before candidate construction; the controller is
the sole caller and its stop-before-mint order makes that branch an invariant
fixture, not a fallback. `.listenerRestart` retries only listener start;
`.browserReopen` retries only browser open; `.listenerThenBrowser` always
restarts the exact listener first and, only after that succeeds, reopens the
same URL. Listener failure retains the byte-equal listener-containing pending.
If listener succeeds and browser then fails, the returned pending is exactly
`.browserReopen`; the controller changes remaining stage to `.browserReopen`
before awaiting that browser operation. Listener-only success changes remaining
stage to none before constructing ready; success of both returns ready. Actor reentrancy is closed:
an async listener failure arriving while a browser recovery is suspended
merges into `.listenerThenBrowser` and invalidates the old pending/attempt, so
the late browser terminal cannot clear it; a duplicate failure during listener
restart likewise makes any late terminal conditional on the exact current
pending and attempt. No stage regenerates state/verifier/URL or starts a
different receipt. Random generation,
listener start, atomic state+verifier-envelope preparation, and browser opening
are sub-stages of that one top-level authorization operation. Their exact
callable seams are `oauthRandomState`, `oauthListener`,
`oauthAuthorizationPreparation`, and `oauthAuthorizationOpen`; no generic
OAuth seam stands in for them.

A callback may supersede a recovery flight only through the two-step claim
capability. `claimOAuthCallback` requires `.oauthCallbackExchange` and a
command carrying the App reservation, opaque authorization, raw callback URL,
and physical event lease. Before any fallible/business I/O its one actor turn
first matches operation+reservation+authorization+lease, then calls exactly the
codec's pure nonthrowing
`callbackStateMatches(configuration,url,expectedState)` against that
controller-current authorization, and only then may perform its claim CAS. The
matcher validates the exact configured redirect scheme/host/path plus exactly
one returned state from the permitted query/fragment location, calls only
`SecretValue.validated(returnedStateString)`, and, for a nonnil value, calls
only `returnedState.constantTimeEquals(expectedState)`. The failable factory's
nil terminal is the closed blank/invalid protocol rejection; the matcher uses
no `catch`, `try?`, `try!`, trap, or throwing initializer. It performs no
payload, code, or error parsing and no I/O. An exact current owner+lease with an absent,
duplicate, blank, malformed, route-mismatched, or unequal state returns
`.currentAuthorizationRejected` with the complete controller owner
byte-identical. A stale owner/lease returns `.superseded`; the two outcomes are
not interchangeable. An exact state match proceeds against this closed table:

- current `.postPreparation` or `.browserOpening` becomes
  `.callbackClaimAwaitingApp`, invalidates the exact open attempt, and freezes
  an opaque `.authorizationRecovery(.browserReopen)` origin;
- current `.ready` becomes the same claim phase with `.ready` origin;
- stable or in-flight authorization recovery becomes the claim phase with its
  exact controller-current remaining stage, invalidating the recovery attempt;
- a recovery whose terminal already sealed same-authorization ready is claimed
  as ready;
- different reservation/authorization/lease, preparing, cleanup/committed,
  duplicate claim, empty, or any other phase returns claim `.superseded` with
  zero mutation and zero Reporter/platform/codec/state/exchange/credential I/O.

The generic custom-scheme path is a separate ingress, never a fabricated
physical event. `AppStore.handleOAuthCallback(_:)` keeps its existing URL-only
signature and the existing `AgentLoopApp.onOpenURL` callsite remains
byte-for-byte. After its pure `agentloop://oauth/...` route guard, App constructs
`RuntimeOAuthCustomSchemeCallbackCommand(callbackURL:)` and calls only
`claimOAuthCustomSchemeCallback(_:trace:)`. That command has no reservation,
receipt, optional lease, dummy lease, or lease factory.

The custom claim is likewise one non-suspending actor operation with zero
Reporter, platform, envelope read, exchange, or credential I/O. It accepts only the
one global `.generic` authorization whose validated configuration has
`requiresLocalListener == false`. Before any owner mutation it calls exactly the
codec's same pure nonthrowing `callbackStateMatches` with the URL and that
authorization's controller-held `expectedState`. The matcher validates the
exact scheme/host/path plus a single state from query/fragment, calls only
`SecretValue.validated(returnedStateString)`, and, for a nonnil value, calls
only `returnedState.constantTimeEquals(expectedState)`. A nil factory result is
the closed blank/invalid protocol rejection and requires no throwing bridge;
absent, duplicate, blank, malformed, route-
mismatched, or unequal state returns claim `.superseded` with the complete
generic owner byte-identical. It performs no payload/code/error parsing and no
I/O. Only an exact match proceeds to the one claim CAS and binds the URL to the controller-current
reservation and authorization itself. Post-preparation/browser-opening maps to
the exact browser-reopen origin, ready maps to ready, and stable/in-flight
recovery contributes the exact remaining stage. Empty, ChatGPT, reserved,
  preparing, route/state mismatch, duplicate claim,
  callback processing/cleanup, or
committed state returns `.superseded` with zero mutation/I/O. The existing
physical claim remains the only entry that requires and validates the App
reservation, authorization, and listener lease.

The common claim phase stores its private ingress source
(`.localListener(lease)` or `.customScheme`), callback URL+trace, claim ID,
controller-current origin/stage, and any later merged listener obligation.
`claim.ingress` exposes only the closed transport kind; a custom claim's
`ownsListenerLease(_:)` always returns false. Command pending stage
is never trusted as progress. A listener failure that reaches this phase merges
its exact stage and returns `.deferredToCallback`; its App application is
display-only and cannot release the callback drain or cancel the pre-claim App
carrier. `abandonOAuthCallbackClaim` accepts only this exact phase. For
local-listener ingress it converts origin plus the consumed-listener obligation
into stable authorization recovery. For custom ingress, a ready origin returns
`.ready(receipt)` because no listener was consumed; browser-opening or
post-preparation returns exact `.browserReopen`, and recovery returns its exact
controller-current pending. It invalidates the old attempt and performs no
capture or I/O. A local-listener claim can never abandon to `.ready`. A
stale/double abandon instead returns
`.superseded(sealedCurrentOwner)` with the same closed whole-owner projection
used by capability processing; it never returns an ownerless bare superseded.
It is the mandatory terminal if App/physical promotion cannot complete.

`handleOAuthCallback` accepts only the common opaque claim capability. At method entry
it CASes exact `.callbackClaimAwaitingApp` to
`.callbackProcessing(reservation,authorization,callbackTrace,
originStage:claimCurrentStage,retainedListenerStage,
credentialCommitted:false)`; a mismatched/abandoned capability returns
`.superseded(sealedCurrentOwner)` before I/O. Only after that CAS may parsing,
optional code exchange, state validation, and the credential bundle commit use
`oauthCallback`; listener-stop/visibility cleanup after commit uses
`oauthCallbackCleanup`, both retaining the claim's single trace. Every await
rechecks claim ID+reservation+authorization+trace+phase. Background refresh
alone uses `.oauthRefreshCommit` inside `OpenAIOAuthSession`; Runtime controller
has no refresh-commit API or App edge.

Local-listener ingress retains every existing lease check and owned-listener
cleanup. Custom-scheme ingress requires the same global generic/no-listener
owner and skips listener start, stop, mint, and physical acknowledgement
entirely; preparation-envelope validation, parsing, exchange, credential transaction, projection
reload, typed failures, and safe diagnostics are otherwise common. A custom
cleanup therefore has listener counters zero. Neither command nor a raw URL can
reach handle or abandon; only the opaque common claim can.

The direct custom-scheme App handshake is independent of the physical callback
candidate map. An unrelated URL is a harmless protocol rejection with zero
trace/controller/UI work. For the exact custom route, App requires the one
current generic `.active` or `.authorizationRecovery` carrier and no existing
custom ingress; empty, other-flow, callback-processing/cleanup, or duplicate
delivery is a zero-mutation rejection. It creates one fresh
`.oauthCallbackExchange` trace, then in one MainActor segment installs the
`OAuthCustomSchemeCallbackIngress` and its Task before the Task's first await.
The existing browser/recovery lifecycle Task remains byte-identical during the
non-I/O claim.

On `.claimed`, App rereads the current lifecycle carrier, proves only the
claim's flow/reservation/authorization against it, maps opaque `claim.origin`
without reconstructing controller stage, and in one non-suspending promotion
cancels/compare-clears the exact old Task, installs a fresh
`.callbackProcessing` attempt and sole `handleOAuthCallback(claim)` Task, and
clears the ingress carrier. Cancellation, teardown, or a truly changed App
owner after `.claimed` must call `abandonOAuthCallbackClaim` and apply its
closed ready/recovery/superseded whole-owner terminal before clearing the
ingress. A claim `.superseded` clears only the exact ingress attempt/Task and
leaves lifecycle state untouched. No cancellation, weak-self loss, or early
return may drop an accepted claim.

While custom ingress exists, the generic authorization-retry enabled predicate
and action entry both reject synchronously with zero attempt, trace, Task,
controller, browser, or platform work. The direct path never calls
`OAuthListenerPlatformOwner`, never reads or fabricates a listener lease, never
touches the physical candidate/ack methods, and leaves all seven physical
callback counters at zero.

If capability processing later returns `.superseded(sealedCurrentOwner)`, App
compare-clears only the exact promoted callback Task and adopts the sealed
ready/recovery/cleanup/none owner as a whole. It never applies
`.transientAuthorizationOwner`; a production capability cannot reach that case
while its exact App attempt remains current. It never merely clears a Task
while leaving `.callbackProcessing`.

Accordingly, a callback parse/state/exchange/credential failure claimed from
`.postPreparation` or `.browserOpening` returns the exact
`.authorizationRecoveryPending(.browserReopen, failure:callbackFailure)` (or
the merged listener stage) rather than plain `.notCommitted`; App can never be
left active with neither a confirmed browser terminal nor a browser-recovery
capability. A failure claimed from ready with no listener obligation restores
ready through `.notCommitted`. Credential commit from any origin proceeds only
to callback cleanup. The late browser-open terminal is stale after callback
claim and cannot clear callback, cleanup, or the restored recovery.

`handleOAuthListenerFailure` races through the same actor state. If it wins
while the authorization is ready/recovering, it installs the ordinary merged
authorization pending. If App has already installed
`.callbackProcessing(attempt,reservation,origin)` and its callback Task, the
listener terminal is display-only: it may publish the exact already captured
failure; only the exact recovery-event acceptance/ack may compare-clear that
event's physical-slot failure Task. It cannot cancel, compare-clear, or replace
the callback Task/lifecycle state. If the callback consumer is between physical
begin and controller claim, listener-first installs/merges recovery and the
later claim adopts that exact stage. If controller claim already won but App
promotion has not, the listener merges into `.callbackClaimAwaitingApp`,
returns `.deferredToCallback`, and App displays only; it neither alters the old
App carrier nor releases the physical callback drain. If App promotion already
installed callback processing, the capability Task remains the sole state
synchronizer. Thus neither ordering relies on Task cancellation or actor FIFO.
If callback processing won in the actor and credentials are not committed, the listener merges restart
with the origin/retained stage inside that callback owner and returns
`.deferredToCallback(failure:)`; App displays the separately traced failure but
keeps the byte-equal callback-processing state. If credentials are already
committed, controller-private callback cleanup exclusively owns listener stop
and visibility reload, so the
listener terminal is observable through `.deferredToCallback` but creates no
authorization-restart capability. No order replaces a pending stage or starts
a second exchange.

A callback failure before credential commit restores ready only when its
controller origin had a sealed successful browser-open terminal and no recovery
stage. A post-preparation/browser-opening origin contributes browser-reopen;
any concurrent listener obligation merges through the same closed stage table.
Those paths return `.authorizationRecoveryPending` with one exact opaque pending
and the callback failure; App installs that value rather than reconstructing a
stage. Immediately after the credential coordinator commits, before cleanup
awaits, the controller marks the exact callback owner
`credentialCommitted:true` and enters its private cleanup phase. From that point
the only legal terminal is committed or committed-with-visibility-failure; an
authorization recovery can no longer be resurrected. A late callback or
listener result conditionally applies only to the exact callback owner, and no
listener result may clear the callback carrier.

Callback parsing, query/fragment handling, form encoding, response shape, and
HTTP status live in `RuntimeOAuthCodec.live` as real Application callables.
They use strict URLComponents/Decodable handling: no `[]`, raw percent-encoding,
status zero, partial row, raw body, or error-description fallback. The
controller calls `readAuthorizationPreparation`, requires its durable flow to
match the opaque receipt, compares payload `returnedState` to the receipt's
expected state only with `constantTimeEquals`, obtains/exchanges the bundle, validates required
account ID, and delegates the entire credential bundle to the shared
coordinator. The coordinator's complete initial replacement first proves the
exact canonical `.prepared` or `.recoveryPrepared` envelope retained by the
closed preparation under the process's shared lock and atomically replaces that
one Keychain item with `.initialCommitting`, then mutates the
four credential fields and deletes the envelope last in the same compensated
credential transaction. If that phase write, final delete, or any intermediate
mutation fails, reverse restoration reinstates the exact pre-commit envelope
phase and bytes when possible and the callback remains not committed;
`.recoveryPrepared` therefore remains quarantined after a successful rollback.
If restoration itself fails, the durable `.initialCommitting` phase
quarantines every OAuth reader. A
successful commit has already removed both state and verifier atomically. Only then does the
controller constructs the committed receipt and enters private cleanup. Cleanup
therefore performs no state or verifier write: when a current listener lease
exists it calls `stopListenerIfOwned(receipt,controllerCurrentLease)`, then
reloads projection. A `.stopped` outcome continues that sequence;
`.ownerShuttingDown` compare-clears the exact cleanup owner and returns
`.superseded` before reload or any visible terminal. Stop-if-owned cannot stop
the newer listener and has no failure outcome. A later reload
failure returns `.committedWithVisibilityFailure` with the committed receipt
and is refresh-only. It does not recreate a cleanup capability or retain a
user-retryable cleanup state; App removes the exact callback-processing carrier,
keeps the known committed credential state, and offers only an ordinary refresh.
`retryOAuthAuthorization(_:)` first accepts only an exact controller-current
`.authorizationRecovery(pending)` owner. A mismatch—including
`.callbackClaimAwaitingApp`—returns `.superseded` before trace creation or I/O.
An accepted retry then generates one fresh same-scope `.oauthAuthorization`
trace and invokes exactly its retained listener-restart, browser-reopen, or
listener-then-browser stage.
A cleaned callback terminal compare-removes the exact
callback-processing carrier; until that terminal, beginning a
replacement authorization is forbidden. The controller maintains one global
owner. App may retain its flow-keyed dictionary to minimize projection churn,
but the total lifecycle-owner cardinality across all keys is `0...1`; every
begin scans the whole dictionary and no insertion is legal merely because the
requested flow's subscript is nil. Terminal apply is compare-and-remove on the
captured flow, generation, and byte-equal opaque value.
After the exact lifecycle is removed, a later authorization may begin; any
stale retained A retry arriving after that later B begins is `.superseded`
before Reporter/UI and before state/listener/credential I/O.

App owns the concrete NWListener and NSWorkspace closures only. For every
initial or retry start, `startListener(receipt, lease)` installs a `.starting`
slot in one MainActor segment before calling `NWListener.start`; if the owner
is already shutdown it returns `.ownerShuttingDown` before construction/start.
`startListener` is construction-only: it never stops, replaces, drains, or
publishes over a nonempty same-flow slot. Any unexpected nonempty slot throws
the closed typed `.accept` terminal before constructing/starting a candidate.
Initial preparation has no predecessor. A recovery caller must separately
await `stopListenerIfOwned(receipt,oldLease)`, recheck its actor owner, then mint
and install G2 before calling start. Thus the App port is never asked to perform
an impossible controller recheck or to linearize G1 and G2 itself.

An unconsumed callback event or an unacknowledged failure is drain-bearing. In
particular `.callbackClaimed` and `.callbackAndFailureClaimed` remain
drain-bearing while the serial consumer awaits controller claim and App
promotion/abandon; merely dequeuing the stream value does not release them. A
`.callbackProcessing` or `.callbackProcessingAfterFailure` slot has completed
that handshake and is immediately physically retireable, while
`.callbackProcessingAndFailureClaimed` drains only its failure claim. A ready
event may change only the exact `.starting` slot to
`.live` and resume that start once with `.started`. An exact `.waiting` or
`.failed` event while `.starting` maps to `.accept`; an unexpected `.cancelled`
maps to `.cancelled`. Each advances/removes that candidate slot, resumes its
start continuation once with the fixed typed error, then calls
`listener.cancel()` exactly once; the resulting `.cancelled` callback sees no
lease and is zero-I/O. It launches no asynchronous failure handler. The first
unexpected `.waiting`/`.failed` event while `.live` maps to `.accept`, and the
first unexpected `.cancelled` maps to `.cancelled`; either atomically changes
that exact slot to `.failureClaimed(failureAttempt:)`, installs its sole failure
Task, cancels the exact physical listener, and calls the controller with the
captured receipt+lease. The same first event while
`.callbackClaimed(callbackAttempt:)` changes to
`.callbackAndFailureClaimed(callbackAttempt:failureAttempt:)`; while
`.callbackProcessing(callbackAttempt:)` it changes to
`.callbackProcessingAndFailureClaimed(callbackAttempt:failureAttempt:)`.
Either retains the callback claim, installs the one failure Task, cancels the
exact physical listener, and invokes the same sink; it
never cancels or supersedes callback processing. Every duplicate event is
zero-I/O. `stopListenerIfOwned(receipt, lease)` is async and has one exact phase
table. A `.starting`, `.live`, or `.callbackProcessing` slot advances/removes
physical ownership before cancellation, resumes any start continuation with
cancellation, cancels the listener exactly once, and returns `.stopped`;
`.callbackProcessingAfterFailure` likewise advances/removes and returns
`.stopped` but does not cancel the listener a second time. A late logical
callback terminal is a physical no-op. A `.callbackClaimed` slot sets
`retireAfterClaimDrain`, installs one checked drain continuation, cancels the
listener exactly once, and waits through controller claim plus App
promotion/abandon or a sealed/local reject acknowledgement. A
`.failureClaimed`, `.callbackAndFailureClaimed`,
`.callbackProcessingAndFailureClaimed`, `.recoveryAppliedAwaitingApp`,
`.callbackFinishedAwaitingFailure`, or
`.callbackFailureAppliedAwaitingConsumer` slot sets the same retire bit and
installs at most one checked drain continuation, but does not cancel the
already-cancelled listener a second time. Those phases await exactly their
still-unacknowledged physical set: failure only, callback-handshake plus
failure, failure only, App acknowledgement only, failure only, and
callback-handshake only respectively.
No branch cancels a claimed callback or failure Task. It returns `.stopped`
only after the last required physical acknowledgement removes the slot. In
particular, recovery-first does not make a still-queued callback removable.
The cancelled state event caused by a callback-only retire is intentional: the
retire bit is checked before phase dispatch, so it cannot create a handler.
Connections rejected before yield and lease/attempt-mismatched stream values
perform zero actor/reporter/UI work. An already yielded exact callback remains
eligible to perform its non-I/O actor claim while stop waits; that is the
linearization that can make the recovery retry stale before G2 exists. Handler terminal application requires the
same slot lease+failure attempt plus the closed App transition table above,
resumes the one claim-drain continuation exactly once only when no callback or
failure claim remains, and clears no newer G2 slot or lifecycle Task. For an
exact recovery event, `consumeRecoveryIfCurrent` compare-clears only its
failure Task and enters an awaiting-App tombstone without removing the slot or
resuming a waiter. It maps `.failureClaimed` to
`.recoveryAppliedAwaitingApp(failureAttempt:remainder:.none)`,
`.callbackAndFailureClaimed` to the same phase with
`.callbackQueued(callbackAttempt:)`,
`.callbackProcessingAndFailureClaimed` with
`.callbackProcessing(callbackAttempt:)`, and
`.callbackFinishedAwaitingFailure(callbackAttempt:failureAttempt:)` with
`.callbackFinished(callbackAttempt:)`. The consumer then attempts the exact
guarded App transition and calls `acknowledgeRecoveryApplyIfCurrent` in the
same non-suspending MainActor segment. That acknowledgement maps `.none` and
`.callbackFinished` to removal; `.callbackQueued` to
`.callbackFailureAppliedAwaitingConsumer`; and `.callbackProcessing` to
`.callbackProcessingAfterFailure` when no waiter exists, otherwise to removal.
Removal resumes one stored drain once with `.stopped`. No failure drain is
acknowledged before App has attempted the guarded apply, while no cleanup stop
waits for the logical callback Task that invoked it. Event-first,
stop-before-event, and replacement-before-event therefore all end with no
second wait; a mismatch changes nothing.

The controller side preserves the same reservation+authorization+lease owner
while an async stop drains, without deadlocking the MainActor platform await.
In particular, callback credential commit marks its owner committed and enters
cleanup before stop. Because the callback consumer already acknowledged the
physical callback delivery, cleanup stop never waits for the same
`handleOAuthCallback` invocation's sealed terminal. With no claimed listener
failure it advances/removes the `.callbackProcessing` slot and returns
`.stopped` immediately. With a same-lease failure already claimed, it cancels
the physical listener, records the failure tombstone, and waits only for the
failure's recovery-event App application and acknowledgement. The controller
therefore remains free to accept the sink actor job while its cleanup method
awaits the port. If the physical failure Task has not entered the actor, that
committed cleanup owner remains current until the sink generates its fresh
listener trace and exact observable `.deferredToCallback` terminal. The
recovery-event App consumer then acknowledges the tombstone and resumes the
port continuation; that terminal carries no authorization-restart capability
after commit. Only after the await returns may cleanup remove the controller
owner and the callback terminal retire the App carrier. A late physical
`finishCallbackIfCurrent` after stop removed the slot is zero-I/O. No actor
method waits for its own future sealed terminal, no actor method awaits an App
continuation while holding nonreentrant ownership, and Swift Task cancellation,
actor FIFO, and whether stop or sink enters the actor first are never evidence
of completion.
Every controller caller switches exhaustively on
`RuntimeOAuthListenerStopOutcome`: `.stopped` permits its ordinary terminal,
whereas `.ownerShuttingDown` compare-clears only the exact controller owner and
returns that API's existing `.superseded` terminal with zero reload, Reporter,
restart, browser, codec, credential, or UI work. Thus teardown cannot be
mistaken for an observed listener-failure drain.
Every controller start caller likewise switches exhaustively on
`RuntimeOAuthListenerStartOutcome`: `.started` permits the ordinary next phase;
`.ownerShuttingDown` compare-clears only its byte-equal attempt and returns the
caller's existing `.superseded` terminal with the same zero-I/O rule. Thrown
bind/start/state errors alone enter the typed listener-failure capture path.

The platform error mapping is closed. A callback port that cannot form
`NWEndpoint.Port` throws `.invalidPort` before listener construction or slot
publication. The retained constructor catch throws `.bind`. Exact
`.waiting`/`.failed` state events throw or sink `.accept`, and an unexpected
`.cancelled` throws or sinks `.cancelled`; raw `NWError` text is always
discarded. A request that cannot decode one exact HTTP `GET /auth/callback...`
URL maps only to `.malformedCallback`: while the same slot is still `.live`, it
atomically becomes `.failureClaimed`, installs one failure Task, responds with
the fixed 400 page, cancels connection and listener, and calls the same sink;
if the lease is no longer live it only responds/cancels and performs zero sink
or controller work. It never yields a callback event. No other condition may
construct these five cases.

The `NWListener.State` switch is exhaustive and fail-fast. `.setup` before
start and a duplicate `.ready` for the exact live slot are no-ops; the first
`.ready` completes only its exact starting continuation. `.waiting` and
`.failed` use `.accept`; `.cancelled` uses `.cancelled` only for an exact
starting/live/callback-claimed/callback-processing slot whose retire bit is
false, and is a no-op after ownership was advanced/removed, retirement was
recorded, or the phase already became failure-bearing.
No default arm or unknown state string is permitted.

`startListener` wraps its ready wait in a cancellation handler. Caller-task
cancellation atomically changes/removes only the exact starting slot, resumes
its one continuation with cancellation, and only then cancels the listener;
the resulting state callback is intentional and launches no failure handler.
Ready/failure/caller-cancel race through the same MainActor one-shot phase, so
exactly one resumes the continuation. If ready wins but the controller attempt
is already stale, the controller compare-stops that exact lease before any
later phase is published. No cancellation path leaves a starting slot or
suspended continuation.

Physical connection delivery is lease-gated twice. `newConnectionHandler`
captures receipt+lease and asks MainActor to prove the exact slot is `.live`
before starting/reading the connection; otherwise it cancels the connection
with zero callback/controller work. After the request is decoded but before
raw URL handoff, MainActor atomically proves the same live slot and changes it
to `.callbackClaimed(callbackAttempt:)`; only that transition may yield the
callback event. Replacement, intentional stop, another callback claim, or a
failure claim during that read cancels/responds with the fixed failure page and
never invokes the callback façade. Every later connection for that lease is
cancelled before decode/handoff, so a connection burst yields at most one event
and cannot grow the stream. Thus a G1 connection or URL cannot enter callback
processing after G2 owns the same receipt.

The callback claim remains physical delivery ownership until the
controller-claim/App-promotion handshake accepts or rejects the event. The
serial consumer's `beginCallbackClaimIfCurrent` accepts the exact attempt in
`.callbackClaimed`, `.callbackAndFailureClaimed`, or
`.callbackFailureAppliedAwaitingConsumer`, but changes no physical phase. A
physical failure never drops an already yielded callback.

For an eligible active/recovery App origin the consumer captures its candidate
and awaits `claimOAuthCallback`; the physical slot and any stop/replacement
waiter remain unchanged. On `.claimed`, the same MainActor promotion segment
first revalidates current App owner+reservation+authorization and the opaque
claim's lease, then calls `acknowledgeCallbackPromotionIfCurrent`. That method
maps plain `.callbackClaimed` to `.callbackProcessing`, queued
`.callbackAndFailureClaimed` to
`.callbackProcessingAndFailureClaimed`, and recovery-first
`.callbackFailureAppliedAwaitingConsumer` to
`.callbackProcessingAfterFailure`. In that same segment App cancels/clears only
the exact old lifecycle Task and installs `.callbackProcessing` plus the sole
capability Task. Only this promotion acknowledges an eligible physical callback.

An exact `.preparing` state may instead local-finish the still-claimed event
with `restoresAuthorization:true` only when its lease belongs to the
preparation reservation. `.reserving`, callback-processing,
empty, owner/flow/authorization mismatch, and stale attempt local-finish with
`restoresAuthorization:false`. A controller claim
`.currentAuthorizationRejected` is accepted only for an exact map-current
candidate whose reservation, authorization, and physical lease still match.
In one no-await MainActor segment it compare-clears only that candidate, leaves
the lifecycle state/attempt/Task byte-identical, and calls the physical finish
with `restoresAuthorization:true`. A plain current slot with no retire/drain
waiter therefore returns to `.live`, so a stale A URL delivered on current B's
listener cannot consume B's sole callback opportunity. A failure-bearing phase
retains its independent failure claim and never reopens; a retire/drain waiter
removes/resumes according to the existing table. The outcome is an invariant
failure for custom-scheme ingress and may not be fabricated by App. A
controller claim `.superseded` also leaves the App carrier byte-identical and
non-restoring-finishes only after that sealed reject. A claimed capability that cannot promote is first abandoned into
stable listener recovery and only then non-restoring-finished. A failed initial
physical begin performs neither finish nor App mutation.

If no failure remains and a stop/replacement waiter exists, an acknowledged
promotion or closed finish removes the slot and resumes it once; the promoted
logical Task continues independently and its later physical finish is a no-op.
If a failure remains, the waiter continues only through the exact recovery/App
acknowledgement. No processing or controller-claim phase may survive without
promotion, abandon, or sealed reject, and callback business work cannot enter
the actor before promotion.
The recovery
consumer accepts its exact failure attempt in `.failureClaimed`,
`.callbackAndFailureClaimed`, `.callbackProcessingAndFailureClaimed`, or
`.callbackFinishedAwaitingFailure`. An exact ordinary recovery consume and a
callback-finished-first recovery consume enter
`.recoveryAppliedAwaitingApp`; only `acknowledgeRecoveryApplyIfCurrent` accepts
that phase. For the dual-claim case the independent callback-delivery and
failure-App acknowledgements form a closed join regardless of logical callback
completion order:

- recovery first with a queued callback passes
  `.callbackAndFailureClaimed` through
  `.recoveryAppliedAwaitingApp(...,remainder:.callbackQueued)`; after guarded
  App apply/ack it becomes `.callbackFailureAppliedAwaitingConsumer`, so a
  stop/replacement still waits for callback claim+promotion/abandon. When that
  event is claimed and App installs its logical Task, a waiter removes the slot
  and resumes immediately; without a waiter the slot becomes
  `.callbackProcessingAfterFailure` until the logical terminal;
- recovery first after callback processing began passes
  `.callbackProcessingAndFailureClaimed` through
  `.recoveryAppliedAwaitingApp(...,remainder:.callbackProcessing)`. The App
  acknowledgement removes/resumes an existing waiter immediately, or retains
  `.callbackProcessingAfterFailure` when there is none. It never waits for the
  Task's sealed terminal;
- callback-terminal first changes the exact dual phase to
  `.callbackFinishedAwaitingFailure(callbackAttempt:failureAttempt:)`. The
  later recovery consume preserves both identities in
  `.recoveryAppliedAwaitingApp(...,remainder:.callbackFinished)`; only its
  guarded App apply/ack removes the slot and resumes one waiter.

In every order the failure is captured/applied once, the callback event is not
dropped, and cleanup stop can never depend on the callback terminal that cannot
exist until that stop returns. A mismatch changes nothing; stop/replacement
cancels the physical resource only when it has not already been cancelled and
never cancels either claimed Task.

`finishCallbackIfCurrent` has one exact physical table. Before promotion, a
matching plain `.callbackClaimed(callbackAttempt:)` with a restoring local
reject returns to `.live` only when neither retire bit nor drain waiter is
present; with a waiter it removes/resumes instead. The same phase with a sealed
non-restoring reject/abandon is retired and removed. A matching queued
`.callbackAndFailureClaimed` never restores live: either disposition drops only
the callback member and becomes `.failureClaimed(failureAttempt:)`, retaining
its failure Task/waiter. A matching
`.callbackFailureAppliedAwaitingConsumer` is already physically dead and is
removed/resumed for either disposition. These are the only finishes before
controller promotion.

After promotion, a matching plain `.callbackProcessing(callbackAttempt:)` with
a restoring pre-commit terminal returns to `.live` only when neither the retire
bit nor a drain waiter is present. If callback promotion inherited a
stop/replacement waiter, that same MainActor segment removes the slot and
resumes the waiter once instead of restoring live. A matching non-restoring terminal marks the exact plain slot
retiring, removes it before cancelling its listener exactly once, and resumes
one stored waiter if present; the ensuing `.cancelled` state has no slot and is
zero-handler. A
matching `.callbackProcessingAndFailureClaimed` becomes
`.callbackFinishedAwaitingFailure(callbackAttempt:failureAttempt:)` and retains
any waiter; a matching `.callbackProcessingAfterFailure` removes the dead slot
and resumes one waiter if present. A phase already removed by stop, a mismatched
attempt/lease, or any newer slot is a no-op. Thus only the exact plain restoring
case permits one later user callback without replaying the consumed event. Any
failure-bearing callback phase is physically dead and may never restore live,
even when the callback terminal precedes the listener actor or App terminal.
Credential commit/cleanup, authorization removal, listener replacement, or stop may retire a plain processing slot immediately because
its physical callback delivery is already acknowledged; the controller
lifecycle owner, not a physical drain, prevents a newer logical authorization
from overwriting the in-flight callback. A queued callback still requires
consumer acknowledgement. A dual claim uses the independent acknowledgement
join above so neither the exact callback event nor listener failure is lost
before its physical obligation is discharged. No other callback-terminal
physical transition exists. A late terminal cannot reopen or retire a newer
lease/attempt. The callback event consumer must rejoin lease+callbackAttempt
immediately before App installs `.callbackProcessing`; otherwise it is stale
and performs zero logical callback work.

The one retained entry catch
`AppStore.startOpenAIAuthCallbackListener()` is rewritten in place with the
same pathname, canonical DeclarationID, and `E[.oauthListenerStart]`
ClassificationSet as a self-free static typed listener-construction adapter.
It catches the raw `NWListener` construction error once, discards it, and
throws only the fixed `RuntimeOAuthListenerFailure.bind`; it owns no slot,
handler, UI, or controller reference. `OAuthListenerPlatformOwner.makePort`
calls that exact adapter and contains no new catch/Result wrapper. Thus the App
adds no final candidate beyond the already frozen DEBUG exit and the retained
entry catch remains the existing business relation, not a planned occurrence.

`openAuthorization` accesses the URL only through
`receipt.withAuthorizationURL`, immediately discards it, and returns/throws a
fixed platform terminal. `NSWorkspace.open` returns Bool and the port maps false
directly to the fixed browser-open error without a catch. App never stores or
reconstructs raw state, verifier, URL query, flow-scoped cleanup input, or
callback trace. Existing view-facing methods retain their
String/Bool/Void signatures by projecting the controller's safe terminal, and
all prior profile/catalog data remains unchanged on failure.

The transitive Runtime/default/catalog boundary is exact. Missing values may
select only the named product default below; a present wrong type, invalid enum,
blank forbidden value, half-present cache, or malformed catalog always throws.
No zero-argument `.standard` wrapper or suffix-String read/write API remains:

```swift
public enum ProfileDefaultsField: String, Sendable, Equatable, CaseIterable {
    case applicationAPIFormat, applicationAPIBaseURL
    case applicationPreferredCredentialSource
    case legacyDefaultModel, legacyDistillModel, legacyPlannerModel
    case legacyModelChoices, profileDefaultModel, profileDistillModel
    case profilePlannerModel, profileModelChoices, profileManualModels
    case profileModelCatalog, profileModelCatalogFetchedAt
    case profileOAuthReconciled
}
public enum ProfileDefaultsValueKind: String, Sendable, Equatable {
    case string, boolean, stringArray, date
}
public enum ProfileScopedDefaultsError: Error, Sendable, Equatable {
    case typeMismatch(field: ProfileDefaultsField,
                      expected: ProfileDefaultsValueKind)
    case invalidValue(field: ProfileDefaultsField)
}
package struct RuntimeStoredPreferences: Sendable, Equatable {
    package let apiFormatRaw: String?
    package let apiBaseURLRaw: String?
    package let preferredCredentialSourceRaw: String?
    package init(apiFormatRaw: String?, apiBaseURLRaw: String?,
                 preferredCredentialSourceRaw: String?)
}
public struct CachedModelCatalog: Sendable, Equatable {
    public let models: [String]
    public let fetchedAt: Date
    public init(models: [String], fetchedAt: Date)
}
fileprivate enum ProfileDefaultsMutationValue: Sendable {
    case string(String), boolean(Bool), stringArray([String]), date(Date), remove
}
package struct ProfileDefaultsMutation: Sendable {
    fileprivate let key: String
    fileprivate let value: ProfileDefaultsMutationValue
    fileprivate init(key: String, value: ProfileDefaultsMutationValue)
}
public struct ProfileScopedDefaults: @unchecked Sendable {
    public init(defaults: UserDefaults)
    package func runtimeStoredPreferences() throws -> RuntimeStoredPreferences
    public func defaultModel(profileID: String, fallback: String) throws -> String
    public func distillModel(profileID: String) throws -> String
    public func plannerModel(profileID: String) throws -> String
    public func modelChoices(profileID: String, fallback: [String]) throws -> [String]
    public func manualModels(profileID: String) throws -> [String]
    public func cachedCatalog(profileID: String) throws -> CachedModelCatalog?
    public func oauthReconciled(profileID: String) throws -> Bool
    public func clampModelSelections(profileID: String,
                                     catalog: [String]) throws -> Bool
    public func setDefaultModel(_ model: String, profileID: String) throws
    public func setDistillModel(_ model: String, profileID: String) throws
    public func setPlannerModel(_ model: String, profileID: String) throws
    public func setModelChoices(_ models: [String], profileID: String) throws
    public func setManualModels(_ models: [String], profileID: String) throws
    public func setCachedCatalog(_ models: [String], fetchedAt: Date,
                                 profileID: String) throws
    public func setOAuthReconciled(_ value: Bool, profileID: String)
    package func prepareLegacyModelDefaults(
        profileID: String, fallbackDefaultModel: String,
        fallbackModelChoices: [String]
    ) throws -> [ProfileDefaultsMutation]
    package func prepareDefaultModelMutation(_ model: String,
        profileID: String) throws -> ProfileDefaultsMutation
    package func prepareDistillModelMutation(_ model: String,
        profileID: String) throws -> ProfileDefaultsMutation
    package func preparePlannerModelMutation(_ model: String,
        profileID: String) throws -> ProfileDefaultsMutation
    package func apply(_ mutations: [ProfileDefaultsMutation])
    public static func canonicalModels(_ models: [String],
                                       allowEmpty: Bool) throws -> [String]
}
public enum RuntimeProfileBootstrapError: Error, Sendable, Equatable {
    case invalidStoredAPIFormat
    case invalidStoredPreferredCredentialSource
    case invalidBaseURL
    case defaultProfileNotFound
    case defaultSelectionInvariant
}
public struct RuntimeProfileBootstrap: Sendable {
    public struct SeedInputs: Sendable, Equatable {
        public var apiKeyPresent: Bool
        public var apiFormat: ProviderAPIFormat
        public var apiBaseURL: String
        public var oauthTokenPresent: Bool
        public var preferredSource: ProviderCredentialSource
        public init(apiKeyPresent: Bool, apiFormat: ProviderAPIFormat,
                    apiBaseURL: String, oauthTokenPresent: Bool,
                    preferredSource: ProviderCredentialSource)
    }
    public init(db: AppDatabase, defaults: ProfileScopedDefaults)
    public static func storedSeedInputs(defaults: ProfileScopedDefaults,
        apiKeyPresent: Bool, oauthTokenPresent: Bool) throws -> SeedInputs
    @discardableResult public func ensureSeeded(
        inputs: SeedInputs,
        fallbackDefaultModel: String = KernelDefaults.defaultGuideModel,
        fallbackModelChoices: [String]
    ) throws -> RuntimeProfileRecord
}
public enum ModelCatalogError: LocalizedError, Sendable, Equatable {
    case invalidBaseURL(profileId: String)
    case unsupportedProfileKind(RuntimeProfileKind)
    case nonHTTPResponse
    case httpStatus(ValidatedHTTPStatus)
    case malformedResponse
}
public actor ModelCatalogService {
    public init(session: URLSession = .shared,
                defaults: ProfileScopedDefaults,
                now: @escaping @Sendable () -> Date = Date.init)
    public func catalog(profile: RuntimeProfileRecord) throws -> [String]?
    @discardableResult public func refresh(profile: RuntimeProfileRecord,
        credential: String) async throws -> [String]
    public static func resolvedCatalog(profile: RuntimeProfileRecord,
        defaults: ProfileScopedDefaults, fallback: [String]) throws -> [String]
    public static func trustedCatalog(profile: RuntimeProfileRecord,
        defaults: ProfileScopedDefaults) throws -> [String]?
    public static func isOfficialCatalogProfile(
        _ profile: RuntimeProfileRecord) throws -> Bool
}
public enum RuntimeProfileStoreError: LocalizedError, Sendable, Equatable {
    case defaultProfileNotFound
    case profileNotFound(String)
    case companionNotFound(String)
    case trustedCatalogUnavailable(String)
    case invalidReconciliationCommand
    case cannotDeleteDefaultProfile(String)
    case profileInUse(profileId: String, companionCount: Int)
    case credentialAttachmentConflict(profileId: String)
}
package struct RuntimeCredentialAttachmentTarget: Sendable, Equatable {
    fileprivate let profileId: String
    fileprivate let expectedKind: RuntimeProfileKind
    fileprivate init(profileId: String, expectedKind: RuntimeProfileKind)
}
extension AppDatabase {
    public func applyReconciliation(items: [ReconciliationItem],
        defaults: ProfileScopedDefaults) throws
    public func reconciliationReport(switchingTo profileId: String,
        defaults: ProfileScopedDefaults) throws -> [ReconciliationItem]
    package func prepareDefaultAPIKeyAttachment() throws
        -> RuntimeCredentialAttachmentTarget?
    package func commitDefaultAPIKeyAttachment(
        _ target: RuntimeCredentialAttachmentTarget,
        account: String
    ) throws -> RuntimeProfileRecord
}
public enum NewcomerProgressField: String, Sendable, Equatable, CaseIterable {
    case materializedKnowledge, referencedMission, artifact
    case userConfirmation, acceptedMission
}
public enum NewcomerUnlockError: Error, Sendable, Equatable {
    case notEligible
    case missingProjection(NewcomerProgressField)
}
extension NewcomerUnlockPolicy {
    package static func progress(database: Database, campId: String) throws
        -> NewcomerProgress
}
```

The exact default matrix is: missing stored API format →
`.anthropicMessages`; missing base URL or present blank base URL → the accepted
default URL; missing preferred source → `.apiKey`; missing default model → the
caller fallback; missing distill/planner → `""` inheritance; missing or explicit
empty model choices → caller fallback; missing manual models → `[]`; both cache
keys missing → nil; missing OAuth marker → false. Every present wrong type,
invalid enum/nonblank URL, blank model element, half cache, or empty cached
catalog throws. Boolean reading accepts actual CFBoolean only.

`prepareDefaultAPIKeyAttachment` strict-reads exactly one default profile. It
returns nil only when that profile is not an eligible API profile or already
has a credential account; otherwise it returns the opaque target with the
loaded profile identity, eligible kind, and expected nil attachment.
`commitDefaultAPIKeyAttachment` performs one conditional update requiring the
same ID, `isDefault = 1`, the same eligible API kind, and
`credentialAccount IS NULL`. Zero changed rows trigger one strict reread: the
same target now carrying the same fixed API-key account is idempotent success;
any changed default/kind/different account is
`credentialAttachmentConflict(profileId:)` with zero wrong-profile write. No
Application/App caller can construct or inspect a target, and the failure
classifier never emits the account.

`ensureSeeded` strict-reads and prepares every legacy/default mutation before
the profile insert. Existing profiles without exactly one default throw. A
preferred source may fall back only when exactly one profile is usable;
`firstIndex ?? 0` is forbidden. Reconciliation validates all profile,
Companion, scope, catalog, and defaults inputs, prepares all defaults mutations,
commits one DB transaction, then applies only nonthrowing prepared mutations;
there is no `continue` or partial success. `trustedCatalog == nil` is legal only
for a custom API profile or an official profile with no cache. Catalog fetch
requires an HTTP response, a 2xx status, and a strict `data[].id` DTO in which
every row is a nonblank String; raw response data never enters Error/evidence.

The old zero-argument/defaulted initializers, generic suffix read/write APIs,
nonthrowing catalog/default overloads, and `uniqueModels` are deleted.
`PlanningProviderResolver` calls throwing `canonicalModels`,
`trustedCatalog`, and `isOfficialCatalogProfile` and maps their typed failures;
it never restores a nonthrowing fallback. Each of NewcomerUnlockPolicy's five
`SELECT EXISTS` values uses `guard let` and throws its exact
`missingProjection` case; the Input bundle reuses this package helper rather
than copying SQL.

`RuntimeCredentialPresencePort.live` delegates exactly once to
`RuntimeCredentialResolver.presence(interactionPolicy:)`; it is the only
release constructor and therefore performs exactly one seven-position snapshot,
one lock acquire/release, and the frozen 1...7 fail-fast store-read prefixes.
It may not perform single-account synchronized emulation. The DEBUG-only
`preview` constructor stores and returns
only its supplied value and has no resolver, `SynchronizedCredentialAccess`,
`CredentialStore`, account String, read closure, or hidden fallback. It exists
solely to let the two isolated previews execute the same bootstrap algorithm
without contacting the real Keychain.

`SynchronousRuntimeBootstrap.run` performs, without `await`: one call to its
required `RuntimeCredentialPresencePort`; existing
`RuntimeProfileBootstrap(database, exactInjectedDefaults).ensureSeeded`; then
one `readRuntimeWorkflowBundle`; then DTO mapping. Any stage throws a closed
typed error; AppStore's shared synchronous WorkflowLoad capture adapter uses the
same bootstrap trace and returns `.failed`, never fatal/empty/default-first. AppStore
composition order is exact: one pre-composition boundary and its application
trace → process-local UserDefaults and one stored
`ProfileScopedDefaults` value → Keychain store/shared gate/coordinator →
isolated AppDatabase → reporter/accounts/resolver → binary synchronous Runtime
bootstrap capture and initial Runtime projection → post-database Coding Ranch
boundary around the retained ProductBootstrapService and initial Ranch state →
joint startup gate constructed from those exact two local states →
`OAuthListenerPlatformOwner` with both lossless streams → the
owner-only-capturing `RuntimeOAuthPlatformFactory` →
actors/controllers/Orchestrator → the two weak-self App stream-consumer Tasks.
All stored properties are initialized before either consumer captures `self`;
both Tasks are installed before the initializer returns, and no port factory or
listener start is invoked by composition. The three Runtime/Ranch/gate stored
carriers have no declaration-site default and are assigned only from those
locals. The loaded snapshot seeds Runtime projection
and existing caches; failure seeds the visible failed projection and leaves
provider dispatch fail-closed. The same ProfileScopedDefaults value is injected
into bootstrap, resolver, controller, scheduler selection, catalog,
reconciliation, and default switching; no component constructs a wrapper over
`UserDefaults.standard`.

AppStore retains that exact `SynchronousRuntimeBootstrap` and immutable
`RuntimeBootstrapRequest`. Initial composition invokes them once through the
binary `captureSynchronous` primitive before `self` exists and constructs
`runtimeProjection` with `WorkflowProjection(initial:)`; RootView retry calls
the sole `runRuntimeBootstrap()` instance method only from `.failed` and maps
the same primitive through `captureSynchronousLoad` with a fresh trace. Thus
initial construction has no impossible idle/loading branch and retry retains
the ordinary loading/current-generation projection semantics. The local
initial terminal constructs the joint gate; RootView's post-init activation
claims it, while a retry loaded terminal calls its typed accept. A Ranch
success cannot compensate for or bypass this failed Runtime projection, and a
later Runtime recovery re-enters the same gate rather than an independent start
path.

Production composition passes `.live(resolver:)` explicitly; there is no
defaulted port and no branch inside `run`. Under a direct `#if DEBUG`, AppStore
recognizes `AGENTLOOP_UI_PREVIEW=1` before constructing the bootstrap and passes
`.preview(RuntimeCredentialPresence(apiKeyPresent: false,
searchKeyPresent: false, oauthAccessTokenPresent: false,
chatGPTAccountIdPresent: false))` for both preview scenarios. The request,
seed/default logic, Runtime read bundle, DTO mapping, and failure capture remain
identical. Only the credential-presence source changes. Bypassing `run`,
installing audit hooks after it, or using a second bootstrap implementation is
a source-gate failure.

The same `run` call also derives `legacyRuminationSnapshot` from the already
loaded unique default profile and the same strict `ProfileScopedDefaults`
value. CLI and genuinely unconfigured model states map only to the existing
explicit `LegacyRuminationStartupSnapshot` cases; corrupt defaults, duplicate
or missing default-profile invariants, and DB errors throw on the bootstrap
trace. The old App-only
`captureLegacyRuminationSnapshot(database:defaults:)` helper and its duplicate
GRDB/default reads are deleted. AppStore consumes the loaded snapshot field.
If the whole bootstrap is failed, it records that visible failure, keeps
dispatch halted, and may pass `.legacyProfileUnresolved` only as the internal
fail-closed Orchestrator initializer value; it never presents that sentinel as
a successful load.

The existing nonthrowing `AppStore.init()` and closed `AgentLoopApp.swift`
remain unchanged at their call boundary. Preview UserDefaults creation,
state-directory lock, or AppDatabase open failure occurs before a usable
store/reporter can exist: the initializer first creates the one
application-bootstrap boundary and trace, emits exactly one fixed safe
SystemFailureLogSink line with that full trace for the failing stage, then
fail-fast terminates with the same fixed safe message—never raw suite/path/Error,
`fatalError`, or `try!`. It does not
construct an in-memory/empty fallback store. `ensureCodingRanchBootstrap`
occurs after the real DB/reporter exist; its failure is captured into the
global visible failure, keeps dispatch halted, and still permits the App to
render/retry. This is the only pre-composition fail-fast boundary, and it is
created before `makeUserDefaults`. Its actual
`ApplicationBootstrapFailureBoundary` callable is executed with a recording
sink for all three closed stages, and AppStore delegation is compile/source-gated;
source rejects `fatalError`/`try!` in `makeUserDefaults` and any composition
action before `makeTrace`. It requires the only terminal call to be
`ApplicationBootstrapFailureBoundary.terminate(stage:trace:)` and the only
pre-composition explicit trap to be that method's single
`preconditionFailure(failure.message)`. No test-only AppStore
initializer or fake StateDirectoryLock/AppDatabase constructor is invented.
Ordinary runtime/profile failures use the visible synchronous bootstrap state
above.

`SecretValue`, `OAuthCredentialBundle`, their accounts, and the coordinator are
Core declarations in `OpenAIOAuthSession.swift` as frozen below; placing them
in Application would create a forbidden Core -> Application dependency. They
validate nonblank values, expose no `description`, and never enter FailureRecord diagnostics. A returned snapshot
is the verification reload. A committed credential/profile write with a failed
reload returns the known committed receipt plus visibility failure; it never
fabricates a pre-write snapshot as success.

`SecretValue.constantTimeEquals` is the sole state-comparison primitive. It
opens both values only inside nested `use` closures, compares UTF-8 bytes with a
fixed-work XOR/OR accumulation across the larger byte count while folding the
length difference into the accumulator, and returns true only when the final
accumulator is zero. It does not call `String ==`, `Data ==`, hash, prefix,
localized comparison, or an early-returning byte predicate. Its work may reveal
the already bounded encoded length but never the first differing byte. Both the
pre-CAS URL state matcher and the post-payload returned-state check call this
same helper; no other raw state equality is permitted.

`SecretValue.validated(_:)` is the sole nonthrowing bridge from a callback URL
String into that comparison. It uses exactly the same canonical nonblank
predicate as the throwing package initializer: reject iff the raw value is
empty after `trimmingCharacters(in: .whitespacesAndNewlines)`, while storing the
original untrimmed bytes for every accepted secret. It returns nil only when
that predicate rejects; otherwise it calls the private `validatedRaw` initializer.
It contains no `catch`, `try?`, `try!`, trap, fallback value, or raw comparison
with the expected state. The explicit `Equatable.==` implementation delegates
directly and only to `lhs.constantTimeEquals(rhs)`; synthesized or fieldwise
String equality is forbidden. The private validated initializer is callable
only from the two validation entrypoints and is not a general unchecked
construction surface.

```swift
package struct SecretValue: Sendable, Equatable {
    private init(validatedRaw raw: String)
    package init(_ raw: String) throws
    package static func validated(_ raw: String) -> SecretValue?
    package func use<T>(_ body: (String) throws -> T) rethrows -> T
    package func constantTimeEquals(_ other: SecretValue) -> Bool
    package static func == (lhs: SecretValue, rhs: SecretValue) -> Bool
}
package enum OAuthCredentialFlow: Sendable, Equatable, Hashable {
    case chatGPT, generic
}
package struct OAuthCredentialBundle: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    package let accessToken: SecretValue
    package let refreshToken: SecretValue?
    package let idToken: SecretValue?
    package let accountID: SecretValue?
    package init(flow: OAuthCredentialFlow, accessToken: SecretValue,
                 refreshToken: SecretValue?, idToken: SecretValue?,
                 accountID: SecretValue?)
}
package struct OAuthCredentialAccounts: Sendable, Equatable {
    package static let live = OAuthCredentialAccounts(
        access: "oauth-access-token",
        refresh: "oauth-refresh-token",
        id: "oauth-id-token",
        accountID: "oauth-chatgpt-account-id",
        verifier: "oauth-code-verifier"
    )
    package let access: String
    package let refresh: String
    package let id: String
    package let accountID: String
    package let verifier: String
    package init(access: String, refresh: String, id: String,
                 accountID: String, verifier: String)
    fileprivate static func compatibility(
        access: String, refresh: String, id: String, accountID: String
    ) -> OAuthCredentialAccounts
}
package struct OAuthAuthorizationPreparation: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    package let state: SecretValue
    package let verifier: SecretValue
    fileprivate let coordinatorID: UUID
    fileprivate let accounts: OAuthCredentialAccounts
    fileprivate let envelopePhase: OAuthCredentialEnvelopePhase
    fileprivate init(flow: OAuthCredentialFlow, state: SecretValue,
                     verifier: SecretValue,
                     coordinatorID: UUID,
                     accounts: OAuthCredentialAccounts,
                     envelopePhase: OAuthCredentialEnvelopePhase)
}
fileprivate enum OAuthCredentialEnvelopePhase:
    String, Codable, Sendable, Equatable {
    case prepared
    case recoveryPrepared
    case initialCommitting
    case refreshCommitting
    case unauthorizedDeleteCommitting
}
fileprivate struct OAuthCredentialEnvelopeOwnerV1:
    Codable, Sendable, Equatable {
    let accessAccount: String
    let refreshAccount: String
    let idTokenAccount: String
    let accountIDAccount: String
    let envelopeAccount: String
}
fileprivate struct OAuthAuthorizationPreparationEnvelopeV1:
    Codable, Sendable, Equatable {
    let version: Int
    let phase: OAuthCredentialEnvelopePhase
    let owner: OAuthCredentialEnvelopeOwnerV1
    let flow: String
    let state: String
    let verifier: String
}
fileprivate struct OAuthCredentialMutationEnvelopeV1:
    Codable, Sendable, Equatable {
    let version: Int
    let phase: OAuthCredentialEnvelopePhase
    let owner: OAuthCredentialEnvelopeOwnerV1
    let flow: String
}
package struct OAuthCredentialReadSnapshot: Sendable, Equatable {
    package let accessToken: SecretValue?
    package let refreshToken: SecretValue?
    package let idToken: SecretValue?
    package let accountID: SecretValue?
    package init(accessToken: SecretValue?, refreshToken: SecretValue?,
                 idToken: SecretValue?, accountID: SecretValue?)
}
package struct OAuthRefreshCredentialRead: Sendable, Equatable {
    package let refreshToken: SecretValue
    fileprivate let coordinatorID: UUID
    fileprivate let accounts: OAuthCredentialAccounts
    fileprivate let revision: OAuthCredentialRevision
    fileprivate let snapshot: OAuthCredentialReadSnapshot
    fileprivate init(refreshToken: SecretValue,
                     coordinatorID: UUID,
                     accounts: OAuthCredentialAccounts,
                     revision: OAuthCredentialRevision,
                     snapshot: OAuthCredentialReadSnapshot)
}
fileprivate struct OAuthCredentialRevision: Sendable, Equatable {
    let valueByAccount: [String: UUID]
}
package struct RuntimeCredentialPresenceReadSnapshot: Sendable, Equatable {
    package let apiKey: String?
    package let searchKey: String?
    package let oauth: OAuthCredentialReadSnapshot
    fileprivate init(apiKey: String?, searchKey: String?,
                     oauth: OAuthCredentialReadSnapshot)
}
package enum OAuthAuthorizationPreparationCommitOutcome:
    Sendable, Equatable {
    case committed(CredentialMutationReceipt)
    case failed(CredentialBundleError)
    case unavailable(OAuthCredentialBundleUnavailableError)
}
package enum CredentialMutationKind: String, Sendable, Equatable {
    case access, refresh, id, accountID, oauthTransactionEnvelope,
         unauthorizedAccess, mcpSecret, mcpDatabaseRow
}
package enum McpDeletionMutationKind: String, Sendable, Equatable {
    case secret
    case databaseRow
}
package struct CredentialMutationReceipt: Sendable, Equatable {
    package let mutationCount: Int
    package init(mutationCount: Int)
}
package enum CredentialBundleError: Error, Sendable, Equatable {
    case preimageRead(flow: OAuthCredentialFlow, status: Int32?)
    case commit(flow: OAuthCredentialFlow, mutation: CredentialMutationKind,
                status: Int32?)
    case rollback(flow: OAuthCredentialFlow, status: Int32?)
    case preimageChanged(flow: OAuthCredentialFlow)
    case unauthorizedDelete(status: Int32?)
    case authorizationPreparationCommit(status: Int32?)
}
package enum McpCredentialDeletionError: Error, Sendable, Equatable {
    case preimageRead(status: Int32?)
    case commit(mutation: McpDeletionMutationKind, status: Int32?)
    case rollback(status: Int32?)
}
public enum CredentialStoreBackendNamespace: Hashable, Sendable {
    case legacyShared
    case keychainService(String)
    case isolated(UUID)
}
public protocol CredentialStore: Sendable {
    var backendNamespace: CredentialStoreBackendNamespace { get }
    func set(_ value: String, account: String) throws
    func get(account: String) throws -> String?
    func get(account: String,
             interactionPolicy: KeychainInteractionPolicy) throws -> String?
    func delete(account: String) throws
}
public extension CredentialStore {
    var backendNamespace: CredentialStoreBackendNamespace { .legacyShared }
    func get(account: String,
             interactionPolicy: KeychainInteractionPolicy) throws -> String? {
        try get(account: account)
    }
}
fileprivate final class CredentialMutationScopeToken {}
fileprivate struct CredentialMutationStore {
    private let store: any CredentialStore
    private let processState: CredentialAccessProcessState
    private let scopeToken: CredentialMutationScopeToken
    fileprivate init(store: any CredentialStore,
                     processState: CredentialAccessProcessState,
                     scopeToken: CredentialMutationScopeToken)
    fileprivate func read(account: String,
                          interactionPolicy: KeychainInteractionPolicy) throws -> String?
    fileprivate func set(_ value: SecretValue, account: String) throws
    fileprivate func delete(account: String) throws
    fileprivate func oauthCredentialRevision(
        accounts: OAuthCredentialAccounts
    ) -> OAuthCredentialRevision
    fileprivate func advanceOAuthCredentialRevision(
        accounts: OAuthCredentialAccounts
    ) -> OAuthCredentialRevision
}
fileprivate final class CredentialAccessProcessState: @unchecked Sendable {
    let lock = NSLock()
    struct OAuthRevisionKey: Hashable, Sendable {
        let backendNamespace: CredentialStoreBackendNamespace
        let account: String
    }
    var oauthRevisionByBackendAccount: [OAuthRevisionKey: UUID] = [:]
}
package final class SynchronizedCredentialAccess: @unchecked Sendable {
    private static let processState = CredentialAccessProcessState()
    package let backendNamespace: CredentialStoreBackendNamespace
    package init(store: any CredentialStore)
    package func read(account: String,
                      interactionPolicy: KeychainInteractionPolicy) throws -> String?
    package func read(
        accounts: [String],
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> [String?]
    package func readOAuthCredentials(
        accounts: OAuthCredentialAccounts,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> OAuthCredentialReadSnapshot
    package func readRuntimeCredentialPresence(
        apiKeyAccount: String,
        searchKeyAccount: String,
        oauthAccounts: OAuthCredentialAccounts,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> RuntimeCredentialPresenceReadSnapshot
    fileprivate func withExclusiveAccess<T: Sendable>(
        _ body: (CredentialMutationStore) throws -> T
    ) rethrows -> T
}
package actor CredentialBundleCoordinator {
    nonisolated package let synchronizedAccess: SynchronizedCredentialAccess
    private let coordinatorID: UUID
    package init(access: SynchronizedCredentialAccess)
    package func commitInitial(_ bundle: OAuthCredentialBundle,
                               basedOn preparation: OAuthAuthorizationPreparation,
                               interactionPolicy: KeychainInteractionPolicy) throws
        -> CredentialMutationReceipt
    package func readAuthorizationPreparation(
        flow: OAuthCredentialFlow,
        accounts: OAuthCredentialAccounts,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> OAuthAuthorizationPreparation
    package func commitAuthorizationPreparation(
        flow: OAuthCredentialFlow,
        state: SecretValue,
        verifier: SecretValue,
        accounts: OAuthCredentialAccounts,
        interactionPolicy: KeychainInteractionPolicy
    ) -> OAuthAuthorizationPreparationCommitOutcome
    package func commitRefresh(_ bundle: OAuthCredentialBundle,
                               basedOn read: OAuthRefreshCredentialRead,
                               interactionPolicy: KeychainInteractionPolicy) throws
        -> CredentialMutationReceipt
    package func readRefreshCredential(
        accounts: OAuthCredentialAccounts,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> OAuthRefreshCredentialRead?
    package func deleteUnauthorizedAccess(basedOn read: OAuthRefreshCredentialRead,
                                           interactionPolicy: KeychainInteractionPolicy) throws
        -> CredentialMutationReceipt
    package func commitMcpServerDeletion(
        secretAccounts: [McpCredentialAccount],
        interactionPolicy: KeychainInteractionPolicy,
        deleteDatabaseRow: @escaping @Sendable () throws -> Void
    ) -> Result<CredentialMutationReceipt, McpCredentialDeletionError>
}
fileprivate enum CredentialStoreAttempt<Value: Sendable>: Sendable {
    case value(Value)
    case failure(osStatus: Int32?)
}
fileprivate extension CredentialBundleCoordinator {
    nonisolated static func primaryAttempt<Value: Sendable>(
        _ body: () throws -> Value
    ) -> CredentialStoreAttempt<Value>
    nonisolated static func rollbackAttempt<Value: Sendable>(
        _ body: () throws -> Value
    ) -> CredentialStoreAttempt<Value>
}
```

These five live account literals remain the one shared preferred web-credential
bundle; Revision03 does not invent per-flow Keychain coordinates or migration.
The `verifier` coordinate now stores one versioned OAuth transaction envelope.
Each envelope contains one nested five-coordinate owner whose exact values are
the access, refresh, ID, account-ID, and envelope accounts of the protected
`OAuthCredentialAccounts`. The six-key
`.prepared`/`.recoveryPrepared`/`.initialCommitting` forms contain version,
phase, owner, closed flow, state, and verifier; the four-key
`.refreshCommitting` and `.unauthorizedDeleteCommitting` forms contain version,
phase, owner, and the closed `.chatGPT` flow. The owner strings are never
logged, diagnosed, normalized, hashed, or used as a derived Keychain account,
and the envelope item is never a raw verifier item. `.prepared` permits the
previous committed OAuth credential bundle to remain usable while browser
authorization is outstanding. `.recoveryPrepared` and every committing phase
quarantine every OAuth credential read before a possibly mixed bundle can be
returned. That quarantine survives a process crash and a replacement browser
authorization by the **same exact envelope owner**; it ends only when that
owner's replacement callback durably writes its complete bundle and deletes
the envelope last. The controller's global lifecycle exclusivity spans the complete
authorization-to-callback-cleanup interval, so there is at most one live
envelope owner and another flow cannot overwrite or delete it in-process.
Across process restart the durable envelope remains self-identifying. A fresh
globally sole reservation for the exact same five-coordinate owner may
atomically replace its canonical recovery/committing envelope with
`.recoveryPrepared` without exposing any old or partial credential, while an
old callback is rejected by the new controller owner and exact returned-state
comparison. A different owner cannot replace, downgrade, or delete that
quarantine and receives the fixed typed bundle-unavailable terminal. The
credential coordinator still serializes every short Keychain transaction; it
is not misrepresented as protection for the longer browser interval.

Those five literals occur in production only in `OAuthCredentialAccounts.live`.
`RuntimeProfileBootstrap.oauthAccessTokenCredentialAccount` is an alias of
`.live.access`; it owns no literal. App's Runtime bundle, strict resolver,
Session, callback/refresh coordinator, presence reads, and controller all
receive or project that one value. A source gate rejects any second production
copy of those five fixed live coordinates, static-init reverse dependency,
profile-derived App OAuth coordinate, or field-by-field reconstruction; tests
may construct a custom bundle only as an explicit fixture. The public
compatibility factory owns no second namespace literal: it explicitly projects
`OAuthCredentialAccounts.live.verifier` as the one backend-global transaction
envelope. It may construct custom credential-field coordinates, but every
Session/coordinator over the same `CredentialStore` namespace observes the
same durable quarantine item. App production still receives the complete live
bundle rather than calling the compatibility factory.

Every coordinator OAuth entry first validates that all five account
coordinates have nonempty UTF-8 bytes and are pairwise distinct under exact
String equality;
coordinate spelling is not trimmed or normalized. An invalid
bundle throws the same fixed safe `OAuthCredentialBundleUnavailableError`,
except the deliberately nonthrowing `commitAuthorizationPreparation`, which
returns `.unavailable(OAuthCredentialBundleUnavailableError())`,
before process revision, lock/store, HTTP, Reporter, or callback work; a
nonthrowing public initializer therefore preserves its signature without ever
performing ambiguous fieldwise mutations. `.live` is source-proven valid.
MCP and API/Search coordinates are outside this five-value proof.
The private envelope owner is constructed only after that proof and is the
one-to-one ordered projection of those exact five strings. Decoding requires
the nested owner object to have exactly those five keys and later owner
comparisons use exact String equality over all five coordinates; there is no
partial, credential-fields-only, verifier-only, hash, prefix, or normalized
owner match.

The gate is one process-global `CredentialAccessProcessState` containing one
`NSLock` and one private revision registry keyed by the closed pair
`(CredentialStoreBackendNamespace, OAuth account coordinate)`. The public
protocol requirement has the source-compatible default witness
`.legacyShared`. Existing external conformers that do not yet opt into an
explicit namespace therefore continue to compile and conservatively share one
revision domain: they may invalidate an unrelated legacy proof, but they can
never miss an overlapping mutation. The default is a stable enum value and
must not mint a UUID, derive object identity, or inspect account strings.
Backends that promise independence must opt in explicitly: every
`KeychainStore` with the same exact service returns the same
`.keychainService(service)`, while each memory/recording backend instance owns
one stored `.isolated(UUID)` that all wrappers over that instance reuse.
Different backend instances must not reuse an isolated UUID. Every
`SynchronizedCredentialAccess`, including instances made by the
source-compatible public Session initializer, uses the exact static lock/state
and freezes the store's namespace at initialization; it cannot create a private
lock or revision. Resolver reads and every mutation use the same lock. The
coordinator's private mutation body receives an already-locked
`CredentialMutationStore`, whose revision accessors are fileprivate and valid
only during that call, and may neither await nor reenter
`SynchronizedCredentialAccess`. Each coordinator command first reads
all pre-images with zero writes, performs the frozen fixed-order mutations, and
on first error restores changed credential fields in reverse order before
releasing the lock. The envelope may return to its pre-command phase/absence
only after every changed credential field has restored successfully. If any
field restoration fails, the command leaves the committing envelope in place
and does not execute its final envelope restore/delete; that durable quarantine
is part of the critical rollback terminal. If all fields restore but the final
envelope restore/delete fails, the remaining committing or otherwise
noncanonical item is likewise fail-closed. A rollback error yields only the
critical rollback case; otherwise the primary commit case remains.
Initial/refresh/generic absence behavior is exactly §6.4. Keychain
item-not-found alone is nil; a successful SecItem read whose
Data is not UTF-8 throws `CredentialValueInvalidError`. No wrapper implements
CustomStringConvertible or exposes raw access outside `SecretValue.use`.

Every coordinator initializer mints one private `coordinatorID`; a refresh
proof retains that identity together with its exact accounts, revision, and
snapshot. `commitRefresh` and `deleteUnauthorizedAccess` accept no caller-
supplied accounts and first require `read.coordinatorID == self.coordinatorID`
before entering the revision/credential gate. They use only `read.accounts`
thereafter. A proof from another coordinator therefore returns
`.preimageChanged(flow:.chatGPT)` with zero lock/store, revision, Reporter,
HTTP-result, or permanent-failure work even if its revision and credential
bytes happen to match. The proof initializer and all binding fields remain
fileprivate; there is no proof-free, caller-account, or cross-coordinator
overload.

The process-global synchronized state owns a process-local opaque revision for
each exact backend-namespace/account pair. A proof snapshots the current
entries for its access object's backend namespace and exact five-coordinate
bundle. While holding the lock,
`oauthCredentialRevision(accounts:)` installs one fresh UUID for each missing
coordinate before returning the complete five-entry snapshot; a second read
without an intervening mutation reuses those exact values. No proof can contain
an absent/default revision entry. Every OAuth mutation attempt assigns fresh UUIDs to
all five distinct coordinates while holding the same lock and before its first
credential I/O—even when the attempt later fails without a durable change.
Thus bundles in the **same backend namespace** whose five-coordinate sets
intersect invalidate one another, while a genuinely five-coordinate-disjoint
fixture in that backend and every fixture in a different **explicit** backend
namespace do not produce false stale terminals. Two conformers using the
`.legacyShared` default intentionally belong to the same conservative domain
even when their storage instances are unrelated. Public compatibility bundles over one
backend intentionally intersect at the shared envelope coordinate even when
their four supplied credential accounts are otherwise disjoint.
`readRefreshCredential`
captures the exact accounts plus their revision snapshot with its locked
credential preimage. A refresh commit or permanent-unauthorized delete first
passes the coordinator-identity guard above, then compares the proof's revision
snapshot for `read.accounts` and advances those five entries inside that same
lock before any credential read/write; mismatch
throws `.preimageChanged(flow:.chatGPT)` with zero Keychain mutation,
Reporter, permanent-failure callback, or success return. The command then
rechecks the absent envelope and byte-equal full credential snapshot under the
lock before its first write; a changed snapshot produces the same terminal.
Because all access instances share the lock and namespace-qualified registry,
this process-local capability closes an HTTP-await race with every coordinator
mutation in the same backend, including a second public compatibility Session
and an ABA that restored byte-equal credential fields on an overlapping
account. Within one backend, two account bundles are revision-disjoint only
when **all five** coordinates, including their envelope accounts, are disjoint.
A mutation of one such genuinely disjoint custom bundle does not invalidate the
other's proof. Public compatibility bundles over one backend are never
five-coordinate-disjoint because they intentionally share
`OAuthCredentialAccounts.live.verifier`; even when their four credential-field
coordinates are disjoint, their proofs deliberately invalidate one another at
that shared coordinate. A process crash destroys all old HTTP Tasks/proofs, while the durable
envelope separately closes crash visibility; neither mechanism is claimed as a
cross-process mutex. App production's already-required `StateDirectoryLock`
remains held for the complete process lifetime and is the explicit
single-writer process boundary for the shared app state/Keychain namespace; a
fresh process may recover a durable envelope only after that lock proves the
old process is gone. The source-compatible public Session initializer promises
same-process serialization plus crash quarantine, not coordination among
unrelated external processes that do not share AgentLoop's process lock.

The coordinator introduces no third catch for the atomic envelope. Every
concrete preimage/read/encode/set/delete in all OAuth and MCP commands is called
through `primaryAttempt`; every reverse restoration is called through
`rollbackAttempt`. Those two helpers own the existing exact typed planned catch
markers `N[.credentialBundlePrimaryFailure]` and
`N[.credentialBundleRollbackFailure]` respectively, reduce a Keychain error to
optional OSStatus, discard every other raw Error, and return only the closed
attempt enum. High-level commands exhaustively switch that value and attach
their already-known flow/mutation domain; they never catch.
`commitAuthorizationPreparation` therefore returns `.failed` after a Keychain
pre-read or its one set, and `.unavailable` either after pre-lock coordinate
validation or after a readable envelope proves that an owner-mismatched or
unprovable durable quarantine may not be replaced. It adds no lexical catch,
while initial/refresh/delete/MCP retain their closed typed throw/Result
surfaces. Inventory regenerates the two
planned DeclarationIDs from these helper names; planned-catch/global-N/
descriptor/resolution cardinalities do not change.

Authorization preparation is one single-item Keychain command. While holding
the shared credential lock it first reads the exact existing envelope item and
decodes both phase and durable five-coordinate owner. An absent item selects
ordinary `.prepared`. A canonical `.prepared` item from any valid owner may be
atomically replaced by ordinary `.prepared` for the requested owner because
that phase proves no credential mutation has begun; the old callback remains
rejected by controller ownership and returned-state comparison. A canonical
`.recoveryPrepared` or committing item selects `.recoveryPrepared` only when
its owner exactly equals the requested five-coordinate bundle. If such a
quarantine names a different owner, or if a legacy raw verifier,
malformed/noncanonical JSON, unknown version/phase, invalid owner object, or
otherwise unprovable item has no exact owner, preparation returns
`.unavailable(OAuthCredentialBundleUnavailableError())` with the item
byte-identical and zero writes. It may never claim that an arbitrary readable
item belongs to the requested bundle. A failed Keychain pre-read instead
returns `.failed(.preimageRead(flow:status:))` with zero writes.

The command encodes the exact closed payload
`{flow,owner:{accessAccount,accountIDAccount,envelopeAccount,idTokenAccount,refreshAccount},phase:<selected>,state,verifier,version:1}`
with a fresh private `JSONEncoder` whose only output formatting is
`.sortedKeys`, wraps those UTF-8 bytes as a `SecretValue`, and performs exactly
one `CredentialMutationStore.set` at `accounts.verifier`. `KeychainStore.set`
is one SecItem update-or-add whose failed Security call cannot partially
replace an item; therefore a failed set preserves the exact
previous-or-absent item and returns
`.failed(.authorizationPreparationCommit(status:))`; it is genuinely not
committed. Successful `set` is the sole atomic commit point and returns
`CredentialMutationReceipt(mutationCount: 1)`; there is no post-write reread
whose failure could misreport an already committed item as not committed.
Canonicality is proven from the locally encoded bytes before the set and
independently enforced by every later reader. There is no state-store closure,
second write, reverse restoration, rollback UUID, retry capability, state lock,
or lock-order decision.

`readAuthorizationPreparation` reads exactly one item, accepts no legacy raw
verifier, validates UTF-8 plus strict canonical JSON bytes/keys/version/phase/
owner/flow/nonblank values, and returns the closed preparation only for
canonical `.prepared` or `.recoveryPrepared` whose owner equals the requested
five accounts and whose flow matches the requested flow. The returned proof
binds the originating coordinator ID and exact accounts in addition to its
private `envelopePhase`; none can be constructed or changed by App/controller
callers. Decode is strict by first
reading only the phase discriminator, then decoding the corresponding private
six-key preparation DTO or four-key mutation DTO plus the exact nested
five-key owner, requiring each exact key set, re-encoding it with the same
encoder, and requiring byte equality with the
stored UTF-8; this rejects
duplicate keys, extra keys, whitespace/key-order drift, or alternate spellings
without a second parser or raw logging. Absence maps to
`RuntimeOAuthBoundaryError.stateMissing`; malformed, noncanonical,
unknown-version/phase, extra/missing-key, duplicate-key, wrong-owner,
wrong-flow, or blank payload
maps to `RuntimeOAuthBoundaryError.stateMismatch`; neither failure exposes the
item. Production no longer reads or writes the historical UserDefaults OAuth
state key. A source gate rejects `oauthStateKey`, `UserDefaults` state
read/write/remove, a second authorization-preparation coordinate, and any raw
verifier interpretation.

Every production OAuth credential consumer enters the same synchronized gate
and decodes the envelope before reading a credential field. An absent envelope
or canonical `.prepared` envelope permits the snapshot; `.recoveryPrepared`,
any canonical committing phase, malformed/noncanonical bytes, an unknown
version/phase, or an invalid closed value throws
`OAuthCredentialBundleUnavailableError` before any OAuth credential is
returned. `readOAuthCredentials` then reads access,
refresh, ID, and account-ID in that exact order in the same lock and constructs
one all-or-nothing `OAuthCredentialReadSnapshot`; blank/invalid present values
throw rather than becoming nil. `readRuntimeCredentialPresence` performs one
lock acquisition and exact order API key, Search key, envelope, access,
refresh, ID, account-ID. Runtime provider resolution, Runtime presence,
App's production `PlanningCredentialSource` use one of those two methods; the
package `OpenAIOAuthSession` uses the coordinator's stricter absent-envelope
`readRefreshCredential`. The Planning source may
retain a default sequential fixture implementation for existing test
conformers, but the App production conformance must override it with the shared
snapshot; the Strict resolver never calls two production OAuth item reads.

`commitInitial` accepts the exact previously read
`OAuthAuthorizationPreparation` and no caller-supplied accounts. Before
entering the credential lock it requires the proof's private coordinator ID to
equal `self.coordinatorID`; a proof from another coordinator returns
`.preimageChanged(flow:)` with zero lock, revision, credential, Reporter, or
callback work. It then requires `bundle.flow == preparation.flow` before that
lock; mismatch returns `.preimageChanged(flow:preparation.flow)` with the same
zero-work boundary. It thereafter uses only the proof-bound accounts. Under the same
lock it reads every credential preimage and requires the current canonical
envelope to equal that preparation, including its exact owner and `.prepared`
or `.recoveryPrepared` phase. Its fixed mutation order is: replace that one
item with the same flow/state/verifier and exact owner in
`.initialCommitting`; set access; set-or-delete refresh;
set-or-delete ID; set-or-delete account ID; delete the envelope last. Generic
always deletes ID/account ID and ChatGPT requires its derived account ID. Any
failure restores changed fields in reverse order and restores the exact
pre-commit envelope phase and bytes last only if every field restoration
succeeds. Any field rollback failure suppresses that last envelope restoration
and leaves `.initialCommitting`; a failure of the final envelope restoration
also leaves a fail-closed item. Thus no consumer can observe the mixed
post-crash/post-rollback bundle. Restoring `.recoveryPrepared` preserves rather
than weakens quarantine.
After a process crash at any point following the phase transition, the durable
committing item keeps all OAuth consumers fail-closed. A fresh globally sole
authorization may replace it only when the committing item's exact owner
equals the requested accounts, and then only with owner-equal
`.recoveryPrepared`; that same-owner replacement authorization and callback are
the sole recovery. A different owner, or an item whose canonical owner cannot
be proven, remains unavailable and byte-identical. The old or partially mutated
bundle remains quarantined throughout the same-owner browser interval. There is no
raw-token fallback, journal replay, or hidden mixed-bundle acceptance. Success
deletes the envelope only after all replacement fields are durable, making the
new bundle visible atomically to later locked readers.

Background refresh and permanent-unauthorized delete require an absent
envelope. `readRefreshCredential` performs that proof and, in one lock before
network I/O, reads access, refresh, ID, and account-ID in that order. A missing
refresh returns nil after the access/refresh prefix and creates no proof. A
present strict refresh returns one opaque `OAuthRefreshCredentialRead` carrying
the full all-or-nothing snapshot plus the process-state current revision;
`.prepared`,
`.recoveryPrepared`, any committing phase, or malformed/noncanonical bytes
throws the typed unavailable error. After HTTP, `commitRefresh` accepts only
that proof, first requires `bundle.flow == .chatGPT` before the lock, and maps a
flow mismatch to `.preimageChanged(flow:.chatGPT)` with zero lock/revision/
credential/Reporter/permanent-failure work. It then validates revision before credential I/O, advances revision,
revalidates absence plus the byte-equal full snapshot under the lock, and only
then writes canonical
`.refreshCommitting` before access/refresh/ID/account mutations, compensates in
reverse, and deletes the sentinel last only after every forward mutation or
field restoration succeeds as applicable. Permanent-unauthorized access
deletion accepts the same proof from that HTTP request and performs the same
revision/snapshot/absence validation before its
`.unauthorizedDeleteCommitting` write, access delete, reverse compensation, and
sentinel delete. Any revision/snapshot mismatch throws `.preimageChanged`
without invoking `onPermanentFailure`; any
rollback failure keeps its committing sentinel; a crash does the same and
therefore preserves quarantine. No Session construction maps quarantine to a
missing token or invokes permanent-failure cleanup for quarantine. The package
initializer captures/rethrows the typed safe terminal on its own
refresh/delete trace; the public compatibility initializer, which has no
reporter parameter, rethrows the same typed terminal for its external caller
without fabricating an internal reporter. The public compatibility initializer
signature and caller boundary remain source-compatible and are forbidden in App
production composition, but its unsafe fieldwise implementation is replaced: it
constructs its account bundle through
`OAuthCredentialAccounts.compatibility(access:refresh:id:accountID:)`, then
constructs a `SynchronizedCredentialAccess` and coordinator over that exact
bundle. Because every access instance uses the process-global lock plus its
store's stable backend namespace, the same Revision03 mutation, HTTP-await, and crash-quarantine guarantees apply
to this source-compatible path as well as the package production path.

Interaction policy is operation-owned: synchronous bootstrap, provider/search
resolution, background OAuth refresh and permanent-unauthorized cleanup, MCP
secret-provider reads, settings presence refresh, and preview use
`.failIfInteractionRequired`; foreground OAuth callback commit and explicit
Settings credential save/delete or MCP-server deletion use `.allow`.
`CredentialBundleCoordinator` applies the one passed policy to every pre-image
read in that critical section. A mixed policy inside a bundle is forbidden.
The policy-injection tests assert every read and prove preview performs none.

OpenAIOAuthSession keeps its existing public initializer signature and caller
boundary exactly source-compatible for closed callers/tests; its former
fieldwise mutation implementation is replaced rather than retained. The
initializer constructs one private access/coordinator over a
compatibility bundle whose four credential-field coordinates are the supplied
strings and whose transaction-envelope coordinate is exactly
`OAuthCredentialAccounts.live.verifier`. The fixed backend-global envelope is
deliberate: every public compatibility Session sharing a CredentialStore
namespace, including distinct or partially overlapping four-account tuples,
observes the same durable crash quarantine before it can expose any credential
field. A per-tuple derived sentinel is forbidden because a process crash after
a partial write through tuple A could otherwise leave tuple B's different
sentinel absent while B reads an overlapping mutated field. The five resulting
coordinates must be nonempty and pairwise distinct, so any supplied credential
account equal to the global envelope coordinate fails with the fixed typed
bundle-unavailable terminal before lock/store/HTTP/callback work. This path
intentionally serializes and conservatively quarantines even disjoint public
compatibility tuples in the same backend; the backend/account revision registry
prevents missed same-backend staleness and prevents false cross-backend stale
HTTP terminals for explicitly namespaced backends during ordinary same-process
work. Legacy-default conformers deliberately accept conservative false stale
terminals to retain source compatibility without inventing an unsafe identity.
The factory owns no derived namespace, hash, encoding, suffix search, or second
envelope literal. The new shared initializer is exact:

```swift
extension OpenAIOAuthSession {
    public init(store: any CredentialStore,
                accessTokenAccount: String,
                refreshTokenAccount: String,
                idTokenAccount: String,
                chatGPTAccountIDAccount: String,
                tokenEndpoint: URL = OpenAIChatGPTAuth.tokenEndpoint,
                session: URLSession = .shared,
                onPermanentFailure: (@Sendable () -> Void)? = nil)
    package init(coordinator: CredentialBundleCoordinator,
                 accounts: OAuthCredentialAccounts,
                 failureReporter: FailureReporter,
                 traceFactory: OperationTraceFactory,
                 tokenEndpoint: URL = OpenAIChatGPTAuth.tokenEndpoint,
                 session: URLSession = .shared,
                 onPermanentFailure: (@Sendable () -> Void)? = nil)
}
```

The public initializer delegates all refresh reads, refresh commits, and
permanent-unauthorized cleanup to its private coordinator; the old direct
`store.get/set/delete` fields and fieldwise refresh/delete methods are removed.
Two public Session instances always share the process lock, but revisions
intersect only when their backend namespaces and account coordinates intersect.
Two wrappers over the same store reuse its exact namespace; two independent
explicitly namespaced memory stores use distinct namespaces and cannot
invalidate one another, while legacy-default stores intentionally intersect.
Tests freeze the exact compatibility envelope
coordinate for non-ASCII, delimiter-like, and long nonempty distinct account strings as the
same exact `.live.verifier` global envelope, and prove it is distinct from every
supplied credential coordinate; empty, duplicate, or global-envelope-colliding
fixtures return/throw the fixed unavailable terminal with zero store/HTTP/
callback work. An initially empty process revision registry is seeded to five
opaque entries by the first locked proof read, a second proof sees the same
entries, and the next mutation changes all five. They then run two
Session instances over one store through refresh/refresh and
refresh/unauthorized interleavings; and prove one stale HTTP proof returns
`.preimageChanged` before write/callback while the winner's complete bundle is
preserved. The package initializer derives access only from
`coordinator.synchronizedAccess`; it accepts no separate store/access and so a
mismatched lock is unrepresentable. Initial callback and
refresh therefore cannot use different locks. This package initializer is the
only production composition path: it retains the reporter/factory and a fixed
global OAuth FailureTraceScope; the public initializer remains source
compatibility for closed external/tests and is forbidden in App production
composition. When the Session creates the one shared `inFlightRefresh` Task it
mints exactly one `.oauthRefreshCommit` trace before the first token/network/
Keychain action; all waiters adopt that Task and its trace and never create
their own. If permanent unauthorized cleanup is required, immediately before
that cleanup's first credential read/write it mints a distinct
`.oauthUnauthorizedDelete` trace. Each owner captures its typed terminal once
through the reporter and then rethrows the sanitized typed provider/session
error; it never attributes a later refresh to the synchronous Runtime provider
resolution trace. RuntimeCredentialResolver merely hands this traced refresh
closure to the provider and does not claim to execute/map its later async
failure. Non-2xx response Data is reduced
inside the actor to HTTP status + fixed category before throwing and is never
stored on an Error.

```swift
package enum McpServerStatusSummary: Sendable, Equatable {
    case stopped
    case starting
    case running(toolCount: Int)
    case down
}
package struct McpRegistrySnapshot: Sendable {
    package let servers: [McpServerRecord]
    package let statuses: [String: McpServerStatusSummary]
    package init(servers: [McpServerRecord],
                 statuses: [String: McpServerStatusSummary])
}
package struct McpCampSnapshot: Sendable, Equatable {
    package let campId: String
    package let enabledServerIds: Set<String>
    package init(campId: String, enabledServerIds: Set<String>)
}
package struct McpToolSnapshot: Sendable {
    package let serverId: String
    package let tools: [McpServerManager.AssembledTool]
    package init(serverId: String, tools: [McpServerManager.AssembledTool])
}
package struct CompanionEditorSnapshot: Sendable {
    package let companion: CompanionRecord
    package let toolAccess: ToolAccess
    package let selectedProfile: RuntimeProfileRecord
    package let availableModels: [String]
    package let modelSelection: CompanionEditorModelSelection
    package init(companion: CompanionRecord, toolAccess: ToolAccess,
                 selectedProfile: RuntimeProfileRecord,
                 availableModels: [String],
                 modelSelection: CompanionEditorModelSelection)
}
package enum CompanionEditorModelSelection: Sendable, Equatable {
    case preserved(String)
    case selectedFirstForMissingValue(String)
    case manualEntryRequired
}
package enum McpServerDraftConfiguration: Sendable, Equatable {
    case template(args: [String], env: [String: String],
                  secretEnvironmentKeys: [String])
    case custom(argsLine: String, envLines: String,
                secretKeysLine: String)
}
package struct McpServerDraft: Sendable, Equatable {
    package let name: String
    package let command: String
    package let configuration: McpServerDraftConfiguration
    package let experimental: Bool
    package init(name: String, command: String,
                 configuration: McpServerDraftConfiguration,
                 experimental: Bool)
}
package enum McpSecretMutation: Sendable, Equatable {
    case set(SecretValue)
    case delete
}
package struct McpSecretMutationReceipt: Sendable, Equatable {
    package let serverId: String
    package let present: Bool
    package init(serverId: String, present: Bool)
}
package struct McpServerDeletionReceipt: Sendable, Equatable {
    package let serverId: String
    init(cleanedLease: McpMaintenanceLease) {
        self.serverId = cleanedLease.serverId
    }
}
package struct McpServerDeletionRetryReceipt: Sendable, Equatable {
    package let serverId: String
    init(cleanedRollback: McpPendingRollbackCleanup) {
        self.serverId = cleanedRollback.serverId
    }
}
package struct McpPendingRollbackCleanup: Sendable, Equatable {
    package let serverId: String
    let traceScope: FailureTraceScope
    let lease: McpMaintenanceLease
    init(lease: McpMaintenanceLease, traceScope: FailureTraceScope) {
        self.serverId = lease.serverId
        self.traceScope = traceScope
        self.lease = lease
    }
}
package struct McpPendingDeletedServerCleanup: Sendable, Equatable {
    package let serverId: String
    let traceScope: FailureTraceScope
    let lease: McpMaintenanceLease
    init(lease: McpMaintenanceLease, traceScope: FailureTraceScope) {
        self.serverId = lease.serverId
        self.traceScope = traceScope
        self.lease = lease
    }
}
package enum McpPendingServerCleanup: Sendable, Equatable {
    case rollback(McpPendingRollbackCleanup)
    case deleted(McpPendingDeletedServerCleanup)
    package var serverId: String {
        switch self {
        case .rollback(let value): value.serverId
        case .deleted(let value): value.serverId
        }
    }
    var traceScope: FailureTraceScope {
        switch self {
        case .rollback(let value): value.traceScope
        case .deleted(let value): value.traceScope
        }
    }
}
package enum McpServerDeletionPortResult: Sendable, Equatable {
    case notCommitted(McpServerDeletionFailure)
    case notCommittedCleanupPending(
        primary: McpCredentialDeletionError,
        cleanup: McpMaintenanceCleanupError,
        pending: McpPendingRollbackCleanup
    )
    case committed(McpServerDeletionReceipt)
    case committedCleanupPending(
        cleanup: McpMaintenanceCleanupError,
        pending: McpPendingDeletedServerCleanup
    )
}
package enum McpServerDeletionOutcome: Sendable, Equatable {
    case notCommitted(UserVisibleFailure)
    case notCommittedCleanupPending(
        pending: McpPendingRollbackCleanup,
        failure: UserVisibleFailure
    )
    case committed(McpServerDeletionReceipt)
    case committedCleanupPending(
        pending: McpPendingDeletedServerCleanup,
        failure: UserVisibleFailure
    )
}
package enum McpServerCleanupOutcome: Sendable, Equatable {
    case deletionRetryReady(McpServerDeletionRetryReceipt)
    case deletionCommitted(McpServerDeletionReceipt)
    case pending(McpPendingServerCleanup, failure: UserVisibleFailure)
}
package enum McpCleanupApplyGuard {
    package static func mayApply(
        currentPending: McpPendingServerCleanup?,
        capturedPending: McpPendingServerCleanup,
        currentAttempt: UUID?,
        capturedAttempt: UUID
    ) -> Bool
}
package struct McpWorkflowReads: Sendable {
    package let registry: @Sendable () async throws -> McpRegistrySnapshot
    package let enabled: @Sendable (String) throws -> Set<String>
    package let tools: @Sendable (String) async throws
        -> [McpServerManager.AssembledTool]
    package let secret: @Sendable (McpCredentialAccount,
                                   KeychainInteractionPolicy) throws -> Bool
    package let companionEditor:
        @Sendable (String) throws -> CompanionEditorSnapshot
    package init(registry: @escaping @Sendable () async throws
                    -> McpRegistrySnapshot,
                 enabled: @escaping @Sendable (String) throws -> Set<String>,
                 tools: @escaping @Sendable (String) async throws
                    -> [McpServerManager.AssembledTool],
                 secret: @escaping @Sendable (McpCredentialAccount,
                                               KeychainInteractionPolicy) throws -> Bool,
                 companionEditor: @escaping @Sendable (String) throws
                    -> CompanionEditorSnapshot)
    package static func live(database: AppDatabase, manager: McpServerManager,
                             access: SynchronizedCredentialAccess,
                             defaults: ProfileScopedDefaults) -> Self
}
package struct McpWorkflowPorts: Sendable {
    package let addServer: @Sendable (McpServerDraft) throws -> McpServerRecord
    package let startServer:
        @Sendable (String) async throws -> McpServerReady
    package let restartServer:
        @Sendable (String) async throws -> McpServerReady
    package let setEnabled:
        @Sendable (String, String, Bool) throws -> Void
    package let mutateSecret:
        @Sendable (String, String, McpSecretMutation,
                   KeychainInteractionPolicy) throws
            -> McpSecretMutationReceipt
    package let deleteServer:
        @Sendable (String, KeychainInteractionPolicy,
                   FailureTraceScope) async
            -> McpServerDeletionPortResult
    package let finishServerCleanup:
        @Sendable (McpPendingServerCleanup) async
            -> Result<Void, McpMaintenanceCleanupError>
    package let saveCompanion:
        @Sendable (CompanionRecord) throws -> CompanionRecord
    package init(
        addServer: @escaping @Sendable (McpServerDraft) throws
            -> McpServerRecord,
        startServer: @escaping @Sendable (String) async throws
            -> McpServerReady,
        restartServer: @escaping @Sendable (String) async throws
            -> McpServerReady,
        setEnabled: @escaping @Sendable (String, String, Bool) throws -> Void,
        mutateSecret:
            @escaping @Sendable (String, String, McpSecretMutation,
                                 KeychainInteractionPolicy) throws
                -> McpSecretMutationReceipt,
        deleteServer:
            @escaping @Sendable (String, KeychainInteractionPolicy,
                                 FailureTraceScope)
                async -> McpServerDeletionPortResult,
        finishServerCleanup:
            @escaping @Sendable (McpPendingServerCleanup) async
                -> Result<Void, McpMaintenanceCleanupError>,
        saveCompanion:
            @escaping @Sendable (CompanionRecord) throws -> CompanionRecord
    )
    package static func live(
        database: AppDatabase,
        manager: McpServerManager,
        credentialCoordinator: CredentialBundleCoordinator,
        reads: McpWorkflowReads
    ) -> Self
}
private struct McpCleanupFlight: Sendable {
    let attemptId: UUID
    let pending: McpPendingServerCleanup
    let task: Task<Result<Void, McpMaintenanceCleanupError>, Never>
}
package actor McpWorkflowController {
    private var cleanupFlightByServerId: [String: McpCleanupFlight] = [:]
    package init(database: AppDatabase, manager: McpServerManager,
                 credentialCoordinator: CredentialBundleCoordinator,
                 reporter: FailureReporter, reads: McpWorkflowReads? = nil,
                 ports: McpWorkflowPorts? = nil,
                 traceFactory: OperationTraceFactory = .live)
    package func loadRegistry(trace: OperationTrace) async
        -> WorkflowLoadState<McpRegistrySnapshot>
    package func loadCamp(campId: String, trace: OperationTrace) async
        -> WorkflowLoadState<McpCampSnapshot>
    package func loadTools(serverId: String, trace: OperationTrace) async
        -> WorkflowLoadState<McpToolSnapshot>
    package func secretPresence(serverId: String, key: String,
                        trace: OperationTrace) async
        -> WorkflowLoadState<Bool>
    package func loadCompanionEditor(companionId: String,
                                     trace: OperationTrace) async
        -> WorkflowLoadState<CompanionEditorSnapshot>
    package func setEnabled(campId: String, serverId: String, enabled: Bool,
                    trace: OperationTrace) async
        -> OperationCommitOutcome<Void>
    package func saveSecret(serverId: String, key: String,
                    mutation: McpSecretMutation,
                    trace: OperationTrace) async
        -> OperationCommitOutcome<McpSecretMutationReceipt>
    package func deleteServer(serverId: String, trace: OperationTrace) async
        -> McpServerDeletionOutcome
    package func finishServerCleanup(
        _ pending: McpPendingServerCleanup
    ) async -> McpServerCleanupOutcome
    package func restart(serverId: String, trace: OperationTrace) async
        -> OperationCommitOutcome<McpServerReady>
    package func saveCompanion(_ companion: CompanionRecord,
                               trace: OperationTrace) async
        -> OperationCommitOutcome<CompanionRecord>
    package func addServer(_ draft: McpServerDraft,
                           trace: OperationTrace) async
        -> OperationCommitOutcome<McpServerRecord>
    package func start(serverId: String, trace: OperationTrace) async
        -> OperationCommitOutcome<McpServerReady>
}
```

`McpWorkflowReads.companionEditor` performs one strict editor projection. It
requires the Companion and its selected/default Runtime profile, obtains the
profile-scoped resolved catalog through the same strict defaults/catalog
helpers used by Runtime workflow, and returns no partially loaded snapshot.
Read/corruption/unloaded state throws and the editor preserves its previous
form. A persisted nonblank model is always represented as `.preserved`, even
when it is no longer in the catalog; load never overwrites it with the first
item. Only a genuinely missing selection after a successful nonempty catalog
may produce `.selectedFirstForMissingValue`. A successfully resolved legal
empty manual catalog produces `.manualEntryRequired`; the accepted named
factory fallback may be used only by the strict catalog resolver, never as a
response to read failure. Consequently the View has no `global catalog`, empty
String, or `first ??` failure branch.

`addServer` receives the raw custom text, not an App-preparsed record. It
validates name/command/args/env/secret-key JSON before the first write; every
nonblank env line must contain exactly one nonempty key and value, so malformed
lines never disappear through `continue`. Template arrays/maps are validated
without reordering args; custom args retain the accepted whitespace-splitting
rule, and canonical JSON uses sorted keys. `start` and `restart`
consume Manager's typed Result, never a status String. A start that reaches
running returns the exact `McpServerReady`; its registry reload is a separate
post-commit projection and may not repeat the start. Adding and starting are
distinct seams and commit points: a committed registry row never claims that a
process is running. A legacy empty secret maps explicitly to
`McpSecretMutation.delete`; it is never passed to the nonblank `SecretValue`
initializer. The
live ports contain no App toast, file picker, or view state; McpStore maps its
existing Template/custom form into a complete `McpServerRecord` and calls these
methods. Filesystem directory selection remains an App-only precondition and
does not count as a successful add until the controller commits the record.

MCP account derivation is Core-owned rather than duplicated in App:

```swift
package struct McpCredentialAccount: Sendable, Equatable, Comparable {
    package let rawValue: String
    package init(server: McpServerRecord,
                 secretEnvironmentKey: String) throws
    package static func < (lhs: Self, rhs: Self) -> Bool
}
```

The initializer strictly decodes the server's `secretEnvKeysJson`, requires
the requested key to be listed and to match
`[A-Za-z_][A-Za-z0-9_]{0,127}`, then creates the existing exact account format
`mcp-<server.id>-<key>`. `rawValue` never enters diagnostics. Comparison is
UTF-8 byte order. McpStore and the Manager secret provider both delegate to
this type; the App-local `secretAccount` helper is deleted.

MCP deletion uses the shared coordinator's exact high-level
`commitMcpServerDeletion`, not a caller-supplied low-level lock primitive. The
controller passes the validated derived Keychain account list and one DB-row
delete closure; the coordinator owns all pre-image reads, fixed-order deletes,
reverse restores, and the terminal `Result` inside one synchronous critical
section. The exact order is the validated secret-key/account list sorted by
UTF-8 bytes. A secret-delete failure restores only earlier changed accounts; a
DB-delete failure restores every deleted account; restoration is reverse
order. Any restoration failure returns `mcp_secret_rollback_failed` critical
and never reports full deletion. The two frozen coordinator catch markers
`N[.credentialBundlePrimaryFailure]` and
`N[.credentialBundleRollbackFailure]` cover OAuth and MCP bundle algorithms;
McpWorkflowController switches the returned Result and introduces no
compensation catch or unreviewed marker.

Manager maintenance release is a second, explicitly represented axis after the
credential/database mutation. The types above make every terminal mutually
exclusive: `McpServerDeletionReceipt` means deletion and Manager cleanup both
succeeded; `McpPendingRollbackCleanup` means credential/database deletion did
not commit but the valid lease still needs `.keepStopped`; and
`McpPendingDeletedServerCleanup` means deletion committed but the same lease
still needs `.removeHandle`. There is no optional token, no receipt-plus-pending
state, and no independently supplied server ID. Each pending initializer, its
stored lease, its stored `traceScope`, and the enum's `traceScope` projection
are intentionally AgentLoopApplication-internal (not `package`); only its
package `serverId`, derived from `lease.serverId`, and its Equatable value cross
into App. An AgentLoopApp compile-negative fixture must fail to name
`.traceScope` on any of the three pending types. TestSuite obtains a token only by driving the
real live port with the DEBUG Manager finish-failure injection. Source gates
forbid AgentLoopApp and TestSuite from calling Manager acquire/finish directly.
Before the initial port call, the controller requires
`trace.operation == .mcpServerDelete`, `trace.scope.type == .mcpServer`, and
`trace.scope.id == serverId`; mismatch is zero-I/O
`trace_identity_conflict`. It passes only the already-validated
`trace.traceScope` into the live port, which retains that capability in either
pending value. For cleanup retry, the controller accepts no caller-supplied
trace: as its first operation line it uses its injected `traceFactory` to
generate `.mcpServerDelete` from `pending.traceScope`. It therefore cannot bind
token A to a server-B scope, re-read a deleted row, or mint scope from
`pending.serverId`.

The initial port/controller mapping is exact:

```text
maintenance acquisition failed
  -> notCommitted(primary)
coordinator failed/restored + keepStopped succeeded
  -> notCommitted(primary)
coordinator failed/restored + keepStopped failed
  -> notCommittedCleanupPending(primary, cleanup, rollback-token)
coordinator committed + removeHandle succeeded
  -> committed(cleaned receipt)
coordinator committed + removeHandle failed
  -> committedCleanupPending(cleanup, deleted-token)
```

The controller captures only the final terminal. The rollback-cleanup double
failure becomes one `McpDeletionCleanupCompositeError`, one critical
`cleanup_integrity_failed` row, and one safe UI failure; its diagnostics contain
only the already-classified primary code plus
`rollbackCode=cleanup_integrity_failed`. It does not first persist a conflicting
primary row. A committed cleanup failure maps the closed
`McpMaintenanceCleanupError` directly to the same critical code. A plain
coordinator failure whose keepStopped succeeds remains the original
not-committed failure.

McpStore maps `notCommittedCleanupPending` by retaining its last-loaded
registry/secret render cache only under an explicit failed state (never as a
newly verified secret truth), storing `.rollback`, showing the final failure,
and offering cleanup-before-delete-retry. It maps
`committedCleanupPending` by treating the DB/credential deletion as durable,
refreshing the registry without reissuing delete, storing `.deleted`, and
offering cleanup-only retry. Neither branch reports full success while its
pending value exists.

`finishServerCleanup` requires one of the two opaque pending values and calls
only `manager.finishMaintenance`: rollback invokes `.keepStopped`, deleted
invokes `.removeHandle`. It performs zero maintenance acquisition,
DB/Keychain/secret-account reads, and DB/Keychain writes. Rollback success
returns `.deletionRetryReady(McpServerDeletionRetryReceipt)`, whose server ID
is derived from the cleaned rollback token; after that only a separate explicit
delete action may retry the full command. That action reloads the still-durable
typed `McpServerRecord`, remints its validated scope, and fails visibly if the
record is unexpectedly absent; the retry receipt's display ID is not itself a
scope capability. Deleted success returns
`.deletionCommitted(McpServerDeletionReceipt)`. Failure preserves the exact
same sum value as `.pending` with a new same-operation cleanup-integrity trace;
it never changes durability or reconstructs a lease. The initial delete
callable is marked `P1-B-SEAM mcpDeleteServer`; this cleanup-only callable is
independently marked `P1-B-SEAM mcpFinishServerCleanup`, and neither delegates
to the other.

The controller actor is independently single-flight across its await. Before
calling the port it indexes `McpCleanupFlight` by the token's derived server
ID. A concurrent call with the same Equatable token awaits the already-recorded
Task and creates no second Manager finish; a different token for the same ID
returns `.pending` with a newly captured nonretryable
`McpMaintenanceCleanupError.invalidLease`, performs zero Manager/DB/Keychain
calls, and does not replace the existing flight. The actor removes a flight
after await only when its attempt UUID still matches. No caller may reconstruct
or mutate the token. Each invocation maps the shared typed result under the
controller-generated trace derived from that same pending scope. Combined
with McpStore's compare-and-remove rule, a stale
second terminal cannot put a consumed lease back into UI state.
The recorded unstructured Task is never canceled after it owns the cleanup
attempt; caller/UI Task cancellation still awaits its nonthrowing Result and
uses the same conditional apply. This preserves the acquired lease terminal
without turning cancellation into a silent leak.

McpStore keeps its current nonthrowing view façade and last-loaded arrays. It
maps Manager's typed `lastError(serverId:)` into
the status-only `McpServerStatusSummary.down`; the owning failed start/restart
projection retains the safe `UserVisibleFailure`. Registry reload never
re-captures several historical Manager errors under one trace. Raw manager detail is never
published by an Application DTO or persisted as diagnostics.

For every load, the controller creates no generation and returns only a
terminal. For every ordinary command, the passed trace is the sole top-level
identity; MCP cleanup is the sole typed exception and generates its trace
inside the controller from the unforgeable pending scope before any await.
The App façade owns one projection per snapshot, creates its generation before
launching the Task, and applies this mapping to ordinary commands:

```text
notCommitted(f)                     -> original action may retry
committed(value)                    -> update committed identity; then refresh
committedWithVisibilityFailure(v,f) -> update known committed identity + banner;
                                       refresh/reconcile only, never repeat command
```

MCP deletion alone uses the frozen two-axis `McpServerDeletionOutcome` /
`McpServerCleanupOutcome` state machine above; it may not be squeezed into a
generic `OperationCommitOutcome` by dropping a pending lease or its durability.

## 7. MCP typed boundary

### 7.1 Manager errors and configuration

`McpServerManager.SecretProvider` becomes:

```swift
@Sendable (String, String) throws -> String?
```

AppStore's provider closure resolves the derived MCP account through the same
`SynchronizedCredentialAccess` gate used by credential mutations. Thus a start
cannot observe a secret set/delete bundle between pre-image and rollback; the
Manager actor still serializes stop/start for the server itself.

Manager configuration decoding reads `argsJson`, `envJson`, and
`secretEnvKeysJson` explicitly and throws `McpOperationError.invalidConfig`;
it never relies on the record's convenience fallback properties. After
validation it re-encodes all three values with sorted JSON keys/order into a
canonical copy of the same `McpServerRecord` identity/metadata and passes that
copy to the unchanged existing
`TransportFactory(McpServerRecord, [String: String])` signature. The default
factory may therefore keep reading `record.args`, because Manager has already
made malformed input unrepresentable at that boundary; no public factory or
closed test signature changes. The typed
error taxonomy is exactly:

```text
registryRead
serverMissing
invalidConfig
secretMissing
secretRead
transportStart
toolList
connectionDown
toolCall
serverMaintenance
```

The public typed surface is exact and preserves ignored-return call sites:

```swift
public enum McpOperationError: Error, Sendable, Equatable {
    case registryRead(serverId: String?)
    case serverMissing(serverId: String)
    case invalidConfig(serverId: String, field: ConfigField)
    case secretMissing(serverId: String)
    case secretRead(serverId: String, osStatus: Int32?)
    case transportStart(serverId: String)
    case toolList(serverId: String)
    case connectionDown(serverId: String)
    case toolCall(serverId: String)
    case serverMaintenance(serverId: String)
}
package enum McpMaintenanceCleanupError: Error, Sendable, Equatable {
    case finishFailed(serverId: String)
    case invalidLease(serverId: String)
}
package enum McpServerDeletionFailure: Error, Sendable, Equatable {
    case credential(McpCredentialDeletionError)
    case maintenance(McpOperationError)
}
package struct McpDeletionCleanupCompositeError: Error, Sendable, Equatable {
    package let primary: McpCredentialDeletionError
    package let cleanup: McpMaintenanceCleanupError
    package init(primary: McpCredentialDeletionError,
                 cleanup: McpMaintenanceCleanupError)
}
public enum ConfigField: String, Sendable, Equatable, CaseIterable {
    case args
    case env
    case secretEnvKeys
}
public struct McpServerReady: Sendable, Equatable {
    public let serverId: String
    public let toolCount: Int
    public init(serverId: String, toolCount: Int)
}
public struct McpEnsureResult: Sendable {
    public let serverId: String
    public let result: Result<McpServerReady, McpOperationError>
    public init(serverId: String,
                result: Result<McpServerReady, McpOperationError>)
}
package struct McpMaintenanceLease: Sendable, Equatable {
    package let serverId: String
    fileprivate let nonce: UUID
    fileprivate let generation: Int
}
package enum McpMaintenanceCompletion: Sendable, Equatable {
    case keepStopped
    case removeHandle
}
@discardableResult
public func ensureRunning(serverIds: [String]) async -> [McpEnsureResult]
@discardableResult
public func restart(serverId: String) async
    -> Result<McpServerReady, McpOperationError>
public func assembledTools(campId: String) throws -> [AssembledTool]
public func assembledTools(serverId: String) throws -> [AssembledTool]
public func call(serverId: String, toolName: String,
                 arguments: JSONValue) async
    -> Result<MiniMcpClient.CallResult, McpOperationError>
package func acquireMaintenance(serverId: String) async
    -> Result<McpMaintenanceLease, McpOperationError>
package func finishMaintenance(_ lease: McpMaintenanceLease,
                               completion: McpMaintenanceCompletion) async
    -> Result<Void, McpMaintenanceCleanupError>
package func lastError(serverId: String) -> McpOperationError?
```

`ConfigField` is the exact fixed enum above; it never contains raw JSON.
`McpMaintenanceCleanupError` is a package-only cleanup-integrity terminal, not
an ordinary server status and never stored in `lastError`; therefore a failed
finish cannot be mislabeled as `mcp_server_maintenance`.
`SecretProvider` may throw any injected `Error`: `KeychainError` supplies its
OSStatus and all other errors become `secretRead(osStatus: nil)`. They never
fall through to `unexpected_failure`; diagnostics already permit an absent
OSStatus. `ensureRunning` preserves input order and returns exactly one entry per
requested ID, including already-running/down/maintenance cases. Existing
callers may ignore the newly returned value; the in-scope Context loader,
McpStore, tests, and Bridge consume it. Manager retains the same typed last
error by server for safe status projection.

Errors carry safe server/dependency IDs and stable codes only. They never carry
secret/key/account values, tool/display names, raw environment, raw stderr, or
a full external response.
`ServerStatus.down` keeps a bounded safe display summary for existing views;
the manager separately retains the typed last failure by server.

`ensureRunning` returns one typed outcome per requested server. Environment
precedence remains login-shell base < stored non-secret env < Keychain. For a
declared secret, nil/empty Keychain is `secretMissing` only when the already
merged base/stored env has no nonempty value for that key; an existing nonempty
value remains valid compatibility behavior. A thrown Keychain error is always
`secretRead` and may not fall back to base/stored env. Transport connect and
`tools/list` are distinct outcomes. Down servers remain no-auto-retry.
`restart` is the only explicit recovery.

`acquireMaintenance` marks the server/generation as maintenance before its
first await, drains an in-flight start, stops the connection, and invalidates
callbacks. Until a matching `finishMaintenance` succeeds, ensure/restart/
assembledTools/call all return serverMaintenance. The lease has no public or
package initializer. Controller cancellation is deferred across the acquired
lease's first terminal attempt: rollback finishes keepStopped; successful row
deletion attempts removeHandle. A failed `finishMaintenance` does not consume,
replace, or unlock the lease; it maps cleanup-integrity and returns the same
lease inside `McpPendingServerCleanup`, and only that exact lease may retry the
finish. A safe injected/internal remove or release failure becomes
`McpMaintenanceCleanupError.finishFailed(serverId:)` before changing Manager
state, so the exact lease remains active. A successful retry consumes it
exactly once. A stale, mismatched, or already-consumed lease returns
`.invalidLease(serverId:)`, never consumes a different active lease, and can
never trigger credential/database mutation. Neither cleanup case contains the
nonce, generation, process detail, command, stderr, or raw Error. Thus the
lease is never silently leaked: during
the session it is owned either by the active command or by McpStore's pending
cleanup map, and a process restart inherits no Manager handle. The secret-key
list is used only inside the credential mutation and is never copied into
McpOperationError or evidence.

Both `assembledTools(campId:)` and `assembledTools(serverId:)` throw on
registry/config reads. A valid stopped/down server may produce an empty cached
list only together with its explicit status/outcome; database/config failure
never produces a plain empty result. Direct Core tests use `try await`; App
views receive last-loaded cached lists plus Mcp workflow state.

### 7.2 Tool-call failure event

McpToolBridge preserves its current public initializer parameters and appends
only defaulted `campId: String? = nil` and `reporter: FailureReporter? = nil`,
so closed construction sites compile. A package test/DEBUG initializer injects
the trace factory/audit hook. The tool name remains an ephemeral transport-call
input; neither McpOperationError nor failure/event/UI/model evidence contains
it.

McpToolBridge creates one trace before the call. When a call fails it prepares
that original MCP failure. Only typed `connectionDown` uses one AppDatabase
transaction to upsert its `failure_record` and append the existing safe
`mcp_server_down` event containing only opaque database `serverId`, original
stable errorCode, and trace ID; server name, tool name, account/key name, raw
arguments, raw external error/detail, and response text are never persisted or
rendered. The ToolOutcome uses a fixed safe body plus the same full trace. A transport response
that is a valid tool-level error (`isError`/typed `toolCall`) writes the failure
record through ordinary `capture` but does **not** mark the server down or append
`mcp_server_down`.

If the connection-down transaction fails, Bridge must not recapture a second
`database_write_failed` under the same trace. It calls
`reporter.persistPrepared(originalPrepared)` exactly once, completes with that
stored/unavailable result, and returns the original safe MCP failure with the
full trace. The auxiliary error itself is never reflected or persisted. If the
isolated upsert succeeds, the original failure row remains durable while the
down event is absent; if it also fails, there is one safe terminal logger line.
There is no business `try?`, contradictory second failure row, success after a
failed call, retry of the event append, or down-state mutation after a
tool-level error.

## 8. Context dependencies and explicit degradation

### 8.1 Current P1-B request construction

P1-D has not yet created OutcomeContract storage, so P1-B does not fabricate
one. It establishes the typed request/loader and wires only current durable
sources:

- each capability name beginning `mcp__` in a valid raw v2
  `{"v":2,"allow":[...]}` selection is required;
- `web_search` is required only when present in that valid raw v2 allow list;
  an unselected or legacy-inherited `web_search` performs no required
  credential read;
- legacy Camp pinned/recent notes are optionalApproved;
- legacy Companion pinned/recent notes are optionalApproved.

`ContextDependencyRequest` carries both the already parsed ToolAccess and the
original `toolsJson`. Loader decodes a private exact `{v:Int,allow:[String]}`
shape only to derive `explicitV2` provenance; it does not reimplement
ToolAccess capability semantics. The raw value is `explicitV2` only when
`v == 2`, decoding succeeds, `ToolAccess.parse` is not failed, and the decoded
allow Set exactly equals parsed capabilities. Any legacy
array—including legacy `"[]"`, whose parsed built-ins are full—has provenance
`legacyInherited` and cannot turn web search into a new required dependency.
Future OutcomeContract knowledge/file/tool entries can create the same typed
request without changing loader policy. ToolAccess parse failure remains
fail-closed and becomes a traceable invalid projection; it does not start any
MCP server.

Selected MCP names are parsed with existing `McpToolNaming`; the server
component must match exactly one enabled registry record, and the fully
composed name must match one assembled tool. Ambiguous/disabled/missing server,
start/list failure, or missing exact tool blocks. The registry is read once,
each unique selected server starts at most once, and selected tools are handled
in full composed-name UTF-8 order.

### 8.2 Loader result and policy

The Core API is exact:

```swift
package enum ContextToolSelectionProvenance: Sendable, Equatable {
    case explicitV2(Set<String>)
    case legacyInherited
}
public enum ContextDependencyPolicy: String, Codable, Sendable, Equatable {
    case required, optionalApproved
}
public enum ContextDependencyType: String, Codable, Sendable, Equatable {
    case search, campNote = "camp_note", companionNote = "companion_note"
    case mcpServer = "mcp_server", mcpTool = "mcp_tool"
}
package struct ContextDependencyRequest: Sendable {
    package let missionId: String
    package let cardId: String
    package let campId: String?
    package let companionId: String
    package let missionScope: FailureTraceScope
    package let cardScope: FailureTraceScope
    package let campScope: FailureTraceScope?
    package let companionScope: FailureTraceScope
    package let runtimeProfileKind: RuntimeProfileKind
    package let toolAccess: ToolAccess
    package let toolsJson: String
    package init(mission: MissionRecord, card: CardRecord, camp: CampRecord?,
                 companion: CompanionRecord,
                 runtimeProfileKind: RuntimeProfileKind,
                 toolAccess: ToolAccess, toolsJson: String) throws
}
package enum ContextDependencyCoordinate: Sendable, Equatable {
    case search
    case campNotes(FailureRecordID)
    case companionNotes(FailureRecordID)
    case mcpRegistry
    case mcpServer(FailureRecordID)
    case mcpTool(FailureRecordID)
    package var durableId: String {
        switch self {
        case .search:
            return "search"
        case .mcpRegistry:
            return "mcpRegistry"
        case .campNotes(let id), .companionNotes(let id),
             .mcpServer(let id), .mcpTool(let id):
            return id.rawValue
        }
    }
}
public struct ContextDegradationNotice: Sendable, Equatable {
    public let degradationId: String
    public let missionId: String?
    public let cardId: String
    public let dependencyType: ContextDependencyType
    public let policy: ContextDependencyPolicy
    public let failure: UserVisibleFailure
    package init(degradationId: String, missionId: String?, cardId: String,
                 dependencyType: ContextDependencyType,
                 policy: ContextDependencyPolicy,
                 failure: UserVisibleFailure)
}
package struct ContextDependencyReady: Sendable {
    package let campNotes: [NoteSnippet]
    package let companionNotes: [NoteSnippet]
    package let searchKey: String?
    package let externalTools: [ExternalTool]
    package let degradations: [ContextDegradationNotice]
    package init(campNotes: [NoteSnippet], companionNotes: [NoteSnippet],
                 searchKey: String?, externalTools: [ExternalTool],
                 degradations: [ContextDegradationNotice])
}
package enum ContextDependencyResult: Sendable {
    case ready(ContextDependencyReady)
    case blocked(failure: UserVisibleFailure, suppressForSession: Bool)
}
package struct ContextKnowledgeReaders: Sendable {
    package let camp: @Sendable (String) throws -> [NoteSnippet]
    package let companion: @Sendable (String) throws -> [NoteSnippet]
    package init(camp: @escaping @Sendable (String) throws -> [NoteSnippet],
                 companion: @escaping @Sendable (String) throws -> [NoteSnippet])
    package static func live(database: AppDatabase) -> Self
}
package typealias ContextTraceFactory = @Sendable
    (FailureOperation, FailureTraceScope) -> OperationTrace
package protocol ContextDependencyLoading: Sendable {
    func load(
        _ request: ContextDependencyRequest,
        onOptionalDegradation: @escaping @Sendable
            (ContextDegradationNotice) async -> Void
    ) async -> ContextDependencyResult
}
package struct ContextDependencyLoader: ContextDependencyLoading, Sendable {
    package init(database: AppDatabase, manager: McpServerManager?,
                 reporter: FailureReporter,
                 searchCredential: @escaping @Sendable () throws -> String?,
                 knowledge: ContextKnowledgeReaders,
                 makeTrace: @escaping ContextTraceFactory)
    package func load(
        _ request: ContextDependencyRequest,
        onOptionalDegradation: @escaping @Sendable
            (ContextDegradationNotice) async -> Void
    ) async -> ContextDependencyResult
}
```

The throwing request initializer accepts only the exact Mission, Card, optional
Camp, and Companion records already loaded by Orchestrator. It validates the
Card/Mission identity relationship and builds every record scope before loader
work. Raw IDs are exposed only as compatibility fields after validation; the
loader never mints a scope from a String or performs an identity-only reread.
An invalid record ID/relationship is a pre-dispatch projection failure on the
fixed projection scope.

`ContextDegradationRecord.dependencyId` is produced only by
`ContextDependencyCoordinate`: `search` and `mcpRegistry` persist those exact
fixed literals; Camp/Companion notes use their typed record IDs; resolved MCP
server/tool dependencies use a typed MCP-server record ID. Registry-read,
ambiguous, disabled, or missing-server failures happen before any server record
exists, use fixed trace scope `.mcpRegistry`, persist dependency ID
`mcpRegistry`, and ignore any raw capability-derived server component carried
by `McpOperationError`. MCP-tool degradation uses dependencyType mcpTool with
the resolved server ID; the external tool name is never persisted. KernelEvent gains public associated cases
`.operationFailed(UserVisibleFailure)` and
`.contextDegraded(ContextDegradationNotice)`; legacy kernelError stays for
closed compatibility, but no P1-B path feeds it an Error-derived String.

`ContextDependencyLoader` accepts the exact request/result declarations in
§6.6, a dependency trace factory, DB, manager, reporter, synchronized search
credential reader, and injected knowledge readers. The request includes
mission/card/Camp/companion identity, raw and parsed tool selection, and exact
model-or-CLI backend kind. The factory creates one distinct trace immediately before
each dependency's first read/start. A single load can therefore persist Camp
notes, Companion notes, and multiple MCP failures without reusing one
`failure_record.id` for different operation/errorCode identities. It returns:

```text
ready(ContextDependencyReady(campNotes, companionNotes, searchKey,
                             externalTools, degradations))
blocked(failure: UserVisibleFailure, suppressForSession: Bool)
```

For a model backend it resolves the selected search credential at most once
and returns that exact `String?`; Orchestrator passes it directly into
CardExecutionContext and never invokes `searchKeyProvider` afterward. It starts
only servers needed by explicitly selected capability names. Missing/thrown selected search credentials and disabled,
missing, secret-missing, secret-read, start, list, registry, or selected-tool-
missing failures are required failures. A failure of an enabled but unselected
server is irrelevant and does not start or degrade the Card.

Load order is deterministic: validate ToolAccess; resolve selected
`web_search` credential; resolve required MCP servers and selected tools in
UTF-8 tool-name order (each server starts at most once);
then optional Camp notes; then optional Companion notes. Registry/server/start
failure records one server dependency and stops at the first required failure;
a running server missing a selected tool records that exact tool dependency.
No optional read occurs after required blocking has won.

A CLI backend has no adapter for `externalTools` or `searchKey` in this slice.
If a valid explicit-v2 selection contains any `mcp__*` capability or
`web_search`, loader creates one `context_backend_capability_unsupported` required
failure at the first selected capability in UTF-8 order and executes the same
atomic required degradation/Card-block transaction *before* any search
credential read, MCP registry/start/list, provider resolution, backend
construction, or tool call. CLI without either unsupported explicit selection
continues and retains its existing board/builtin behavior. P1-B does not edit or
pretend to extend `CliProcessBackend.swift`.

For every dependency failure the loader uses that dependency's trace and
`FailureReporter.prepare`, then
calls one AppDatabase transaction that:

1. inserts/upserts the exact prepared `failure_record`;
2. inserts the exact `context_degradation` row;
3. for required policy, transitions the affected Card to blocked using reason
   `context_unavailable` and safe detail containing the full trace ID;
4. for optionalApproved, leaves Card state unchanged.

Required returns `.blocked` and Orchestrator never creates/runs a backend.
OptionalApproved may continue only after the transaction commits. It appends
one explicit `NoteSnippet` marker titled `上下文降级` with the fixed body
`可选上下文暂时不可用。追踪 ID：<full traceId>`; it contains neither a raw
dependency value nor a raw error. The marker makes omitted context visible to
the model and UI; it is not an empty-list substitute.

If the degradation/Card transaction rolls back, loader invokes
`reporter.persistPrepared(originalPrepared)` exactly once before returning.
Whether that isolated fallback is stored or unavailable, optional continuation
is forbidden; required work also remains blocked in-session and no auxiliary
statement is retried. The reporter completes the same trace, the loader returns
blocked/failure, and no provider/tool dispatch begins. Only
`.blocked(..., suppressForSession: true)`—the transaction-rollback case—makes
Orchestrator immediately add the Card ID to its actor-isolated session set
`contextSuppressedCardIds`; a committed required block returns false because
the durable Card is already blocked. Candidate selection excludes the set when
a failed transaction necessarily left the durable Card `ready`. This prevents the
next tick from retrying and generating a failure/log storm while never writing a
false durable state. Dispatch resume, ordinary reconcile, and unrelated success
do not clear suppression.

Only the failure banner's explicit `retryContext(cardId:)` action or a process
restart clears that one session entry. The method verifies that the Card still
exists, is ready, and has no owned running task, removes the ID, and requests one
reconcile; it performs no database mutation. The next load creates new
dependency trace/degradation IDs. If persistence still fails it re-suppresses
before returning. P1-B does not invent idempotency storage absent from v13.
`ContextDependencyLoading.load(_:onOptionalDegradation:)` receives an exact
`@Sendable (ContextDegradationNotice) async -> Void` sink. Orchestrator passes
an actor-hop closure that emits its in-process `KernelEvent.contextDegraded`.
After the atomic failure + optional degradation row commits, loader awaits that
sink; only after the sink returns does it append the missing marker and return
`.ready`, and only after that may Orchestrator resolve a provider or
construct/dispatch a backend. No subscriber acknowledgment or event commit is
claimed. AppStore reloads the
durable row and displays the same trace; cold-start truth is the row. Required already
commits the existing durable `card_blocked` event. P1-B does not add a legacy
EventKind or v14 domain event; cold-start truth is `context_degradation`.

### 8.3 Orchestrator integration

The three existing silent helpers (`assembleMcpTools`, `loadCampNotes`,
`loadCompanionNotes`) are replaced by one loader call before provider resolution
or CardRunner/Cli backend construction. The card execution `run` path no longer
receives a provider resolved by the pump: only a model `.ready` result invokes
the existing throwing `makeProvider` once; CLI blocking therefore has zero
provider calls. Orchestrator rechecks cancellation and dispatch mode
after the async load. `.blocked` is handled separately from generic kernel
failure so it does not overwrite the Card or persist raw errors. Background
failure events emitted to App carry `UserVisibleFailure`, not reflected error
strings. Rate-limit cooldown whose in-memory transition already occurred but
whose event write failed emits committed-with-visibility-failure; cancellation
or UI must not repeat the provider operation merely to recreate the event.
The actor owns `contextSuppressedCardIds`; the loader does not own scheduling
state. An ID is inserted before any await that could permit another reconcile,
and explicit retry is covered by an event-driven gate rather than sleep/poll.

## 9. MemoryDistill and knowledge outcomes

`Distiller` no longer hides failure inside a success-like return. The accepted
product behavior that closeout still produces one deterministic fallback note
is preserved explicitly by Orchestrator, where it can be observed:

```swift
public enum DistillerError: Error, Sendable, Equatable {
    case invalidPayload
}
// Same-file conformance so synthesis may use CardDigest's existing stored
// fields without redeclaring the nested type.
extension Distiller.CardDigest: Equatable {}
extension Distiller {
    public func distillCloseout(goal: String, cards: [CardDigest]) async throws
        -> Note
    package static func parseNoteJSON(_ raw: String) throws -> ParsedNote
    package static func closeoutFallback(goal: String,
                                         cards: [CardDigest]) -> Note
}
```

`parseNoteJSON` explicitly decodes the required sorted/ordinary JSON object.
A valid `{"skip":true}` remains `.skip` for memory/guide only; closeout treats
skip, empty text, missing/non-string title/body, blank title/body, malformed
JSON, and non-text-only provider output as `DistillerError.invalidPayload`.
The former first-line parser, fallback Bool, raw logger, and generic catch are
removed. The existing pure deterministic `closeoutFallback` remains package API
and accepts no Error. Provider errors propagate unchanged. Orchestrator's
existing closeout owner catches that typed error with the same Mission trace,
prepares (but does not yet persist) the primary failure, calls the historical
pure handoff-summary fallback without reading or formatting the raw error, and
persists that note. The repair receipt is frozen in `.fallbackMissing` before
that write. A successful fallback-note commit derives `.realRetryReady`, then
persists/completes the original prepared failure and returns
`MissionAcceptanceOutcome.committedWithVisibilityFailures` with one failure and
the one `.realRetryReady` receipt; the Mission remains accepted, exactly one
note exists, and retry may attempt real distillation only—it never repeats
acceptance or creates a second fallback note.

If fallback-note persistence also fails, Orchestrator persists/completes one
critical `cleanup_integrity_failed` composite for the same trace with only the
already-classified primary code and `database_write_failed` secondary code in
the typed diagnostic fields. It returns that failure with the already-frozen
`.fallbackMissing` receipt, never writes two conflicting rows for one trace,
and never claims a note exists. The receipt's internal closed primary
discriminator is the sole source of that exact provider-vs-invalid-payload code
on a later retry; no failure-row reread or raw Error is used. A retry of that receipt inserts/validates the
same fixed fallback note/event before it can attempt real distillation; another
write failure retains the byte-identical receipt. The existing Distiller tests
prove the helper now throws; the existing closeout/Orchestrator tests retain
and extend the deterministic one-fallback-note contract plus committed-
visibility and double-failure cases. This preserves the accepted product
semantics while making both failures observable.

`MemoryDistillService` owns one flat public terminal for both DM and guide. The
three success cases remain a file-private execution value; only the public terminal
can cross into App, so failure always carries the same captured trace rather
than escaping to a second owner:

```swift
fileprivate enum MemoryDistillOutcome<Record: Sendable>: Sendable {
    case noEligibleInput
    case skipped
    case created(Record)
}
extension MemoryDistillOutcome: Equatable where Record: Equatable {}
public enum MemoryDistillTerminal<Record: Sendable>: Sendable {
    case noEligibleInput
    case skipped
    case created(Record)
    case failed(UserVisibleFailure)
}
extension MemoryDistillTerminal: Equatable where Record: Equatable {}
public enum MemoryDistillOwnerKind: String, Sendable, Equatable {
    case companion, guide
}
public enum MemoryDistillCaptureViolation: String, Sendable, Equatable {
    case empty, blankMessageID, duplicateMessageID
}
public enum MemoryDistillError: Error, Sendable, Equatable {
    case invalidMinimumMessages(Int)
    case invalidCapturedMessages(MemoryDistillCaptureViolation)
    case ownerNotFound(MemoryDistillOwnerKind)
    case threadInvariant(MemoryDistillOwnerKind)
    case read(grdbResultCode: Int32?)
    case provider(httpStatus: ValidatedHTTPStatus?)
    case invalidPayload
    case write(grdbResultCode: Int32?)
}
public struct MemoryDistillRaceLostError: Error, Sendable, Equatable {
    public init() {}
}
fileprivate enum MemoryDistillExecutionStage: Sendable, Equatable {
    case input
    case ownerRead
    case threadEnsure
    case messageRead
    case provider
    case watermark
    case persistence
}
fileprivate struct ValidatedDistillationCapture: Sendable, Equatable {
    fileprivate let messageIds: [String]
    fileprivate init(validating messageIds: [String]) throws
}
extension AppDatabase {
    package func advanceDistillationWatermark(
        capturedMessageIds: [String]
    ) throws
    public func markDistilled(messageIds: [String]) throws
    @discardableResult
    public func persistCompanionDistillation(
        note: CompanionNoteRecord,
        capturedMessageIds: [String]
    ) throws -> Bool
    @discardableResult
    public func persistGuideDistillation(
        note: CampNoteRecord,
        capturedMessageIds: [String]
    ) throws -> Bool
}
public struct MemoryDistillService: Sendable {
    public static let autoMinMessages = 4
    public init(db: AppDatabase, provider: any LLMProvider)
    package init(db: AppDatabase,
                 provider: any LLMProvider,
                 reporter: FailureReporter,
                 traceFactory: OperationTraceFactory)
    @discardableResult
    public func distillDM(companionId: String, minMessages: Int) async
        -> MemoryDistillTerminal<CompanionNoteRecord>
    @discardableResult
    public func distillGuideChat(campId: String) async
        -> MemoryDistillTerminal<CampNoteRecord>
}
```

The existing public initializer constructs `FailureReporter(database: db)` and
uses `OperationTraceFactory.live`; the package initializer is the only
injectable test route. Each public invocation's first semantic action creates
exactly one trace: DM uses
`.memoryDMDistill + .fixed(.memoryDM)`, and guide uses
`.memoryGuideDistill + .fixed(.memoryGuide)`. Each existing lexical catch is
the sole outer catch for that public method: it feeds the exact closed
execution-stage discriminator and caught error to the total Memory normalizer,
captures once with that pre-created trace, and returns `.failed(failure)`.
The method sets that exact file-private stage immediately before each fallible
owner read, thread ensure, message read/decode, provider call, watermark CAS, or
persistence call; no fallible call can execute under an earlier stage. Invalid
minimum/capture terminals use the same trace/reporter before DB work. The
file-private success value is flattened to the three matching public cases
only after the `do` body completes.
There is no nested catch, raw logger, second App capture, or unknown-stage
default. The public return types compile across Core/App/Test targets and
distinguish:

- `distillDM` requires `minMessages > 0` before any owner/thread/message read;
  invalid input captures `.invalidMinimumMessages` and returns `.failed`, and never applies
  `max(1, minMessages)`;
- missing Companion, Camp/guide owner, or an impossible missing thread after a
  successful find-or-create is a typed `notFound`/invariant failure;
- `.noEligibleInput` is returned only after all required owners/thread reads
  succeed and the resulting message list is genuinely empty or below the
  configured threshold;
- model returned no note: atomically advance captured watermark, then
  `.skipped`;
- note committed with exact captured IDs: `.created(record)`;
- provider, read, write, decode, or watermark commit failure: the internal
  error remains typed, the watermark is preserved, and the public owner returns
  `.failed` with its one exact trace;
- a lost watermark race after another writer consumed the exact captured
  messages: raw persistence throws exact `MemoryDistillRaceLostError`, while
  the Service returns a captured `memory_race_lost` failure; it is neither
  no-input, provider skip, nor a creation by this invocation.

All three commit paths share one `KnowledgeStore.swift` conditional CAS helper.
Their source-compatible raw-array entry signatures first call one shared
capture validator **before** `pool.write` or any DB operation. The
validator rejects empty input with
`.invalidCapturedMessages(.empty)`, then rejects an ID empty after
whitespace/newline trimming with `.invalidCapturedMessages(.blankMessageID)`
without normalizing an accepted ID, then rejects any repeated exact String ID
with `.invalidCapturedMessages(.duplicateMessageID)`, and otherwise returns the
file-private `ValidatedDistillationCapture` holding the byte-equal ordered
array. It neither removes/reorders IDs nor exposes an initializer.
The validation precedence is exact and independent of `Set` iteration: empty
array first; then the first blank ID in original array order; then the first
left-to-right repeated exact ID; then success. A temporary Set may only prove
the duplicate condition and is never used as the stored array.
The public created owners and package skip owner then pass only that token across their
transaction boundary; `consumeCapturedDistillationMessages(_:database:)`
accepts only the token, executes one update over its exact ID set with
`distilled = 0` in the predicate, then requires
`changesCount == capture.messageIds.count`; a mismatch throws
`MemoryDistillRaceLostError` and never returns Bool. The skip-only
`advanceDistillationWatermark` owns one `pool.write` and calls that helper.
`persistCompanionDistillation` and `persistGuideDistillation` retain their
existing public `@discardableResult throws -> Bool` signatures exactly. Each
calls the same helper before inserting its note/event inside the same existing
transaction and returns `true` only after that entire transaction commits.
Invalid capture, CAS loss, and note/event database failure all throw; `false`
is unreachable and no caller may branch on it. Any insert/event fault rolls
back the watermark. New messages outside the frozen captured set remain
untouched.

The only empty-array compatibility guard is the pre-existing one in
`markDistilled(messageIds:)`, which preserves empty-as-no-op and delegates
nonempty input to the dedicated validated CAS API; a nonempty duplicate array
therefore fails typed rather than deduplicating. The shared validator uses
closed `if`/throw branches, not a second guard candidate.
`advanceDistillationWatermark` adds no guard. Every production capture is the direct ID projection of one
nonempty `undistilledMessages` result whose message primary keys are unique; it
is never concatenated, duplicated, normalized, or reconstructed. All three
production commit calls pass that exact frozen array. This source proof is an
additional invariant, not a substitute for the public boundary validation.
No raw API authorizes an empty/duplicate capture or a hidden deduplication
fallback.
The service's skip branches call only `advanceDistillationWatermark`; its
created branches call only the matching atomic persistence owner and explicitly
discard its successful `true`. The old catch-to-false race conversion,
`StaleMemoryDistillationError`, `return false`, and any
race-to-skip/no-input/success arm are deleted; the public source-compatible Bool
is not itself a semantic branch.

AppStore shows distinct no-input, skipped, created, and failed-with-trace
messages. Each of its three entry points resolves the provider first through
the existing `captureSynchronous` boundary with a fresh
`.runtimeProviderResolve + .fixed(.runtime)` trace. Legal nil is the explicit
absence lane; a resolution failure displays that trace and starts no Memory
Task. After a provider is available, the Task only awaits the Service terminal,
clears its exact in-flight flag, and exhaustively switches the four cases with
no catch. Automatic leave may suppress only a `.noEligibleInput` toast; it must
surface `.failed`. KnowledgeStore reads used for context and note UI propagate
errors; no caller projects failure to `[]`.

Every existing caller is migrated explicitly rather than relying on optional
truthiness. The three AppStore entries—manual guide, manual DM, and automatic DM
leave—exhaust the flat terminal; manual no-input/skip remain distinct and
automatic leave may silence only no-input. `.created(record)` is an irrevocable
commit terminal. DM then performs a separate refresh with a fresh
`.memoryNoteLoad` trace; guide uses a fresh `.campKnowledgeLoad` trace. A reload
failure is displayed as created-but-visibility-refresh-failed, preserves the
created record/watermark/event, and offers only that reload. It never converts
the completed Service terminal to `.failed` and never reruns provider or
distillation persistence.

That committed-visibility lane is the Application-owned
`MemoryKnowledgeProjectionCoordinator` frozen in §6.3, not an App-local copy.
AppStore stores one coordinator, exposes `memoryNotes`, `campNotes`, their
closed visible load states, and `memoryDistillationVisibilityCards` only as
computed projections of it, and never assigns a global note array. Its initial
screen loads, CRUD reloads, created-terminal reloads, and
`retryMemoryDistillationVisibility(cardId:)` all use the exact coordinator
request → `InputWorkflowController` terminal → coordinator apply sequence.
Companion/guide traces remain `.memoryNoteLoad + .fixed(.memoryDM)` and
`.campKnowledgeLoad + .fixed(.memoryGuide)`. RootView receives only card ID,
safe failure/count, and the reload action; it never receives a provider, raw
owner ID, persistence closure, or distillation capability. The reducer's
Application tests, plus pathname source gates proving App delegation and zero
direct KnowledgeStore reads, are the executable authority.

`MemoryDistillTests` replaces all old optional/nil
assertions with the flat terminal; `KnowledgeGoldenPathTests` requires
`.created(record)`. In the existing CAS race test the winner asserts the public
persistence result is `true`, while the loser uses
`#expect(throws: MemoryDistillRaceLostError.self)`. These are body migrations
inside existing declarations and do not add tests beyond MD1–MD7.

The existing Distiller tests keep count stability. Exact declaration renames
are limited to
`distillCloseoutFallsBackOnProviderFailure` →
`distillCloseoutPropagatesProviderFailure` and
`distillCloseoutFallsBackOnUnparseableEmptyText` →
`distillCloseoutRejectsUnparseableEmptyText`; the parse-success test adds
`try await`. No other existing test is renamed/deleted/disabled.

## 10. `try?` closure contract

`try-question-mark-inventory.md` is a planning-entry snapshot and lists every
occurrence in all 64 paths by file/current line, operation, fallback, class,
new behavior, and regression. Its 133 count remains the literal snapshot. Its
separate equivalent appendix freezes all 134 entry catch arms, 85 named raw
formatter lexemes plus two reflected-type lexemes, and an independent exact
130-row equivalent-default ledger (89 typed, 14 capture, 27 approved-residual).
Revision03 changes only the two existing Memory catch dispositions:
`E[.memoryDMFailure]` and `E[.memoryGuideFailure]` move from typed propagation
to Service-owned capture-return. The exact 134-arm terminal split is therefore
19 typed, 98 capture, and 17 approved-residual; no catch is added or removed.
The planned-new-catch manifest remains a separate fourteen rows (6 typed, 7 capture,
1 approved-residual). Their globally unique N-tag union is therefore exactly
144 (95 typed, 21 capture, 28 approved-residual). Catch, equivalent-default,
planned-new-catch, approved residual, and exact marker gates remain distinct;
none of those counts is
folded into or relabeled as 133. Entry
counts are not recomputed after line drift; final source gates compare semantic
disposition plus fresh anchored scans.

The implementation rule is exact:

1. business DB/Keychain/permission/MCP/knowledge/state operations: zero
   residual `try?`; propagate typed error or capture one trace;
2. parse projection: no plain empty/nil/false fallback. It either throws to a
   top-level reporter or produces an explicit invalid state carrying trace ID;
3. cleanup: only cancellation sleeps and truly idempotent cleanup may retain
   `try?`, immediately preceded by the exact comment
   `P1-B best-effort cancellation sleep; CancellationError only; no business failure is discarded.`;
   the two UI expiry sites also carry
   `Subsequent UI state cleanup is idempotent.` Any safety/integrity cleanup
   failure is captured instead;
4. test fakes do not use `try?` to hide malformed messages; they fail the test
   or use an explicitly named invalid-fixture path.

AppStore's OAuth network flow and unrelated UI layout remain in place, but all
of their Keychain/DB `try?` operations are replaced or delegated. The slice
does not move whole AppStore sections merely to reduce line count.

## 11. App projection and preview

### 11.1 Visible surfaces

AppStore owns a global `UserVisibleFailure?` plus domain workflow states.
RootView renders a persistent, accessible failure banner with the exact
formatter and a retry/navigation action appropriate to the domain.
RuntimeProfileViews, CodingRanchHome/Rumination/NoteListPane, and
McpStationSection render their local failed state without clearing last-loaded
content. Success clears only the matching operation's failure; an unrelated
success cannot clear another trace.

CompanionEditor assigns form fields only after both the Companion read and
`ToolAccess` parse succeed. `parseFailed` becomes
`projection_decode_failed` with the same visible trace, preserves every prior
form value, and never renders the damaged payload as a legitimate zero-tool
selection.

No view prints diagnostics, raw error descriptions, credential/account values,
provider response, raw MCP stderr, or full external content. VoiceOver uses the
exact §5.4 formula: closed operation label plus the already-formatted safe
message/full trace, with no extra dynamic text.

### 11.2 Isolated preview seam

Only `#if DEBUG` and `AGENTLOOP_UI_PREVIEW=1` together may recognize:

```text
AGENTLOOP_UI_PREVIEW_SCENARIO=p1b-runtime-profile-db-failure
```

AppStore composes `SynchronousRuntimeBootstrap` with the exact DEBUG-only
all-false `RuntimeCredentialPresencePort.preview` value above and composes
RuntimeProfileWorkflowController with a deterministic
`RuntimeWorkflowReads(load:)` that succeeds for synchronous bootstrap and
throws typed `RuntimeProfileReadError` on the first controller refresh. The same
isolated AppDatabase remains writable, so FailureReporter persists the trace.
RootView opens Settings and shows prior profile data plus the failure banner.
Release builds ignore the scenario variable entirely. No product behavior,
normal state root, Keychain, provider, scheduler, MCP process, or tool dispatch
uses this seam.

All DEBUG injection surfaces are explicit and fully erased from release:

```swift
#if DEBUG
package struct CredentialAccessAuditHooks: Sendable {
    package let onRead: @Sendable () -> Void
    package let onWrite: @Sendable () -> Void
    package init(onRead: @escaping @Sendable () -> Void,
                 onWrite: @escaping @Sendable () -> Void)
}
package struct RuntimeResolverAuditHooks: Sendable {
    package let onProviderResolution: @Sendable () -> Void
    package init(onProviderResolution: @escaping @Sendable () -> Void)
}
package struct OrchestratorAuditHooks: Sendable {
    package let onCandidateDispatch: @Sendable () -> Void
    package init(onCandidateDispatch: @escaping @Sendable () -> Void)
}
package struct McpManagerAuditHooks: Sendable {
    package let onStart: @Sendable () -> Void
    package let finishMaintenanceFailure:
        @Sendable (String, McpMaintenanceCompletion)
            -> McpMaintenanceCleanupError?
    package init(
        onStart: @escaping @Sendable () -> Void,
        finishMaintenanceFailure:
            @escaping @Sendable (String, McpMaintenanceCompletion)
                -> McpMaintenanceCleanupError? = { _, _ in nil }
    )
}
package struct McpBridgeAuditHooks: Sendable {
    package let onCall: @Sendable () -> Void
    package init(onCall: @escaping @Sendable () -> Void)
}
extension SynchronizedCredentialAccess {
    package convenience init(store: any CredentialStore,
        auditHooks: CredentialAccessAuditHooks)
}
extension RuntimeCredentialResolver {
    package init(database: AppDatabase, defaults: ProfileScopedDefaults,
        credentialAccess: SynchronizedCredentialAccess,
        accounts: RuntimeCredentialAccounts, defaultBaseURL: String,
        tokenRefresher: (@Sendable () async throws -> String)?,
        auditHooks: RuntimeResolverAuditHooks)
}
extension Orchestrator {
    package static func makeForDebugAudit(
        db: AppDatabase,
        planningProviderResolver: any PlanningProviderResolver,
        makeProvider: @escaping @Sendable
            (String, String?) throws -> (any LLMProvider)?,
        artifactStoreRoot: URL,
        tickInterval: Duration? = .seconds(5),
        searchKeyProvider: @escaping @Sendable () throws -> String? = { nil },
        rateLimitCooldown: Duration = KernelDefaults.rateLimitCooldown,
        mcpManager: McpServerManager? = nil,
        reconcilePostDatabaseGate: (@Sendable () async -> Void)? = nil,
        recoveryPostAdoptionGate: (@Sendable () async -> Void)? = nil,
        resumePreAdoptionGate: (@Sendable () async -> Void)? = nil,
        requiresStartupRecovery: Bool = false,
        legacyRuminationSnapshot: LegacyRuminationStartupSnapshot,
        failureReporter: FailureReporter? = nil,
        contextDependencyLoader: (any ContextDependencyLoading)? = nil,
        auditHooks: OrchestratorAuditHooks
    ) -> Orchestrator
}
extension McpServerManager {
    package init(
        db: AppDatabase,
        transportFactory: @escaping TransportFactory,
        secretProvider: @escaping SecretProvider,
        baseEnvironment: @escaping @Sendable () async -> [String: String],
        initTimeout: Duration,
        callTimeout: Duration,
        auditHooks: McpManagerAuditHooks
    )
}
extension McpToolBridge {
    package init(
        manager: McpServerManager, db: AppDatabase,
        missionId: String, cardId: String,
        serverId: String, serverName: String, toolName: String,
        campId: String?, reporter: FailureReporter,
        makeTrace: OperationTraceFactory,
        auditHooks: McpBridgeAuditHooks
    )
}
#endif
```

Every hook type/property/initializer/use is inside `#if DEBUG`; production
initializers have no hook field and release objects contain none of these
symbols. `onRead` fires immediately before any Keychain store read, `onWrite`
before any set/delete, providerResolution immediately before resolver work,
candidateDispatch before provider/backend construction, mcpStart before
transport start, and mcpToolCall before transport call. The DEBUG-only
`finishMaintenanceFailure` fixture is consulted exactly once immediately
before a valid lease would change Manager state; a matching injected error
returns it with the lease still active. It is used only by the MCP deletion
case table to obtain real opaque pending values, is configured as nil for both
previews, and is absent from release objects. A fixture error whose associated
server ID differs from the lease is normalized to
`.invalidLease(serverId: lease.serverId)`; test input cannot inject a foreign
coordinate. The DEBUG manager
initializer has no defaulted production arguments: AppStore passes the same
literal defaults used by the public initializer, preventing an overload from
silently choosing another transport/time-out policy. `makeForDebugAudit` is the
only DEBUG Orchestrator constructor and duplicates the exact package production
initializer, including the legacy Rumination snapshot. AppStore increments
schedulerKick immediately before MissionScheduler start/run/fire entry. The
audited `SynchronizedCredentialAccess` is constructed before the preview port,
bootstrap, resolver, coordinator, or any account consumer; all real
CredentialStore read/write call edges from process start must pass it. Normal
preview short-circuits all seven paths; the failure preview uses the explicit
presence value plus the injected Runtime DB read only, not a credential or
provider hook.

DEBUG definition/caller guards are closed. Each of the 13 aggregate
`...ForTesting` definitions, its descriptor closure, and its call expression
is entirely inside a direct non-nested `#if DEBUG/#endif` region with no
`#else/#elseif`. `WorkflowProjection.init(testingGenerationValue:)` has exactly
one guarded caller:
`ApplicationWorkflowTests.workflowGenerationRejectsStaleTerminalCompletion`
subcase `debug.generation-overflow`; the declaration's ordinary stale/current
rows remain release-compiled. `PreviewAuditPersistenceBoundary` and its owner
subcase `previewAuditPersistenceFailureFailsClosed` are guarded the same way.

Every audit-hook definition, storage, initializer, Core invocation, AppStore
composition call, preview type/string/persistence caller, and each
`finishMaintenanceFailure` caller is likewise enclosed by its own matching
direct, non-nested `#if DEBUG/#endif` region with no `#else` or `#elseif`.
The `RuntimeCredentialPresencePort.preview(_:)` definition and both preview
composition call expressions follow the same direct guard rule; release
artifacts contain no demangled `RuntimeCredentialPresencePort.preview` label.
Release branches call only production initializers; production types never
retain nil/no-op hook storage. `finishMaintenanceFailure` has exactly four
guarded caller groups: the one
Manager consult immediately before a valid lease mutates state; MCP test rows
`debug.finish-failure.rollback-pending` and
`debug.finish-failure.deleted-pending`; and AppStore preview composition's
explicit always-nil closure. All other MCP deletion/cleanup rows compile in
release. A conditional-region source parser proves every named DEBUG token has
zero unguarded occurrence; release artifacts contain zero, while each debug
owning target contains the expected token.

Normal and failure previews use separate `mktemp -d` canonical `/private/tmp`
roots and one fresh debug bundle. Before each launch, if any non-owned
AgentLoop process exists, preview stops instead of killing it. Each run passes
`AGENTLOOP_UI_PREVIEW=1`, its exact `AGENTLOOP_STATE_DIR`, and (failure only)
the scenario via `open --env`; `scripts/run-app.sh` is not modified. Graceful
TERM must leave owned process count zero.

Evidence proves:

- normal Application Support open count is zero;
- Keychain/provider/scheduler/MCP/tool-dispatch counts are zero;
- screenshot contains the exact visible failure pattern;
- disposable DB `failure_record.id` exactly equals the full screenshot trace,
  with sanitized operation/errorCode/message;
- normal preview has no injected failure and both roots remain isolated.

The evidence mechanism is frozen and fail-closed:

1. Build/assemble/sign exactly one `.build/AgentLoop.app`, resolve its
   executable with `realpath`, and record its SHA-256. Before launch, both
   `pgrep -x AgentLoop` and `pgrep -x AgentLoopApp` must return zero; otherwise
   stop without terminating anything.
2. Immediately before `open -n --env ...`, record UTC start time. Resolve the
   launched PID from `ps`, require exactly one candidate, and use a temporary
   Swift `proc_pidpath` probe plus `ps -o lstart=` to prove its executable path
   and start time match this launch. Unknown, extra, pre-existing, or mismatched
   processes fail the preview. TERM is sent only to that recorded PID after the
   same ownership check is repeated; exit-to-zero is verified.
3. Run `lsof -p <owned-pid>` and fail if any descriptor path is at or below the
   canonical normal root
   `~/Library/Application Support/AgentLoop`. Require the isolated root and its
   `agentloop.sqlite` to be open instead.
4. A `#if DEBUG` AppStore type named `P1BPreviewAudit` injects Sendable increment
   closures into only the allowed Runtime resolver, Orchestrator,
   McpServerManager, and McpToolBridge boundaries. Its exact counters are
   `keychainRead`, `keychainWrite`, `providerResolution`, `candidateDispatch`,
   `schedulerKick`, `mcpStart`, and `mcpToolCall`. `candidateDispatch` increments
   before any backend construction and therefore dominates every built-in tool
   call; `mcpToolCall` owns external-tool calls. It atomically writes sorted JSON to
   `<isolated-root>/p1b-preview-audit.json` on every counter change and at
   shutdown. Both previews require every counter zero. The release App binary
   must contain zero symbols/strings matching `P1BPreviewAudit`,
   `p1b-preview-audit.json`, `AGENTLOOP_UI_PREVIEW_SCENARIO`, or
   `p1b-runtime-profile-db-failure`; the debug App binary must contain all four.
   `swift build --show-bin-path -c debug|release` returns only a configuration
   directory. The gate resolves the exact executable/object manifests from
   that directory by §14.2 and never uses an automatic product fallback,
   arbitrary glob, or first matching object.
   Before either preview launch, the existing
   `ApplicationWorkflowTests.keychainReadDistinguishesNotFoundFromFailure`
   declaration runs the DEBUG subcase `preview-credential-audit-canary`: an
   in-memory `CredentialStore` is wrapped by the same
   `SynchronizedCredentialAccess`/`CredentialAccessAuditHooks`, one deliberate
   read changes `keychainRead` from zero to one, and the strict-zero evaluator
   rejects that snapshot. The same subcase then runs bootstrap through
   `RuntimeCredentialPresencePort.preview` and proves the wrapped store count
   remains zero. It contacts no macOS Keychain and adds no `@Test` declaration.
   `verify.log` must contain the passing canary before `preview.log` may accept
   either real preview's all-zero JSON. A source gate proves every release and
   DEBUG real CredentialStore `get/set/delete` edge is dominated by the audited
   synchronized access; direct AppStore/bootstrap/resolver credential-store
   calls are forbidden.
5. Screenshot evidence is visual only. A temporary read-only macOS
   Accessibility probe enumerates the owned PID's static-text/accessibility
   values and must recover exactly one full trace matching the safe formatter.
   `sqlite3 -readonly` then selects `id,operation,errorCode,userMessage` from
   the failure preview's isolated DB. Exact AX trace == DB id, safe message
   equality, the DB query, executable/PID/lstart proof, `lsof` result, audit
   JSON, and command statuses are written to
   `evidence/preview-db-correlation.txt` and `preview.log`. OCR or a screenshot
   alone never establishes correlation.

## 12. Failure-first implementation order

1. Verify the already-frozen Revision 04 document hashes and require immutable
   Review05 `APPROVED` with zero P0/P1, then reuse the already captured entry
   manifest without
   changing any planning bytes. Any planning-byte drift reopens plan review
   before implementation.
2. Add v13 migration tests/runner/script assertions first. Record expected red
   only because v13 is absent/final migration is still v12.
3. Register exact v13 and make the eight-fixture dual-SQLite matrix green.
4. Add failure types/reporter tests, then FailureRecord/Reporter and the exact
   AppDatabase failure transactions/read bundles.
5. Add credential/OAuth tests, then Keychain invalid-value handling, shared
   synchronized access, coordinator, and OpenAIOAuthSession typed boundary.
6. Add MCP tests, then Manager maintenance/typed APIs and Bridge atomic failure
   path.
7. Add context required/optional tests, then Context loader and Orchestrator
   integration/compatibility overloads.
8. Add Package/Application target and workflow tests, then WorkflowProjection,
   synchronous Runtime bootstrap, read carriers, controllers, and compile
   fixtures. Application cannot precede its Core bundle/credential types.
9. Add MemoryDistill typed tests and implementation.
10. Wire AppStore/McpStore/Adapter projections, Views, and DEBUG isolated
    preview; no App fallible decision remains outside a mapped seam.
11. Close both literal and equivalent inventories from Core outward; parse and cleanup residuals must
   satisfy §10 exactly.
12. Run targeted tests, matrix, eight debug/release target compile gates plus
    two explicit AgentLoopApp product-link gates; extract the frozen inline
    terminal-AST producer and generate its six-pair 43-path corpus. The driver
    does not run the real-corpus validator. Run source gates inside one fresh
    unfiltered authoritative RunTests: its single final scanner invocation
    extracts and runs the independent validator exactly once, consumes the new
    validation handoff, and completes typed extraction from retained bytes;
    then run the two isolated previews.
13. Write `impl-report.md`; run a fresh responsibility-isolated implementation
    review. Only an approved implementation may receive independent acceptance.

No green test is deleted, filtered, skipped, serialized, relaxed, retried after
failure, or replaced by source-string evidence alone.

## 13. Exact test obligations

The slice adds exactly **47** new `@Test` declarations. Existing tests may be
updated for typed signatures and only the two exact Distiller semantic renames
frozen in §9 are permitted; no existing test may be deleted, otherwise
renamed, disabled, or duplicated. Every declaration below is an ordinary
non-parameterized `@Test`:
Swift Testing `@Test(arguments:)` is forbidden in this slice because each
argument would change the authoritative test count. Case matrices run as
deterministic table loops inside their one owning declaration, fail with the
case tag, and emit one base test ID exactly once.

### 13.1 `FailureVisibilityTests.swift` — 18 new declarations

1. `observabilityMigrationExactDDLAndConstraints`
2. `observabilityMigrationRollbackLeavesV12ScheduleUntouched`
3. `failureRecordInsertUsesTraceAsPrimaryKey`
4. `failureRecordSameIdentityUpsertIncrementsOccurrence`
5. `failureRecordTraceConflictDoesNotOverwrite`
6. `failureRecordResolveReopenAndOverflowAreChecked`
7. `failureReporterScrubsSecretsAndRawExternalResponses`
8. `failureReporterDatabaseUnwritableLogsAndReturnsSameTrace`
9. `userVisibleFailureContainsExactFullTrace`
10. `operationTraceGeneratesAndAdoptsSafeDurableIdentity`
11. `requiredKnowledgeFailureAtomicallyBlocksAndRecordsDegradation`
12. `optionalKnowledgeFailureRecordsBeforeContinuingWithMarker`
13. `optionalDegradationPersistenceFailureDoesNotContinue`
14. `requiredMcpRegistryFailureBlocksCard`
15. `mcpSecretAbsentAndReadFailureHaveDifferentCodes`
16. `mcpConnectAndToolListFailuresHaveDifferentCodes`
17. `contextDegradationKernelEventOccursOnlyAfterCommit`
18. `invalidProjectionCasesAreTraceableAndNeverDefault`

The first two use internal loops across the eight predecessors/dual schema
contract as appropriate and cover every §4.4 legal/illegal CHECK/FK/redaction/
boundary shape. Test 6 includes the immutable-redacted-tombstone case. Test 18
uses an internal loop across all 13 production parse tags and asserts mutation
lanes have zero partial writes. The two TestSuite fake parse tags execute in
their existing MCP fake-helper tests and join the same immutable 15-tag literal
set without claiming a production seam.
Test 13 also proves a failed degradation transaction session-suppresses the
ready Card across ticks, dispatch resume does not clear it, and only explicit
retry/process restart allows one new traced attempt.
The two atomic production owners are `AppDatabase.persistContextFailure` and
`AppDatabase.persistMcpConnectionDown`. Their deterministic post-upsert faults
have exact owners: MCP `mcp_server_down` event append belongs only to
`McpTests.toolBridgeEventWriteFailureRemainsVisibleWithTrace`; required Card
transition/event rollback belongs only to
`FailureVisibilityTests.requiredKnowledgeFailureAtomicallyBlocksAndRecordsDegradation`;
optional `context_degradation` insertion rollback belongs only to
`FailureVisibilityTests.optionalDegradationPersistenceFailureDoesNotContinue`.
Every such
transaction rolls back, invokes `persistPrepared` once with the byte-identical
original `PreparedFailure`, and proves one original trace/errorCode, no
contradictory row/auxiliary event, and zero dispatch. Test 8 owns only isolated
failure-table-unwritable -> safe logger/UI fallback: no DB record, one fixed
safe terminal logger line, the same UI trace, and zero retry or dispatch. Test
8's separate pre-composition stage table invokes the real
`ApplicationBootstrapFailureBoundary.capture` for `.previewUserDefaults`,
`.stateDirectory`, and `.databaseOpen`, requires the three fixed safe
message/code pairs plus one full-trace sink entry, and proves no supplied raw
suite/path/Error can enter evidence. Production termination is source-gated to
the boundary's sole `terminate` primitive and is not invoked by the test. Test
12 owns optional atomic success; Test 17 owns only post-commit awaited event
ordering. Test 17 uses an ordered ledger and requires database commit < awaited
KernelEvent sink < ready return < provider/backend/tool dispatch; transaction
failure yields zero event, marker, provider, backend, and tool calls. Tests 7
and 9 run formatter boundaries for ASCII, combining scalars, and multi-scalar
emoji using `unicodeScalars.count`; every accepted at-most-1000-scalar message
must pass SQLite `length(TEXT)` and round-trip byte-identically, while the
1001-scalar candidate is truncated before insertion. Diagnostic JSON keeps its
independent 4096 UTF-8-byte boundary.
Tests 5–7 also exhaust `FailureOperation.allCases`, FailureScope type/fixed/
record coordinate pairs, FailureCode.allCases, and every typed classifier case.
They inject account, key, path, prompt, callback, server/tool display name,
external response, stderr, and reflected-type canaries into every associated
value and assert none reaches DB, logger, KernelEvent, ToolOutcome, UI, or
Accessibility. Invalid metadata is rejected before I/O; trace-identity,
credential/MCP rollback, proposal composite, Memory owner/thread/race,
projection-contract, and backend-capability codes round-trip exactly and a
same-trace identity conflict never overwrites the original row.

### 13.2 `ApplicationWorkflowTests.swift` — 14 new declarations

1. `databaseReadFailureIsFailedNotLoadedEmpty`
2. `workflowProjectionPreservesPriorValueOnRefreshFailure`
3. `workflowGenerationRejectsStaleTerminalCompletion`
4. `workflowCancellationCannotMasqueradeAsLoaded`
5. `missionStartPreservesCallerDurableTrace`
6. `runtimeProfileWriteFailureNeverProjectsSuccess`
7. `runtimeProfileDeleteFailureNeverProjectsSuccess`
8. `runtimeReconcileFailureNeverChangesDefault`
9. `keychainReadDistinguishesNotFoundFromFailure`
10. `keychainMutationFailureNeverProjectsSuccess`
11. `mcpRegistryRefreshFailurePreservesPriorRegistry`
12. `inputRefreshFailurePreservesDashboardAndInbox`
13. `committedVisibilityFailureCannotRepeatMutation`
14. `codingRanchBootstrapIsAtomicAcrossEveryWriteBoundary`

Test 14 invokes the real public bootstrap API with SQLite abort triggers and no
DEBUG production hook. Its four rows fail: guide insert; legacy guide update;
base-cow insert for `CowTemplate.baseCowId`; and the
`base_cow_provisioned` event insert. Each row proves the complete pre/post Camp,
Companion, and matching-event snapshot is byte-identical, the Application
terminal is `.notCommitted`, the typed bootstrap state retains the exact
failure/trace, downstream listener/recovery/scheduler/provider/Kernel dispatch
counts are zero, and one full retry—after a throwing `DROP TRIGGER` plus an
exact query proving that trigger absent—produces exactly one stable Camp,
one guide upgraded to `营地管家`, one base cow, and one provisioning event. The
Application post-database boundary binds the returned
`CodingRanchBootstrapResult` explicitly, owns one trace, captures a thrown
terminal once, and does not dispatch after failure. Trigger teardown never uses
`try?` or suppresses a cleanup error. Initial composition and RootView retry use
the same typed boundary and distinct fresh traces; initial runs before `self`,
while the sole retry method accepts only `.failed`. Initial composition
constructs but does not claim the joint Application startup gate. After
AppStore initialization, RootView's existing `onAppear` invokes the repeat-safe
activation entry once per appearance; retry successes feed that same gate
directly. An internal
gate table covers Runtime failed/loaded × Ranch failed/loaded and both success
orders: either one alone returns `.waitingForOther`; the missing peer's recovery
returns `.startNow` exactly once; all repeats return `.alreadyStarted`. Each row
asserts a supplied downstream-start counter stays zero or becomes one
accordingly while executing the exact Application type. A pathname/source gate
separately proves AppStore stores that type, passes the exact installed values,
and invokes downstream only for `.startNow`; the initializer has zero gate
claim/downstream edge and repeated RootView appearances remain one-start. No
copied Boolean fixture is claimed as App runtime evidence.
Existing expert-roster/
idempotence rows remain: expert roster succeeds atomically with
`baseCow == nil`, while an existing base cow never appends a second event.
Source gates require exactly
one `pool.write` in `ensureCodingRanchBootstrap`, exactly one
`Self.ensureDefaultCamp(database)` call and zero public `ensureDefaultCamp()`
calls in that body, and the guide update, cow insert, and event append to use the
same closure-local `database`. Bootstrap compensation, partial-commit repair,
and DEBUG fault-hook declarations are forbidden. App pathname gates require
the initial typed-terminal gate constructor plus both
`runRuntimeBootstrap()`/`runCodingRanchBootstrap()` retries to use the same
stored gate, and require every downstream start edge to be dominated by
`.startNow`; no Ranch-only, Runtime-only, or second start Boolean exists.

Test 13 includes the committed Memory visibility row. DM and guide creation are
allowed to commit once, then their separate note/knowledge reload is faulted.
The App keeps the created record/watermark/event, displays the reload trace, and
its offered retry invokes only that reload. Provider, captured-watermark CAS,
note insert, and creation-event counters remain one total across the retry. A
Application reducer fixture runs companion and guide separately, then runs two
created terminals for the same owner with both reloads faulted: it proves one
stable card ID, two exact committed records in service-terminal order, the
latest reload failure, and a nonzero count of two. A stale card-ID action is
pre-trace zero work; an exact retry failure preserves the list and replaces
only the failure; an exact retry success removes only that owner card. The
nonvisible-owner rows load successfully without overwriting the currently
visible companion/Camp projection. It also selects A successfully, then selects
B and faults B, proving B exposes `[]` plus B's failure and never A's rows; a
later B success remains cached when A is visible without overwriting A. These
are runtime tests of the exact Application type AppStore stores. Only
AppStore's zero-direct-read delegation and RootView binding remain
pathname/source/compile evidence because AgentLoopTestSuite does not import the
App target.

Tests 1–4 use internal tables over all four controllers. Runtime command cases
include set/delete/post-write verification; MCP includes config/registry/
secret/list; Input and Mission prove prior projection preservation.
Tests 1, 2, 8, and 12 also exercise every Core pure read bundle through a
barrier-controlled concurrent writer: Mission detail/index; Input Camp/review,
mission-draft; runtime bootstrap/default/provider resolution; Schedule
workflow/runtime/notification must each be entirely pre-write or entirely
post-write, never mixed. Chat/Guide history creation, atomic turn preparation,
and ingestion deletion use a two-writer serialization ledger plus abort
triggers instead: they prove the user-message commit and returned post-insert
history share one transaction, a concurrent writer cannot interleave, and a
fault before commit leaves no new thread/message or partial deletion. The runtime rows use a
private UserDefaults suite and the one injected `ProfileScopedDefaults`; they
prove synchronous AppStore composition requires no actor await and neither
bootstrap, catalog/reconciliation/default commands, nor verification touches
`UserDefaults.standard`. Test 9 additionally proves a selected search key is
read exactly once and handed off byte-for-byte, while an unselected or
legacy-inherited capability performs zero search reads. Its DEBUG
`preview-credential-audit-canary` subcase proves one in-memory store read makes
the shared audit nonzero and fail-closed, while the explicit preview presence
port executes the same bootstrap with zero store reads/writes. Context cases cover
model MCP/search success, CLI explicit MCP/search atomic block with zero
provider/backend/tool/MCP/search calls, and compatible CLI dispatch without an
unsupported explicit selection.
Test 9 and the existing Test 18 Runtime descriptor rows hard-code the exact
twelve-case `RuntimeCredentialResolutionError.Kind` set and exhaust its
construction matrix. Separate retained Planning rows keep the existing
`PlanningProviderResolutionError` contract byte-for-byte. Runtime rows assert
`code`, `failureCode`, `retryable`, safe message, category, domain, and optional
OSStatus; only the associated
`.keychainReadFailed(osStatus:)` lane may carry that diagnostic. The provider's
exact CLI/API-or-OAuth-access item-not-found lanes, the required OAuth
account-ID item-not-found typed failure, Search's exact item-not-found
lane, and each live presence bit's own item-not-found lane produce only their
specifically allowed nil or false terminal; the preview all-false value is
proved to bypass the resolver entirely. Blank-present, invalid UTF-8, Runtime
DB/catalog/model/endpoint, and non-not-found Keychain failures, plus injected
strict-Planning credential/factory failures, throw the exact typed kind with
no empty/success-like projection. The retained strict Planning rows keep their
factory-failure, missing-credential/account, and CLI cases. A source/compile
gate rejects a Runtime alias to the Planning error, a second Runtime error
type, raw code/message initializers, generic catch-to-nil conversion,
cross-error passthrough, and any resolver nil/false outside those
callable-specific lanes. The OAuth table proves one lock and exact envelope ->
access -> refresh -> ID -> account-ID snapshot; missing access returns nil only
after that consistent snapshot, present access plus missing account ID throws `.oauthAccountIdNotFound`, and
every non-not-found account-ID failure preserves its exact Keychain status or
generic credential-read Kind. Prepared/absent envelope permits normal provider/
presence results; any committing phase or malformed/noncanonical envelope maps to the exact typed read
failure before returning any OAuth field. The live-presence table proves the exact
API-key -> Search-key -> envelope -> OAuth-access -> refresh -> ID -> OAuth-
account-ID order with the same interaction policy: a failure injected at
positions one through seven produces exactly 1...7 reads, zero later reads, no partial presence, and the exact
typed credential terminal. Retained Strict Planning rows additionally prove
that an invalid or missing API endpoint performs zero catalog, credential, and
factory calls and remains `.endpointInvalid`; a valid normalized endpoint is
the exact URL handed to the catalog/factory path.
The same ordinary declarations compare candidate-ID and ingestion-ID Mission-
draft bundles with the public factory field-for-field; duplicate candidate/
link, missing or wrong-Camp note, and malformed detail fail with no `来源笔记`
fallback. Chat/Guide cases require the last prepared history item to be the
just-inserted user message and cover malformed preexisting history, insert
abort, write serialization, exact committed stream terminals, and delta-only/
non-text rejection. Existing `ScheduleTests.scheduleCRUDAndClaimDedupe` adds
public-wrapper/static-helper parity, while
`scheduleFiredEventMarksScheduledOrigin` adds an existing malformed event that
throws the exact projection error. These are internal cases, not new or renamed
`@Test` declarations. Test 13's internal MCP cleanup rows invoke
`McpCleanupApplyGuard`: exact token+attempt may remove once, while changed
token, changed attempt, missing current token, and a late stale failure all
return false. A pathname/anchor gate proves McpStore's retry façade delegates
both the guard and `mcpFinishServerCleanup` rather than restating either rule.
Test 13 also owns the closed credential-attachment lifecycle table: a Search-
key save and delete preserve an existing API-key pending byte-for-byte; a
failed API-key delete preserves it; a committed API-key delete compare-clears
it; and every late retry after that delete performs zero DB and Keychain I/O
and cannot reinsert or attach. The table additionally proves a failed newer
API-key write preserves the old pending, while each committed newer API-key
terminal either replaces it with the exact new pending or clears it only after
the required attachment has completed. A default-A target drifting to default
B makes the first retry write no wrong profile and transition only to
`.resolveDefault`; the second retry attaches eligible B exactly once, while a
noneligible or already-correct B completes without a write. Both retries keep
the Keychain write counter at zero. The same rows assert the receipt field
exactly: Search success and Search post-write visibility failure are nil; every
API-key post-Keychain pending step retains the byte-equal API/nil base receipt;
normal CAS and zero-row same-target/same-account idempotent CAS return the exact
target ID; reload failure retains that same completed ID; prepare-nil for both
noneligible and already-attached defaults remains nil; A-to-B conflict is nil
until a successful B CAS yields B's ID; and stale/superseded paths perform zero
I/O and cannot reinsert an old ID. Slot and original trace remain unchanged in
every terminal.

The same Test 13 declaration owns the mandatory OAuth-lifecycle tables over
the real Core/Application Runtime controller boundary with injected platform
factory/port doubles; AgentLoopTestSuite never imports or instantiates
AgentLoopApp/AppStore. Its executable rows cover every reservation, controller
phase, opaque lease, sink, platform-call, Reporter, codec, state, and credential
counter below. The corresponding AppStore lifecycle/physical-owner assertions
are pathname-exact source plus compile fixtures in the same Test 13 subcase:
they parse the production App declarations/transitions and are compiled by the
normal App target gate, but are not falsely reported as TestSuite runtime calls.
Thus (1) a synchronous listener/preparation
failure stops exactly the candidate receipt, leaves the envelope preimage
byte-identical, and leaves no listener owner; (2) A's App `.reserving` state is installed with its lifecycle
Task before the first await; a B tap queues one rejection, and after the actor
mints A's reservation B is rejected exactly once while A proceeds normally;
(3) reserve completion followed by B/prepare actor jobs in either order still
uses one byte-equal reservation and never treats B as an empty-flow attempt;
(4) a second begin during A's preparing, post-preparation, browser-opening,
ready, listener-restart, browser-reopen, callback-claim-awaiting-App,
callback-processing, or controller-private callback-cleanup phase is rejected before
RNG/listener/state/Keychain/platform I/O and leaves A byte-identical; (5)
callback A commits credentials and B remains blocked while the exact inline
listener-stop/reload cleanup is suspended; the terminal then removes only A's
callback-processing carrier and B may become owner; (6) duplicate/stale cleanup
and reopen terminals fail the App+controller value/attempt compare-and-remove
guards and cannot erase a current pending. No callback-cleanup retry capability
or App state exists.
The TestSuite controller table directly covers A-live -> attempted-B
reservation/rejection, while the AppStore pathname fixture proves the real
`openProviderAuth()` façade's third branch delegates only to that reject-only
controller API and B can reach neither listener nor preparation; there is no
replacement rollback path. If A remains current,
the separately owned B rejection persists exactly one fixed
`oauth_authorization_failed` failure on B's trace through the real reporter
(or its one unavailable fallback) and never attributes that failure to A. If A
finishes between the App check and actor rejection, B returns `.superseded`,
emits no failure, and starts no authorization. Two taps share one rejection
single-flight. Both lanes prove the B Task never makes A's late terminal stale
or clears any A carrier. The pre-reservation lane captures only
`.reserving(attempt:queuedRejection:)`; it does not call the actor until A's
reservation is installed. Every launched rejection captures the exact
reservation-bearing App state. A transition between that capture and B
terminal makes the result stale rather than forcing App to read a
controller-private owner. Direct package double-reserve, A failure before a
late rejection, a newly reserved C versus stale A/B, queued-rejection
single-flight, and every attempt/reservation-mismatch terminal are mandatory
rows with zero unintended business I/O.
The reservation table is global, not merely same-flow. It repeats the complete
matrix in both directions (`chatGPT` A / `generic` B and `generic` A /
`chatGPT` B): B tap while A is App-reserving, and B actor reservation while A
owns reserved, preparing, post-preparation,
browser-opening, ready, recovery, callback claim, callback processing, or
cleanup. B has zero RNG/listener/state/
verifier/browser/codec/exchange/credential effects. A failed atomic envelope
write clears A as not committed before B's first envelope write; A cleanup-
pending blocks B through exact cleanup completion. After B begins, stale A
retry/callback/cleanup has zero
mutation against B. A generic custom URL while ChatGPT owns the global
lifecycle is superseded without changing ChatGPT; generic preparation has
listener mint/start zero. The measured maximum concurrent authorization owner
and verifier owner is one.
The App-reserving rows additionally change the mutable selected profile/API
format after B's tap but before A's reservation terminal. The queued rejection
must still use its byte-equal stored `requestedFlow`; rereading the later
selection is forbidden. Both directions assert one rejection capture on B's
original flow/scope and zero reject call for the replacement selection.
The table also runs sequential completed logins in both directions against one
seeded five-account bundle. ChatGPT → generic finishes with the generic access
and optional refresh only, with ID/account deleted; generic → ChatGPT finishes
with ChatGPT access, its supplied-or-deleted refresh, supplied-or-deleted ID,
and required derived account ID. Each transition reads the complete preimage,
uses the fixed full-replacement order, rolls back every changed field on each
Nth write fault, and leaves no credential from the prior flow. Runtime resolver/
Session tests consume that exact postimage and never mix a prior flow's refresh,
ID, or account into the new access token.

The atomic preparation table starts from absent, canonical `.prepared`,
canonical `.recoveryPrepared`, every committing phase, legacy raw, malformed,
noncanonical, and unknown-version/phase readable preimages, with both
owner-equal and owner-different canonical fixtures. Absent and every valid
canonical `.prepared` preimage select ordinary `.prepared` for the requested
owner. Owner-equal `.recoveryPrepared` or committing preimages select
owner-equal `.recoveryPrepared`; owner-different recovery/committing preimages
and every unprovable legacy/malformed/noncanonical/unknown item return exact
`.unavailable` and remain byte-identical. The table injects pre-read failure and
failure in the sole item set/update, and asserts one
not-committed terminal, one capture on the original authorization trace, the
preimage byte-identical, the exact listener stopped, and the global controller/
App attempt cleared. There is zero repair capability/Task, second write,
state lock, full-authorization retry, browser, callback codec, exchange, or
credential replacement. Success performs exactly one atomic set of the
locally proven canonical selected-phase envelope and no post-set read. A
separate invalid-coordinate row supplies each empty, duplicate, and
credential-equals-global-envelope bundle to the nonthrowing preparation
commit. It returns exact `.unavailable`, and the controller exhaustively maps
that value to one not-committed typed failure with exact listener stop/owner
clear plus zero lock/revision/store/browser/callback/credential work; neither
`.failed` nor `.committed` is fabricated. A
simulated process restart constructs an empty controller/App owner over a
durable committing or recovery-prepared item for bundle A. An overlapping
bundle B and credential-field-disjoint-but-shared-envelope compatibility bundle
C each attempt both preparation and callback: neither can change/delete A's
envelope or read a credential field, and each returns the fixed unavailable or
state terminal before callback exchange/commit. Only an exact five-coordinate
A owner may replace the item with owner-equal `.recoveryPrepared`; Runtime,
Strict Planning, presence, and Session remain quarantined throughout that
replacement browser interval. An old local or custom callback has zero
claim/exchange/credential work and cannot delete the new envelope. The exact-A
callback succeeds with the new state/verifier, writes the complete A bundle,
and only its final envelope delete makes credentials readable. Legacy raw,
malformed/noncanonical JSON, unknown version/phase, duplicate/extra/missing
keys, invalid/missing owner keys, wrong owner/flow, and blank state/verifier
never acquire a recovery owner and remain closed failures without exposing
bytes.

The initial credential-commit half adds a crash barrier after every fixed
mutation boundary. Before mutation the canonical `.prepared` envelope permits
the seeded old bundle through Runtime, Strict Planning, and presence snapshot
readers, while Session refresh rejects before network so it cannot collide with
the pending authorization. Canonical `.recoveryPrepared` permits none of those
credential reads. The first callback mutation changes either preparation phase
only to `.initialCommitting`;
from that barrier through the final credential-field write, a fresh simulated
process makes all consumers throw their exact safe unavailable/read
terminal and returns no credential or partial presence. In-process injected
errors restore fields in reverse and restore the byte-equal original
preparation envelope only after all field restores succeed; an injected field
restoration failure proves the envelope restore is not called and leaves
`.initialCommitting`. A final envelope-restore failure likewise remains
fail-closed. Only the final successful envelope
delete makes the complete new bundle visible. Replacing a stale committing or
recovery-prepared item with a fresh **same-owner** authorization produces
another owner-equal `.recoveryPrepared` item and never re-enables the old or
mixed bundle; a different owner cannot replace it. No row maps
quarantine to nil, unauthorized cleanup, a refresh HTTP call, or a success-like
projection.

The descriptor transcript for
`N[.oauthAuthorizationStatePersistence]#default` injects the one atomic item
write failure. Its expected seam-counter multiset is exactly
`{oauthAuthorizationPreparation: 1}` with one trace and one not-committed
capture; success and strict-decode rejection rows have zero extra descriptor
occurrence and no new variant.
The same table requires direct reserve/reject protection during
callback-processing: a second reserve is one B failure on B's reservation-
bound trace, performs zero RNG/listener/state/codec/exchange/credential I/O,
and leaves A's callback owner byte-identical. It then injects browser-open failure and asynchronous listener failure
in both orders. It requires one merged `.listenerThenBrowser` pending, then
listener restart before browser reopen; listener-retry failure retains both,
listener success plus browser failure reduces to `.browserReopen`, and full
success becomes ready. A listener failure arriving while browser reopen is
suspended invalidates the old terminal and preserves the merged pending.
Duplicate listener failure, duplicate retry, and every late completion perform
zero extra state/verifier generation and cannot drop an obligation. App's
single `authorizationRecovery` case stores the exact combined pending; it has
no parallel listener/browser maps.

The same Test 13 declaration owns an independent custom-scheme ingress tuple:

```text
ingressInstalled, claimInvoked, claimSettled, claimAccepted,
appPromoted, claimAbandoned, logicalCompleted
```

Its only legal vectors are installed `(1,0,0,0,0,0,0)`, claim suspended
`(1,1,0,0,0,0,0)`, claim superseded `(1,1,1,0,0,0,0)`, claimed before App
promotion `(1,1,1,1,0,0,0)`, promoted before business finish
`(1,1,1,1,1,0,0)`, accepted then abandoned `(1,1,1,1,0,1,0)`, and promoted
completion `(1,1,1,1,1,0,1)`. Every other vector fails. Every row also proves
the physical seven counters, listener mint/start/stop, physical cancellation,
and physical acknowledgement remain zero.

Mandatory direct rows deliver generic callbacks during browser opening, ready,
browser recovery, and in-flight browser retry; permute actor claim against the
browser/recovery terminal and a controller terminal sealed before its delayed
App apply; prove promotion adopts only opaque controller-current `claim.origin`
and makes the old terminal stale; and prove claim-first invalidates an in-flight
retry while retry-first is claimed at its exact current stage. Duplicate
`.onOpenURL` during ingress, claim, processing, and cleanup produces zero second
trace/claim/codec/exchange/commit. Cancellation before a superseded claim clears
only ingress; cancellation after `.claimed` abandons. Custom ready abandon
restores ready and browser/recovery abandon restores exact pending. A callback
whose state belongs to old generation A delivered while B is browser-opening,
ready, or recovery returns claim `.superseded` before the claim CAS: B's
controller owner, App Task/carrier, and preparation envelope remain byte-identical,
with zero payload parse/exchange/commit. Only a state-matched claimed callback
may later produce `oauth_state_invalid` for a different payload invariant. Committed
cleanup performs only reload with listener stop zero, and a stale ingress can
neither commit nor clear a newer generation.

The physical-listener closure has two explicit evidence halves. TestSuite's
injected platform double freezes opaque controller generations independently of
the authorization receipt and proves the controller-visible transcript. Every
callback command carries the opaque lease from its physical event, but a lease
alone is not treated as acknowledgement. Recovery retry freezes the exact
order `record attempt -> stop old lease -> await callback/failure drain ->
actor recheck -> mint/install G2 -> start G2`; no row may install G2 before the
old stop returns.

The controller/port-double table has seven independent counters per callback:
`physicalYielded`, `claimInvoked`, `claimAccepted`, `appPromoted`,
`claimAbandoned`, `physicalAcknowledged`, and `logicalCompleted` in that order.
It freezes these exact seven-tuples at the named barriers/terminals:

- yielded but physical begin not yet accepted, or begin later mismatches:
  `(1, 0, 0, 0, 0, 0, 0)`;
- eligible claim call suspended before its actor result:
  `(1, 1, 0, 0, 0, 0, 0)`;
- `.claimed` returned before App promotion:
  `(1, 1, 1, 0, 0, 0, 0)`;
- claimed promotion installed before callback business completion:
  `(1, 1, 1, 1, 0, 1, 0)`;
- accepted-but-unpromotable claim closed by abandon:
  `(1, 1, 1, 0, 1, 1, 0)`;
- sealed actor reject: `(1, 1, 0, 0, 0, 1, 0)`;
- exact current local route/state reject with listener restoration:
  `(1, 1, 0, 0, 0, 1, 0)`;
- preparing/invalid-state local reject: `(1, 0, 0, 0, 0, 1, 0)`;
- promoted logical completion, including a sealed capability supersession:
  `(1, 1, 1, 1, 0, 1, 1)`.

`physicalYielded` means the producer successfully placed the already physically
claimed event in the stream; a pre-yield connection rejection has the all-zero
tuple and is not a callback row. At every barrier with
`physicalAcknowledged == 0`, the old stop waiter remains pending and G2
mint/start counts are zero. After acknowledgement, only the controller old-
owner/attempt/lease recheck decides whether G2 may start: local/sealed rejection
with byte-identical controller recovery may proceed; claim, abandon, or any
different controller owner makes the retry stale. No other tuple is legal.

A queued eligible G1 callback keeps stop pending while the
serial consumer calls the non-I/O claim. If G1 claim wins, controller phase
becomes `.callbackClaimAwaitingApp`; App promotion/abandon then acknowledges the
physical claim, stop resumes, and the waiting retry recheck is stale with G2
mint/start count zero. If G1 is locally rejected, or actor-rejected while the
controller recovery owner remains byte-identical, App state/Task is
byte-identical until the stable reject/finish, stop resumes once, the recovery
recheck remains current, and only then may G2 be minted. If actor rejection was
caused by a different/newer controller owner or duplicate claim, the old
recovery recheck is stale and G2 mint/start remains zero. No row relies on
actor FIFO or Task cancellation.

The physical transcript also delivers stale authorization A's browser URL to
the new current authorization B's local listener after B owns its exact
reservation, authorization, and lease. The local claim invokes the pure state
matcher once, returns `.currentAuthorizationRejected` before controller
mutation, compare-clears only the exact tentative App candidate, and
restoring-finishes B's plain slot back to `.live`. B's controller/App owner and
lifecycle Task remain byte-identical; payload parse, exchange, credential, and
Reporter counts are zero; and the seven-tuple is
`(1,1,0,0,0,1,0)`. The next exact B URL is then claimed, promoted, and
completed once. The inverse state-valid A event carrying a stale A lease
returns `.superseded` and may not use the current-restoration lane. Repeat both
rows with a concurrent listener failure and retire waiter: the independent
failure member/drain remains and no failure-bearing slot reopens.

The table then injects a current G2 callback and a current G2 failure around the
start await with both actor orders. If callback claim or failure sink wins the
actor before the start caller rechecks, it changes the controller phase; the
mandatory post-start phase+lease+attempt recheck is stale, compare-stops only
G2, and publishes zero false ready/App success. If the start caller rechecks
first, it may advance only to the ordinary post-preparation/browser-opening/
ready owner; the later callback claim must claim that controller-current phase
and make the late open/retry/App terminal stale, while the later failure must
install its exact pending. The same two orders are repeated after start returns
but before App applies its terminal. A later event remains buffered while the
sole consumer finishes the earlier claim/promotion/abandon handshake; claim
Tasks are never parallel.

The full cross-product includes initial preparation (direct G1 mint, stop=0),
browser-only recovery (stop/start=0), listener and combined recovery (old-stop
before G2 mint), G1 claim accepted, G1 claim superseded with controller
unchanged versus changed, G1 listener failure before/after callback claim, G2
ready before/after claim, recovery terminal before/after claim, claim accepted
then App promotion invalidated for every ready/browser/listener-stage origin,
cancellation or shutdown before claim return versus after `.claimed`, stale/
double abandon and capability handle, preparing restore with and without a
drain waiter, and an unexpected nonempty start. Accepted-but-unpromotable claims call
exact abandon before physical acknowledgement and return listener-restart or
listener-then-browser pending; they never restore ready with a dead listener.
Shutdown after claim uses abandon or the closed owner-shutdown supersession,
never an orphan claim. Unexpected nonempty start is typed `.accept` with
candidate construction and physical start counts zero.
The claim-first/listener-second pre-promotion row additionally requires the
listener sink to return the exact `.deferredToCallback` failure, the independent
recovery consumer to match `oauthCallbackClaimCandidateByFlow` while App still
holds its old active/recovery carrier, and that apply to be display-only. It
must leave candidate, old lifecycle Task, and physical drain unchanged; the
subsequent promotion retains the immutable claim-time App origin and clears the
candidate, while `handleOAuthCallback(claim)` reads the actor claim phase's
merged listener stage for its eventual recovery outcome.
Listener-first before actor claim instead applies the ordinary pending row, and
the later claim adopts that controller-current stage. No failure is recaptured
or silently discarded in either order. A separate abandon-first/App-event-late
row installs the exact abandon pending, clears the candidate, then applies the
same-lease `.deferredToCallback` failure display-only through its physical
failure-attempt join; the pending/Task stay byte-identical and capture count
remains one.
Every row asserts at most one exchange/credential commit, exactly one physical
acknowledgement, zero orphan claim/slot/Task, and no stale terminal clearing a
newer recovery/callback/cleanup owner. A late simulated old sink call either
produces its one already-earned fresh trace/capture or is zero-I/O according to
the exact lease+claim CAS; it is never retroactively treated as unclaimed.

These executable rows assert opaque lease inequality, stop/mint/start order,
sink/trace/reporter/platform-double counters, and controller
reservation+authorization+lease+claim-attempt guards. They do not claim to run
MainActor slot code, allocate `NWListener`/`NWConnection`, or prove App-object
deallocation. The App pathname/source+compile half proves the exact private
slot/candidate declarations, serial stream-consumer shape, claim-before-
promotion control flow, one-shot continuation/cancellation-handler, weak
captures, and guarded MainActor transitions. Together the two halves cover the
boundary without presenting static App evidence as runtime.
The executable construction-order rows use the production Application factory
boundary rather than a test-only AppStore initializer. They prove the platform factory is stored by a
new controller without being called; the first reserved-to-preparing
transition calls it exactly once with an already controller-bound sink before
the first listener start; a second flow reuses that port; and a listener
failure can never observe an empty or later-bound controller cell. The separate
App source/composition+compile fixture proves both owner streams/continuations are created
before the factory, the factory closure captures only the owner, every stored
property is initialized before the two stream-value-plus-weak-self consumers,
neither of which captures the owner, and both consumers
are installed before `AppStore.init()` returns. The source gate proves the
streams use `.unbounded` and that no yield can precede slot publication; the
TestSuite port-double analogue proves an event delivered before its controller
consumer proceeds is handled once after the lease/attempt join, while a
replaced lease is stale with zero controller effect. It does not claim to run
the App-private `AsyncStream`. Factory construction itself has zero listener/
open/stop/event effects. Compile/source-negative rows reject an IUO or
optional controller cell, a mutable bind method, `lazy` recursive composition,
direct App sink construction, a factory capture of `self`/controller, a second
slot dictionary, or a listener start before consumer installation. These App
fixture rows remain static/compile evidence; TestSuite's runtime analogue drives
the injected port double and controller sink without claiming to allocate an
`NWListener` or inspect App-private storage. The App source gate proves every
listener/connection/receive callback captures the owner weakly, both consumer
loops capture only their pre-extracted stream value and weak AppStore. The
recovery loop binds its awaited `MainActor.run` and synchronous apply results to
`Void`. The callback loop promotes weak AppStore to one strong per-event local
only after dequeue, retains it only through the bounded non-I/O
claim/promotion/abandon handshake, and releases it before awaiting the next
stream element. Cancellation or termination after `.claimed` must still run
exact abandon before that iteration exits. Every side-effect call is a typed
binding; a bare `MainActor.run`, optional-call root, strong loop capture, or
accepted-claim early exit fails. The App source fixture
also proves the owner-held block termination handler performs the exact
synchronous shutdown-then-cancel sequence, while ordinary `deinit` captures
only the Sendable owner/Task values into one typed MainActor cleanup Task and
never captures `self`.
The same fixture requires the unchanged pure-Swift
`@MainActor @Observable final class AppStore` header and init signature, exactly
one owner-held `NSObjectProtocol?` observer token, an owner-only block capture,
and removal/nil of that token inside idempotent shutdown. Negative fixtures
reject NSObject conversion, selector/relay/super-init paths, an observer block
capturing AppStore/controller, a second will-terminate observer, an unowned
token, or shutdown that leaves the NotificationCenter/owner cycle live.
That shutdown finishes both streams, removes physical slots before cancellation,
resumes each stored start continuation with `.ownerShuttingDown`, and resumes each
stored drain exactly once with `.ownerShuttingDown`; it cannot be
called by a live-flow stop or replacement. The same gate proves no strong
owner/listener/Task cycle is present. These are structural lifetime proofs, not a claim that
TestSuite releases an AppStore or observes real object deallocation. Dedicated
negative compile/source fixtures reject a listener callback or consumer Task
capturing the owner strongly, and reject hoisting `guard let self` outside a
consumer loop or otherwise retaining AppStore across its next `for await`.
The package compile-positive fixture captures the opaque leases delivered to
the injected platform port, calls only `belongs(to:)` and
`pending.ownsListenerLease(_:)` on those values, and separately awaits the
exact async `startListener` and `stopListenerIfOwned` closure signatures with
typed receipts and exhaustively switches start
`.started/.ownerShuttingDown` and stop `.stopped/.ownerShuttingDown`;
compile-negative fixtures prove App/TestSuite
cannot construct a lease or read its reservation/lease IDs or a pending's
fileprivate lease. The same fixture constructs
`RuntimeOAuthAuthorizationOpenCommand` only through
`.prepared(_:reservation:)`, calls `openOAuthAuthorization(_:)`, and constructs
active/recovery callback commands through their two exact factories, passing
the exact opaque lease delivered by the simulated physical callback event.
It calls `claimOAuthCallback(_:trace:)`, switches
`.claimed/.currentAuthorizationRejected/.superseded`, uses only the claim's
package flow/origin and three
pure comparison methods, then calls exactly one of
`handleOAuthCallback(_:)` or `abandonOAuthCallbackClaim(_:)` with that opaque
claim and exhaustively switches abandon
`.ready/.authorizationRecovery/.superseded(sealedOwner)`. A parallel positive
fixture constructs `RuntimeOAuthCustomSchemeCallbackCommand` with only
`callbackURL`, calls only `claimOAuthCustomSchemeCallback`, switches the same
custom two-case `.claimed/.superseded` outcome and exhaustive `claim.ingress`, proves
`ownsListenerLease` is false for custom ingress, and reaches only the same
handle/abandon capability APIs. Custom cleanup records listener mint/start/
stop/ack zero. The old command-based
handle overload and ownerless abandon supersession are absent.
Compile-negative rows reject direct access to either command's fileprivate
authorization/owner/reservation/listenerLease, reject either callback factory
without `listenerLease:` specifically for the physical
`RuntimeOAuthCallbackCommand`, reject an optional/default/fabricated lease in
the custom path, a lease-bearing custom command, cross-passing either command
to the wrong claim API, claim construction/private ingress IDs, either command
or a raw URL passed directly to `handleOAuthCallback`, local-listener abandon
to ready, and an invented recovery-form browser-open command.
The App pathname/source+compile connection-delivery fixture proves the two
lease joins, the exact live-to-callback-claim transition before yield, the
closed dual-claim transitions, and absence of a second yield path. It also
proves by control-flow/anchor gates that a non-live G1 cancels/responds before
logical callback work. Only an exact plain `.callbackClaimed` preparing-local
reject, or an exact plain promoted `.callbackProcessing` pre-commit terminal,
may reopen live; either requires no failure claim and no retire/drain waiter. A failure-bearing
claim must drain, and ready/failure/caller-cancel share one continuation owner.
It does not claim to suspend or burst real `NWConnection` instances. The
executable TestSuite platform double feeds an equivalent deterministic
100-event and dual-claim transcript into the real Application controller/sink:
one logical callback reaches the controller, 99 are rejected by the modeled
one-shot lease claim, one post-claim failure produces one fresh listener trace,
and recovery-before-consumption, recovery-during-callback-processing,
callback-terminal-first, plus cleanup-stop-before-sink-entry all retain the
failure and converge without restart after credential commit. Its physical-ack
table first freezes the App consumer's closed partition. Matching
active/recovery reservation+authorization+lease creates one candidate while
leaving lifecycle, lifecycle Task, and physical phase unchanged; it performs
one non-I/O actor claim and installs exactly one logical capability Task only
after claimed promotion. Matching preparing plus
`lease.belongs(to: reservation)` performs a true-restoring local finish with
zero actor claim. Reserving, callback-processing, empty,
owner/flow/authorization mismatch, and stale attempt perform a non-restoring
local finish and have zero logical Task/controller/Reporter/codec/exchange/
credential calls. A lease/attempt mismatch at
`beginCallbackClaimIfCurrent` performs no finish or App mutation. Claim
superseded preserves the prior App carrier; claimed but unpromotable performs
abandon before physical finish. The table counts claim, promotion, abandon,
physical acknowledgement, and logical completion using the exact same seven-
tuple vectors frozen above; it may not collapse them into a five-counter or
single-completion assertion. Each suspended barrier also asserts the matching
stop-waiter and G2-start rule. It then has three
mandatory cleanup rows. First, plain `.callbackProcessing`
calls committed cleanup stop: stop returns `.stopped`, slot count becomes zero,
and physical cancel count becomes one before the callback method may return its
sealed terminal; that later finish is a physical no-op and credential
commit/reload remain one total. Second,
`.callbackProcessingAndFailureClaimed` calls committed cleanup stop before the
sink enters: stop remains pending with controller cleanup ownership intact, the
sink creates exactly one fresh listener trace/capture, the recovery consumer
attempts the guarded display-only App transition and acknowledges it, and stop
resumes once before the callback sealed terminal; no restart capability or
second cancel/capture is produced. Third, recovery-first while the callback
event is still queued retains stop through controller claim and App promotion;
once App installs the logical capability Task, the physical callback claim is acknowledged
and, when failure App acknowledgement is already complete, stop resumes before
that Task's sealed terminal. The inverse callback-terminal-first pre-commit row
retains only the failure claim and removes it only after recovery/App
acknowledgement. Every row records the same seven callback counters plus the
independent failure-App acknowledgement counter and
forbids double resume. A retry/G2 is not held merely by
`.callbackProcessing` as a physical claim: the real controller lifecycle owner
rejects a newly requested start with a zero platform-start counter, and every
already pending/stale start rechecks its controller attempt/lease before it can
publish App success over the callback owner. A queued callback still blocks
stop/replacement through claim plus promotion/abandon, not through later codec
or the callback sealed terminal. The same double races start
ready/waiting/failed/unexpected-cancelled/caller cancellation in both orders.
It asserts one completion, exact `.started/.accept/.cancelled` mapping,
physical cancel=1 for every failed candidate, slot=0 after failure/stop, no
extra sink call, and no orphan listener; a stale controller
lease cannot publish ready. Ordinary live
failure rows cover event-first, stop-before-event, and replacement-before-event:
the exact recovery consumer removes the dead slot and resumes at most one
waiter, so a later G2 never waits for an already consumed event. The closed
error table additionally injects invalid port→`.invalidPort`, constructor
throw→`.bind`, waiting/failed→`.accept`, unexpected cancelled→`.cancelled`,
and malformed request→fixed 400 plus `.malformedCallback`; it asserts zero raw
error formatting, no callback yield for malformed input, and no alternative
case construction. It also returns `.ownerShuttingDown` from the listener stop
that follows a failed atomic preparation write: the controller compare-clears
only the exact failed preparing owner and returns `.superseded`, with zero
second capture or repair owner because the envelope preimage never changed.
The corresponding committed callback-cleanup stop likewise compare-clears only
its exact lifecycle owner and returns `.superseded` with zero reload, Reporter,
restart, browser, codec, credential, or UI work; ordinary `.stopped` rows retain
their existing terminals. Separate initial-listener and recovery-retry rows
return `.ownerShuttingDown` from the start port before ready and require the
same exact-owner `.superseded` terminal with zero failure capture or downstream
state/browser/credential work; `.started` retains the normal path. Those runtime
counters are explicitly port-double/controller evidence,
not proof that a real `NWListener` or App-private dictionary executed.

The preparation/browser/listener interphase subtable freezes the two-step
handoff rather than treating browser opening as a preparation side effect.
First it suspends the credential-coordinator await. A matching listener failure
returns `deferredToPreparation` with the exact already captured failure and
leaves preparation running; rollback stops only the exact lease and clears its
obligation. Committed preparation with no obligation returns `.prepared` while
the platform-open counter is still zero. The App pathname fixture proves one
MainActor segment changes the exact `.preparing` owner to `.active` with a fresh
open attempt, compare-clears the preparation Task, constructs only
`RuntimeOAuthAuthorizationOpenCommand.prepared`, and installs the browser-open
Task before yielding. Committed preparation with a listener obligation instead
returns the same failure plus `.listenerThenBrowser`, installs recovery, and
keeps the platform-open counter zero.

The same subtable then controls every boundary on both sides of that MainActor
segment. If the controller has returned `.prepared` but App has not applied it,
a listener failure changes controller post-preparation to
`.listenerThenBrowser`; listener-apply-first installs that pending from the
matching preparation origin, while prep-apply-first installs active/open Task
and then lets the listener transition replace only that exact Task. A raw
callback event delivered while App is still `.preparing` is a local zero-I/O
reject and compare-reopens only its exact physical callback claim after proving
the event lease belongs to that preparation reservation. A `.reserving` or
otherwise mismatched state non-restoring-finishes the consumed claim. No
platform browser call has occurred. The same callback-state subtable calls the
real `SecretValue.constantTimeEquals` helper for equal values, same-length
first/middle/last-byte mismatches, and an unequal-length value; both physical
and custom pre-CAS matchers plus the post-payload controller check must select
that helper and never raw equality. It also proves `SecretValue.validated`
returns nil for empty and whitespace-only protocol values, returns a value for
one valid state without throwing, and that explicit `SecretValue.==` produces
the same results as `constantTimeEquals` for every equality/mismatch row. A
nonblank state formed by adding leading/trailing whitespace around the exact
expected state remains byte-distinct and must mismatch; the fixture opens the
factory result only inside `use` and proves its stored bytes equal the original
untrimmed input. No
matcher contains `catch`, `try?`, `try!`, or a trap. It asserts functional terminals/counters,
not wall-clock timing. After App is active, the table separately suspends
(a) the browser-open Task before its actor call, (b) the MainActor platform
open, and (c) the returned open terminal before App apply. A callback in (a)
claims controller post-preparation, in (b) invalidates browser-opening, and in
(c) claims the controller-current ready/recovery owner; all three cancel/
compare-clear only the exact App open Task, perform at most one callback
exchange/commit, and make every late open terminal stale. Pre-commit callback
failure in (a) or (b) returns browser-reopen (merged with any listener stage),
never an active owner with no confirmed open or recovery capability. Browser
success/failure versus listener failure is exercised in both actor orders:
listener-first yields listener-then-browser and cannot be overwritten;
browser-failure-first merges browser-reopen to listener-then-browser;
browser-success-first followed by failure yields listener-restart. Each failure
has its one exact trace/capture, with zero recapture.

Finally, with an explicit listener/browser/combined recovery retry suspended,
a matching listener terminal cancels/compare-clears that exact recovery Task,
installs a fresh App attempt, and enables the retry control only after proving
that flow has no callback claim candidate; if
that retry requests a listener start while an older queued callback or failure
claim is unacknowledged, the controller/port Task remains pending with its stable
owner and the UI cannot publish recovery success or another retry until the
claim-drain acknowledgement permits G2. The late old retry cannot clear the
newer Task. Every row asserts no browser call before App
active, no dead-listener ready state, no stranded open Task, no duplicate state/
verifier/listener/browser work, and no actor-job or MainActor-apply FIFO
assumption.
The callback-concurrency subtable suspends exchange, then delivers a listener
failure and a duplicate callback in every actor-terminal/MainActor-apply order.
It freezes three ownership orders: (a) the listener actor installs pending P
before callback claim, so the non-I/O claim adopts controller-current P and the
later App promotion installs the capability Task. If listener App apply runs
before that promotion, it installs P and atomically retargets the exact
candidate to P's fresh lifecycle attempt/origin; promotion still succeeds. If
promotion runs first, the late listener apply is display-only under the
promoted callback row. (b) Listener App apply installs P before candidate capture, so
the command is formed from that recovery origin and claim precedes promotion;
and (c) callback claim wins first, the listener merges into
`.callbackClaimAwaitingApp` and returns deferred-to-callback, then promotion
installs the capability Task whose controller phase retains the merged stage.
A separate mandatory four-row retarget barrier table runs both
preparation-origin row two and active/recovery row three with the pending App
apply (i) while the actor claim result is suspended and (ii) after the
controller has sealed `.claimed` but before the callback consumer's MainActor
continuation resumes. At (i), the seven-tuple remains
`(1, 1, 0, 0, 0, 0, 0)`; at (ii), it remains
`(1, 1, 1, 0, 0, 0, 0)`. Every row proves that only candidate
`lifecycleAttempt` and `origin` change, while reservation, command, trace,
listener lease, and physical callback attempt remain exact; the old lifecycle
Task cancel/compare-clear count is one, the stop waiter remains pending, and G2
mint/start counts remain zero. Promotion must reread that map-current candidate,
succeed rather than abandon, and advance the tuple to
`(1, 1, 1, 1, 0, 1, 0)` before callback business completion.

Each of those four retarget-barrier rows also asserts the authorization retry
control is disabled after retarget and invokes the action handler directly once
to model a queued stale click. The handler leaves lifecycle state/attempt/Task
and the entire map-current candidate byte-equal, mints zero retry trace, calls
`retryOAuthAuthorization`/port/browser zero times, leaves the seven-tuple
unchanged, and still promotes to `(1, 1, 1, 1, 0, 1, 0)` with
`claimAbandoned == 0`. A reciprocal retry-first row completes the retry
action's MainActor attempt/Task installation before candidate capture; that
candidate captures the new attempt, and the existing in-flight-retry takeover
rows prove exact cancellation/promotion. After reject or abandon removes and
physically acknowledges the candidate, an exact remaining recovery owner
re-enables one retry and one tap mints exactly one attempt, Task, and trace. A
direct controller retry after `.callbackClaimAwaitingApp` is installed returns
`.superseded`, preserves that controller phase byte-for-byte, and performs zero
listener/browser/Reporter/trace work.

In all three ownership orders, the pre-claim App carrier stays byte-identical
until `.claimed`, except for rows two and three's exact pre-sealed pending
transition, which installs the pending, retargets the candidate guard, and
never acknowledges the callback. The listener terminal never cancels or
compare-clears the promoted callback Task. The capability Task enters
`handleOAuthCallback` unless its exact claim
owner was sealed/abandoned, and its terminal alone restores P on pre-commit
failure or advances to cleanup after commit. Duplicate callback is zero-I/O
superseded, exchange/credential commit occur at most once, and no actor/
MainActor ordering leaves controller callback-processing while App is recovery.
A committed callback ignores restart as an authorization obligation and
proceeds only through cleanup. The mandatory commit-first drain row pauses
the newly installed physical failure Task before `sink.handle`, lets callback
credential commit and cleanup call async stop, and proves stop recognizes that
the failure claim already cancelled the listener, issues no second cancel,
neither cancels the Task nor removes controller cleanup ownership, and waits
only for the failure App acknowledgement rather than its own callback terminal.
Releasing the Task produces exactly one fresh listener trace/Reporter capture
and `.deferredToCallback`; the App recovery consumer applies that result and
then acknowledges the physical tombstone in the same MainActor segment. Stop
resumes once, cleanup completes, and no authorization-restart
capability is created. The inverse sink-first order has the same one-capture
terminal. Late duplicate failure/stop/callback terminals perform zero work.
Active callbacks use only
`RuntimeOAuthCallbackCommand.authorization(_:reservation:listenerLease:callbackURL:)`, and
recovery-pending callbacks use only
`RuntimeOAuthCallbackCommand.recovery(_:reservation:listenerLease:callbackURL:)`; preparing/
reserving callbacks are local zero-I/O rejects, and invalid trace/owner or
duplicate callbacks return `.superseded`, not `.notCommitted`. Only an exact
`.preparing` state whose event lease belongs to its App-held reservation may
finish the consumed physical callback with `restoresAuthorization:true`; a
`.reserving` state has no reservation proof and finishes it with
`restoresAuthorization:false`. Callback-processing, empty,
owner/flow/authorization-mismatched, and stale-attempt App states take that
same non-restoring local branch. None of those branches enters the controller
or installs a second logical callback Task.
Callback/listener late terminals must fail attempt+reservation+authorization+
phase equality and cannot clear a newer recovery or cleanup. The App table
asserts candidate creation leaves lifecycle state/Task and physical phase
unchanged across the non-I/O claim await. Only a `.claimed` promotion installs
`.callbackProcessing` and its capability Task synchronously before that Task's
first actor/business call. A listener terminal cannot cancel/clear that
carrier, and only the callback's promoted attempt and sealed terminal may
restore its opaque controller-current origin.
The same callback-concurrency subtable covers callback takeover during an
authorization recovery retry, not only a queued listener failure. It suspends
`.listenerRestart` before completion, suspends `.listenerThenBrowser` before
listener completion, and then suspends it after listener success while browser
reopen awaits. In every lane the non-I/O controller claim first claims the
current same-reservation/same-authorization recovery owner, invalidates the
retry attempt, and adopts its exact current remaining stage while App retains
the old Task. Only the subsequent claimed promotion atomically cancels/compare-
clears that exact recovery Task/attempt and installs callback processing. A callback
failure restores listener restart while it was still outstanding, restores
only browser reopen after listener success, and restores ready after no
obligation remains. Both retry-first/callback-first late-terminal orders prove
one exchange/credential commit maximum, no duplicate listener/browser work,
no resurrected completed stage, no stranded callback phase, and no stale retry
clearing a new recovery or cleanup carrier.
The table separates callback-claim-first from controller-recovery-terminal-
first for all three remaining-stage shapes. If the old retry has already made
the controller stable `.authorizationRecovery` or `.ready` while its App
terminal is stale, callback adopts that controller-current stable stage/none;
it never requires the command's older pending byte equality. A true
`.superseded` result must restore/adopt a matching stable App owner under the
captured attempt guard and may not leave `.callbackProcessing` after merely
clearing its Task.
The cleanup table includes initial CAS failure -> retry CAS/listener success ->
verification reload failure: exchange and credential commit remain one total,
state/listener cleanup occurs once, the pending is removed through
`.cleanedWithVisibilityFailure`, B may begin, and only a refresh action remains.
Credential attachment, authorization recovery/listener failure, and callback-
cleanup rows additionally assert a fresh trace ID for each controller-current
accepted explicit recovery or asynchronous listener-failure invocation, the
exact retained public scope and expected operation, and an unchanged original
receipt provenance trace. A stale/superseded retry returns before trace
creation or recovery I/O. Two different injected
retry failures therefore persist as distinct rows and never exercise the
same-trace identity-conflict fallback. Retry APIs accept no caller trace; the
controller trace-factory counter increments exactly once before recovery I/O.
`O1` remains supplemental evidence only for the
coordinator's compensated credential/state transaction; it is not the primary
owner of these Application lifecycle cases.
Test 13 also owns the complete post-commit repair matrix: proposal link/event
faults create one Mission and reconcile the retained link/event identity only;
rate-event failure changes cooldown once and its retry performs zero provider,
reconcile, RNG, clock, or cooldown mutation. Its two-pending rows prove each
call processes only the oldest receipt: first success returns `hasMore=true`
and retains the second; first failure retains it byte-identically; the explicit
next call processes the next receipt; a late completion cannot remove a newer
one; `.noPending` is zero I/O. No row performs a batch or automatic continue.
The schedule repair subtable covers every committed identity—template save,
template delete, schedule save, schedule enablement change, and schedule
delete—with enabled/disabled save plus enable/disable variants. It injects a
database fault, authorization throw, each of the four nonthrowing authorization
dispositions, registration throw, authorization-retry throw,
authorization-success followed by registration throw, registration-only retry,
success, concurrent duplicate retry, stale receipt, and late generation. Every
retry row asserts save/update/delete/enable counters are zero, deletion uses
the exact captured preimage, a single flight captures at most once, and a
replacement failure preserves the old scheduler set byte-for-byte. The stage
transition is exhaustive: authorization throw retains
`.authorizationThenRegistration`; successful authorization plus registration
throw retains the same repair ID as `.registration`; `.registration` retry has
zero authorization calls. Each actual registration attempt consumes exactly one
fresh fixed `ScheduleRegistrationEvaluation`; DB/auth failure consumes zero.
The exact authorization and registration receipts survive in platform evidence,
and the four nonthrowing authorization dispositions render distinctly rather
than claiming notification delivery. Each identity asserts its frozen retry
operation/scope mapping and one fresh trace only after controller-current
acceptance; stale/superseded receipts mint zero traces.

The mandatory ownership matrix starts with repair R1 and then performs: a
same-key DB failure, which leaves R1 current; a same-key committed success,
after which a direct R1 retry is zero trace/authorization/registration/Reporter;
a same-key committed platform failure producing R2, after which only R2 is
current; a different-key commit, which leaves R1 current; and a template delete,
which supersedes the template plus every cascade-child Schedule repair from its
exact preimage. A barrier row suspends R1 authorization, commits a same-key
mutation, then releases R1 once with success and once with a throw:
authorization may have run once but registration/evaluation/Reporter are zero,
the stale throw is not captured, R1 cannot mutate R2, and both terminals are
`.superseded`. Old-stage receipt,
completed receipt, partial-key ownership, and unknown receipt are zero work.
A successful global registration replacement reports and removes every other
registration-stage opaque receipt exactly once while leaving authorization-
pending receipts current; duplicate R2 callers join one Task and capture once.
The same rows call `refreshSchedules`: success returns the identical sorted
opaque registration-stage removal list and App same-owner-clears those cross-key
carriers; a replacement throw preserves the old scheduler set plus every owner
and App carrier and returns no supersession list. Its fixed evaluation closure
is called once per real attempt and the legacy caller-supplied now/time-zone
surface is absent.
The initial-effect matrix separately suspends committed M1 authorization, then
runs a same-key M2 DB failure, a same-key M2 committed success, a same-key M2
visibility failure producing R2, a different-key commit, and an overlapping
template-delete/child-Schedule commit. Releasing M1 with authorization success
and separately with a throw proves a superseded M1 returns only
`.committedSuperseded`, performs zero registration/evaluation/Reporter/repair/
map cleanup, cannot touch M2/R2, and cannot return the predecessor receipt list
already transferred to M2. Every barrier asserts each reverse-map ID resolves
one owner state; the current successor drains the unique sorted list once.
One non-fault initial-success row freezes the retirement boundary: immediately
after registration returns and before App consume it observes zero
`.performing` effect owners/reverse mappings for that command, exactly one
application state, one published carrier, and a byte-equal
state→carrier→receipt bijection. After consume both application entries and
reverse keys are zero; neither retains or points to an effect owner.

App rows compare key + generation + explicit flight-attempt UUID + purpose +
old receipt for flight entry/tail, never `Task` values, and separately consume
the opaque application receipt as the sole committed-projection authority. They
prove a late initial/retry terminal cannot remove a newer flight, a not-
committed new mutation preserves an older repair, and a template-delete
completion invalidates only matching repair flights on the template/returned
child-schedule keys while leaving a newer mutation flight and its generation
byte-identical. Cross-key
`supersededRepairs` clear only carriers whose pure opaque
same-repair-owner proof matches; App never reads a stage or repair ID. A
dedicated barrier transitions Rauth to Rreg in the
controller and suspends the repair Task terminal before App apply, then lets a
cross-key global replacement apply first. The returned Rreg witness must
`isSameRepairOwner(as:Rauth)`; App removes a matching older repair flight and
Rauth carrier without advancing generation, while the current command's own
repair flight remains until its ordinary tail. The late
`.stillPending(Rreg)` consumes `.globallyVisible`, applies
the DB-current identity/authorization evidence and all owned clearances, but
cannot reinstall Rreg or its registration failure. A different repair ID
remains untouched.
The row runs through `refreshSchedules` (no protected key) and an initial
mutation terminal (protected primary key), asserting zero application-time
generation arithmetic and no duplicate witness. Every closed outcome, including not-committed and
superseded, runs the one matching-flight compare-clear tail; a deliberately late
old terminal cannot clear a new flight. Controller repair rows make the same
assertion for repair ID + private flight attempt and cover cancellation after
owner supersession. Positive package-surface fixtures compile only the four
receipt wrappers, `consumeSchedulePostCommitApplication`, and the decision's
three-arm fold. Pathname/source structural gates keep repair/application/
program/decision initializers and IDs plus owned keys, stage, evidence,
failure, and scope fileprivate; reject the former raw associated-value outcome
forms, any sealed program/decision construction outside the controller file,
an apply-capable terminal without exactly one application receipt, outcome
payload reads in App, and raw-ID/stage overloads. No intentionally
noncompiling source is placed in TestSuite and this Revision adds no separate
negative-compiler job. The same gates require the retry
callable to contain zero mutation-port references; require the registration
branch to contain zero authorization references and the authorization branch to
dominate registration; require one exhaustive stage switch without a default;
and reject any `Task` equality comparison.

The terminal-application matrix covers every receipt-bearing terminal kind and
freezes these non-FIFO barriers:

- initial schedule-child save S1 returns successful `.committed` and pauses
  before App consume; an overlapping template delete T2 commits/applies first.
  S1 then consumes `.mutationSuperseded` and applies zero old child identity.
  In the reverse order S1 applies current first and T2 subsequently removes it;
  both end with App projection byte-equal to the DB-deleted child;
- S1 returns, then a same-key S2 advances the App flight but fails its DB write.
  Because no newer DB commit tombstoned S1, S1 consumes its sealed
  `.committed` decision and applies its DB postimage despite a stale local
  generation, without removing S2's
  mutation flight. If S2 instead commits, S1 consumes
  `.mutationSuperseded` and cannot overwrite S2;
- a `.repaired` terminal pauses before App consume and runs the same DB-failure
  and overlapping-delete orders. Current repair success clears its starting
  carrier and applies the sealed projection even with a stale local generation;
  successor commit makes the old terminal zero apply;
- Rauth already published, then two genuine same-stage retry failures and one
  Rauth→Rreg transition each receive distinct application receipts. Each
  current token applies once; duplicate delivery of the same token returns
  `.alreadyConsumed`. No repair-owner-wide published flag suppresses a new
  failure/trace or leaves App holding an old-stage receipt;
- M2 produces visibility-failure R2 and pauses before consume. A cross-key
  global replacement marks its registration-stage token globally visible but
  does not return R2/its inherited R1 separately. Global-first makes the late
  M2 token apply the DB identity plus authorization evidence/clearances with
  zero obsolete registration failure or R2 carrier; M2-first installs R2 and
  the later global witness clears it. An authorization-stage token is not
  marked visible. A subsequent intersecting DB commit upgrades either current
  or globally-visible M2 to mutation-superseded;
- an initial mutation and a repair retry each suspend inside registration after
  their unpublished carrier exists. A cross-key global replacement wins first,
  removes effect reverse ownership, retains exactly one
  globally-visible-awaiting-terminal owner/carrier, and keeps the carrier's
  union reverse keys. Releasing the old registration once with success and once
  with a throw seals the same globally-visible program, captures/installs no
  stale failure/repair, and consumes once. If a partial-overlap DB commit claims
  that unpublished carrier before release, the old terminal is receipt-free
  superseded and only the successor's composed plan applies. Before releasing
  the old port, the old effect-owner entry, every old effect reverse key, and
  its exact repair flight are absent; after release its counters prove zero
  program reconstruction, Reporter capture, repair write, or owner mutation;
- when an old token is mutation-superseded before delivery, its complete
  undelivered clearance set—including the repair returned by that terminal and
  a repair retry's starting receipt—is transferred exactly once to the
  successor. The old terminal delivers none; the successor's current token
  alone drains the unique sorted list;
- template-delete D1 commits keys `template:T/schedule:A/schedule:B` and pauses
  before App consume; a later template-save S2 for only `template:T` commits.
  D1 consumes mutation-superseded, while S2's controller-sealed program begins
  with exactly `[.project(D1.templateDeleted),
  .project(S2.templateSaved)]` before its clearance/evidence terminal suffix:
  applying it removes A/B
  and leaves T saved, byte-equal to DB. The reciprocal subset/superset and two
  independently disjoint predecessor groups prove deterministic group order,
  preserved order inside each inherited plan, and zero operation deduplication;
- the positive package fixture can read only each terminal wrapper's receipt,
  call consume, and exhaust the three-arm decision fold. The pathname/source
  gate proves that outcome cases contain no raw identity/evidence/failure/
  repair values, that canonical-program and decision initializers/storage are
  fileprivate in the controller file, and that no raw apply overload exists.
  Runtime duplicate delivery can only replay the same receipt and receives
  already-consumed, never another program;
- every decision-application row seeds touched App generation counters at
  `UInt64.max`; consume and apply still complete because the segment performs
  zero generation arithmetic. A current repair terminal's own starting witness
  clears its carrier but cannot remove/cancel its own flight before the sole
  terminal tail; an older same-owner repair flight is compare-removed without
  generation change, while mutation/different-owner flights remain byte-equal.

Every row asserts the receipt-state/carrier bijection and carrier-key reverse-map cardinality, exact
owned-key closure, decision/tombstone consume count one, no optional/forged
receipt or raw-outcome payload, DB authoritative reread equal to App after all terminals, and zero
identity/evidence/list/failure/carrier mutation for mutation-superseded or
already-consumed outcomes. A cancellation/weak-owner barrier fires after the
controller returned but before consume; the App Task retains its bounded strong
owner, ignores cancellation through the no-await consume/apply segment, and
then releases it. No receipt-bearing terminal may early-return on a stale flight
guard.

The production-registration adapter fixture invokes two live-adapter closures
in MainActor order A then B and proves each closure reaches its synchronous
build-and-swap helper and returns without a suspension hook, Task, continuation,
or interleaving callback; the observed swap order is exactly A then B and the
final registered IDs are B's fully built set. The separately suspending port
doubles used by the controller race table own no scheduler collection and only
release a precomputed receipt/counter. Source gates reject an `await`, async
helper, continuation, Task/yield, callback, or actor hop anywhere in the
production `MissionScheduler` `replaceAll` closure/helper call graph.

The flight-purpose matrix pauses an App Task after its flight is installed but
before its task-body entry CAS. When a global witness or template-delete child
clearance arrives, a `.mutation` flight retains the exact generation, attempt,
Task, and purpose, subsequently enters the controller once, and its guarded
terminal remains applicable. A same-owner `.repair` flight is removed and may
be canceled; when released, its entry CAS performs zero trace/controller/
database/platform/Reporter work. A different-owner repair flight is likewise
untouched. The same rows run clearance after task-body entry and rely on the
controller's post-await owner guards rather than cancellation. They assert a
database mutation that commits can never become invisible merely because an
older repair witness applied first.
Closeout report/distillation
faults leave Mission accepted, create at most one fallback note, and each retry
invokes only its exact retained effect. The distillation table includes the
only-failure double-fault lane: provider/parse fails, fallback persistence
fails, outcome carries one composite plus one `.fallbackMissing` receipt;
the provider and invalid-payload variants retain and later reproduce
`memory_provider_failed` and `projection_decode_failed` respectively without
crossing codes;
another failed fallback retry retains that exact receipt, while a successful
fallback retry inserts the original fixed note/event once and either completes
the real note or returns the derived `.realRetryReady` receipt. Stale/late
phase receipts cannot remove a newer pending value or repeat acceptance/report/
cowork work. Cowork rows prove an unassigned done
Card remains only in the Camp note, explicit skip creates no repair, and a
missing Companion/provider/parse/write failure retains one per-companion
capability whose ID-only retry repeats no acceptance, Camp note, report,
Mission distillation, or other companion; report presentation writes/ensures
the file once and then retries only the platform port. Duplicate, concurrent,
stale-receipt, already-completed, and mismatched-existing-identity rows prove
idempotency plus conditional removal. Multiple closeout effect failures use
distinct trace IDs and one nonempty `MissionAcceptanceRepairSet`; their ordered
failure/receipt cardinality must match exactly.
The primary case tables also execute all 134 `E[...]` catch tags, all 130
equivalent-default `N[...]` tags, and all fourteen planned-new-catch `N[...]` tags.
They verify the global N union is exactly 144 with no duplicate between the two
N ledgers. Each case asserts its production invocation
counter, exact FailureOperation, same invocation trace, and absence of empty/default/
success-like projection. Approved residual cases assert both that their exact
domain/cancellation path creates no failure row and that a neighboring
non-approved error is propagated/captured rather than swallowed.
The same declarations parse the inventory's frozen entry annex, which Revision
03 validates once against the 35 dirty-tree entry hashes and eight `ABSENT`
planned paths before freeze. Those entry bytes are not committed and are not
falsely reconstructed after implementation. The declarations require the
annex's exact 954-entry vector and disjoint 431 descriptor/cross + 523
closed-nonfallback partition, then execute the same reviewed scanner in final
mode against terminal source under the resolution rules. Negative micro-probes
retain every expected N/E/literal tag while
injecting one unmarked occurrence of each syntax class, including a no-space
ternary, a new Optional/Result projection, a known non-Void bare/`_ =` call,
raw-string interpolation, numeric clamp/overflow, and changed harmless anchor;
every probe must fail for the injected occurrence rather than because an
unrelated count changed. These are table rows inside the existing declarations,
not additional `@Test` declarations.

### 13.3 `OpenAIOAuthSessionTests.swift` — 3 new declarations

1. `oauthCredentialCommitFailureRollsBackEarlierWrites`
2. `oauthCredentialRollbackFailureIsExplicitAndCritical`
3. `oauthPermanentUnauthorizedDeleteFailureNeverReportsCleanRelogin`

Their internal case tables cover both initial-callback and refresh credential transaction helpers,
fixed write order, reverse restoration, one final errorCode per trace, and no
credential/account/body leakage. They also cover the package production
Session initializer's reporter/trace-factory ownership: concurrent refresh
waiters share one in-flight Task and exactly one `.oauthRefreshCommit` trace;
permanent unauthorized cleanup mints a distinct
`.oauthUnauthorizedDelete` trace before its first credential operation;
capture/rethrow occurs once per owner; and the public compatibility initializer
has zero App production callsites. Its internal table nevertheless proves the
unchanged signature uses exactly `OAuthCredentialAccounts.live.verifier` as
the backend-global envelope account for non-ASCII, delimiter-like, long, and
partially overlapping nonempty credential-coordinate tuples, and performs all
reads/mutations through its private coordinator. The table crashes tuple A
after each credential-field mutation, restarts through an overlapping tuple B,
and proves B rejects at the shared envelope before returning any overlapping
field. A credential-field-disjoint tuple C runs the same barrier and likewise
rejects at the shared global envelope with credential-field read count zero;
because C shares that fifth coordinate it is explicitly not called
five-coordinate-disjoint. Conservative crash quarantine is explicit rather
than misreported as per-tuple independence.
Empty, duplicate, or global-envelope-colliding supplied coordinates
throw the fixed unavailable error with zero store/HTTP/callback work. No row
expects a per-tuple derived coordinate, and App has zero compatibility-factory
callsites.
Two public Session instances over one recording store run refresh/refresh and
refresh/unauthorized-delete barriers: their access objects share one process
lock/revision, the winning complete bundle remains byte-exact, and the stale
HTTP continuation returns `.preimageChanged` before any write or permanent-
failure callback. No refresh failure is attached to the
earlier synchronous provider-resolution trace.
The recording store owns one stored `.isolated(UUID)` backend namespace. Two
independently constructed access/coordinator/Session stacks over that same store
must read the same namespace and retain the overlapping stale behavior above.
A reciprocal barrier creates two distinct recording-store instances with the
same five account spellings but different stored isolated namespaces; both HTTP
proofs remain current and both commits mutate only their own backend with zero
cross-store `.preimageChanged`. The ordinary top-level compatibility tests keep
their per-test store instances/namespaces and remain parallel—serialization,
global reset, or account renaming is forbidden. A Keychain fixture separately
proves equal service strings yield equal `.keychainService` namespaces and a
different service is revision-independent without performing a Security write.
A positive external-module fixture conforms a minimal legacy recording store to
`CredentialStore` without declaring `backendNamespace`, constructs the existing
public Session initializer unchanged, and proves the default is
`.legacyShared`. A two-store legacy barrier deliberately advances one shared
revision domain and makes the other proof stale before its store write; this is
the documented conservative compatibility behavior, not explicit-backend
independence. The default witness is never a fresh UUID per access/session.
One cross-coordinator row obtains a byte-equal refresh proof from coordinator
A and submits it to coordinator B over the same access/store/accounts. B
returns `.preimageChanged` before lock/revision/store/Reporter/permanent-
failure work; only A may consume that proof. The production refresh/delete APIs
have no caller-supplied `accounts` parameter and use the proof-bound accounts.
The same row reads an authorization-preparation proof through coordinator A
and submits it to coordinator B over the same access/store/accounts. B returns
`.preimageChanged` before lock/revision/store/Reporter/callback work;
`commitInitial` has no caller-supplied accounts parameter and only A may consume
the proof using its privately bound exact accounts. Two same-coordinator
cross-flow rows then keep that proof fixed but submit an initial bundle whose
`flow` differs from `preparation.flow`, and keep a valid ChatGPT refresh proof
fixed but submit a refresh bundle whose `flow` is `.generic`. The initial row
returns `.preimageChanged(flow: preparation.flow)` and the refresh row returns
`.preimageChanged(flow: .chatGPT)` before the credential lock; each has zero
revision/store/Reporter/callback or permanent-failure work. The proof flow,
proof accounts, and payload flow therefore form one closed pre-lock guard rather
than three caller-composable inputs.
The same three declarations run the envelope phase matrix: only absent permits
one locked refresh proof; prepared, recovery-prepared, any committing phase, or
malformed/noncanonical bytes throw `OAuthCredentialBundleUnavailableError`
before HTTP or permanent-failure callback. A present refresh reads the exact
access/refresh/ID/account snapshot and revision; a missing refresh stops at the
access/refresh prefix and returns nil with no proof. Barrier rows suspend the
HTTP response, then run authorization preparation, initial callback commit, a
second refresh commit, and permanent-unauthorized delete in both orders. An
intervening OAuth mutation attempt invalidates the old revision even when that
attempt fails; an external/injected snapshot change is caught by the byte-equal
preimage guard. Every stale old response throws `.preimageChanged` with zero
sentinel/credential writes, Reporter capture on the newer owner, or
permanent-failure callback, while the accepted owner alone mutates once.
One distinct revision row constructs two package test bundles whose complete
five-coordinate sets—including different envelope accounts—are disjoint. A
mutation through the first in the same backend namespace leaves the second
bundle's proof current and consumable. A separate public-compatibility row uses disjoint four-field tuples
that necessarily share `.live.verifier`; a mutation through either deliberately
invalidates the other's proof at that fifth coordinate. The test never calls
the latter five-coordinate-disjoint and never expects independent revisions
from the compatibility factory.
Refresh commit and unauthorized delete write their exact committing sentinel
before their first credential mutation, delete it last only after full success,
and crash/rollback barriers never expose a mixed credential. Any field rollback
failure proves the sentinel delete count remains zero.

### 13.4 `MemoryDistillTests.swift` — 7 new declarations

1. `memoryDistillNoEligibleInputIsDistinct`
2. `memoryDistillProviderSkipAdvancesWatermarkAndReturnsSkipped`
3. `memoryDistillCreatedReturnsRecord`
4. `memoryDistillProviderFailureReturnsFailedWithTrace`
5. `memoryDistillReadFailureReturnsFailedWithTrace`
6. `memoryDistillPersistenceFailureReturnsFailedWithTrace`
7. `memoryDistillWatermarkRaceReturnsFailedWithTrace`

DM and guide variants are internal cases. Successful empty/no-input remains
distinct from every failure. Test 7 is a four-row barrier table over
`dm.skip`, `dm.created`, `guide.skip`, and `guide.created`: seed one captured
batch, suspend the provider after capture, let a winner consume exactly those
IDs, then release the loser. Every Service loser returns one `.failed` carrying
exact `memory_race_lost` and its invocation trace, inserts zero loser note/event
rows, cannot mark a new-arrival message, and preserves the winner's watermark.
The same table invokes the raw persistence owner directly and requires exact
`MemoryDistillRaceLostError`; it never accepts Bool false. Test 2 separately
proves DM+guide skip success; Test 3 proves DM+guide created atomic success.
Across Tests 2 and 3, an internal capture-validation table invokes
`advanceDistillationWatermark`, both public persistence owners, and nonempty
`markDistilled` with empty, blank-ID, and duplicate raw arrays as applicable.
The overlap row `[" ", " "]` throws `.blankMessageID`; the duplicate row
`["id", "id"]` contains no blank and throws `.duplicateMessageID`. Every empty
dedicated/persistence call throws exact
`.invalidCapturedMessages(.empty)` and every duplicate call throws exact
`.invalidCapturedMessages(.duplicateMessageID)` only after the exact blank-first
precedence is excluded; every array containing an empty or whitespace-only ID
throws exact
`.invalidCapturedMessages(.blankMessageID)` before `pool.write`, SQL,
note, or event work; `markDistilled([])` alone retains its existing zero-work
compatibility no-op, while `markDistilled([id,id])` throws the duplicate case.
Accepted rows prove the validated token preserves the original array order and
bytes. Both public created-owner winners return `true`; no success can return
false. These are internal cases, not new declarations or descriptors.
Faults after the conditional update but before note/event completion roll the
entire transaction back. The existing `E[.memoryWatermarkRace]` descriptor is
the sole owner: its callable matrix is skip through
`advanceDistillationWatermark` and created through the two atomic persistence
methods; these four cases are test rows, not new invocation variants or seams.
Tests 4–7 also run the complete Memory stage/classifier table for DM and guide:
threshold/capture, missing owner, duplicate owner thread, owner/message read,
thread creation, invalid persisted role, Distiller invalid payload, provider,
persistence, CAS loss, and cancellation. They assert the exact code/severity,
safe body, category, domain, retryable, sole allowed diagnostic, exact fixed
DM/guide scope, one Service trace/capture, and zero raw error/logger leakage.
Provider rows cover nil, recognized 100/599, and rejected out-of-range HTTP
diagnostics without hiding the failure. Every known error at an impossible
stage and one ordinary unknown Error assert exact `unexpected_failure` with
unknown/unknown/false and no diagnostics. Cancellation is repeated under all
seven stages and remains warning `operation_cancelled` with
cancellation/cancellation/true.

### 13.5 `McpTests.swift` — 5 new declarations

1. `secretProviderAbsentAndThrowsAreDistinct`
2. `assembledToolsRegistryFailureThrows`
3. `requiredSelectedToolMissingIsTypedFailure`
4. `mcpServerDeletePreimageAndReverseRollbackAreAtomic`
5. `toolBridgeEventWriteFailureRemainsVisibleWithTrace`

Test 4 internally covers pre-image read zero-write, Nth secret-delete failure,
DB-delete failure, successful reverse restore, and restore failure critical.
It also proves the Manager maintenance token rejects a concurrent start/list
and cannot leak after either terminal path. DEBUG finish failure produces both
the rollback and deleted opaque pending variants through the real live port.
The independent `mcpFinishServerCleanup` seam proves rollback success becomes
delete-retry-ready while deleted success becomes a cleaned receipt, with zero
maintenance acquisition, DB, Keychain, or secret-account access. Concurrent
same-token controller calls share exactly one Manager finish Task; different or
stale tokens fail closed without replacing it. Repeated finish failure
preserves the byte-equal token and durability, while a successful retry
consumes it exactly once. Canceling one waiter after flight creation neither
cancels the Manager finish nor leaks the pending token.
The cleanup API has no trace parameter; its deterministic injected factory is
called once before the flight lookup and the resulting failure scope equals
the pending value's retained scope/server ID. Compile/source fixtures reject a
raw-ID or caller-trace cleanup overload.
Rollback-primary plus finish failure asserts one and only one
`cleanup_integrity_failed` row with the closed primary/rollback code pair and
the same full trace; it never first writes a conflicting primary row.
The internal descriptor set contains both `mcpDeleteServer` and
`mcpFinishServerCleanup`; the latter is one of exactly two execution-only
inventory §9.2 descriptors (`mcpFinishServerCleanup` and
`schedulePostCommitRepair`) and adds no `@Test` declaration or entry-fallback
row.
Start versus list failures are owned by FailureVisibility test 16. The existing
spike and MCP tests are updated to `try` the new API. The fake transport parse
paths throw rather than silently drop/substitute frames.

### 13.6 Complete inventory-to-test ownership

The `Regression` cell of every one of the 133 literal-inventory rows is a member
of one and only one primary case family below. Exactly 131 are production
descriptors and two are TestSuite-helper descriptors as frozen in the mapping
appendix. The owning test first asserts
that its hard-coded case-tag set equals the corresponding tags parsed from the
frozen inventory artifact; a missing/extra/duplicate tag fails before
exercising any case. That set check is not coverage by itself: every production
descriptor also names one `ProductionFailureSeam` case, injects its failure through that
real Core/Application callable, and asserts a per-seam invocation counter plus
the terminal DB/log/UI outcome. A descriptor whose only behavior is returning
its expected tag fails. Domain-specific tests in the right column are
additional evidence, not a replacement for the primary table.

Every production App/App-view literal row must map in the inventory to the exact
Core/Application callable to which that production callsite delegates. The
pathname/anchor source gate proves the production App expression calls that
seam; AgentLoopTestSuite then invokes the same seam. Of the four approved
cancellation-only rows, the three App/View rows delegate to
`WorkflowCancellationSleeps` and the Orchestrator row retains its Core seam;
all four additionally use source/object gates. The bounded debug App preview
exercises the actual failure projection. The two MCP fake parse descriptors
must execute their real fake helper and throw, but do not claim a production
counter or delegate. No fake App-free table may restate an expected result
without reaching production decision logic.

| Inventory tags | Primary owning declaration / internal table | Additional exact owners |
|---|---|---|
| every `R[...]` tag | `ApplicationWorkflowTests.databaseReadFailureIsFailedNotLoadedEmpty` | mission/input/MCP controller load tests; Memory read test; MCP registry/list tests |
| every `W[...]` tag | `ApplicationWorkflowTests.runtimeProfileWriteFailureNeverProjectsSuccess` | runtime delete/reconcile; committed outcome; MCP delete; Memory persistence/race tests |
| every `KR[...]` tag | `ApplicationWorkflowTests.keychainReadDistinguishesNotFoundFromFailure` | OAuth and MCP secret tests |
| every `KW[...]` tag | `ApplicationWorkflowTests.keychainMutationFailureNeverProjectsSuccess` | three OAuth transaction tests and MCP delete test |
| required `D[...,required]` tags | `FailureVisibilityTests.requiredKnowledgeFailureAtomicallyBlocksAndRecordsDegradation` | required MCP registry/secret/start/list tests 14–16 |
| optional `D[...,optionalApproved]` tags | `FailureVisibilityTests.optionalKnowledgeFailureRecordsBeforeContinuingWithMarker` | persistence/event tests 13 and 17 |
| production `P[...]` tags (13) | `FailureVisibilityTests.invalidProjectionCasesAreTraceableAndNeverDefault` | direct domain parse tests |
| TestSuite-helper `P[...]` tags (2) | matching existing MCP fake transport tests | real fake helper throws before production entry; no production seam/delegate |
| every `C[...]` tag (4) | `ApplicationWorkflowTests.workflowCancellationCannotMasqueradeAsLoaded` | final source gate proves exact four annotated residual sites |
| every `E[...]` tag (134) | the operation-matched FailureVisibility/Application case table frozen in the catch appendix | direct Core domain test where one exists; never source-only |
| equivalent-default `N[...]` tags (130) | exact owner in §9.1; owner hard-codes and executes its N subset | App dagger rows additionally require `P1-B-DELEGATE` to the same callable |
| planned-new-catch `N[...]` tags (14) | exact owner in §10's planned-catch manifest | global uniqueness/count gate keeps them separate from the 130 |

Policy-specific D tags are exactly the current required/optional decisions in
the inventory; future P1-D policy variants do not inflate this slice's 133-row
count. `mcpServerDeletePreimageAndReverseRollbackAreAtomic`
owns the four deletion failure stages even though they arise from replacing two
inventory rows; `committedVisibilityFailureCannotRepeatMutation` owns every
§5.2 split-commit site in an internal enum table.

The two new declarations plus the matrix runner cover v13; the existing A4
Database test remains an up-to-v12 declaration and therefore does not change
the count. Final authoritative output must be exactly **714 tests in 7 suites**
(accepted A4 667 + 47), with no duplicate test IDs. UI source/object gates and
the two real previews additionally prove prior-data rendering, safe trace text,
release-seam absence, and §11.2 process/data isolation.
Revision 04 edits the bodies of exactly the four named existing Coding Ranch
declarations in §6.3 and preserves their IDs. The final suite must execute each
exactly once; the 714/7 and 47-new-declaration arithmetic is unchanged.

## 14. Verification gates and evidence

### 14.1 Targeted and authoritative tests

Targeted logs list exact test IDs and each must execute once. Final authority is
one fresh, unfiltered invocation carrying the producer-PASS outside-workspace
corpus; it is the sole real-corpus validator/scanner consumer:

```bash
P1B_TERMINAL_AST_CORPUS="$p1b_terminal_root/corpus" swift run RunTests
```

Its complete stdout/stderr and exit status go to `verify.log`. `swift test` is
not authoritative on this machine. The environment path must be absolute,
outside the repository, and owned by a `P1BTerminalASTHandoffV2` PASS record;
missing, legacy-V1, non-PASS, relative, in-workspace, symlinked, or mismatched
corpus fails rather than skips the source-gate subcase. At process entry its
validation-handoff destination must be absent. Exactly one TestSuite source-gate
invokes scanner `--final`; that scanner alone extracts and invokes the
independent validator exactly once, requires its exit-zero canonical result,
snapshots the newly exclusively published validation handoff, constructs its
own retained `ValidatedTerminalState`, and performs typed extraction. All
preflight/self-probe executions use distinct fresh roots. A failed phase poisons
its real output root and is never retried there. No earlier A4 evidence is rerun
or overwritten.

### 14.2 Builds

Both debug and release must pass for all four targets, using `--target`:

```text
AgentLoopCore
AgentLoopApplication
AgentLoopTestSuite
AgentLoopApp
```

That is eight independent target compile gates. Immediately after each
configuration's `AgentLoopApp` target gate, run one explicit declared-product
link gate:

```text
swift build -c debug --product AgentLoopApp
swift build -c release --product AgentLoopApp
```

Those two product gates are the only authority for the corresponding App
executable; an automatic-product invocation or a pre-existing executable is
never accepted. The full build boundary is ten gates: eight target compiles
plus two product links. Release/debug object inspection proves the preview
scenario and test seams are absent/inert as specified. Artifact resolution is
performed only after the product link for that configuration completes, is
exact and fail-closed; `--show-bin-path` is never itself called a binary result.

For each configuration, its path query must emit exactly one nonempty path.
The canonical path is an existing non-symlink directory matching
`$REPO/.build/<one-component>/<configuration>`. The fixed target set is the
four names above. For each target only these paths are accepted:

```text
buildDir = <bin>/<target>.build
map      = <buildDir>/output-file-map.json
module   = <bin>/Modules/<target>.swiftmodule
```

`AgentLoopApp` additionally and exclusively owns the regular executable
`<bin>/AgentLoopApp`. Every path is canonical, regular, non-symlink, and has
the exact parent above; missing is fatal. A fail-closed parser reads each
output-file map without shell glob/find/candidate search:

1. without following symlinks, independently enumerate the complete regular
   `.swift` source set below `$REPO/Sources/<target>`; the expected nonempty key
   set for `AgentLoopApp` is that source set plus exactly
   `<buildDir>/DerivedSources/resource_bundle_accessor.swift`, while the other
   three targets use only their source set; the map's nonempty key set must
   equal the expected set byte-for-byte in both directions;
2. each nonempty key has one unique absolute `object` path that is a direct,
   regular, non-symlink Mach-O child of `buildDir`;
3. `os.scandir(buildDir)` enumerates direct-child `.o` files and that actual
   byte-path set equals the map-declared object set exactly;
4. the empty metadata key may not introduce an extra existing object;
5. duplicate, missing, extra, wrong-parent, unknown generated source, symlink,
   or mixed whole-module/per-source shape fails rather than selecting another
   artifact.

Each exact object runs `nm -j | xcrun swift-demangle` and `strings -a`; only
the executable produced by the just-completed explicit product-link gate runs
both as well. Producer and consumer statuses are captured
separately, and expected-nonempty output that is empty fails. Evidence records
SHA-256 for every map/module/object/executable. An object, module, and
executable can never substitute for one another.

The release four-target artifact union has zero DEBUG token. Debug ownership
is exact. Core and TestSuite each require the following 13 distinct demangled
signature fragments—not twelve base-name matches:

```text
readMissionDetailBundleForTesting(missionId:afterAnchorRead:)
readMissionIndexBundleForTesting(includeArchived:afterAnchorRead:)
readInputCampBundleForTesting(campId:afterAnchorRead:)
readInputReviewBundleForTesting(ingestionId:afterAnchorRead:)
readInputMissionDraftBundleForTesting(candidateId:afterAnchorRead:)
readInputMissionDraftBundleForTesting(ingestionId:afterAnchorRead:)
readRuntimeWorkflowBundleForTesting(afterAnchorRead:)
readRuntimeProviderResolutionBundleForTesting(companionId:afterAnchorRead:)
readScheduleWorkflowBundleForTesting(campId:afterAnchorRead:)
readScheduleRuntimeBundleForTesting(templateId:afterAnchorRead:)
readScheduledMissionNotificationBundleForTesting(missionId:afterAnchorRead:)
prepareDMChatTurnForTesting(companionId:userText:afterAnchorRead:)
prepareGuideChatTurnForTesting(campId:userText:afterAnchorRead:)
```

Each full fragment has count greater than zero in its owning debug artifact;
each is zero in the release union. The gate parses each demangled function
symbol, extracts the base name plus ordered external parameter labels, and
normalizes it to the exact forms above before counting; substring/base-name
matching is forbidden. The remaining debug ownership is:

- Core: the five audit-hook types,
  `makeForDebugAudit`, and `finishMaintenanceFailure`;
- Application: `testingGenerationValue`,
  `PreviewAuditPersistenceBoundary`, `PreviewAuditPersistenceError`, and the
  exact demangled `RuntimeCredentialPresencePort.preview(_:)` label;
- TestSuite: `testingGenerationValue`, `finishMaintenanceFailure`, and
  `previewAuditPersistenceFailureFailsClosed`, plus the guarded
  `preview-credential-audit-canary` subcase string;
- App: `P1BPreviewAudit`, `p1b-preview-audit.json`,
  `AGENTLOOP_UI_PREVIEW_SCENARIO`, and
  `p1b-runtime-profile-db-failure`.

The four App tokens also all occur in the exact debug executable and are absent
from the exact release executable. Counts are computed from saved demangled and
string outputs, never inferred from `grep` status.

#### 14.2.1 Terminal typed-AST corpus production and handoff

Inventory §9.1g-p freezes the complete producer source and §9.1g-v freezes the
independent validator source. Both are framed normative bytes located after the
complete §9.1g scanner frame and before §9.1h; their metadata binds exact byte,
physical-line, and SHA-256 values, and the bootstrap extracts/compiles each only
after checking all three. The driver runs the extracted producer; final
TestSuite/source authority runs exactly one final scanner, which extracts and
invokes the independent validator once inside that same source-gate flow.
Neither source imports the other, consults a generator path, or treats this
prose as executable authority.

Producer, validator, and final scanner use one fail-closed descriptor-anchored
snapshot protocol for every file consumed as authority. Starting from an
already-open canonical repository or output-root directory descriptor, each
exact relative component is traversed with `openat`-equivalent
`O_NOFOLLOW | O_CLOEXEC` semantics and `O_DIRECTORY` for parents; the final
regular file is opened exactly once. Matching pre/post-read `fstat` file type,
device, inode, and size plus one complete EOF read produce one retained raw-byte
snapshot. Byte count, SHA-256, strict parse, schema validation, cross-authority
binding, and downstream consumption in that validation epoch all use those same
bytes. A binding returns the retained snapshot, never a pathname to reopen.
A hash-then-reopen, parse-by-path worker, later `read_bytes()` used as the same
binding, symlinked component, or descriptor/path identity drift is fatal.
`resolve()`, pathname `stat()`, and mtime may be diagnostic only and are never
security or byte-identity authority.

Because each CLI receives pathnames rather than inherited authority FDs, every
process acquires each repository, output, or fresh normative-source-extraction
anchor itself by opening `/` and traversing every absolute component with the
same `O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC` rules. The resulting anchor FD is
retained for the complete epoch and the pathname is descriptor-retraversed for
final identity comparison. Direct resolve-then-open acquisition or later anchor
reopening is forbidden. The invoking parent retains and pre/post checks each
source-extraction-root FD across its child. An anchor leaf or ancestor replaced
before/after acquisition must reject, or continue only through the already-held
FD and then reject at the final pathname-identity gate. `resolve()` may add a
rejection only after FD ancestry is established; it never grants acceptance.

Every terminal-V2 JSON boundary in the producer, validator, and final scanner
uses its one recursive strict loader over retained bytes:
duplicate object keys and `NaN`, `Infinity`, or `-Infinity` are rejected, and
all producer/validator serialization uses `allow_nan=False`. Producer-owned
JSON authorities, validator result/handoff, and every command-ledger JSONL row
must equal the exact sorted-key compact canonical encoding plus one LF; blank,
extra, or noncanonical ledger rows fail. Compiler AST and SwiftPM
`description.json` need not be canonically serialized, but must satisfy the
same duplicate-key/nonfinite rejection and expected top-level kind. Every
schema integer uses `type(value) is int`, its closed range, and never accepts a
Boolean or float; Boolean fields accept only the exact Boolean value.

The validator and final scanner each construct one deeply immutable
`ValidatedTerminalState`. It retains the complete authority snapshot table,
all 299 indexed artifact snapshots, the exact 86 AST raw-byte snapshots, and
the 43 final-source snapshots through PASS publication or typed-role
extraction. Isolated AST workers receive retained bytes rather than paths;
`astBindings` are derived from those bytes. Validator publication and final
typed extraction accept only `ValidatedTerminalState`; no validated AST or
source pathname is reopened between validation and consumption. Every nested
collection that publication or extraction observes is canonical bytes, a tuple,
or a read-only record; a frozen wrapper around a mutable dict/list is not
immutable authority.

After all ten build/link gates and before final source gates or authoritative
RunTests, the driver extracts the complete normative producer bytes from
inventory §9.1g-p and invokes only:

```bash
python3 "$p1b_terminal_ast_producer" \
  --root "$repo" \
  --inventory "$p1b_inventory" \
  --output-root "$p1b_terminal_root"
```

`p1b_terminal_root` must be an existing empty absolute non-symlink directory
outside the repository. It is never reused or overwritten. The producer first
requires the exact frozen `swiftc --version`. For debug and release it runs the
exact `swift build -c <config> --show-bin-path`, reads that configuration's
`description.json`, and uniquely selects the `swiftCommands` records for
AgentLoopCore, AgentLoopApplication, and AgentLoopApp. It independently
enumerates each complete target source set and requires exact bidirectional
equality and order with the record; App alone may add the exact derived
`resource_bundle_accessor.swift`.

The six config-target records retain module, SDK, target, optimization,
conditional `-D`, import, plugin, Xcc, and source arguments in exact order. The
closed transform changes them only to typecheck plus JSON AST dump, rewrites
Swift/Clang module-cache roots below the outside output root, and removes the
configuration-specific scheduling/output flags frozen verbatim in §9.1g-p.
Any unknown output/scheduling flag or remaining workspace cache/output path is
fatal. Immediately before spawn and immediately after wait for every producer,
validator, or scanner-launched subprocess, all terminal-owned `TMPDIR`,
environment Swift/Clang cache roots, and argv-specific Swift/Clang cache roots
must pass the same gate. Every path component is a direct non-symlink
directory, its resolved path is below the outside output root and outside the
repository, and its held directory-FD device/inode/type identity is unchanged
across the subprocess. The relevant root/cache/tmp FDs remain held for that
interval. Lexical containment alone, a resolved escape, a symlink at any
component, or a pre/post descriptor identity change fails even when the child
exits zero.

`swiftc -###` must then produce one primary frontend job per complete
target source: Core 89, Application 5, App 38 in each configuration, 264 dry-run
primary jobs total. Each has exactly one `-primary-file`. The producer executes
only the exact production subset:

```text
debug:  Core 24 + Application 5 + App 14 = 43
release: Core 24 + Application 5 + App 14 = 43
total selected jobs = 86
```

Each selected frontend argv is executed serially without a second transform.
Success requires exact `0\n` exit evidence, empty stderr, and a nonempty fully
parseable JSON-dictionary AST. Failure preserves partial evidence, prints only
the safe stage/config/target/path, exits nonzero, and never writes a handoff.
The output contains `corpus/`, outside-workspace Swift/Clang caches,
`provenance/`, `corpus-command-ledger.jsonl`, `corpus-progress.tsv`,
`corpus-artifact-manifest.tsv`, `corpus-manifest.json`, and last, atomically,
`corpus-handoff.json`. Job IDs are
`SHA256("P1BTerminalASTJobV2\0" + config + "\0" + target + "\0" + exactPath)`.
Both entry and terminal exact-path vector digests use one lossless formula:
`SHA256(UTF8("P1BExactPathVectorV2") || NUL || ASCII(decimalCount) || NUL ||
sum(UTF8(pathInScannerSourceOrder) || NUL))`. Paths are nonempty canonical
repository-relative ASCII strings; absolute, dot/dot-dot, backslash, empty,
non-ASCII, duplicate, reordered, or separately sorted input fails. The exact
35-path entry digest is
`605edeea68344c959ec88accf780093d691ac16f69760727db6ed49b66d5ac1a`;
the exact 43-path terminal digest is
`ecd9834f57d67901b1bbe97f22e3881f68d7337b7587a0b69e49a4975fac5fd2`.
The closed ledgers have 95 command rows (compiler version + two bin-path
queries + six dry-runs + 86 primary jobs), 86 progress rows, and 299 indexed
artifacts. Manifest and PASS handoff bind repository/output roots, inventory/
producer/scanner hashes, compiler, exact 43-path digest, all six records,
complete base/dry-run/primary argv including NUL-argv hashes, source bytes/
hashes, every artifact path/bytes/hash, and the true all-success predicate.

The producer has exactly one production publisher for the complete
`corpus-handoff.json` PASS and the validator has exactly one for
`corpus-validation-handoff.json`; the scanner has none. No fixture, helper,
error path, or alternate success branch may write either final destination
directly. Each publisher first requires an absent destination, serializes the
complete canonical payload, creates a unique same-parent temporary through the
held parent FD with exclusive no-follow semantics, writes all bytes, fsyncs and
fstats the temporary, performs one atomic non-overwriting rename, then fsyncs
the parent directory before returning success. On Darwin the required primitive
is `renameatx_np(..., RENAME_EXCL)` with exact symbol/errno checking; missing or
unsupported flags/functions fail. `os.rename`, `os.replace`, check-then-rename,
or silently substituting zero for an unavailable `O_NOFOLLOW`, `O_DIRECTORY`,
`O_CLOEXEC`, or dir-FD feature is forbidden. Within the publisher-owning
subprocess, publication is its last output-root mutation and no further
validation occurs after the publisher returns. The authorized next subprocess
may consume the prior PASS and, for the validator phase only, publish the
validation handoff. Rename or either fsync failure
returns nonzero, prevents the next phase, and poisons the one-shot output root
against reuse; an accidentally visible file is not accepted as PASS.

“Last-written” therefore means the sole causally last PASS-publisher call after
all bound evidence, followed by successful parent-directory fsync. It is never
proved by `st_mtime`, timestamp ordering, or touching files. The validator
byte-binds the producer handoff, and the scanner accepts only the validator's
exit-zero result plus its byte-identical independently published handoff.

Scanner final mode accepts only `P1BTerminalASTCorpusV2` plus the matching
last-written PASS handoff; entry mode alone accepts the immutable legacy V1
corpus. The final validator imports no producer function. It independently
reruns show-bin-path, reads current description records, enumerates target
sources, repeats the frozen closed transform and `-###`, then exact-compares
every argv, source/module/SDK/target/conditional/import/plugin/Xcc field, job
ID, primary source, command/source hash, ledger, and artifact. Its artifact
index is bidirectionally closed and rejects missing/extra/symlink/path-
traversal entries, nonzero exit, nonempty stderr, empty/invalid/non-dictionary
AST, premature handoff, or manifest/hash drift. Each AST is fully parsed in an
isolated worker before typed-role extraction. Producer, validator, and scanner
own their respective complete negative self-probes frozen in §9.1g-p,
§9.1g-v, and §9.1g: bad root; missing/
duplicate pair; path/source order/digest drift; unknown flag; workspace cache;
bad primary count; SDK/target/module/DEBUG/argv drift; job/source/command hash
drift; artifact closure/hash/type failures; invalid process evidence; and a
legacy V1 corpus offered to final mode.

Self-probe authority must traverse the real production snapshot/state/
publisher/loader call graph; an equivalent test-only parser, writer, or direct
PASS-fixture write is not evidence. Using injected process and syscall seams
only to supply deterministic outputs or faults, the exact positive probes
`real-producer-complete-pass`, `real-validator-complete-pass`, and
`real-scanner-retained-state-pass` must close 264 compile inputs, 95 commands,
86 ASTs, 43 final paths, and 299 artifacts, invoke each applicable complete
PASS publisher exactly once, and prove final extraction receives the 86
retained AST bytes from `ValidatedTerminalState`.

The same real helpers own negative probes for a same-size pathname replacement
between hash and parse/binding with restored mtime; AST replacement after
validation but before extraction; parent or leaf symlink; duplicate JSON keys
at authority, ledger, and nested-AST depth; each nonfinite JSON constant;
Boolean in every representative integer field; noncanonical or blank JSONL;
cache/tmp symlink, resolved escape, or held-FD replacement before/after a child;
pre-existing PASS destination; short write; file-fsync, rename, and
parent-fsync failure; forged older/equal/newer mtimes; incomplete success
arithmetic; and any alternate PASS writer. Each must fail closed or continue
only from the already-retained bytes, never accept the replacement.

### 14.3 Matrix and source gates

`migration-matrix.log` is the complete dual-SQLite real+literal run. Source
gates are fail-closed and prove:

- exact migration order v12-durable → v12-schedule → v13;
- exact 31/65/4 and absence of v14+ objects;
- Package target/dependency graph and unchanged Package.resolved/RunTests;
- Application import/dependency direction;
- `SynchronousRuntimeBootstrap` has exactly one required presence-port call;
  release composition passes `.live(resolver:)`, preview composition passes the
  guarded all-false `.preview` value, and neither branch skips or duplicates
  bootstrap; every real CredentialStore access from process start is dominated
  by `SynchronizedCredentialAccess` and its audit hook;
- AppStore's first composition action constructs
  `ApplicationBootstrapFailureBoundary` and its trace; `makeUserDefaults`
  returns the closed Result and has no trap. Preview-default, state-directory,
  and database-open terminals all call the same `terminate(stage:trace:)`;
  the only pre-composition explicit trap is that boundary method's one
  `preconditionFailure(failure.message)`, and no pre-composition AppStore
  helper contains an independent `fatalError`, `try!`, `exit`, or alternate
  Never primitive. The only other terminal `exit` in scope is the separately
  frozen DEBUG-only `P1BPreviewAudit.persist(_:to:)` failure branch; it is the
  exact final-only `explicitTrapCall` joined to
  `N[.previewAuditPersistenceFailure]` and is absent from release objects;
- zero business `try?`; every parse/cleanup residual matches the literal
  inventory and required comment/explicit invalid contract;
- Memory watermark source has exactly one conditional
  `UPDATE ... distilled = 0` helper and an exact `changesCount` comparison;
  one fileprivate `ValidatedDistillationCapture` initializer rejects an empty
  array, a blank ID, or duplicate raw IDs with the three exact typed
  `MemoryDistillError` terminals
  before `pool.write`/SQL, stores the byte-equal ordered input, and is the only
  way to call that helper. All three raw-array commit owners construct it before
  their transaction; no owner deduplicates, sorts, drops, or normalizes IDs.
  `markDistilled([])` is the sole compatibility no-op, and its nonempty path
  delegates to the same validation;
  skip plus both created owners call that helper, MemoryDistillService has zero
  `markDistilled` calls, and `StaleMemoryDistillationError`, race-to-Bool,
  catch-to-false, `return false`, and race-to-skip branches are absent. The two
  public persistence signatures remain exact
  `@discardableResult throws -> Bool`; their sole successful terminal is `true`
  after full commit. The three production
  calls pass the byte-equal nonempty/unique ID projection from one captured
  message array, with no concatenation/deduplication/reconstruction; the only
  empty compatibility guard remains in `markDistilled`. Existing AppStore,
  `MemoryDistillTests`, and `KnowledgeGoldenPathTests` callsites exhaust the
  public four-case terminal with no optional/nil/Bool projection. The public
  Service initializes/injects exactly one Reporter and trace factory; each DM or
  guide entry creates its exact fixed Memory trace before owner read, owns one
  outer catch, sets the exact seven-case stage immediately before every
  fallible edge, runs the closed type+stage normalizer, captures once, and returns
  `.failed`. The normalizer implements the exact stage/source table: body,
  code, severity, category, domain, retryable, and nil-or-sole GRDB/HTTP
  diagnostic all match; cancellation is recognized first at every stage; an
  impossible known type and every other Error are exact unknown/unknown/false
  `unexpected_failure`; there is no default, reflected type, raw provider body,
  or owner/message value. App has zero Memory catch and resolves provider only through
  `captureSynchronous` before installing a Task. The two Memory entry catches
  are capture disposition, making the exact 134-arm split 19/98/17. The sole
  `E[.memoryWatermarkRace]` descriptor has exactly the four DM/guide skip/created
  callable rows and no catch-to-false relation. A `.created` terminal precedes
  a separately traced memory-note/camp-knowledge reload; reload failure cannot
  call provider, watermark CAS, or persistence and cannot rewrite the Service
  terminal as `.failed`. AppStore has exactly one
  `MemoryDistillationVisibilityCard` per companion/guide owner, retains every
  exact committed record across repeated failed reloads, and offers only
  `retryMemoryDistillationVisibility(cardId:)`. Initial, CRUD, committed, and
  retry loads all begin in the one Application
  `MemoryKnowledgeProjectionCoordinator`, call exactly one matching
  `InputWorkflowController.loadMemoryNotes/loadCampNotes` with a fresh
  `.memoryNoteLoad + .fixed(.memoryDM)` or
  `.campKnowledgeLoad + .fixed(.memoryGuide)` trace, and conditionally apply
  the closed `WorkflowReadTerminal`. AppStore has zero direct
  `companionNotes`/`campNotes`/`captureSynchronousLoad` call in these paths and
  exposes its two lists/states/cards only from that reducer. Per-owner caches
  prove selecting B and failing cannot display A. Stale attempts are zero
  mutation; unknown/stale card IDs return before trace; exact failure preserves
  only the same owner's prior list; exact success clears only that owner card;
  nonvisible-owner completion cannot overwrite the visible projection. The
  controller uses existing `captureAsyncOperation`, so no new catch exists.
  RootView's card action delegates only to the retry method. Pathname/source
  fixtures reject a toast-only failure, global mutable note arrays, a second DB
  load owner, one global overwriteable repair slot, dropped committed records,
  a retry that calls either distillation entry, and any provider/CAS/persistence
  edge reachable from the retry. Validation tests and source order prove
  blank-before-duplicate precedence without Set-order authority;
- schedule repair and terminal-application receipt construction, identity,
  owned keys, stage, evidence, scope, and IDs are opaque. Initial committed/
  visibility-failure and repair repaired/still-pending outcomes contain only
  exactly one application receipt; not-committed/committed-superseded/
  superseded contain none. The four distinct terminal wrappers have
  fileprivate initializers and each exposes only its application receipt; raw
  identity/evidence/failure/repair/clearance data is absent from those outcome
  cases. The canonical-program and decision storage/initializers are
  fileprivate and are returned only by the controller's synchronous consume;
  App has only the closed three-arm fold and the program's ordered operation
  view. Token/program
  splicing, decision relabeling, and optional illegal combinations are
  impossible. The sole
  `schedulePostCommitRepair` callable accepts no raw ID/stage/mutation closure/
  caller trace, contains zero database mutation-port edges, switches the closed
  stage without a default, and performs authorization only in the authorization
  stage and before registration. The controller owns the exact effect-state-
  by-ID/current-effect-ID-by-key, terminal-application-state-by-ID/current-
  carrier-ID-by-key/application-carrier-by-ID/application-tombstone-by-ID,
  and attempt-bearing
  repair-flight-by-ID maps; identity-to-owned-key projection is
  exhaustive, every reverse-map ID resolves one `.performing` or `.repair`
  effect owner, and every carrier-key reverse-map ID resolves directly to one
  carrier. A
  published application state contains only its receipt and carrier ID; source
  requires the exact state→carrier→published-receipt bijection and forbids a
  duplicated program/payload in that state. Every DB commit creates its
  unpublished carrier with the exact DB-postimage operation before the first
  platform await; every accepted repair flight creates its carrier before the
  first effect await. Terminal publication seals that same exact carrier rather
  than reconstructing a program, and a transferred carrier yields a receipt-
  free stale terminal. An intersecting committed mutation removes the
  complete old effect and carrier-key reverse mappings before platform work,
  leaves one exact mutation-superseded application tombstone, and transfers
  the complete ordered canonical operation program
  to the successor. For an unpublished predecessor, source requires complete
  removal of its old effect owner, effect reverse keys, and exact repair flight
  after transfer and forbids any `applicationTransferred` phase; its late
  continuation is dominated by the now-failing owner/attempt/all-keys guard and
  has zero reconstruction/capture/state edges. Only
  `globallyVisibleAwaitingTerminal` may retain an old owner after a global
  visibility operation. Independently current predecessor groups must be key-
  disjoint, are deterministically ordered by canonical minimum key, preserve
  their internal order, and the successor identity appends last; a partial-
  overlap successor may not discard the predecessor's nonoverlapping child
  deletes, and every inherited key reverse-maps to the successor carrier.
  Global visibility normalizes eligible unpublished and published carriers
  without removing their carrier-key reverse mappings; an eligible unpublished owner moves
  to the exact `globallyVisibleAwaitingTerminal` phase so either success or
  catch seals the normalized token with no stale capture/repair, while
  authorization-stage carriers remain current. A DB failure changes none.
  Every apply-capable terminal seals the complete program in its existing
  carrier and publishes one receipt/carrier link in its final no-await
  controller segment before return; a joined Task
  shares that token, and a repair owner with a pending token rejects another
  retry before trace/I/O. Retry
  Task body entry proves byte-equal state, exact flight attempt, and every
  reverse key before trace/I/O; retry proves them again after
  authorization before registration. Both initial authorization success and
  catch paths are dominated by an exact `.performing` owner/all-keys guard
  before Reporter, repair, evaluation, runtime load, or replacement;
  `.committedSuperseded` has zero such edges and zero identity/carrier apply.
  A current initial registration success must publish the carrier and then
  remove its exact `.performing` effect owner plus every effect reverse key in
  the same no-await segment; source rejects a successful initial terminal that
  leaves an effect owner, removes the application carrier, or lacks the exact
  receipt→carrier link.
  `repairId` equals the effect-owner ID, retry accepts only its byte-equal
  `.repair` receipt, and transferred supersessions are drained only by the
  successor. Both success and catch after repair authorization are dominated by
  exact receipt+flight+all-key guards before Reporter, registration, evidence,
  or stage mutation; a stale throw is discarded and returns superseded. Each actual registration attempt calls the
  injected evaluation exactly once and awaits the async port once; the port
  type itself must be `async throws`, all production/test invocations use
  exactly one `try await`, and production still performs at most one atomic
  scheduler swap. The production `MissionScheduler` adapter closure and its
  synchronous build-and-swap helper contain no await/Task/continuation/yield/
  callback/actor-hop edge and return in one MainActor segment; only no-shared-
  scheduler-state test doubles may suspend. DB/auth
  failures call it zero times. Global
  replacement removes registration-stage repair owners, marks only eligible
  unpublished carrier or published terminal kinds/stages globally visible while
  retaining their carrier-key reverse mappings, and leaves authorization-stage
  owners/carriers/tokens current. It never duplicates a carrier's clearance
  witnesses in the global return. `refreshSchedules` returns the same published opaque removed-
  receipt list on success and no list/state mutation on failure;
  its App caller uses only the receipt's pure same-repair-owner proof and removes
  matching carriers. Decision application is nonthrowing, increments no
  generation, never removes its own current repair flight before the ordinary
  tail, and may remove only another same-owner `.repair` attempt; a `.mutation`
  or different-owner flight remains byte-identical. Every receipt-bearing
  terminal synchronously consumes its exact application decision in the same
  no-await MainActor segment before any flight-tail check. An apply decision
  folds only the controller-returned sealed canonical operations even when
  local generation is stale; a globally-visible carrier was normalized in
  place to suppress obsolete registration evidence/failure/repair before that
  same fold; mutation-superseded/already-
  consumed applies nothing. Source rejects any payload read from the outcome,
  identity application not dominated by the decision's sealed `.apply` arm,
  application dominated by a local generation guard, a pending-state removal
  without exact tombstone/full-program transfer, a repair install before
  consume, a consume await, or a failable step after one-shot consume. The App
  Task holds a bounded strong owner and has no cancellation,
  weak-self, or early-return path between controller terminal and consume/apply.
  Source requires generation checked-increment only at command entry before
  controller/DB work; overflow is typed not-started with zero flight/effect, and
  no application/clearance/tail edge increments it. The App Task body
  repeats key+generation+attempt+purpose before its first controller call, and
  controller repair Task body repeats receipt+flight+keys before trace/I/O. It has no caller
  `now`/`timeZone`. `MissionWorkflowPorts.live` deletion
  closures call only `deleteMissionTemplateWithPreimage` and
  `deleteScheduleWithPreimage`, bind their exact return, and contain zero public
  Void-wrapper calls or post-commit rereads/reconstruction. App gates flight
  entry/tail through key + generation + explicit attempt UUID + purpose + old-
  receipt, but applies committed projection only through the opaque application
  decision. It contains no `Task` equality, stage switch, repair/application-
  ID access, or sleep, and a current committed template-deletion receipt clears
  child repair owners without canceling or generation-invalidating an already-
  installed child mutation flight;
- Coding Ranch bootstrap has one `pool.write`, one
  `Self.ensureDefaultCamp(database)` and zero public `ensureDefaultCamp()`
  calls; guide update, cow insert, and event append use the same handle, and no
  partial-bootstrap repair, compensation, nested transaction, or DEBUG fault
  hook exists. The post-database boundary accepts/returns the exact
  `CodingRanchBootstrapResult`, never Void. App has one typed bootstrap load
  state, one retained post-database boundary, one retained
  ProductBootstrapService, one initial boundary evaluation, and one
  failed-state retry method;
  Runtime likewise has one retained bootstrap/request, one initial boundary
  evaluation, and one failed-state retry method. Runtime initial evaluation is
  the binary `captureSynchronous` result passed directly to
  `WorkflowProjection(initial:)`; only retry maps through
  `captureSynchronousLoad`, and no startup switch/default/fatal handles
  idle/loading. The Runtime projection, Ranch state, and joint gate carriers
  have no declaration-site defaults and are initialized exactly from the
  ordered pre-self local pipeline; source rejects omission/reordering of the
  initial Ranch boundary or reconstruction of either Ranch dependency on
  retry. Every attempt has a fresh owner trace. Ranch not-committed or Runtime failed keeps all downstream
  dispatch counters zero. Ranch committed/fixture-visibility and Runtime loaded
  enter the two typed sides of one stored `ApplicationStartupGate`; downstream
  is reachable only from `.startNow`, while waiting/already-started do zero
  work. No second Boolean or Ranch-only/Runtime-only start path exists. The
  AppStore initializer only constructs the gate and has zero claim/start edge;
  RootView's existing `onAppear` calls the synchronous repeat-safe activation
  entry then the ordinary reload after initialization, while its retry actions call the two matching
  methods. Every downstream start call is dominated by the exhaustive private
  decision applier's `.startNow` arm and the other two arms have zero downstream
  edge. The initializer contains zero `reload` or
  `startKernelEventListener` calls and the latter has exactly one production
  call site in that `.startNow` arm. A14 uses
  throwing trigger teardown, proves the trigger absent before retry, and has no
  `try?` cleanup;
- every production `catch`/default arm and raw formatter in the exact 43
  production paths within the 64-path implementation allowlist matches one
  pathname-exact marker from the equivalent-fallback appendix;
  no unclassified arm or formatter is accepted merely because the global count
  happens to match;
- before Revision03 freeze, the inventory §9.1 reference scanner verifies all
  35 dirty-tree entry hashes plus eight literal `ABSENT` paths and reproduces
  exactly 954 IDs, the per-class/per-path vectors, 431 descriptor/cross
  occurrences, 523 disjoint closed-nonfallback occurrences, and 2,962 syntax
  exclusions. After implementation begins, TestSuite treats only the reviewed
  inline annex as entry truth and never claims those uncommitted entry bytes
  still exist; it extracts the same §9.1g reference scanner and exact §9.1h
  2,476-row typed-role registry from the frozen inventory. The authorized
  terminal debug/release compile gate mechanically emits the exact 43-path AST
  corpus under the frozen toolchain/argv transform, then TestSuite invokes
  `--final --ast-corpus <terminal-corpus>` against those paths. The scanner
  freshly extracts the final typed evidence, joins every retained privileged
  root one-to-one, and exact-compares all frozen identity/signature/USR/module/
  builder/conditional/role fields. Entry typed authority is exactly
  2,476 = 2,203 standalone + 54 map/flatMap + 60 GRDB query + 159 optional-dot,
  with zero unclosed and seven exact DEBUG-only rows; terminal arithmetic is the
  retained subset plus typed deletions, with zero unjoined/new privileged root.
  Missing/malformed corpus, compiler/argv/schema drift, an absent/ambiguous AST
  match, selected-declaration/return/receiver/builder-role drift, a newly
  self-approved role, or any nonclosed final root is fatal. Its lexer masks comments and every
  normal/raw/multiline string body while recursively scanning exact-hash
  interpolations; its ternary parser accepts no whitespace evasion; unknown
  projection receivers and non-Void roots outside the exact closed §9.1h role
  families are fatal. Terminal source permits
  no new harmless identity. A retained harmless occurrence must match its
  frozen path/declaration/node-window ID. KEEP/PLANNED markers attach only by
  the candidate/default/catch rules; a DELETE semantic+relation block exists
  only between the mechanically projected `P1-B-SEAM` marker and its callable
  declaration. `P1-B-DELEGATE` edges are verified separately and never host or
  select DELETE. The eight entry-absent paths may add
  exactly eight catch occurrences, the one
  `ApplicationBootstrapFailureBoundary.terminate` explicit-trap occurrence,
  and the one
  `ApplicationPostDatabaseBootstrapBoundary.ensureCodingRanchBootstrap`
  `Result(catching:)` wrapper; every other candidate class in those paths
  remains zero. Existing `OpenAIOAuthSession.swift` may add exactly two
  credential catches, existing `McpToolBridge.swift` may add exactly one MCP
  persistence catch, existing `PlanningProviderResolver.swift` may add exactly
  the three Runtime source-stage catches frozen by the planned manifest, and
  existing `AppStore.swift` may add only the exact
  DEBUG `P1BPreviewAudit.persist(_:to:)` `exit(EXIT_FAILURE)` occurrence owned
  by `N[.previewAuditPersistenceFailure]`. New/unmarked candidates,
  self-approved harmless reasons, moved markers, changed harmless anchors, and
  an unknown candidate hidden in comment/string/interpolation all fail. Every
  frozen negative micro-probe must reject its injected occurrence while all
  expected semantic tag sets remain unchanged;
- the terminal-evidence source gate parses all three extracted Python sources
  and permits final-authority opens only through each independent source's
  exactly one local descriptor-anchored snapshot primitive, JSON loads only
  through its strict loader, and final
  handoff writes only through the two sole complete publishers above. It proves
  the validator publisher and scanner extractor accept
  `ValidatedTerminalState`, the isolated worker accepts bytes rather than a
  path, all integer guards exclude Bool, every subprocess runner performs the
  cache/tmp pre/post FD gate, and each publisher contains temp-file fsync,
  atomic rename, and parent-directory fsync. A pathname hash followed by parse
  or binding reopen, direct final-authority `Path.read_*`, lexical-only cache
  containment, mtime acceptance, alternate PASS target write, a plain
  `json.loads` on terminal-V2 authority outside the local strict loader, or a
  path-taking terminal extractor fails. It runs
  the three real-success probes and every named negative probe above and
  requires exact PASS/rejection sets before final scanner mode can run;
- terminal equivalence resolution is evidence, not design authority. Each of
  the 523 frozen harmless entry occurrences may only be retained with its exact
  final normalized-ID suffix or deleted automatically; it may not be rewritten,
  marked, or replaced by a new harmless candidate. Each of the 431 descriptor/
  cross entry occurrences has exactly one source relation using the closed
  `P1-B-RESOLVE KEEP EF-E-… EF-F-…` or
  `P1-B-RESOLVE DELETE EF-E-… NONE` grammar. The seventeen exact final-only
tuples each have one `P1-B-RESOLVE PLANNED PF-P-… EF-F-…` line, for exactly
  448 resolution lines. KEEP preserves exact pathname, DeclarationID, and
  ClassificationSet; it cannot move an entry across an owner. Its retained/
  rewritten label is derived from suffix equality rather than chosen by the
  implementer. DELETE owner selection is
  mechanical: read each frozen ClassificationSet in its exact-sorted reference
  order and use the first reference's primary seam as `DeletionOwnerSeam`; a
  sorted semantic+DELETE block sits between that `P1-B-SEAM` marker and its
  exact callable declaration. The first reference selects only the static host;
  every reference retains its own frozen descriptor primary, callable,
  delegate, owner, variant, and counter closure. Delegate/owner edges are
  independently verified and never select or host DELETE. Static placement
  alone is insufficient: the exact
  descriptor variants must execute the callable and prove its seam counter,
  exact invocation trace, terminal, persistence/log/UI evidence, and primary owner.
  All 431 business entry occurrences are DELETE-eligible under that
  deterministic host rule, including the seven groups/eight IDs whose other
  references project to additional seams. Cross references are orthogonal
  ClassificationSet members, not a resolution action. The final equations are
  `BK ⊎ BD = 431`, `HR ⊎ HD = 523`, `PLANNED = 17`, and
  `FinalCandidateSet = final(BK) ⊎ final(HR) ⊎ final(PLANNED)`. No relation may
  change disposition, terminal behavior, or legitimize a plan-deviating
  implementation. The 2,962 exclusions are entry evidence: exact suffixes may
  remain or disappear, while a changed/new root is accepted only by the closed
  Optional-type-postfix or closed GRDB-query structural grammar; changed/new
  Optional chaining, `as?`, optional patterns, new standalone calls, and
  collection map/flatMap roots fail. Every final candidate is consumed
  exactly once; unknown, duplicate, orphan, self-approved, or missing-marker
  occurrences fail;
- no `localizedDescription`, `String(describing:)`, reflected type, raw
  credential/account/path/prompt/callback/provider/MCP/SQL/stderr response, or
  unregistered operation/scope coordinate reaches failure/degradation/event/
  UI/log/Accessibility evidence;
- no Application file imports GRDB or names `.pool`, `DatabasePool`,
  `DatabaseQueue`, `DatabaseReader`, `DatabaseWriter`, `Row`, or `Column`;
  compile fixtures instantiate and call every package DTO,
  initializer, overload, bundle, injection seam, and compatibility wrapper;
- Schedule aggregate implementations call only the six frozen
  Database-parameter ScheduleStore helpers; Chat/Guide façades and preparations
  call only their seven frozen helpers; MissionDraftFactory and both bundle
  overloads share the one same-file private decoder. Duplicated SQL/JSON
  parsers or a legacy App call to `ChatMessageRecord.text`/`proposal` fail;
- App's OAuth surface contains only injected NWListener/NSWorkspace platform
  closures and raw callback-URL handoff. State/verifier generation,
  authorization/callback codecs, query/fragment parsing, HTTP token exchange,
  credential mutation, and cleanup have one Runtime controller/Application
  implementation; any App parser, HTTP exchange, or duplicate codec fails;
- AppStore owns exactly one `oauthLifecycleStateByFlow` authoritative sum-state
  dictionary, not parallel receipt/pending/attempt maps, and its total
  lifecycle-owner cardinality across all flow keys is `0...1`; the controller
  stores one global optional owner and source rejects controller lifecycle
  storage keyed by `OAuthCredentialFlow` or an App begin guarded only by the
  requested subscript. Its physical auxiliary
  callback carrier is `oauthCallbackClaimCandidateByFlow`, which holds one
  tentative exact physical/claim handshake per flow, never represents a
  lifecycle owner, and is absent outside that bounded handshake. Nil alone synchronously installs
  `.reserving` plus the lifecycle Task before its first await. A tap during
  `.reserving` may queue one rejection but cannot call the actor; after
  reservation, `.preparing`/`.active`/`.callbackProcessing` rejections must
  pass the exact opaque reservation through the separate rejection Task/UUID
  carrier. An eligible callback first inserts one exact
  `OAuthCallbackClaimCandidate`; before the non-I/O actor claim returns, source
  mechanically forbids any lifecycle-state/Task cancellation, clearing, or
  replacement except the exact row-two or row-three listener pending
  transition, which installs its fresh pending and atomically retargets that
  same candidate's lifecycle attempt/origin while preserving
  reservation/command/trace/lease/physical attempt. It keeps the physical
  callback phase drain-bearing. The sole
  callback stream consumer awaits claims serially and may not spawn sibling
  claim Tasks. Only `.claimed` plus one no-await MainActor physical+App
  promotion may install the explicit attempt+reservation+claim-origin
  callback-processing state and its sole capability Task. After the actor
  await, promotion must reread the map-current candidate, compare its immutable
  handshake fields with the submitted candidate and physical event, prove the
  claim's flow/reservation/authorization/lease only through its package-visible
  value and three pure comparison methods, and use only that current entry's
  possibly retargeted lifecycle attempt/origin for the App/Task guard. It must
  not require the App candidate origin to equal the controller-current
  `claim.origin`: post-preparation, browser-opening, ready, or advanced-recovery
  claim origins may legitimately differ, and `claim.origin` is independently
  installed as the restoration witness. Use of the pre-await local
  attempt/origin or any nonexistent claim field getter fails the gate. Claim superseded
  preserves the old App carrier; claim accepted but promotion-invalidated must
  call exact abandon before physical finish. The old command-based handle
  overload, direct claim construction, and capability-free processing fail.
  Duplicate/prepared-less callbacks are zero-I/O, and listener terminals may
  cross phase only through the closed seven-row deferred-preparation,
  preparation-origin, active/recovery, pre-promotion display-only,
  promoted-callback display-only, post-abandon display-only, and stale
  transition table. Each requires
  exact slot lease+failure attempt,
  reservation binding, flow, opaque authorization, and returned pending lease;
  preparation/active/recovery rows cancel/compare-clear only the exact old
  lifecycle Task before installing a fresh attempt, and an exact candidate on
  that old attempt is retargeted in the same segment rather than invalidated.
  The authorization-retry UI enabled predicate and action entry must both prove
  the same flow's candidate map entry is nil in the one no-await MainActor
  attempt/Task-install segment. Any candidate-first branch that changes the
  lifecycle attempt/state/Task, calls the controller, mints a trace, queues a
  second retry carrier, or retargets the candidate from an explicit retry
  fails. The inverse retry-first branch must finish attempt/Task installation
  before later candidate capture. After controller claim, a direct retry must
  take the exact `.superseded` phase guard before trace creation or I/O.
  Callback-phase listener
  rows are display-only and are mechanically forbidden from cancelling,
  clearing, or replacing the callback claim candidate, promoted Task, or
  lifecycle state; deferred rows also never replace them. Listener failure
  before claim is adopted by the claim CAS; failure after claim merges into the
  claim owner. Only the promoted capability Task may enter callback business
  I/O, and only its sealed terminal synchronizes App. Late
  preparation/recovery/callback/listener terminals cannot clear a newer
  carrier. Direct App access to pending authorization/stage/lease IDs remains a
  compile-negative fixture. Every non-listener App apply requires
  attempt+reservation+phase equality. The controller installs
  its reservation before suspension/I/O; prepare/reject accept only that
  opaque value, and old flow-only/trace-only overloads are absent. Rejection
  cannot cancel, replace, adopt, or clear A and has no edge to RNG, listener,
  preparation envelope, Keychain, codec, browser, or normal preparation; it can only
  capture one fixed failure or return superseded. Source gates explicitly
  reject any dependency on actor-job FIFO ordering. `claimOAuthCallback` is a
  single non-suspending actor operation with zero Reporter/platform/envelope/
  payload/exchange/credential I/O. It first proves the exact reservation+
  authorization+lease, then calls the pure nonthrowing
  `callbackStateMatches(configuration,url,expectedState)`, and only an exact
  configured route/state match may create `.callbackClaimAwaitingApp`. An
  accepted state is constructed only by nonthrowing
  `SecretValue.validated`, whose nil result is the blank/invalid protocol
  rejection, and compared only through `constantTimeEquals`; source rejects a
  throwing initializer bridge, `catch`, `try?`, `try!`, trap, raw
  `String`/`Data` equality, hash,
  prefix, localized comparison, or an early-returning byte loop in both this
  pre-CAS matcher and the later parsed-payload state check. The helper itself
  must fold length difference plus every byte position into one accumulator;
  the explicit `SecretValue.==` body calls only `constantTimeEquals`, and source
  rejects a synthesized/fieldwise/raw-value Equatable path. The private
  `validatedRaw` initializer is reachable only after the common nonblank
  predicate in the throwing initializer or failable factory; no other caller
  may construct it. The factory's sole success construction is exactly
  `SecretValue(validatedRaw: raw)` with the original argument; source rejects
  passing a trimmed, normalized, copied, decoded, or otherwise transformed
  value to that initializer.
  Functional fixtures cover equal, same-length first/middle/last-byte mismatch,
  and unequal-length values without a wall-clock assertion. An
  exact current tuple with invalid route/state returns
  `.currentAuthorizationRejected` with controller state byte-identical; a stale
  tuple returns `.superseded` without calling the matcher. App may true-restore
  only the former exact map-current candidate, and source requires candidate
  clear plus physical finish in the same no-await MainActor segment. It rejects
  true-restoring `.superseded`, reopening a failure-bearing/retiring slot, or
  mapping either terminal to callback business work. `handleOAuthCallback` accepts only its
  opaque claim, and `abandonOAuthCallbackClaim` is the sole no-I/O escape from
  that phase. Every source path from `.claimed` reaches exactly promotion or
  abandon even when the consumer Task is cancelled; no claim phase may be
  dropped by loop exit/weak-self loss. The controller's
  nonempty-flow guard includes callback-claim-awaiting-App and callback-
  processing, and every callback await
  checks its distinct callback attempt/phase rather than reservation alone.
  The distinct custom-scheme carrier/Task is the only named lease-free ingress:
  it calls only `claimOAuthCustomSchemeCallback`, retains the prior lifecycle
  Task through claim, and after `.claimed` must promote or abandon before
  clearing. It never touches the listener owner, physical candidate/ack API, or
  constructs/accepts an optional/default/fabricated lease. The physical
  callback factories alone require `listenerLease:`. Source requires exhaustive
  `claim.ingress`, permits `.ready` abandon only from custom ingress, requires
  custom cleanup listener counters zero, and rejects commands/raw URLs passed
  to handle/abandon. The custom claim's only pre-CAS codec edge is the pure
  nonthrowing `callbackStateMatches(configuration,url,expectedState)`;
  URL route and one nonblank query/fragment state must match before owner
  mutation, and every absent/duplicate/blank/malformed/stale state returns
  superseded with the current generic controller/App owner byte-identical and
  zero payload/exchange/credential work. Generic retry is disabled synchronously while the direct
  ingress exists. `AgentLoopApp.swift` and its existing onOpenURL callsite are
  byte-identical and outside scope.
  The coordinator's initial callback command performs a complete shared-bundle
  replacement: access and supplied refresh/ID/account are set only by the active
  flow, absent refresh is deleted, generic deletes ID/account, ChatGPT requires
  and sets its derived account, the canonical envelope advances to `.initialCommitting`
  first, and that envelope deletes last. Source rejects every
  preserve-preimage/fieldwise-merge branch in initial callback, while background
  refresh retains its separately frozen behavior. Authorization preparation
  returns exactly committed/failed/unavailable for one versioned atomic
  envelope item. `.unavailable` owns only invalid coordinates or an
  owner-mismatched/unprovable durable quarantine, and the controller
  exhaustively maps all three cases. Source requires one pre-read and at most
  one canonical selected-phase set with no post-set read. Absent or canonical
  prepared preimages select owner-bearing `.prepared`; owner-equal recovery or
  committing preimages select owner-equal `.recoveryPrepared`; an
  owner-different recovery/committing item or any unprovable legacy/malformed/
  noncanonical/unknown item returns unavailable with zero writes. No branch may
  downgrade, reassign, or delete another owner's quarantine. Source rejects all UserDefaults OAuth state and
  raw verifier paths and forbids rollback state/API/App cases. A failed pre-read
  or set is not committed and leaves the prior-or-absent item byte-identical. The default
  authorization-state-persistence descriptor has one final
  `oauthAuthorizationPreparation` occurrence and counter value one; its two
  entry relations both resolve to that single atomic owner without a fifth
  multi-variant descriptor;
  every production OAuth credential read is dominated in the same synchronized
  critical section by strict envelope decoding. Only absent/`.prepared` permits
  an ordinary provider/presence read; `.recoveryPrepared`, any committing phase,
  or malformed/noncanonical bytes throw
  `OAuthCredentialBundleUnavailableError` before returning a credential.
  Runtime presence uses one ordered API/Search/envelope/access/refresh/ID/
  account-ID snapshot; Runtime provider and App Planning source use the shared
  OAuth snapshot, while every Session construction uses
  `readRefreshCredential`; none uses
  raw individual production reads. The Session read returns an opaque
  coordinator-and-account-bound revision+full-snapshot proof. Every OAuth entry rejects an
  empty/duplicate five-coordinate bundle before lock/store/HTTP work;
  `commitAuthorizationPreparation` alone expresses that rejection as its
  closed `.unavailable` value because its API is nonthrowing, and the
  preparation controller must exhaustively map all committed/failed/
  unavailable cases without a default before any browser work. Every
  OAuth mutation attempt advances all five coordinate revisions under the
  process-state lock; refresh commit and unauthorized delete must validate
  the proof's exact coordinator identity and per-coordinate revision snapshot
  before I/O and the absent envelope plus byte-equal
  access/refresh/ID/account snapshot before their first write. Source rejects a
  proof-free overload, a proof fabricated outside the coordinator, validation
  after the sentinel write, stale-result `onPermanentFailure`, and
  `.preimageChanged` mapped to missing/unauthorized/success. Initial commit
  accepts the exact coordinator-and-account-bound preparation and no caller
  accounts, rejects another coordinator before lock/revision/credential work,
  then proves the current byte-equal owner-bearing envelope including its
  fileprivate `.prepared`/`.recoveryPrepared` phase. It writes owner-equal
  `.initialCommitting` before any credential
  field, compensates fields in reverse, restores the exact original phase only
  after every field restore succeeds, and deletes the
  envelope last. A fresh same-owner authorization over quarantine remains
  owner-equal `.recoveryPrepared` until that delete; a different or unprovable
  owner cannot start recovery. Refresh/delete require absence, write their exact
  `.refreshCommitting`/`.unauthorizedDeleteCommitting` sentinel first, compensate
  in reverse, and delete it last only after complete success. Source rejects an
  envelope restore/delete after any field rollback failure as well as
  quarantine-to-nil/unauthorized mapping and any App-production use of the public
  compatibility Session initializer. The compatibility initializer must use
  exactly `OAuthCredentialAccounts.live.verifier` as its backend-global fifth
  envelope account,
  construct the same coordinator path, and contain zero direct
  `CredentialStore.get/set/delete` refresh edges. All
  `SynchronizedCredentialAccess` initializers reference the exact static
  `CredentialAccessProcessState`, freeze the store's required stable
  `CredentialStoreBackendNamespace`, and address revisions only through the
  composite backend/account key. `KeychainStore` projects its exact service as
  `.keychainService`; every memory/recording fixture retains one unique
  `.isolated(UUID)` per backend instance. The public protocol extension must
  provide the exact stable `.legacyShared` default so an external conformer
  with no new member remains source-compatible; source rejects a generated UUID,
  object identity, or per-call/per-wrapper default. Independence is required
  only for explicit namespaces, while legacy-default stores conservatively
  invalidate one another. Source rejects a per-instance lock,
  an account-only or store-object-identity registry, reuse/regeneration of a
  backend namespace, cross-**explicit**-backend invalidation, invalidation of a genuinely
  five-coordinate-disjoint same-backend custom bundle, failure to invalidate an
  overlapping same-backend coordinate, or any claim that
  two public compatibility tuples sharing `.live.verifier` are revision-
  disjoint. It also rejects a compatibility
  envelope other than `.live.verifier`, any derived/hash/encoded/suffixed
  per-tuple envelope identity, or revision validation outside the credential
  lock. The initial revision read must populate every missing coordinate under
  that lock and return a complete five-entry snapshot; source/tests reject a
  nil/default/missing revision, fresh UUIDs on an unchanged second read, or
  partial advancement. Source also rejects a caller-supplied accounts argument
  on initial/refresh commit or delete, an authorization/refresh proof not bound
  to the exact coordinator and accounts, or coordinator
  identity validation after lock/revision/credential work. Initial commit must
  also prove `bundle.flow == preparation.flow`, and refresh commit must prove
  `bundle.flow == .chatGPT`, before the credential lock. Source rejects a
  payload-flow check after any lock/revision/store/Reporter/callback/permanent-
  failure edge or a flow-mismatch terminal other than the exact
  `.preimageChanged` flow owned by the proof.
  `CredentialMutationStore` and `withExclusiveAccess` are same-file
  `fileprivate`; the store is deliberately non-Sendable and the generic result
  remains `Sendable`, so the locked mutation capability cannot be returned or
  retained. Source rejects storage/capture/escape of that value or any direct
  mutation outside its synchronous closure. App's
  production coordinator is constructed only after the process-lifetime
  `StateDirectoryLock` is acquired, and that stored lock cannot be released or
  replaced while OAuth owners/Sessions remain reachable; no cross-process
  guarantee is attributed to the public compatibility initializer;
  `prepareOAuthAuthorization` has zero edge to the platform
  `openAuthorization`; its only committed terminals are prepared or the exact
  listener-then-browser recovery. The only initial browser edge is
  `openOAuthAuthorization(RuntimeOAuthAuthorizationOpenCommand)`. The App
  source fixture requires one no-await MainActor segment to apply the exact
  prepared owner as active, replace the preparation Task with a fresh open
  Task, and install that Task before the controller call. Controller phases
  include distinct post-preparation and browser-opening owners. Listener and
  callback claims can invalidate only their exact open attempt; late open
  terminals cannot change recovery/callback/cleanup. A callback claimed from
  post-preparation/browser-opening retains browser-reopen on pre-commit failure,
  while one claimed from ready restores ready. No platform open occurs while
  App is preparing, and no exact active owner may receive a superseded open
  terminal without a newer App transition;
- every local-listener start receives a controller-minted opaque lease bound to
  the current reservation, and every controller phase after receipt creation
  carries its current optional lease. `RuntimeOAuthPlatformPort` has no
  receipt-only start/stop overload and the listener-failure API has no
  lease-free overload. App owns exactly one physical slot per flow with the
  closed `starting/live/failureClaimed/callbackClaimed/callbackProcessing/
  callbackAndFailureClaimed/callbackProcessingAndFailureClaimed/
  callbackFinishedAwaitingFailure/recoveryAppliedAwaitingApp/
  callbackFailureAppliedAwaitingConsumer/callbackProcessingAfterFailure`
  phases plus the closed recovery-apply remainder. There is no unconstructed
  `stopping` phase. Recovery replacement is controller-owned and has one exact
  order: stop the old lease, await every physical callback/failure
  acknowledgement, recheck old owner+attempt+lease, then and only then mint,
  install, and start G2. `startListener` is construction-only, rejects a
  nonempty slot with typed `.accept`, and contains no controller recheck or
  replacement branch. A yielded callback blocks G2 through its non-I/O
  controller claim and App promotion/abandon or sealed/local reject;
  stream dequeue alone is not acknowledgement. `.callbackProcessing` and
  `.callbackProcessingAfterFailure` are not outstanding callback claims. A
  failure-bearing G1 blocks only until the guarded recovery App apply is
  acknowledged. Starting failures advance/
  remove, complete the start once, cancel the exact candidate listener once,
  and never launch a handler; a live failure claims and cancels exactly once.
  An async start returns the exact closed `.started/.ownerShuttingDown` result,
  and its controller caller rechecks the exact phase+lease after the await
  before publishing any success. Every callback command carries the physical
  event's opaque lease; source gates reject any callback factory or actor claim
  without it, and require a mismatch to fail before codec/exchange/credential
  work. A G2 callback/failure that claims the current lease before start returns
  makes that post-await start terminal stale rather than fabricating success.
  `beginCallbackClaimIfCurrent` only proves the exact physical attempt; it does
  not transition or resume a waiter. An eligible event must pass
  `claimOAuthCallback`, then `acknowledgeCallbackPromotionIfCurrent`, before App
  cancels an old lifecycle Task or installs the capability Task. Claim reject
  leaves the App carrier byte-identical; an exact
  `.currentAuthorizationRejected` compare-clears only its map-current candidate
  and true-restores only a plain nonretiring/nonfailure slot, whereas
  `.superseded` is always non-restoring; accepted-but-unpromotable claims call
  abandon before finish. Local invalid-state branches install no Task and call
  `finishCallbackIfCurrent` with the exact restoring/non-restoring rule. Only
  exact preparing+reservation-bound lease or the exact current-authorization
  state-rejection outcome may request restoration; reserving and every stale
  owner/lease, callback-processing/cleanup/empty/mismatch state are
  non-restoring. A failed
  physical begin has zero finish or App mutation. Source rejects the former
  `consumeCallbackIfCurrent`, any dequeue/begin phase advance, a failed
  promotion that installs a Task or omits exact abandon, and any accepted-claim
  exit on cancellation/weak-self loss. The exact candidate map is the sole
  App-visible proof for pre-promotion `.deferredToCallback`; it is removed only
  by the matching promotion/abandon/sealed-reject/current-state-reject/
  local-reject terminal. The
  `stopListenerIfOwned` removes starting/live/callback-processing slots before
  cancellation and never awaits or cancels the installed logical callback Task.
  It drains a queued callback through claim+promotion/abandon/reject and drains a failure only to
  recovery/App acknowledgement. For
  `.callbackProcessingAndFailureClaimed`, it awaits only that exact failure;
  the committed callback cleanup-to-stop call graph has no dependency on
  `finishCallbackIfCurrent` or the enclosing callback method's return. Every
  failure consume first enters `recoveryAppliedAwaitingApp` with its closed
  remainder; only the immediately following guarded App apply plus
  acknowledgement may remove/resume that failure drain. A callback-only retire
  sets the retire bit before its single listener cancel, and a failure-bearing
  phase never cancels the already-cancelled listener twice. An ordinary failure event
  enters a short awaiting-App tombstone whether it arrives before or after
  stop/replacement; only the same MainActor consumer segment's guarded App-apply
  acknowledgement removes it and resumes at most one waiter, so G2 cannot race
  ahead of the visible terminal and no later second wait can appear.
  Replacement likewise cannot publish G2 across an undrained claim. A
  committed callback cleanup retains its controller owner/lease only while
  awaiting an independently claimed failure; the sink still mints one fresh
  trace/report and returns no restart capability. A plain processing cleanup
  stop returns before that same callback's sealed terminal. Source/compile gates
  require both exact closed start/stop result enums and exhaustive no-default
  controller switches; they reject a Void-returning start/stop, synchronous stop,
  cancelling a claimed callback/failure Task, treating logical callback
  completion as physical delivery acknowledgement, owner removal before the
  final required acknowledgement, a cleanup-stop dependency on its enclosing
  callback return, or use of Task cancellation/FIFO as an ack.
  The sole whole-owner teardown path is an idempotent MainActor `shutdown()`
  called synchronously by the owner-held App-termination block, with an
  ordinary nonisolated-deinit fallback that copies only Sendable owner/Task
  values into one typed MainActor cleanup Task. It is legal only while AppStore
  itself is ceasing. It finishes
  both streams, removes physical slots before cancellation, resumes each start
  continuation with `.ownerShuttingDown`, and resumes each claim drain exactly once with
  `.ownerShuttingDown`. Every ordinary start/stop controller caller maps that
  outcome to its existing `.superseded` terminal without publishing a lifecycle
  success, replacement, restart, Reporter, or UI terminal. A failed atomic
  preparation write has no integrity exception or retained owner because its
  Keychain preimage did not change; teardown compare-clears only that exact
  controller attempt after the ordinary captured failure. Source gates reject
  inventing a rollback pending/API or treating shutdown as a successful
  preparation acknowledgement.
  Once the private `isShutdown` bit is set, source gates require start/stop to
  return their closed shutdown outcomes and every event-consume/finish/physical
  callback to be false/no-op/cancel-without-yield; slot/stream recreation and
  resetting that bit are forbidden.
  Controller failure
  claim and every terminal compare reservation+authorization+lease+claim
  attempt before reporter or lifecycle I/O. Old-generation, duplicate,
  intentional-cancel, and post-replacement callbacks have zero handler,
  reporter, UI, or lifecycle effects. The exhaustive NWListener-state gate
  maps invalid port/bind/waiting-or-failed/unexpected-cancelled/malformed-request
  only to `.invalidPort/.bind/.accept/.cancelled/.malformedCallback`, treats
  intentional cancellation as zero-handler, and permits no default arm. Every
  starting wait has one cancellation handler and one MainActor one-shot
  continuation; ready/failure/caller-cancel races resume it exactly once and
  every non-ready terminal advances/removes ownership before exactly one
  listener cancel. Malformed input yields no callback and its exact live lease
  enters the same one-shot failure claim after a fixed 400 response. Every
  accepted connection joins the exact live slot before read and atomically
  changes live to one `callbackClaimed(callbackAttempt:)` before raw URL
  handoff. A burst yields at most one callback event per lease; an old,
  already-claimed, replaced, or stopped lease has zero callback,
  codec, exchange, or controller calls. A first physical failure after callback
  claim preserves both exact attempts, invokes the sink once without cancelling
  callback, and uses the closed independent-ack join. Recovery-first preserves
  a queued callback through its serial claim consumer; stop/G2 waits through
  claim plus App promotion/abandon/reject, not through that Task's later sealed terminal. Failure drain waits through
  guarded App acknowledgement. Callback restoration to live is permitted only
  for an exact preparing local reject from plain `.callbackClaimed`, or a
  pre-commit plain promoted callback with no failure claim/drain waiter; it is
  never permitted from a failure-bearing phase. Both apply orders preserve the fresh failure and callback and retire
  the dead slot with no FIFO assumption. App has exactly one private
  `OAuthListenerPlatformOwner`, and only that owner contains the slot
  dictionary and two event continuations. Composition constructs its two
  lossless streams before the owner-only-capturing platform factory and
  controller. The App declaration remains the pure-Swift
`@MainActor @Observable final class AppStore` with its one existing init.
After the exact two stream-value-plus-weak-self consumers are installed, one typed-binding call
asks the owner to install the sole will-terminate block observer; the block
captures only owner+consumer Tasks, and the owner stores/removes its one token
during idempotent shutdown. Each consumer is required to capture its
pre-extracted `AsyncStream` value and is forbidden to capture the owner, so the
observer's Task captures cannot form a persistent indirect owner cycle; the
callback consumer's permitted per-event strong AppStore local is bounded by
mandatory promotion/abandon/reject and cannot cross the next stream wait. NSObject
conversion, selector/relay/super-init,
AppStore/controller capture, a second observer, or an unowned token fails.
The existing `NotificationCenter.default.addObserver(forName:object:queue:
using:)` standalone root and observer role are rewritten in place rather than
duplicated: path and `AppStore.init()` DeclarationID remain exact, while the
same statement delegates to the owner installer. Its changed final root is an
automatic deletion of the frozen SC-X row. The owner installer assigns the
returned token to `terminationObserver`, so it creates no bare final root or new
SC-F exclusion and needs no B/KEEP relation. The former nested `terminateAll`
SC-X row is also an automatic deletion; its replacement is a typed Void binding
inside the observer body.
  The factory is pure construction,
  controller calls it exactly once with its nonempty bound sink before the
  first listener start, and every later flow reuses the port. Source and
  compile gates reject a factory capture of AppStore/controller, any
  optional/IUO/late-bound controller cell, empty sink initializer, bind method,
  `lazy` recursive composition, second slot registry, event-dropping buffer,
  listener start before consumer installation, direct App construction/storage/
  introspection of the sink, or any use other than forwarding the exact factory
  parameter once into `makePort(failureSink:)`. A streamed recovery event must
  rejoin the exact current lease and failure attempt, and a streamed callback
  event the exact current lease and callback attempt both at physical begin and
  immediately before promotion/local finish. Recovery apply additionally
  rejoins immediately before its guarded App transition; mismatch is zero-I/O.
  The retained
  `AppStore.startOpenAIAuthCallbackListener()` catch is the sole raw-NWListener
  constructor mapper: same path/DeclarationID/`E[.oauthListenerStart]`, static
  and self-free, fixed `.bind` error, zero raw formatting. The owner invokes it;
  `makePort` and every other new App OAuth declaration contain no catch or
  Result wrapper, and browser false maps directly without catch;
- App constructs one `OAuthCredentialAccounts`, nests that exact value in one
  `RuntimeCredentialAccounts`, and injects the Runtime value everywhere.
  Slot-to-account selection is the exact exhaustive API/Search switch; all
  OAuth reads and writes project the one nested value. No copied literal,
  second Runtime/OAuth bundle, independent OAuth init parameter, default arm,
  profile-derived account, or caller-supplied attachment account exists;
  Runtime and Planning closed error types are distinct and neither owner may
  catch, alias, or project the other's type. The seven deleted AppStore legacy
  provider symbols (`storedProviderCredential`, `resolveProvider`,
  `runtimeProfileCredential`, `attachAPIKeyToEmptyDefaultProfileIfNeeded`,
  `AppStore.makeProvider`, `AppStore.StoredCredential`, and
  `RuntimeProfileResolutionFailureHandler`) have zero declarations and zero
  references; the Orchestrator initializer's unrelated `makeProvider` parameter
  remains the required throwing closure;
- Runtime provider resolution interprets one optional DB snapshot, then CLI,
  then validates the effective endpoint before catalog/credential/factory
  work. Strict API-profile resolution likewise validates and retains its
  normalized endpoint before catalog/credential/factory calls; invalid or
  missing endpoints have zero downstream calls and remain the exact typed
  endpoint terminal. Live credential presence has exactly the fail-fast
  API-key -> Search-key -> preparation-envelope -> OAuth-access -> refresh ->
  ID -> OAuth-account-ID order with one shared interaction policy and one
  `readRuntimeCredentialPresence` lock interval; its injected failures prove
  one lock acquire/release, 1...7 underlying store-read prefixes, zero later
  reads, no partial result, no single-read emulation,
  and no alternative order;
- OAuth background refresh and permanent-unauthorized deletion have one owner:
  `OpenAIOAuthSession` package production composition with injected reporter
  and trace factory. One in-flight refresh Task mints one refresh trace for all
  waiters; unauthorized deletion mints a distinct trace before its first I/O.
  Runtime controller/App expose no refresh-commit callable or edge, and Runtime
  resolver only passes the traced closure without executing/mapping it;
- authorization recovery stores one closed combined stage, not parallel
  listener/browser state. The two failure orders merge to
  `.listenerThenBrowser`; retry order is listener then browser, and every
  partial/late terminal conditionally preserves the exact remaining
  obligation. Before each recovery await the controller owns an exact
  reservation+authorization+recovery-attempt+remaining-stage phase. A callback
  from the same opaque authorization first passes the pure configured-route+
  expected-state matcher and then performs the non-I/O claim CAS,
  atomically supersedes that exact attempt, and freezes a claim-time App origin
  while retaining the controller-current in-flight or stable pending stage; if
  the controller already reached same-auth ready it retains no remainder. It
  does so even when the App's starting pending stage is older, while App leaves
  that state and recovery Task byte-identical until `.claimed`, except when an
  already controller-sealed listener pending is exactly applied through row two
  or row three before promotion; that one segment installs the pending and
  retargets the candidate without acknowledging it. An exact callback
  candidate temporarily closes explicit authorization retry: candidate-first
  is a synchronous zero-mutation no-op, while retry-first completes its
  attempt/Task install and is captured by the later candidate. Rows two and
  three never re-enable retry while that candidate exists. The following no-await
  promotion rereads the map-current candidate, cancel/compare-clears only its
  exact Task, and installs callback processing; capability processing reads any
  listener stage merged after claim. Pre-commit failure restores only the retained
  remainder, and every late recovery terminal is stale. No other callback may
  take over a recovery and App still cannot read pending authorization/stage.
  Credential attachment, authorization/listener, and callback-
  cleanup recovery each mint one fresh trace from the controller's injected
  factory and retained opaque scope only after its controller-current guard
  accepts and before I/O; a stale/superseded retry returns before trace
  creation or I/O. Original receipt traces remain
  provenance only; no retry reuses them for capture, accepts a caller trace, or
  reconstructs scope coordinates;
- MCP pending-token lease fields/initializers remain module-internal;
  AgentLoopApp/TestSuite have zero direct `acquireMaintenance` /
  `finishMaintenance` edges, and McpStore's retry anchor delegates to both
  `McpCleanupApplyGuard` and `mcpFinishServerCleanup`; no raw server-ID cleanup,
  optional-token deletion receipt, raw-ID scope reconstruction, or full-delete
  retry from a pending state is permitted; cleanup trace creation uses only the
  controller's injected factory plus the pending value's retained
  `FailureTraceScope`, and no cleanup overload accepts a caller trace;
- no post-loader `searchKeyProvider` call and no provider resolution before a
  context `.ready` result;
- exact 66-path delta, new-file regularity, no source symlink/type drift;
- A3/A4 historical successor partitions and unaffected hashes;
- `git diff --check` clean.

Logs are written from actual command output with explicit command, cwd,
environment boundary, exit status, and terminal sentinel. Empty/truncated/
post-hoc summaries do not pass.

## 15. Completion, independent review, and acceptance

P1-B implementation completion requires all of the following:

- every §13 test and §14 gate green;
- R-05 and R-06 have evidence-backed closure;
- R-07 closes only as consumer extraction; AppStore remains composition root
  and no whole-file architecture rewrite occurred;
- injected DB, Keychain, MCP, and knowledge failures produce nonempty failed
  workflow state with stable trace;
- required/optionalApproved workflow behavior is durable and visible;
- the normal/failure previews prove UI/DB trace correlation without normal data;
- no P0/P1 finding, unknown failure, scope drift, or Open Question remains;
- fresh implementation review is `APPROVED — 0 P0 / 0 P1`; then a separate
  acceptance records R-05/R-06/R-07 and opens only bounded P1-C planning.

P1-B acceptance does not authorize P1-C implementation. P1-C requires its own
decision-complete leaf plan and responsibility-isolated plan review.

## 16. Red lines

1. No product/test/Package/script change before plan approval.
2. No empty/nil/false/default-success projection of business failure.
3. No optional continuation before atomic failure+degradation-row commit and
   synchronous in-process KernelEvent emission; no event commit or subscriber
   acknowledgment is claimed.
4. No downgrade of explicit MCP selection from required.
5. No provider/backend/tool dispatch after a required context failure.
6. No raw error, SQL, path, prompt, credential, account, callback, stderr, or
   external response in failure/degradation/event/UI/log evidence.
7. No `try?` for safety/integrity cleanup and no catch-and-ignore equivalent.
8. No AppStore whole-file move, Acceptance controller, OutcomeContract
   fabrication, v14+ schema, event-outbox/domain-event substitute, or P1-C+ work.
9. No change to Package.resolved, RunTests, dependency packages, normal data,
   historical A3/A4 evidence, or accepted A4 logs.
10. No commit, push, merge, release, real-user operation, or external action.

## 17. Open Questions

None. Any new question reopens `blocked.md` and stops implementation until a
bounded plan revision receives a fresh responsibility-isolated review with
zero P0/P1.
