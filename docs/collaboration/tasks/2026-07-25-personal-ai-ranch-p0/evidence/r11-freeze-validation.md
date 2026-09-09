# R11 有界修订与 Candidate 冻结证据

> 日期：2026-07-27
>
> 分支：`codex/personal-ai-ranch-p0`
>
> HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> 状态：R11 Candidate Frozen；Review11 Pending；A1b Product/Test Code Frozen

## 1. Authority 与边界

牧场主已明确“授权 R11”。本轮只按
`p1-a1b-durable-planning/blocked.md` §8–§10 的四个 implementation-discovered
根因有界修订三份 canonical 规划文件、两个 P1 execution index、本冻结证据与
blocker 状态；未修改 master spec、A1a、旧 R10/R10A evidence/review、产品、
测试、migration、Package、runner/script 或 RunTests。

Review11 判定 `APPROVED — 0 P0 / 0 P1` 前，A1b 产品/测试实施、产品 test/build/
matrix/preview、implementation Review、acceptance、A2、commit、push、merge、
release、数据操作、外部沟通与真实用户动作继续禁止。

进入 R11 前的 canonical hashes：

| 文档 | SHA-256 |
|---|---|
| Stage | `d05452fd0a877fb03e94ff0e1a75a0efa3b095c93c14ff856c79da04619db3a6` |
| 总 Plan | `b14c145c433a03606c925d5f027d7a3a25d458b07a2a5bb447a29424cce58a61` |
| A1b leaf | `cf1b603c2147a2cb2619a5230ff3b71a41b2968f78e0c3e28480da09460feb0e` |

历史 pre-R11 map 保持 pre-authorization 原字节，SHA-256：
`7b01d323faa6b330c83689e9eb0e42a26de8447d6301a3147219b30f7e4b5cb5`。
预冻结审计发现 Stage §6.2 lifecycle 枚举、leaf §4 与 §5.5、三份 status header
是同根一致性锚点后，只在当前 controlling `blocked.md` §10 记录窄边界；没有回写
历史 map。

## 2. 四个 R11 根因的冻结闭包

1. Schedule：
   - A1b production allowlist 只增加 `ScheduleStore.swift`；
   - `lastFiredAt` 新写入使用 numeric epoch seconds，decoder 保持
     `.deferredToDate`，兼容 legacy TEXT 与 INTEGER/REAL；
   - non-finite Date 在 UUID、runtime selection、preparation Result 与 claim 前
     fail fast且完整零写；
   - finite milliseconds overflow 继续 `Result.failure → claim → missed`；
   - schema、valid finite slot、claim CAS、logical value 与 missed 语义不变。
2. Startup：
   - process-local `.recoveryReady + suppressed` 把 Supervisor recovery 与 Card
     recovery/activation 分成两阶段；
   - activation 内部 durable-mode read 是最终 DB fence；
   - emergencyStop/shutdown 与 activation 由 Supervisor actor顺序线性化；
   - durable-running startup retry 精确分为
     `.initialized + first-phase retry eligibility` 的完整 Supervisor recovery 与
     `.recoveryReady + Card-retry eligibility` 的 Card-only retry；
   - control winner 清除 eligibility/current attempt token；reactive
     `suppressForOrchestratorRecoveryFailure` 最终路径必须删除。
3. Legacy：
   - running legacy Mission 含 Card 时抛 package
     `LegacyPlanningHasCardsError: Error, Sendable, Equatable`；
   - 类型只含 `package let code = "legacy_planning_has_cards"` 与 package init；
   - Mission/Card/work/event 完整 transaction snapshot 零变化。
4. Unexpected fallback：
   - 唯一 seam 是 matching-`#if DEBUG package`
     `injectOwnedSuccessProposalForTesting(workId:result:)`；
   - seam 只能从 owned entry 复用生产 completion/pending/failure owner；
   - release Core 无该符号；
   - 总 Plan §11 的 source/release gates 使用 `set -euo pipefail`，区分
     `rg` no-match与error，并显式传播 `nm`/`find` 失败。

## 3. R11 Candidate canonical hashes

| 文档 | SHA-256 |
|---|---|
| `p1-stage-spec.md` | `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2` |
| `p1-plan.md` | `143db98e995ddc1c182e13fd22ab1a52a6517b6610e7bdb070f731c790d180a0` |
| `../personal-ai-ranch-p1/p1-a1b-durable-planning/plan.md` | `4fd98fad71ead93e88d36545127e484be121f8177784a006659483162f922f56` |

三份文档均未写入自身当前 hash。顶部状态为 R11 Candidate Frozen /
Review11 Pending；Stage、总 Plan 与 leaf 的 Open Questions 都精确为空。

