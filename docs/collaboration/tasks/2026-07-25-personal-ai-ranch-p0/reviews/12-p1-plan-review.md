# Review12 — P1-A2 R12/R12-A Candidate Independent Plan Review

> 日期：2026-07-27
>
> 分支：`codex/personal-ai-ranch-p0`
>
> HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> Reviewer：职责隔离的独立 Review12 reviewer

## 1. Scope 与独立性

本 reviewer 未参与 R12/R12-A canonical 修订、A2 leaf、blocker、freeze evidence
或 control index 写入。审查只针对本报告记录的 exact candidate；唯一写入是本文件。
canonical Stage/总 Plan/A2 leaf、两个 P1 execution index、A2 blocker/freeze
evidence、产品、测试、Package、runner/script 与既有 implementation evidence
全部保持只读。

这是 plan review，不是 A2 implementation Review 或 acceptance。当前 worktree 是
fully-expanded dirty A1a/A1b accepted baseline；本报告没有把它误报为干净，也没有
清理、覆盖或回滚其中任何用户改动。

## 2. Frozen inputs 与入口证据

以下 SHA-256 均由本 reviewer 独立复算，actual 与 frozen expected 逐字一致：

| 输入 | SHA-256 | 结果 |
|---|---|---|
| canonical Stage `p1-stage-spec.md` | `14a6f003e9aa59e2a00e04a878e9fa9bfda8a666ef26a4093dbca1c0f4d35637` | match |
| canonical 总 Plan `p1-plan.md` | `01c19e54b06b91d716b98bfbada21984a735807c1673b7815e03b5fd3535416d` | match |
| A2 leaf `plan.md` | `55140ca98a37b34d004ce4704cfaf427ce6b87f0f9f04062257453b398387206` | match |
| A2 freeze evidence | `652c71bd9d47d7ba7fe86651dd4e0422ed2edaf744cdbd1dd55c4d81d3e466a5` | match |
| A2 `blocked.md` | `44949d4bcb3c0761a4d8267a36e9d2c17133b26be120cbfcb2ee6ace07eacafc` | match |
| P1 Stage control index | `8d2aeb304ec08e107b3c360deeb48c66cb1e552086d0509534b5cdea1cbac580` | match |
| P1 Plan control index | `5f9a9f2f3656fc2f021c10ad43d0d82b2afb93a4c945fd701c0cc4033934cf05` | match |

三个 canonical 文档的 Open Questions 均精确为 `无。`。控制索引正确指向上述
hashes，状态仍为 `Review12 Pending / A2 Implementation Frozen`，没有把
candidate freeze误写为 implementation authorization。

前置入口也独立复算：

| 证据 | SHA-256 | 内容 |
|---|---|---|
| A1a acceptance | `070a2b6815ef85323d1041d3023ebc28ec5f98737513746ec9bdf961183a0032` | `ACCEPTED` |
| A1b final implementation Review01 | `8c96b742285da1c1999c5360071728cbdf287cfeffeb6b25e281485336e0b1a0` | 最终 `APPROVED — 0 P0 / 0 P1` |
| A1b acceptance | `efe4d20a7cb4dc3f61d028637a6705d3ed56d4fdd5596ebc3cb993d94481bf1e` | `ACCEPTED`，22/22 PASS |

## 3. Freeze manifest 与机械一致性

### 3.1 R12-A control delta

- matrix script current SHA-256：
  `9c44660a341f3c56d9156c98947fcad4ccd0d9635834bc2eb8e3ac476bc8afaf`；
- runner SHA-256：
  `db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267`；
- line 115 的 Stage hash 为当前 frozen Stage exact hash；
- 只在输入流中把该 value 恢复为旧
  `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2`
  后，整份 script SHA-256 精确恢复为
  `b51129fe71cc7074f644ba8d0969ddb98aa664253887ea6c3840baa6655e5be5`。

因此 R12-A 的单值 restoration proof 成立；没有执行 matrix。

