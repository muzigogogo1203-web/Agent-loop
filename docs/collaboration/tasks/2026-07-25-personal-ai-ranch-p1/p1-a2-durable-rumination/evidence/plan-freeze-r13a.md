# R13A Plan Freeze Evidence

> 状态：R13A Candidate Frozen；Review13A Pending；A2 Seam/Test Completion Frozen
>
> 日期：2026-07-27
>
> Owner：R13A planner

本证据只关闭immutable Review13的唯一P1-01 current-gate split。没有改变R13 seam
合同、2×23矩阵、41 names、13+2 allowlist、schema/API/event/package边界、产品/
test/script或任何旧Review；没有运行build/test/matrix/preview或Git写操作。

## 1. Immutable predecessors

| Artifact | SHA-256 / verdict |
|---|---|
| R13 freeze evidence | `9bcfd9a6a430899bb51e164121e48ae7fb23f8e8454694b47ea30fcf7d6132d0` |
| R13 Stage | `09e782f7fa3ba792a64f58d1f4db3cbbcfdcafa233d1efbb70b59c454c7e5f78` |
| R13 total Plan | `23593ea5954903d5c08498defbd08d7ca8f5ae7f0daa5c6063532bfefa6f4846` |
| R13 A2 leaf | `c1c245cf3f64a4e9f3c362853e53b077ced6c3b9d838f72474788d95799fb0b0` |
| immutable Review13 | `5203057f2a4a7f04827d9f5e0f20b717e08a31125404483b11f5cad722bda66b`；`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2` |

Review12C继续只作为R12-F approved historical predecessor；Review13继续只作为R13
changes-required historical predecessor。两份Review均未修改。

## 2. Exact R13A candidate

| Artifact | SHA-256 |
|---|---|
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `2382ac752807e2a36dbb6de834636a9858c539d5e19c607608af55094fdb2626` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `4564896993dad717f0150800f918133fd7c17508e3c57cfb941a322e49d46908` |
| A2 `blocked.md` | `93163448339d4838ae0e3cdaf1a831fd678cfa5f644e2429e15adaad24677d80` |
| P1 Stage control index | `79472bed53d9ece376511f5fac6becc05de329878f62d2e96700c17fd2d2662b` |
| P1 Plan control index | `07d39f51f9a2ebe32b3618e12f65b43abb1f3c32b7e0d53b83172f27ae2568f1` |

## 3. Bounded gate synchronization

- 三份canonical header统一为R13A Candidate/Review13A Pending；
- Stage当前redline只允许Review13A在本证据exact hashes上开门；
- total Plan §3.3/§11的current entry、review writer与implementation opening只指向
  Review13A及`reviews/13a-p1-plan-review.md`；
- leaf §1/§10/§12的current evidence、stop、验证前置与完成门只指向Review13A；
- Review12C/Review13只出现在明确的immutable historical predecessor语境或历史
  appendix，不再拥有当前implementation-opening authority。

R13A未修改Stage §6.4.9 seam合同、total Plan R13 matrix/gates或leaf §9 matrix
内容。

## 4. Zero product/test drift

R13A前后以下15个allowlist hashes逐项相同：

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

matrix script保持R13时的
`187da197ea4b0c80e1e437a6b5c576216f7c3491696c45b0f9104a9197401467`；
R13A未修改。

## 5. Next gate

下一职责隔离reviewer只能写
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/13a-p1-plan-review.md`。
Review13A达到`APPROVED — 0 P0 / 0 P1`前，DEBUG seam、测试、其他产品代码实施、
A2 implementation Review/acceptance、A3与全部既有Git/发布/normal-data/外部权限
继续关闭。