## 4. 预冻结职责分离复核

两路只读 reviewer 均未参与最终 candidate 写入，也未运行产品命令：

| Cross-audit | Verdict | 重点 |
|---|---|---|
| contract crosscheck | `APPROVED — 0 P0 / 0 P1 / 0 P2` | 四个 R11 owner、startup 两类 retry、control linearization、typed error、DEBUG/release gate、allowlist |
| structure/scope audit | `APPROVED — 0 P0 / 0 P1` | bounded anchors、hashes、Open Questions、11 minimal names、fences、bash syntax、manifests |

结构快照：

```text
Stage fences=42 balanced=true trailing-whitespace=0 CR=0
Plan fences=18 balanced=true trailing-whitespace=0 CR=0
A1b leaf fences=36 balanced=true trailing-whitespace=0 CR=0
11 R11 minimal test names: Stage=1 each, Plan=1 each, leaf=1 each
all total/leaf bash blocks: syntax pass
```

普通 `git diff` 不能证明 untracked canonical task tree 的章节边界；本证据同时保存
进入 hashes、最终 hashes、明确锚点、结构与以下逐文件 manifests。

## 5. Manifest 算法与 aggregates

算法固定为：按 leaf §3 的显式数组顺序；存在文件使用原生
`shasum -a 256` 行，不存在使用 `ABSENT␠␠path`；保留每行与最终尾换行，再对
完整字节流做 SHA-256。

| Manifest | Entries | SHA-256 |
|---|---:|---|
| production | 13 | `b7ddddadd04a68f676b125605c04d91cb6adee5f9c50835689cba58ccec90aab` |
| existing + new tests | 19 | `03da4e7bfbe18cf64148af879baf6df39662b8ee86c79a6f3f8341331c02abd0` |
| runner/script/Package/resolved/RunTests | 5 | `b2e07ddf612913a78c132cbf51350d49cb62eb51ba3207a0a2bd539423156b53` |

以上 aggregates 与 R11 修订前只读 capture 一致；唯一清单结构变化是 production
manifest 从历史 12 entries 扩为 13 entries，把已授权
`ScheduleStore.swift` 纳入零漂移证明。

### 5.1 Production 13

```text
d6478b05158697120c60c21466b68aec0a1675bf825d0fce0db277bb7f84966b  Sources/AgentLoopCore/Database/AppDatabase.swift
1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4  Sources/AgentLoopCore/Database/EventKind.swift
419844fa57f748078fc995c788631832899fbd4bc4093380eda8bb9049d71cd4  Sources/AgentLoopCore/Database/ScheduleStore.swift
f3fdca6b325e297b042cd159f2bf96dd9116934cf0cc70a152bd8da162773664  Sources/AgentLoopCore/Kernel/Orchestrator.swift
0412b01bef7657f5305760d225bdcc6322dca1661395b8749e6c2dfeaec6ff43  Sources/AgentLoopCore/Kernel/Planner.swift
9bbfde860060837b959670d6a986a65810ea025c870ef566168e1ffce40efb4b  Sources/AgentLoopCore/Provider/LLMProvider.swift
2a78ce6764d680618db4cd63669261a0d65b1c8235af7744bd83dc52f5779cf7  Sources/AgentLoopCore/Work/DurableWork.swift
a231c754b82c4d9630f3a4222f2338ebba23ed28d5f6aa12973093c6ca7372a7  Sources/AgentLoopCore/Database/DurableWorkStore.swift
21d4c912d4542d5ec7952bd523cd98b636c9950b4d37f660ad5647c2770284b2  Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift
094319b38c287a9265311fa60eb3c0e289555c6676dd0e3cfc0345cf289907c5  Sources/AgentLoopCore/Work/PlanningProviderResolver.swift
e379333cd693ec3ec84e7ab77033a7f3142b7462ac4fe42bf8ed24cb1c7891de  Sources/AgentLoopApp/AppStore.swift
149a0497790bf62f5ab459f31e94cf52e5c467816846fe29211a7dcc411c4f18  Sources/AgentLoopApp/CodingRanchStoreAdapter.swift
f1a072a8da5032e47fc78b4b7736680fcd103049da014dbf96fb5d3694bc9c0a  Sources/AgentLoopApp/MissionScheduler.swift
```

### 5.2 Tests 19