### 3.2 Product/test 与 immutable manifests

freeze evidence 列出的 13 个未来允许 product 文件和 2 个 test 文件全部逐文件
复算并匹配。总 Plan 与 leaf 的 allowlist机械提取结果分别为 13/13 与 2/2，顺序及
路径无 diff。

以下 immutable 边界也全部匹配：

| 边界 | 独立复算结果 |
|---|---|
| `PlanningProviderResolver.swift` | `094319b38c287a9265311fa60eb3c0e289555c6676dd0e3cfc0345cf289907c5` |
| `RuminationResult.swift` | `7ec1e5a45bc99d6af0270e84c535e59aa04cd57ae02e9f60537ec94c699b8be7` |
| `RuminationMaterializer.swift` | `f0cd523ddf43789a9b0485bbcd0ee7b860b43a129795e06b1483c077d522623f` |
| `EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` |
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| AppDatabase migrator block（lines 21–612） | `5bbb555016a64801c25be3634b0fcfcca0da8fe3b4d3cda493b0df3851a8ccff` |
| Stage §18.1 literal | 187 lines；`fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2` |

### 3.3 Exact named tests 与文档结构

- 总 Plan 与 A2 leaf 各自机械提取到 41 个 test names；
- 每份均为 41 unique，且每个名字在各自文件中精确出现一次；
- 两份有序列表逐字无 diff；
- Stage/总 Plan/leaf Markdown fence计数分别为 42/18/2，均为偶数；
- 三份文件 trailing whitespace与 CR计数均为 0；
- 写报告前 `git diff --check` 通过。

## 4. B1–B5 与当前拓扑审查

### B1 — Recovering UI

允许范围已包含 `CodingRanchContracts.swift` 与 `RuminationViews.swift`，并冻结
`.recovering`、`正在恢复`、recovering/live 两套 exact stage list、matching
work/attempt投影、source gate与 isolated cold-start preview。原 B1 的文件范围与
truthful UI blocker已关闭。

### B2 — 单一 Supervisor owner

当前 production `DurableWorkSupervisor(` callsite精确一处，位于
`Orchestrator.swift`；另有 8 个直接 test callsites。当前 production
`Orchestrator(` callsite精确一处，位于 AppStore；其余约 56 个为 tests。R12
allowlist包含 Orchestrator，且 Stage/Plan/leaf一致冻结 single owner、global FIFO、
统一 startup/halt/resume/wait/shutdown、兼容 initializer defaults 与 production
source sentinel。原 B2 的 owner/scope blocker已关闭。

### B3 — Captured runtime 与 legacy repair

normal captured profile/model、absent-only strict preflight、claim-time exact
resolution、11项 safe resolver map、legacy terminal-only input与 startup snapshot
均已冻结；但 legacy mode × snapshot 状态空间仍有一项 P1，见 §5.2。

### B4 — Command、terminal、phase

normal generation/key/trace/replay、specialized transactions、generic capability
seal、failure/retry、usage、terminal proposal、halt/cancel race与 mutation fences
均有 owner和测试门；但 provider/parse 与 organizing phase之间的唯一合法交接合同
自相矛盾，见 §5.1。

### B5 — Completion gates

41 个 exact tests、required subcases、全量 RunTests/build/release、双 SQLite
matrix、source/privacy/hash gates与 isolated preview均已加入。除 §5 两个
decision-completeness finding外，原 B5 的数量与证据范围 blocker已关闭。

## 5. Findings

### P1-1 — `organizing-before-parse` 没有合法 owner/API 交接

**证据**

- Stage §6.4.7（lines 1149–1157）规定 RuminationService 的唯一 pure API 是
  `produce(ingestion:) -> RuminationProduction(result,usage)`，且 parse在该调用
  内完成；
- 总 Plan §3.3（lines 1449–1454）与 leaf §6（lines 203–210）进一步明确禁止
  callback或第二 provider path；
