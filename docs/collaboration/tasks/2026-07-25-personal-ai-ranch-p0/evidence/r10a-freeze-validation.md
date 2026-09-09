# R10A Review10 Findings Closure 与重新冻结证据

> 日期：2026-07-26
>
> 分支：`codex/personal-ai-ranch-p0`
>
> HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> 状态：R10 Candidate 2 Frozen；Review10 Rereview Pending；A1b Product/Test Code Frozen

## 1. Authority 与边界

牧场主已明确“授权 R10”。首轮职责隔离 Review10 在获授权 R10 candidate 上判定
`CHANGES REQUIRED — 0 P0 / 2 P1`，并明确两项 finding 分别属于既有 R10-6 与
R10-1 根因。依照 Review10 的 disposition，本次仅在同一 R10 授权内做有界修订：

1. Stage 仅修订状态、§6.2.2、§6.3；
2. 总 Plan 仅修订状态、§3.2、§10、§11；
3. 同步 A1b leaf Plan、freeze evidence、blocker 与控制索引；
4. 重新冻结后，由未参与 planner 修订的同一职责隔离 reviewer 执行
   Review10 rereview，并写入新的不可变报告。

本轮没有修改产品、测试、migration、Package target graph 或 dependency。rereview
零 P0/P1 前，产品/测试实施、产品 test/build/matrix/preview、A1b acceptance、A2、
commit、push、merge、release、数据操作、外部沟通与真实用户动作继续禁止。

## 2. 首轮冻结与 Review10

| 输入 | SHA-256 |
|---|---|
| R10 Stage candidate | `36420de83e30043665c72d8ad8f0cf6ed98e930df296327c9f2d19bc9a72e62e` |
| R10 总 Plan candidate | `e89f7e972f665a49f1bd07bd4921ad86e6ce595429344718639ef0688f8b32af` |
| R10 A1b leaf candidate | `bb5aa2cd5e7eb7e0cfcbd472b63382d4e5d0a0afd6d4e195737772e82f8c35be` |
| `evidence/r10-freeze-validation.md` | `a26bed58bbea1a161af589a2347a9ad200fff88432c2990eb11b7b8c71d88e22` |
| `reviews/10-p1-plan-review.md` | `acac1f5b09359f27a095acb12804a58daf6ac3d1250dc5fb7309699cd21851c1` |

原 Review10 报告保持不可变；本轮不覆盖或改写它。

## 3. 两项 P1 的同根闭包

### 3.1 R10-P1-01 / R10-6 — generic planning capability

Candidate 2 把 `.planning` 封为 generic mutation/dispatch reserved kind：

- generic `enqueue`、`claimNext`、`nextClaimableDate`、`renewLease`、
  `complete`、`retryOrFail`、`cancel`、`cancelActive`、
  `adoptInterrupted` 九个 API 及同名 internal helper 均不能操作 planning；
- public typed error 固定为
  `PlanningRequiresDurablePlanningCapabilityError`；
- target-based API 在 transaction 读取 work 后、任何 state/idempotent/CAS/update/
  event/closure 前拒绝；planning terminal cancel 也不得走 already-canceled 返回；
- `activeWork`、`latestWork`、`work(id:)` 只读 seam 保留；
- specialized planning lifecycle、adoption、halt cancel 只能经
  `DurableWorkStore.swift` 内唯一
  `fileprivate enum PlanningDurableWorkLedgerOwner` 与同文件 specialized boundary；
- dual-reserved list API 先保留既有 time/lease validation，再按 caller 原数组顺序、
  dedupe 前扫描，第一个 `.planning` / `.campDeletion` 决定 typed error；
  `enqueue` 与 `cancelActive` 均 kind-first；
- 命名测试与 source sentinels 同步冻结，包括
  `genericReservedKindOrderingUsesCallerOrderBeforeDeduplication` 的两种顺序和
  validation-priority 覆盖。

### 3.2 R10-P1-02 / R10-1 — App 四入口测试在 target graph 中可达

Candidate 2 保持 `Package.swift`、`Package.resolved` 与 `RunTests` target graph
字节不变，并冻结 package-only production test seam：

- 在已允许的 `Orchestrator.swift` 内定义 package-access DTO 与
  `@MainActor package final class PlanningEntryCoordinator`；
- AppStore 只创建一个 coordinator，adapter extension 使用同一 property，
  MissionScheduler required 注入同一实例；
