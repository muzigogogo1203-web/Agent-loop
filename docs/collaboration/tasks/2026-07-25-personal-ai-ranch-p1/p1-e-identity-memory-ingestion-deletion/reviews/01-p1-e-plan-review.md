# P1-E Plan Review — Review01

> Date: 2026-08-26  
> Reviewer: current Codex implementation owner, fresh read-only pass  
> Process disclosure: the user explicitly directed Codex to proceed without
> Claude and without delegated agents; this is a same-agent self-review and is
> not represented as independent  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

approved_plan_sha256=b47d9307fee24395d58b6440131b9948dd61ec5981aaf25700534aba620b4f8e
approved_allowlist_sha256=ab95ea1f33ff41de6819f32602ac5fe0bf5988085bb6cfed9a2a8819687ecb60

## 1. Review scope and authority

I reviewed the exact 790-line Revision 1 plan and exact 88-line machine
allowlist against:

- accepted master spec §§5–7, 22–24, and 29;
- canonical P1 stage §§14–15, 18.6, 19, 26–27, and the P1-E completion gate;
- canonical P1 plan §§7, 10, and 11, including the sealed R6-P1-1 ordinary
  Ingestion deletion contract;
- accepted P1-D plan/revisions/review/acceptance and current implementation;
- current Package target direction, GRDB 7.11.1 public API, source call sites,
  current legacy archive UI, and the complete dirty-worktree boundary.

Authority hashes independently match:

| Input | SHA-256 |
|---|---|
| Stage | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| Canonical P1 plan | `d499111f168e52a82485d70fd8aa412f34f8db92597d7c8dca3c22b68b24d18f` |
| Master spec | `5f942e58745500925c90405460a9bbd161dd07389d7e4d0ee10e156b374d4b4a` |
| P1-D acceptance | `bef50bba0f5baf6d0fbe4a194b97b1fe05c247ba211dc6f111cf145b5c7566bd` |
| Package.resolved | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| RunTests | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |

The Stage §18.6 SQL extraction independently produces 1,998 lines, 80,830
bytes, and SHA-256
`3a86de973a0feff2a5a26bbd6d721464382f6cd13c667b062501808a5325fd71`.
The plan fixes one runtime literal and one exact split before the four late
surviving-table trigger drops, so typed legacy-scope resolution and its
count/FK barrier occur before any late drop, with no DML afterward. This closes
the otherwise blocking mismatch between the normative SQL body and the
required exhaustive Swift resolver.

## 2. Scope and entry evidence

The machine allowlist has 88 nonblank unique paths: 67
product/test/Package/matrix paths and 21 task artifacts. Programmatic extraction
of canonical plan §7.1 yields 66 paths; all 66 are present with no omission.
The sole derived carrier is `Sources/AgentLoopApp/Views/RootView.swift`, which
is necessary because current product code still displays two callers of the
legacy `setCampArchived` route. Its plan-limited change is only removal of
those controls; the Core compatibility method becomes mutation-incapable in
release. This is required to honor E's explicit “retirement not exposed” gate
without pulling F2 into E.

The 24 exact new source/test paths are absent. The 43 existing allowlisted
pre-images are:

| File | SHA-256 |
|---|---|
| `Package.swift` | `b55b600fc7489aca6bc4e305ea968ac5c9d9e438b4b70be48bf47527e445b99c` |
| `Sources/AgentLoopCore/Database/AppDatabase.swift` | `8f33661c321109096f11646e6ccefc4458c5b5887e4e903d89593c34ab1a8c34` |
| `Sources/AgentLoopCore/Database/Records.swift` | `017f43c4d8976c763872c438d20975238d9329caab89f540a0d52e6fa3aa2543` |
| `Sources/AgentLoopCore/Database/EventKind.swift` | `67ca50ba59b0ec191a3543e7af5a39164e644909219a6b621a929d084991c117` |
| `Sources/AgentLoopCore/Database/DurableWorkStore.swift` | `71e2dd602cf59647fd9dc5c0bd5a74eeb770f6b4d91010744c4a40b91ae28b6e` |
| `Sources/AgentLoopCore/Database/KnowledgeStore.swift` | `1b97a0495576d0556cdab26e01edcfc516facaa35bd0659d7dd1bc2c9a291a24` |
| `Sources/AgentLoopCore/Database/OutcomeStore.swift` | `f44189917f456f8d72930765e6354f650fbb76f48ae075e696bcd9d721d10d87` |
| `Sources/AgentLoopCore/Database/DomainEventStore.swift` | `662fcc1f51b7a56c2989608c6bea7a5b3748f207dd29d25660d32301f82c24a9` |
| `Sources/AgentLoopCore/Ingestion/IngestionRecords.swift` | `af5854b2545cf59f32ea8e216b7dc9d1e91b0387d2a8dda5e10030f3056f0d33` |
| `Sources/AgentLoopCore/Ingestion/FeedService.swift` | `2d5907a5cbeb23934025e3fad248de7c719e61935f34ca7a776c8a525fb0fdae` |
| `Sources/AgentLoopCore/Rumination/RuminationService.swift` | `e1adf999b7b4d4b69ca5530601d3363fc691074d3dc5b4342b9ba36a95faeb6e` |
| `Sources/AgentLoopCore/Rumination/RuminationMaterializer.swift` | `f0cd523ddf43789a9b0485bbcd0ee7b860b43a129795e06b1483c077d522623f` |
| `Sources/AgentLoopCore/Product/ProductBootstrapService.swift` | `8abad506040a4b23bf118400a5785d55ceb91422d2af696f265e7eff181847c7` |
| `Sources/AgentLoopCore/Product/NewcomerUnlockPolicy.swift` | `7d15795307928e81d93e1edacff747e75446e523deb6c4449b7cf99b1575908e` |
| `Sources/AgentLoopCore/Product/CowTemplate.swift` | `2915317b77511ffaf99ea2180a5788cb6e29f4cbfd894b00937d30b58f6c647b` |
| `Sources/AgentLoopCore/Chat/GuideChatService.swift` | `849d026abe5ec6b5223885f5a5bbd650db84110514ab6e114370b9ef67392b55` |
| `Sources/AgentLoopCore/Chat/ChatService.swift` | `f1eb56555be9a9a57bffe726ee2514c5205d1f675edf484cbc98b2da44a96b77` |
| `Sources/AgentLoopCore/Knowledge/MemoryDistillService.swift` | `c2c4131edd309c9a153f950d90c5527eff9857ac6cf1df61de4e0abccc4151bc` |
| `Sources/AgentLoopCore/Knowledge/Distiller.swift` | `2452db81bedd9d3aa89e903046d20473e7bd9c0e178052fc829202de0e477ac5` |
| `Sources/AgentLoopCore/Kernel/Orchestrator.swift` | `b3818ceb5ce33c736a035027d8fa70380885406df249cd8c4c2498e1636483ca` |
| `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift` | `e4efbd3679549cb3db6d87aa7a1272c7b200ba5ac35781a2d626b7e1b75beaae` |
| `Sources/AgentLoopApplication/InputWorkflowController.swift` | `0021a0cb8b5d80624cc5bd49fd5d96cc96202bf8da73d3c911e2d5453aeca17f` |
| `Sources/AgentLoopApp/AppStore.swift` | `84bbf8d84a100af0e958c6ee74d312affa8aed65dbccaf3dc166b31148be4c4d` |
| `Sources/AgentLoopApp/CodingRanchContracts.swift` | `93e925354509f897722d0b7572ff6baa3be9c65f2c45245f1e6f17348dc0f9e0` |
| `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift` | `b9ca45a48bae38345f37a7011ca9b2bf7ce052697d944a4ecacc93f5adc81e69` |
| `Sources/AgentLoopApp/Views/RootView.swift` | `558c49ea0379e4e6b3c16e379b45f26a9bd92136094d128797b925228c3511cd` |
| `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift` | `51e126316e9a058344bbbf01b99e5960a88fc3f7a99e4fdf0ac307648f6474d4` |
| `Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift` | `54950383569ee7b0965364eda8a6402277e2c7f251aeab7de4f68340a4f97e34` |
| `Sources/P1MigrationMatrixRunner/main.swift` | `2c3f66a42504b0273968ac902834136164c150cf2acf7b2cb6f1ddacf6c0cb00` |
| `scripts/verify-p1-migrations-sqlite-matrix.sh` | `1beee980f7a5cdf284a96b1cd8d587cf0748d16614de39ac547545a829cf84e9` |
| `Sources/AgentLoopTestSuite/MultiCampTests.swift` | `ba36076929dfd26d2c4281203eb94400dbad8b56ddf44cda4ced60d395171b25` |
| `Sources/AgentLoopTestSuite/KnowledgeStoreTests.swift` | `eec31a29b1b5724f6de4b8c8f05da1d513681bc45a50432e5448b65287bca043` |
| `Sources/AgentLoopTestSuite/KnowledgeGoldenPathTests.swift` | `9d5e2828e320af54b79dadefa451e4a4b61337f447bfe9ae212032197d7aacb4` |
| `Sources/AgentLoopTestSuite/OutcomeContractTests.swift` | `099e39c411c12d275608a2d72ba2e55743308a6c05058d8d2a7ad7788b18344f` |
| `Sources/AgentLoopTestSuite/DomainEventContractTests.swift` | `c05a7736b49dee3b83229f4777cca5928d6555ffa1e2f931a70551a0e96d4aec` |
| `Sources/AgentLoopTestSuite/VerificationContractTests.swift` | `03c5996d1c737f7a2a9a44f626bfbc4f01bde01ccb5d9530feb365d36c0ad805` |
| `Sources/AgentLoopTestSuite/DatabaseTests.swift` | `323c67f00de83e68348b52a5299cd8b47ae9046f4e224788a0efab6cda1b1727` |
| `Sources/AgentLoopTestSuite/DurableWorkTests.swift` | `061b23b239592ae7f6803ef3174c5ade2f29f73193781f621f8b16643669b3ad` |
| `Sources/AgentLoopTestSuite/ChatServiceTests.swift` | `af4d27e21cdb9b5b54a78eecf3cf6d5b6870c85b8f51e390ace57ac54f28f953` |
| `Sources/AgentLoopTestSuite/GuideChatTests.swift` | `6b6150e00bf826fa98ae9eafbb5735735af81ed39fa64d05cd8628022329e7c7` |
| `Sources/AgentLoopTestSuite/MemoryDistillTests.swift` | `c6abc9357f787e1adfe65e4b47af308f809d4ce3fed338ef374f81cfceb33bc2` |
| `Sources/AgentLoopTestSuite/DistillerTests.swift` | `b6592325963aad0a4ef4c1460e908f6ce0138473b7582fc559b52edfc222930d` |
| `Sources/AgentLoopTestSuite/CodingRanchTests.swift` | `ee72549cd4c36880f7c99f881d558f16d81dd606cc94031a340f3b54db168cfd` |

