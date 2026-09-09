# R13B Control Freeze Evidence

> 状态：R13B Control Candidate Frozen；Review13B Pending；A2 Seam/Test Completion Frozen
>
> 日期：2026-07-27
>
> Owner：R13B control planner

本证据只关闭 immutable Review13A 的同根 P1-01：旧 Review12C 开门文字仍被三个
control surfaces 表述为 current。R13B 未修改 canonical Stage、总 Plan、A2 leaf、
产品/test、matrix script、旧 freeze 或旧 Review。

## 1. Immutable R13A canonical

| Artifact | SHA-256 |
|---|---|
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `2382ac752807e2a36dbb6de834636a9858c539d5e19c607608af55094fdb2626` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `4564896993dad717f0150800f918133fd7c17508e3c57cfb941a322e49d46908` |

R13B 没有改变 release-absent DEBUG seam、`first|second` × 23 = 46 matrix、
#27/#31/#35/#40/#41、`PlanningTestFixtures.uniqueFunction`、release `nm`、
41 names、13+2 allowlist、schema/migration/DDL/EventKind、callback/KernelEvent
或 target/package graph。

## 2. R13B exact control candidate

| Artifact | SHA-256 |
|---|---|
| A2 `blocked.md` | `07f0442af08f4198ac5e48e0f66fdf8eb227ed1fb0c2c80179f6c19b0b0207b1` |
| P1 Stage control index | `dd79876ee754fd4cea46da18f7043871b4d0cbafa43e2b301a6a73de68e12da1` |
| P1 Plan control index | `6024f7fb1fc92f94a6bfc00c5d72e907771bb059c2ce3c1219a13d7f60abdba0` |

唯一 current 状态是
`R13B Control Candidate Frozen；Review13B Pending；A2 Seam/Test Completion Frozen`，
唯一 next-review artifact 是
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/13b-p1-plan-review.md`。
Review12C 的开门只保留为 historical past；pre-R13 绿色 evidence 不构成当前实施
授权。

## 3. Immutable predecessor evidence

| Artifact | SHA-256 |
|---|---|
| R13 freeze | `9bcfd9a6a430899bb51e164121e48ae7fb23f8e8454694b47ea30fcf7d6132d0` |
| Review13 | `5203057f2a4a7f04827d9f5e0f20b717e08a31125404483b11f5cad722bda66b` |
| R13A freeze | `a79e577ecb14978fd5097ce05d9c012711427ea50d3b16ce9ea2b67e57691138` |
| Review13A | `edfb632ce1af2514dfe3168f87e0506fffe3a116f9cd6d3a427874933d399580` |
| R12-F freeze | `d88c14815b08aaa9187ae4053b33c8bfa45b1b03b0f2d2d61adf24e76bebbf41` |
| Review12C | `db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109` |
| matrix script | `187da197ea4b0c80e1e437a6b5c576216f7c3491696c45b0f9104a9197401467` |

## 4. Product/test zero drift

| Artifact | Before = After SHA-256 |
|---|---|
| `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift` | `48fa9a04ec21f07c41b958e54433681c5099e31ed851f3b4ff6deb064aef07cf` |
| `Sources/AgentLoopTestSuite/CodingRanchTests.swift` | `13733b134cf80a63415ade04fa5ec407de3b7930b0ec7c31bb78c6e04132597a` |
| `Sources/AgentLoopTestSuite/DurableWorkTests.swift` | `893944ff1266cd94d0cf2ddba15840719415596bc25e8b39415b205f3e54c346` |
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |

完整 15 项 allowlist 与 immutable source/package sentinel 继续由
`plan-freeze-r13a.md` 的逐项 manifest 约束；R13B 只复核上述最可能漂移的实现入口，
没有运行 build/test/matrix/preview。

## 5. Next gate

下一步只能由未参与 R13B control 同步的职责隔离 reviewer 写
`reviews/13b-p1-plan-review.md`。其判定
`APPROVED — 0 P0 / 0 P1`前，禁止 DEBUG seam、#27/#31/#35/#40/#41、其他产品代码、
完整验证、A2 implementation Review/acceptance、A3、commit、push、merge、release、
normal-data access/reset、外部操作与真实用户操作。
