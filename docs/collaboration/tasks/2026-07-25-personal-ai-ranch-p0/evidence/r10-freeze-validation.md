# R10 Durable Planning 修订与冻结证据

> 日期：2026-07-26
>
> 状态：R10 Candidate Frozen；Review10 Pending；A1b Product/Test Code Frozen

## 1. 授权与边界

牧场主明确回复“授权 R10”。本轮授权只用于：

1. 按 A1b `blocked.md` 的 R10-1…R10-7 有界修订 Stage §6.2.2/§6.3 与总 Plan
   §3.2/§10/§11；
2. 建立可执行 A1b leaf Plan；
3. 复算 hashes、更新 freeze/control evidence；
4. 由未参与修订的 reviewer执行职责隔离 Review10。

Review10 零 P0/P1 前，产品、测试、A1b acceptance、A2、commit、push、merge、
release、数据重置、外部操作和真实用户操作继续关闭。

本文件是 planner freeze evidence，**不是 Review10、implementation Review或
acceptance**。

## 2. 基线

| 输入 | R10 前 SHA-256 |
|---|---|
| Stage | `330dfd6de888e3cca14927cb9d82d5d4b1e1b7057b2814736fa923e2a2df0190` |
| P1 总 Plan | `19e57761a9da3b11905ce72cb40e0e5c1a7bbcec1cb5f9462ef1cb1260da6ee3` |
| A1a leaf Plan | `4fc04f2c6c7a3dd67db71874f7d86807fa7882d566a64fe76c60cb3722593deb` |
| A1a acceptance | `070a2b6815ef85323d1041d3023ebc28ec5f98737513746ec9bdf961183a0032` |
| A1b blocker | `289a133dd31f8969d0ddcb57c3b08ffaeadb4d475b232c875269c321729a6bb1` |
| pre-R10 feasibility | `26465e6295993421f42791a46e0ab386b8f463bb3a4c1c03ac08f8309876c50e` |

进入 branch/HEAD：

```text
branch=codex/personal-ai-ranch-p0
HEAD=02334ec8d21533be81d93d39191bc7d9b9c24f7f
```

Worktree 在 R10 前已经包含 P0/P1/A1a 的已授权长期差异；R10 没有回滚或接管这些
既存用户差异。

## 3. R10 新冻结 hashes

| 文档 | SHA-256 |
|---|---|
| `p1-stage-spec.md` | `36420de83e30043665c72d8ad8f0cf6ed98e930df296327c9f2d19bc9a72e62e` |
| `p1-plan.md` | `e89f7e972f665a49f1bd07bd4921ad86e6ce595429344718639ef0688f8b32af` |
| A1b leaf `plan.md` | `bb5aa2cd5e7eb7e0cfcbd472b63382d4e5d0a0afd6d4e195737772e82f8c35be` |

三份文档顶部均为 `R10 Candidate Frozen；Review10 Pending`；Stage §28、总 Plan
§18 与 leaf §16 的 Open Questions 均精确为“无。”。

## 4. R10-1…R10-7 闭包

| Blocker | 冻结结果 |
|---|---|
| R10-1 matrix allowlist | A1b test-only allowlist加入runner/script；named `v12-durable`在SQLite 3.51/3.52两条真实GRDB linked lane close/reopen/replay；不改DDL/literal/A1a verdict/Package |
| R10-2 key/trace来源 | `startMission` required profile/key/trace；manual/candidate/schedule/proposal四入口精确key；manual增加process-local pending command生命周期 |
| R10-3 immutable identity | `MissionPlanningStartIdentityV1` canonical首写到唯一`mission_created`；replay验证identity/input/hash/graph；首次trace权威 |
| R10-4 resolver owner | enqueue required同一个resolver；durable/local gate → replay-first → absent-only preflight → transaction kind/mode recheck → kick |
| R10-5 fallback | nil不写fallback event；non-nil success command零写，并由deterministic failure owner以同一个exact usage收口 |
| R10-6 Supervisor/halt | independent suppressed gate、mode-aware legacy repair、adoption、restored-halt bulk cleanup、transaction durable gate、fatal/pending matrix、resume ordering、late callback和bounded shutdown |
| R10-7 usage overflow | typed same-origin failure、negative usage、turn/projection exact evidence、special terminal path、`>2^53`/multi-field/invalid-shape tests；无nil/saturation/prefix/Double |