- manual、candidate、proposal、schedule 四入口的 capture、idempotency、
  compare-and-clear、CAS/attach/revert/heal owner 与 exactly-once missed 语义均冻结；
- `AgentLoopTestSuite` 直接调用真实 package coordinator；无需 import App target、
  新增 target、扩大 public Core surface 或修改 Package；
- 五项真实 App source-range/order test 使用固定函数签名与跳过注释/字符串的
  balanced-brace scanner，缺失、重复、brace 不平衡或顺序错误立即失败；
- source sentinels 禁止 App/adapter/scheduler 继续旁路 coordinator。

## 4. Candidate 2 冻结 hashes

| 文档 | SHA-256 |
|---|---|
| `p1-stage-spec.md` | `d05452fd0a877fb03e94ff0e1a75a0efa3b095c93c14ff856c79da04619db3a6` |
| `p1-plan.md` | `b14c145c433a03606c925d5f027d7a3a25d458b07a2a5bb447a29424cce58a61` |
| `../personal-ai-ranch-p1/p1-a1b-durable-planning/plan.md` | `cf1b603c2147a2cb2619a5230ff3b71a41b2968f78e0c3e28480da09460feb0e` |

三份文档顶部均为 `R10 Candidate 2 Frozen；Review10 Rereview Pending`；
Stage §28、总 Plan §18 与 leaf §16 的 Open Questions 均为“无。”。

## 5. 预冻结只读复核

两路职责分离的只读 crosswalk 均未参与 planner 修订，也未写文件或运行产品命令：

| Crosswalk | 结果 | 重点 |
|---|---|---|
| generic planning seal | `APPROVED — 0 P0 / 0 P1` | 九 API ban、dual-reserved 顺序、唯一 specialized owner、adoption、tests/sentinels |
| App entry test reachability | `APPROVED — 0 P0 / 0 P1` | package DTO/API、单 coordinator、四入口 lifecycle、十项功能测试、五项真实 source test、Package 不变 |

这些 crosswalk 是 refreeze 前的对抗审计，不替代独立 Review10 rereview。

## 6. 产品、测试与 Package 指纹

按“清单顺序；存在文件为 `shasum -a 256` 输出，不存在为 `ABSENT  path`”拼接，
Candidate 2 冻结时的 manifests 与 Review10 进入指纹逐字一致：

| Manifest | SHA-256 | 结果 |
|---|---|---|
| production 12 entries | `44f0104b82a23d8b1db7c8110fc340a9b777d104df8e71438b1b3a58711be3f7` | match |
| existing + new tests 19 entries | `4678484e4a4eaadfaaf60f8d3e721d26e0426499b541cb3533e309865387534c` | match |
| runner/script/Package/resolved/RunTests 5 entries | `90174bf00f8955f5df387ea35ff3c08f9e726adeade1dfee54109be72eafe65d` | match |

具体逐文件基线仍以不可变
`evidence/r10-freeze-validation.md` §6 与
`reviews/10-p1-plan-review.md` §7 为准。Supervisor、Resolver、
`DurablePlanningTests.swift`、`PlanningTestFixtures.swift` 仍为 `ABSENT`。

## 7. 结构与 hygiene

```text
Stage fences=42 balanced=true trailing-whitespace=0
Plan fences=16 balanced=true trailing-whitespace=0
A1b leaf fences=34 balanced=true trailing-whitespace=0
git diff --check=pass
```

本轮只运行了 read-only 文本、hash、status、结构与 hygiene 检查。没有运行
`swift run RunTests`、App build、migration matrix 或 preview。

## 8. Review10 rereview 门

职责隔离 reviewer 的 rereview 唯一允许写入为：

`reviews/10a-p1-plan-review.md`

它必须：

1. 在 §4 的三个精确 hashes 上复审；
2. 逐项验证 R10-P1-01 与 R10-P1-02 已闭合，且未产生新 P0/P1；
3. 验证本轮修订没有越过 R10-1/R10-6 同一根因和授权文档范围；
4. 复算 §6 三个 manifests 与 §7 结构；
5. 保持产品/测试/Package 只读，不运行产品 test/build/matrix/preview；
6. 明确给出 `APPROVED — 0 P0 / 0 P1` 或精确 findings。

只有新报告在 §4 精确 hashes 上判定零 P0/P1，A1b implementation gate 才能打开；
A2 继续关闭。