The exact NUL-safe serializer was rerun from `scope-allowlist.txt`:

```text
dirty_total=549
allowlisted_present_count=42
outside_count=507
outside_manifest_v1=7fc97d0d47c192d888e752d6c8669c4a99bcddc09d32c1d904f0d3868d0ac242
```

Adding this review changes only the first two counts. The outside count and
manifest remain the implementation boundary. `git diff --check` passes.

## 3. Architecture and feasibility review

### Migration and SQLite lifecycle

- The plan preserves the full v16 literal while placing all typed scope
  backfill and assertions before the late-drop/trigger suffix.
- It fixes the 79-table/208-index/67-trigger checkpoint, predecessor fixtures,
  v15 rollback snapshot, poison-row rejection, child-FK final names, and
  archived work closure in E1 rather than deferring matrix work.
- Local GRDB 7.11.1 exposes `Configuration.prepareDatabase`,
  `Database.sqliteConnection`, `Database.afterNextTransaction`, and
  `DatabasePool.writeWithoutTransaction`. Its package exposes the existing
  `GRDBSQLite` product, so the one direct Core dependency is feasible without
  changing the resolved revision.
- Registry construction-before-pool, unlocked raw registration, provisional
  reconcile, exact xDestroy ownership, writer/resolver role split, sticky
  mismatch, BUSY/zombie/reuse scenarios, and 53/63 UDF contracts have one
  named owner and executable tests.

### Identity, lifecycle, and Memory

- Migration backfill and post-v16 creation both create Cow/lifecycle/residency
  truth; nil Camp remains no authority.
- Active residency and exact bridge authorization replace UI/global filtering;
  inactive access throws typed.
- Only E-owned writes consume the active Camp fence. Retirement tables are
  schema-ready, while current archive UI is removed and no F2 command/worker is
  introduced.
- Memory has one writer, exact carriers/provenance, accepted-Outcome skill
  evidence, append-only dependencies, and required atomic participation in
  P1-D invalidation. There is no optional Growth hook.

### Scope and provider durability

- The plan resolves all 45 accepted legacy event kinds with no default and
  converts the old append name into a typed funnel, avoiding a broad edit to
  already-scoped historical call sites while still closing raw insertion.
- Domain-event scope, content scope, Guide/Camp provider checkpoints, returned
  replay, lifecycle races, global routes, and unknown external writes have
  explicit owners and tests.
- No service-held unregistered provider/task authority is retained for the
  canonical Camp routes.

### Ordinary Ingestion deletion and UI truth

- Caller facts cannot create a command. One Store owns prepare, execute,
  resolution, evidence, permit, validator, and physical mutations.
- The two legal scopes, three affected counts, five fixed-zero blockers,
  receipt/event/outbox graph, replay ordering, exact JSON privacy, raw guards,
  transaction generation, and typed resolution are all frozen.
- The 90-test manifest covers the original four P0 counterexamples, every
  lifecycle/row/blocker TOCTOU class, raw UDF lifecycle, graph forgery/relaunch,
  worker races, and all four UI phases.
- UI failure injection is DEBUG/release-zero, exact preview-mode only, and
  exposes no mutation or raw SQLite capability. It provides real isolated-app
  evidence without normal state or external provider use.

## 4. Boundary and red-line review

The plan contains no placeholder, unresolved product choice, external
authority, destructive action, or hidden later-stage dependency. It explicitly
forbids v17/F1/F2-only implementation, Camp retirement commands/worker/UI,
candidate/link deletion, generic mutation callbacks, global/cross-connection
permit fallback, relaxed CLI UDF, swallowed errors, optimistic navigation, and
normal-state preview.

The five bands preserve TDD ordering while remaining one P1-E acceptance leaf.
Each has an immutable red log and stop condition. Full tests, build, dual
SQLite matrix, source/scope gate, isolated UI evidence, report, Review02, and
acceptance are all mandatory.

## 5. Findings and decision

- P0: 0
- P1: 0

The exact P1-E plan is decision-complete and the E1 test gate may open. E2–E5
product changes remain closed behind their preceding preserved red/green band
gates.

verdict=APPROVED — 0 P0 / 0 P1