## 5. 冻结前对抗审计

冻结前另做了未写文件的 adversarial audit。它最初把“repair/adopt 在 mode read前
写入”标为候选 R10-8。该问题最终在 **R10-6 同一 restored-halt 根因**内闭合，没有
新增产品方向：

- 每个 workless legacy Mission transaction先读取 exact durable mode；
- halted使用`LegacyPlanningTerminalInputV1`，创建queued attempt=0 work并在同一
  transaction复用queued cancel primitive，以
  `emergency_halt_during_planning`收口；
- running才创建queued repair或exact `legacy_planning_*` terminal；
- mode read是线性化点；running下已提交terminal事实先于后来的halt，不能被改写；
- interrupted adoption仍在suppressed下执行，restored halted随后以一个bulk
  transaction收口全部其余active planning；
- 新增static halted、running-vs-concurrent-halt与attempt=0 atomic tests。

复核结论是该矛盾已关闭，不构成独立R10-8。同期发现的fatal/pending分类、manual
retry生命周期、proposal越界承诺、逐race/overflow测试、negative source sentinel与
preview证据问题也均在对应R10-2/R10-6/R10-7范围内关闭。冻结前最终只读审计为
0 P0 / 0 P1；它不替代Review10。

## 6. 产品、测试与 Package 冻结指纹

R10 文档修订没有修改以下A1b生产/test-only/Package路径。生产基线：

| 路径 | SHA-256 / 状态 |
|---|---|
| `Sources/AgentLoopCore/Database/AppDatabase.swift` | `faf98fa6b1f252d0e58bd463b46cbdc98753324a880357901aeaca07361756ac` |
| `Sources/AgentLoopCore/Database/EventKind.swift` | `a3705837724a27beeb9f372fccafc7e61d3b0f9b98bd853bd6b4e3750b4ba52a` |
| `Sources/AgentLoopCore/Kernel/Orchestrator.swift` | `c0967ba6a78c7e5818e65d7991f21dee4f4ff5de952e5ec6509fcba3b109b329` |
| `Sources/AgentLoopCore/Kernel/Planner.swift` | `9d7a6cb233e3f310df9f34dc8199e9b26e81d066fb07d54e570e93c448c43d98` |
| `Sources/AgentLoopCore/Provider/LLMProvider.swift` | `9bbfde860060837b959670d6a986a65810ea025c870ef566168e1ffce40efb4b` |
| `Sources/AgentLoopCore/Work/DurableWork.swift` | `694e922ef582ea1551dfcb78ec7544a191967dda980a4f2b82852fa62b20bbb2` |
| `Sources/AgentLoopCore/Database/DurableWorkStore.swift` | `68098d8e4f977a3591826772a737f2e67a2070f1eebf5fa8d18b8172b192f07b` |
| `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift` | `ABSENT` |
| `Sources/AgentLoopCore/Work/PlanningProviderResolver.swift` | `ABSENT` |
| `Sources/AgentLoopApp/AppStore.swift` | `1c1e48a5ca6dad0a8080f1365057bbe35377cfb2d3d117d2c8be9d0db8e89153` |
| `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift` | `603935ca0a628f794f95c420e50098bbf54494ad52ff0b66dbe3ec10d7f13cf7` |
| `Sources/AgentLoopApp/MissionScheduler.swift` | `1c5998aac4ae81eba29c0d5639b74527523794a2bf231af8b72e787f38afbf8a` |

Existing tests：