- Stage §6.4.9（lines 1225–1227）与 leaf §8（lines 237–238）又要求 valid
  Supervisor owner在“恰好一个 valid turn之后、parse之前”发
  `organizing`；
- 当前 `RuminationService.swift` lines 45–53 能命中该时点，恰好是因为使用
  `onPhase` callback；R12 明确要求删除这条 callback路径。

**影响**

Supervisor 在调用 `produce` 前尚未得到 valid-turn证明；`produce` 返回时 result
已经 parse完成。冻结 API 中没有 phase observer、typed pre-parse handshake、分步
result或其他同步交接。implementer只能：

1. 提前伪造 `organizing`；
2. 在 parse后迟发；
3. 保留/新增被禁止的 callback；
4. 绕过 Service建立第二 provider path；
5. 自行发明未进入冻结 Plan 的 provider wrapper/handshake架构。

五种均违反 no-unplanned-decisions 或 exact phase truth。named tests 27/31/35
无法同时证明现有冻结合同。

**要求**

由 planner有界修订并冻结唯一交接合同：明确哪个 owner、哪个 typed API、何时完成
one-turn与usage验证、如何在 parse前 generation/latest-claim revalidation后顺序
发 phase；同时同步 Stage/总 Plan/leaf和对应 exact tests。不得把时点放宽为
parse后，也不得用 unowned callback/Task掩盖顺序。

### P1-2 — Legacy repair漏掉 `halted + invalid snapshot` 三个真实组合

**证据**

Stage §6.4.6 lines 1130–1139 与 leaf §5 lines 194–199只定义：

1. `running + valid snapshot`；
2. `halted + valid snapshot`；
3. `running + invalid snapshot` 的三个 terminal reasons。

它们没有定义 persistent durable mode为 `halted` 时，startup snapshot分别为
`legacy_rumination_profile_unresolved`、
`legacy_rumination_model_unavailable` 或
`legacy_rumination_profile_cli_unsupported` 的结果。snapshot捕获与 durable mode
彼此独立，因此这三项不是不可达状态。

**影响**

implementer必须自行选择：

- 以 emergency-halt canceled work收口并把 item置 queued；
- 以 snapshot reason failed work收口并把 item置 failed；
- 将其视为 recovery fatal并保持整个 supervisor suppressed。

三者的 durable work state、item/UI、event、resume/restart语义都不同。当前四个
terminal codes不足以推导唯一优先级；test 39
`legacyRuminationRepairCoversValidHaltedAndEveryTerminalReason` 也没有明确钉住
这三个 mode/reason交叉组合。

**要求**

planner必须冻结 mode × snapshot 的完整状态表、reason优先级、work/input/attempt/
event/item结果、provider零调用与 restart幂等语义，并在总 Plan/leaf的 exact
subcases中覆盖三个 halted-invalid组合。

### Finding summary

- P0：0。
- P1：2。
- P2：0。

## 6. Commands deliberately not run

遵守 Review12 predecessor gate，本 reviewer没有运行：

- `swift run RunTests` 或任何单项/targeted Swift测试；
- `swift build`、App build或release build；
- SQLite 3.51/3.52 migration matrix；
- App preview、UI smoke或任何产品进程；
- commit、push、merge、release、数据重置或外部操作。

本次只执行了只读文件/源码检查、Git identity/status读取、SHA-256与manifest复算、
R12-A输入流 restoration proof、allowlist/test-name机械对照、Markdown/static
structure检查与 `git diff --check`。

## 7. Gate

A2 product/test implementation、red-test evidence、implementation Review、
acceptance与 A3 必须继续冻结。只有上述两个 P1 经过获授权的有界修订、重新冻结，
并由职责隔离 reviewer在新 exact hashes上给出零 P0/P1 verdict后，A2
implementation gate才可重新评估。

## 8. Verdict

CHANGES REQUIRED — 0 P0 / 2 P1
