# R13 Plan Freeze Evidence

> 状态：R13 Candidate Frozen；Review13 Pending；A2 Seam/Test Completion Frozen
>
> 日期：2026-07-27
>
> Owner：R13 planner

本证据只冻结牧场主原话“继续，授权”所批准的 completion-coverage planning
closure。没有实施产品/test代码，没有运行build/test/matrix/preview，没有创建
Review/acceptance，也没有执行Git写操作。

## 1. Authorization and bounded paths

R13只改：

1. canonical Stage §6.4.9；
2. canonical total Plan §3.3/§11；
3. A2 leaf §9/§10；
4. A2 `blocked.md`与P1两个执行控制索引；
5. 本freeze evidence。

R12-F canonical predecessor hashes为：

| Artifact | SHA-256 |
|---|---|
| Stage | `cfe8562d530052f08a645a07f91cf87875ccf50c1f9fe6d7580f28fccbafaaa9` |
| total Plan | `79c9252048697a84c395c5bbdad2bd68495f07fec4a9294c5b6937b02d8e02ab` |
| A2 leaf | `42ddb63dc73cd62514f09956b08378d397d146c2c5eba19c57a3950835bef2e3` |

## 2. R13 exact candidate

| Artifact | SHA-256 |
|---|---|
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `09e782f7fa3ba792a64f58d1f4db3cbbcfdcafa233d1efbb70b59c454c7e5f78` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `23593ea5954903d5c08498defbd08d7ca8f5ae7f0daa5c6063532bfefa6f4846` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `c1c245cf3f64a4e9f3c362853e53b077ced6c3b9d838f72474788d95799fb0b0` |
| A2 `blocked.md` | `1b8888f0355b54f0735f0c42baa547ac225a34cc92f8df5429aa5275f4abaca4` |
| P1 Stage control index | `6309b39cc364907b14339bd26c0a0cbf6becbe1cbad84a8a538eb2fe80b6b5bb` |
| P1 Plan control index | `842b5837e9bbf8ca764427134f19bff75e3ffc402a11fbeee304f8403ee3b830` |

## 3. Frozen closure

- release-absent matching-`#if DEBUG` package scenario seam，single armed、
  one-shot consume；
- exact `first|second` × 23 losses = 46 runtime cells；11 actor、10 durable、
  DB-read/invariant，且actorAttempt/durableAttempt分离；
- arm只接already-owned exact `RuminationPhaseIdentity`并内部捕获token/generation；
- first/second consume均在真实actor gate与真实DB validator成功后，consume只throw
  入既有catch，不直接拥有Store/validator/invalidator/fatal/sink/handler；
- #27/#35动态46格，#31 production callsites，#40 Supervisor端到端usage，
  #41 status-only/work-only/neither；
- `PlanningTestFixtures.uniqueFunction` masked unique enclosing range；
- exact Supervisor release object `nm -j | xcrun swift-demangle`零seam符号，DEBUG
  object反向存在，所有type/storage/helper/caller/test arm caller均guarded；
- 防伪禁止reflection/unsafe/SQL scenario/direct Store/sink/handler/test-local fake。

41 exact names、13+2 allowlist、schema/migration/DDL/EventKind、persistent phase、
callback、KernelEvent、Package/target/dependency graph均未改变。

## 4. Zero product/test drift during R13 planning

以下hash在R13规划编辑前后逐项相同：

| A2 allowlist file | Before = After SHA-256 |
|---|---|
| `Sources/AgentLoopCore/Work/DurableWork.swift` | `80fdb08592d0e48b09b64f4bd17db5f54019e35ef9b738907915d6c429aa61d6` |
| `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift` | `48fa9a04ec21f07c41b958e54433681c5099e31ed851f3b4ff6deb064aef07cf` |
| `Sources/AgentLoopCore/Database/DurableWorkStore.swift` | `f8842cbdde0bdb93c4139e59372cd897e8c091f79925a1cb9e18e8570ee954b5` |
| `Sources/AgentLoopCore/Database/AppDatabase.swift` | `147fac786fb877aae96423caa406af4f2d79c33f8298a164e9969cc518d558de` |
| `Sources/AgentLoopCore/Ingestion/IngestionRecords.swift` | `af5854b2545cf59f32ea8e216b7dc9d1e91b0387d2a8dda5e10030f3056f0d33` |
| `Sources/AgentLoopCore/Ingestion/FeedService.swift` | `2d5907a5cbeb23934025e3fad248de7c719e61935f34ca7a776c8a525fb0fdae` |
| `Sources/AgentLoopCore/Rumination/RuminationService.swift` | `e1adf999b7b4d4b69ca5530601d3363fc691074d3dc5b4342b9ba36a95faeb6e` |
| `Sources/AgentLoopCore/Rumination/RuminationParser.swift` | `80420d32709974fafcada2e6cb8cc71444792a2440c70c7901c514465ab1e8e3` |
| `Sources/AgentLoopCore/Kernel/Orchestrator.swift` | `b2f49eb3350aed0c1f03b574df5eadc09d5401b7c0a467ddc81e9af4819e87c2` |
| `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift` | `1bf853e7bcd2addf679cf55588c0ae45f2b0d6955dda1e966e8629f11818dcd2` |
| `Sources/AgentLoopApp/AppStore.swift` | `0b3a918ac539c5975e9aa9a6583e2c6f723039b0f243bba497368f4d9d1f6e33` |
| `Sources/AgentLoopApp/CodingRanchContracts.swift` | `d0d769d025d5927485e833d327abb2c6b36fb5444a56a3c250dc11cea1448a6d` |
| `Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift` | `54950383569ee7b0965364eda8a6402277e2c7f251aeab7de4f68340a4f97e34` |
| `Sources/AgentLoopTestSuite/CodingRanchTests.swift` | `13733b134cf80a63415ade04fa5ec407de3b7930b0ec7c31bb78c6e04132597a` |
| `Sources/AgentLoopTestSuite/DurableWorkTests.swift` | `893944ff1266cd94d0cf2ddba15840719415596bc25e8b39415b205f3e54c346` |

## 5. Immutable history and control delta

| Artifact | SHA-256 / result |
|---|---|
| R12-F freeze evidence | `d88c14815b08aaa9187ae4053b33c8bfa45b1b03b0f2d2d61adf24e76bebbf41` |
| immutable Review12C | `db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109` |
| matrix script | `187da197ea4b0c80e1e437a6b5c576216f7c3491696c45b0f9104a9197401467`；R13 planner未修改 |

matrix script仍保留R12-A的单值control历史；Review13批准后，post-R13完整matrix前
只可按既有R12-A规则机械同步其唯一`expected_stage_hash` value并保存restoration
proof，不得改任何其他byte。本freeze没有运行matrix。

## 6. Next gate

下一步只能执行职责隔离Review13。其判定
`APPROVED — 0 P0 / 0 P1`前，禁止seam/test implementation、A2 implementation
Review/acceptance、A3、commit、push、merge、release、normal-data access/reset、
外部操作与真实用户操作。