| 路径 | SHA-256 |
|---|---|
| `AskUserTests.swift` | `1d4cb2ae0c4e92f4d70cbf0bced2aa25bfbe709a4fc1de9f39168292ef8574bd` |
| `BudgetTests.swift` | `7343a28e1c8bd0733a6fc457b850fe5a1486589534c83a06c308fdf52cd986f1` |
| `CrashRecoveryTests.swift` | `04596497591a5e7085762ee1e3cbcb18200a03433e7dd9540368ade0abdf7060` |
| `DatabaseTests.swift` | `bb35ad60d06e418afe62f261493535a57545a7fb37dda2db049a763150ea6c56` |
| `GoldenPathTests.swift` | `359e6b6076133987901984d5934b8d52875b1199762f1b1e22b30af5fce7fc87` |
| `GuideChatTests.swift` | `aa89913441bd1d49572926cc03b99a4df691f1123f227eae5d5191c4ce7eabca` |
| `HaltAndCooldownTests.swift` | `42f977735ce3a094cd27619f4a4dc352165ff428974879504653538e860bf37e` |
| `HarvestTests.swift` | `12a3e3780b8ca0f8f2533278d2800d65f81df735a1df415e5df42f8eace2e4ce` |
| `KnowledgeGoldenPathTests.swift` | `6d643e732c7759fea28e07e3e1ae0aa1b09276524b8da2ca96a1c81e53c4e369` |
| `McpTests.swift` | `964a41c8e6b20ae647efb314ca4e3990f0bbb1b0c3fda60cd8218f53ffdf2494` |
| `MultiCampTests.swift` | `7162e1a1706040d28ace363d9a2f14013342c16914ac91bd9eb9a42c57dda92a` |
| `OrchestratorTests.swift` | `f2d5768dc3685cde5d5fd8853fec39a0e2947564e7d87a4d723c6a4d528dd4cf` |
| `PlannerTests.swift` | `68c6526b4fa4a37b95eda074abea42380d78fdd77be9094edd592d6b36048001` |
| `PlanningTokensTests.swift` | `2b361402c8bb2e990de7a72e1bc169b45b14df21cd66eee05480285347d1f524` |
| `RuntimeProfileTests.swift` | `4999ae3cca1660e84bcb9684bdda75dd14bfbd12676162913629fdd40f55071a` |
| `ScheduleTests.swift` | `c2573a0e9949af56de9b763f7b3b29d22459cbb738767d4e313bd6ae9993e7ce` |
| `DurableWorkTests.swift` | `cc7a14046193664e7d9886ead85e8a185a4ae2bad409c359fcb5bcf7d874bbaf` |

New A1b test files `DurablePlanningTests.swift` 与 `PlanningTestFixtures.swift`均
`ABSENT`。

Test-only/Package：

| 路径 | SHA-256 |
|---|---|
| `Sources/P1MigrationMatrixRunner/main.swift` | `dddd1ef320ca591493387f7f90f9be4d1b663f141821fd9bc6e80f49551bf8c5` |
| `scripts/verify-p1-migrations-sqlite-matrix.sh` | `41777ea24e60914734fa4e9c2fbe9bd334cf2bcd1dbbd9abd10494984d470c56` |
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |

## 7. 结构与 hygiene

冻结时：

```text
Stage fences=42 balanced=true trailing-whitespace=0
Plan fences=16 balanced=true trailing-whitespace=0
A1b leaf fences=32 balanced=true trailing-whitespace=0
git diff --check=passed
```

本轮没有运行产品tests/build/matrix/preview，因为Review10前它们仍处于代码冻结门；
本文件不把A1a历史结果冒充A1b验证。

## 8. Review10 门

Review10必须由未参与R10修订的reviewer完成，且唯一写入为：

`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/10-p1-plan-review.md`

Reviewer必须：

1. 复算三份candidate hashes与A1a acceptance hash；
2. 对照R10-1…R10-7及本文件的adversarial closure；
3. 检查API shape、same-key replay、mode-aware legacy repair、fatal/pending owner、
   manual lifecycle、fallback/usage exactness、Supervisor halt/shutdown；
4. 检查Candidate/Schedule/A2边界和allowlist；
5. 复算产品/test fingerprints，确认Review10前零代码变化；
6. 给出exact P0/P1 verdict。

零P0/P1才打开A1b implementation；任何finding都重新关闭实施并回到有界修订。