```text
d5dac6eb020c65f9a2eb9333bddb34a003b0c70df1faac36d17c4bedada14da0  Sources/AgentLoopTestSuite/AskUserTests.swift
374bd6a2be6c8f72ca5ddf68e8e208adc5004be9d7df20a8c9a0abc49556a455  Sources/AgentLoopTestSuite/BudgetTests.swift
d461638a6949120a8d6b2270df71da684b3b441ceb3009fa821b485d13b12a15  Sources/AgentLoopTestSuite/CrashRecoveryTests.swift
bb35ad60d06e418afe62f261493535a57545a7fb37dda2db049a763150ea6c56  Sources/AgentLoopTestSuite/DatabaseTests.swift
0d4e55b9e0e678406edc020d566b9b1066fea24cdc86ce9a8d9892e364a1c081  Sources/AgentLoopTestSuite/GoldenPathTests.swift
6b6150e00bf826fa98ae9eafbb5735735af81ed39fa64d05cd8628022329e7c7  Sources/AgentLoopTestSuite/GuideChatTests.swift
8fce2825fe3d7cd565d9457dca5e218701d68a54a71360e59f621934f4e03828  Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift
12a3e3780b8ca0f8f2533278d2800d65f81df735a1df415e5df42f8eace2e4ce  Sources/AgentLoopTestSuite/HarvestTests.swift
bf472de3d1d14df44c951d6f6254d6514662c2df178ceb88caaae780726c68a3  Sources/AgentLoopTestSuite/KnowledgeGoldenPathTests.swift
a5f59b694ff2a8f41e40fad2c4794fc26d8bf614d74a4b789ef5c88e0a75359d  Sources/AgentLoopTestSuite/McpTests.swift
ba36076929dfd26d2c4281203eb94400dbad8b56ddf44cda4ced60d395171b25  Sources/AgentLoopTestSuite/MultiCampTests.swift
6bcb043ccd8c29bc76e3b1590a034cdc354ce4772c2a0d4c39b76c4ce82f2790  Sources/AgentLoopTestSuite/OrchestratorTests.swift
52cf173cb65066d6f809bbd31c9c3d60d60bc6d64d99daa5405a1f852fcf1e3e  Sources/AgentLoopTestSuite/PlannerTests.swift
2b361402c8bb2e990de7a72e1bc169b45b14df21cd66eee05480285347d1f524  Sources/AgentLoopTestSuite/PlanningTokensTests.swift
db5ef5b8a4edd1c423899143507af5d50e4d8f01d7724aa6c269fe52506e1a0e  Sources/AgentLoopTestSuite/RuntimeProfileTests.swift
c2573a0e9949af56de9b763f7b3b29d22459cbb738767d4e313bd6ae9993e7ce  Sources/AgentLoopTestSuite/ScheduleTests.swift
2f3367fa38ee1b8528eb7aab61d64399ca008a632bd47bdf9e60a821dc46f6e5  Sources/AgentLoopTestSuite/DurableWorkTests.swift
c36196c6cef55c5cb22ac032eb505022e5d6ca108dd813ec91b07e26b49b01dc  Sources/AgentLoopTestSuite/DurablePlanningTests.swift
2ee0faa8f8ee79b9d2cc8f9b87f831bf107f21170515036ef41140e3e0f60ce8  Sources/AgentLoopTestSuite/PlanningTestFixtures.swift
```

### 5.3 Runner/script/immutable 5

```text
db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267  Sources/P1MigrationMatrixRunner/main.swift
c085c13c072509f9b0a61c5d386841f70f8cf5b6d8bb5afedc6166f436536f93  scripts/verify-p1-migrations-sqlite-matrix.sh
577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d  Package.swift
d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a  Package.resolved
70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3  Sources/RunTests/main.swift
```

## 6. Worktree 与不可变指纹

```text
git status --porcelain=v1 -z SHA-256:
57d5d99e31248fa05093e6702129c6df8e02dcd4ae20168a72974d854faa1910
```

Package/Resolved/RunTests 三个指纹与进入值逐字一致。当前 worktree 仍包含 R10/A1b
已存在的产品与测试修改；本轮只用 manifests 证明 R11 planning期间没有继续改变
这些文件，不把 dirty worktree误报为干净或已验收。

## 7. Review11 门

职责隔离 Review11 reviewer 必须：

1. 未参与 R11 canonical 修订或上述预冻结 cross-audits；
2. 复算 §3 三个 exact hashes、§5 manifests、§6 immutable fingerprints；
3. 逐项审计四个 R11 根因、同根一致性修正、两个 startup retry predicate、11 个
   minimal tests与总 Plan §11 fail-fast gates；
4. 保持产品、测试、Package、runner/script只读，不运行产品 test/build/matrix/
   preview；
5. 唯一写入
   `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/11-p1-plan-review.md`；
6. 明确给出 `APPROVED — 0 P0 / 0 P1` 或精确 findings。

只有 Review11 在 §3 精确 hashes 上判定零 P0/P1，A1b implementation gate 才能重新
打开；Review11 不替代 A1b implementation Review 或 acceptance，A2 继续关闭。
