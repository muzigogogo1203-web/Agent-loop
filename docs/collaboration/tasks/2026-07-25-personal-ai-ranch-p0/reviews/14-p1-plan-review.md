# Review14 — P1-A2 R14 Incident-Disposition Plan Review

> 结论：**CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2**
>
> 日期：2026-07-27
>
> Reviewer：职责隔离 independent plan reviewer

## 1. 职责隔离、范围与方法

本 reviewer 未参与 R14 修订，也未默认继承 freeze 的自评结论。审阅前完整读取了
仓库根 `AGENTS.md`。本轮唯一写入是本 Review；没有修改 canonical、control、
产品、测试、script、freeze、旧 Review、实现日志或 acceptance，没有 commit、
push、merge、release、外部操作或真实用户操作。

本轮没有运行 test、build、migration matrix、source gate 或 preview，没有启动
AgentLoop App，也没有访问 normal state root。只进行了 `sed`/`rg`/`nl`、
`shasum -a 256`、`git status`、`git diff --check` 等只读检查；normal root 未被
list/find/stat/hash/SQLite-open/export/cleanup/reset/rebuild。

审阅快照：

| 项 | 独立核对值 |
|---|---|
| Branch | `codex/personal-ai-ranch-p0` |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` |
| Worktree | 已有大量用户/前序改动与 untracked task tree；本 reviewer 未改写它们 |
| `git diff --check` | 无输出 |

审阅对象包括 canonical Stage、canonical total Plan、A2 leaf、三个 current control
surfaces、R14 freeze、immutable Review01、R13/R13A/R13B freezes 与 Reviews、
R13 implementation/incident artifacts，以及计划实际依赖的 Package 与 App
bundle 生成入口。

## 2. Exact R14 candidate

以下值均为独立重算，逐项匹配题定值与
`p1-a2-durable-rumination/evidence/plan-freeze-r14.md`：

| Artifact | Verified SHA-256 |
|---|---|
| canonical Stage | `5a128120d8fc815c207c93dc06a9aa0c016f48ded275107564d1df6dae0d7f8b` |
| canonical total Plan | `c8f6240eb6a5622390edf58278a8a2890c06f659077babe4667a10b9b4d4b028` |
| A2 leaf | `1f9e2ea7140bf9c0daa5ab7004897fd5a97e6386f64ae7e20a4a16b5c0c08665` |
| A2 `blocked.md` | `81a5a955ed0b74261ce7e65a0afa83088119a74d154f7050e3571dd60fc69af1` |
| P1 Stage control | `40c3cc7eeab2831eaf6582ffa83ac5bcc43be6e727fd088de79f36337244a372` |
| P1 Plan control | `a1cde01d606e1611761a856479791e5b0163209319a6ae083e600bc06fb89a89` |
| R14 freeze | `66436eeeedba03e3e0a4411e208c3dd7993f5c2968952c7bff64446232ca011d` |

六个 current surfaces 的唯一 current 状态均为
`R14 Incident-Disposition Candidate Frozen；Review14 Pending；A2 Clean Re-verification Frozen`
（两个顶层 control index另保留已成立的 A1a/A1b Accepted、R-01 Closed 前缀）。
唯一 next-review artifact 是本文件。

## 3. Review01 P1-01 与 immutable incident

R14 对 Review01 P1-01 的事实处置是诚实的：

- `evidence/preview-bootstrap.log:35-44` 原样记录第一次 attempt invalid；
- display-name lookup 自动启动 installed
  `/Applications/AgentLoop.app` PID `74836`；
- PID `74836` 实际打开 normal root 的 `.agentloop.lock`、
  `agentloop.sqlite`、`agentloop.sqlite-shm`、`agentloop.sqlite-wal` 四项；
- `impl-report.md:237-265` 同样保留该事实，并因缺少 incident 前 content hash
  没有宣称 zero mutation；
- Review01 继续是
  `CHANGES REQUIRED — 0 P0 / 1 P1`，没有被追加、覆盖或降级；
- 整个 R13 implementation/completion invocation 永久标记
  `REJECTED_CONTAMINATED`，mutation 保持 `UNKNOWN`；
- 后续 fresh full-path retry 只保留为真实历史技术证据，未被用来反向洗绿
  incident 或声称 A2 历史 zero access。

关键 incident/implementation artifacts 均匹配 R14 freeze：

| Artifact | Verified SHA-256 |
|---|---|
| `red-tests.log` | `30f80fb1a90889ac1e6c207e58464509924358a4936d5058259bc23ed9b3ac46` |
| `verify.log` | `354c0165ad261d7ec7a47b1cd2e7fe83db81fbf5ac10ce9ff0fce40ed0ccd861` |
| `build.log` | `b5c4aca2d6484ac8778fb65f942fc463eb3075380aa94190b113ce693937882d` |
| `migration-matrix.log` | `be62651c13e3dd3b05cedb4f074d1f6a0020ba6c8f79f648c7d5926970830940` |
| `impl-report.md` | `4702259ad90b367538ede4cc4a7a98cfee131b3724f60d1a0ac54cfdeed50afc` |
| `evidence/source-gates.log` | `f52b1a98a81e39fed0d3c619ecca81dfa34f22eaf1fd507d79dbf2ed56c5e7d2` |
| `evidence/hash-manifest.log` | `12617d5dd3bb43eb9d10074a0aa5fe50328b88c22dac40232fc90f7e10a2765f` |
| `evidence/preview-bootstrap.log` | `9ec0fd18369e4d7f3e9f78afb59e55a8072dbee7e0611f5c74c68df414589bd0` |
| `evidence/preview-cold-start.log` | `04f0b602b465a7c8521a8ef9af058ce47477ba380f4ef4243ef33ce323017795` |
| `evidence/preview-smoke.png` | `8623453541c08c538eab784bac1872fee86e1e497c553ce9576b50ae4f84a9c3` |
| `evidence/r13-release-nm.txt` | `1a9cf5785ae7603461873ff73b9c61a48422d4b881b91e6c634be4803533a824` |
| `evidence/r13-debug-nm.txt` | `408a6f1c0e96e9ab663d690d361b25e80445f218be11cf805e698fd1593986f6` |
| `evidence/r13-seam-symbol-gate.log` | `f5885f6812e9acab36c86f271b8db52233df5d3dce587fa4a2f28f83afe293cb` |
| `reviews/01-p1-a2-review.md` | `5b6a171515404a644abcd05e3afc3840cb1dd4d84d7993f74af48de0692b4dd5` |

## 4. Product/test/script 与 immutable predecessor audit

15 个 R14 frozen product/test bytes 全部逐项匹配：

| Path | Verified SHA-256 |
|---|---|
| `Sources/AgentLoopCore/Work/DurableWork.swift` | `80fdb08592d0e48b09b64f4bd17db5f54019e35ef9b738907915d6c429aa61d6` |
| `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift` | `e7cde04d577cc53b5b4ad0f8ad18bb4ca4ce604de18c660020fbc4096cd48f45` |
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
| `Sources/AgentLoopTestSuite/CodingRanchTests.swift` | `5e311070fc5299fd4f576b4af6fb2286e4a515bf5b23a72d1ccc464c88c2c2bb` |
| `Sources/AgentLoopTestSuite/DurableWorkTests.swift` | `818dfc5f897a0258b3113902f175d65bdf917732652ca44c08bd86fd0a2f0dd7` |

Immutable sentinels 也全部匹配：

| Artifact / boundary | Verified SHA-256 |
|---|---|
| `StateDirectoryLock.swift` | `863819791bbbead28c7fb0ba80540703fa275977682c846fbb8b415ce512c363` |
| `SupportTests.swift` | `eb5f8392870a8cca3a0e9729cc17082d259346b8187ff68cde9ee71ff1497386` |
| `PlanningProviderResolver.swift` | `094319b38c287a9265311fa60eb3c0e289555c6676dd0e3cfc0345cf289907c5` |
| `RuminationResult.swift` | `7ec1e5a45bc99d6af0270e84c535e59aa04cd57ae02e9f60537ec94c699b8be7` |
| `RuminationMaterializer.swift` | `f0cd523ddf43789a9b0485bbcd0ee7b860b43a129795e06b1483c077d522623f` |
| `EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` |
| `Sources/P1MigrationMatrixRunner/main.swift` | `db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267` |
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| AppDatabase lines 21–612 | `5bbb555016a64801c25be3634b0fcfcca0da8fe3b4d3cda493b0df3851a8ccff` |
| Stage lines 3850–4036 | `fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2` |
| matrix script R14 entry | `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c` |

Matrix script line 115 当前仍是 predecessor Stage
`a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f`；
R14 planning 没有提前修改 script。计划冻结的 post-Review14 单一 64-hex
机械替换例外没有扩张为其他 script 修改。

R13/R13A/R13B predecessor chain 也逐项匹配：

| Artifact | Verified SHA-256 |
|---|---|
| `evidence/plan-freeze-r13.md` | `9bcfd9a6a430899bb51e164121e48ae7fb23f8e8454694b47ea30fcf7d6132d0` |
| `reviews/13-p1-plan-review.md` | `5203057f2a4a7f04827d9f5e0f20b717e08a31125404483b11f5cad722bda66b` |
| `evidence/plan-freeze-r13a.md` | `a79e577ecb14978fd5097ce05d9c012711427ea50d3b16ce9ea2b67e57691138` |
| `reviews/13a-p1-plan-review.md` | `edfb632ce1af2514dfe3168f87e0506fffe3a116f9cd6d3a427874933d399580` |
| `evidence/plan-freeze-r13b.md` | `b9ff965be2477e68d70b2d938a3e496ff47409a20efae710a971b0a96322b8d1` |
| `reviews/13b-p1-plan-review.md` | `b798cffd016865b9441f6c8978da96d7382feb3e5dd51c7555e635bfbca84444` |

Current canonical/control text把 Review13/13A 保持为 changes-required historical
predecessors，把 Review13B 保持为曾打开 R13 implementation 的 approved historical
predecessor；未发现它们重新形成 current split-brain。

## 5. R14 gate semantic audit

除下述 P1 外，R14 disposition 与 clean-boundary gate 在审阅范围内完整且同向：

- Review14 通过只允许**后续新的用户授权 turn**开始一次
  zero-product/test-delta clean re-verification，不打开产品/test实施；
- BEGIN 位于 targeted/full test、build、matrix、source gate、App launch 之前；
- boundary 记录 unique ID、UTC、branch/HEAD、canonical/control/freeze/source/
  test/package/runner/script/historical hashes、no-process、fresh root、repository
  executable realpath/hash；
- App/UI 只按 exact repository full path/PID 操作，明确禁止 display name、
  bundle ID、frontmost-name、installed path、LaunchServices fallback 和
  `scripts/run-app.sh --preview`；退出后只允许 shell process-presence 检查；
- normal root 只能通过进程 `lsof` 输出比较 open-file path metadata，禁止
  list/find/stat/hash/SQLite-open/export/cleanup/reset/rebuild；
- normal-root access、第二 App、wrong path/hash/env/PID、unknown child、provider
  dispatch、post-quit UI call或证据缺口会使整个 boundary 永久
  `REJECTED_CONTAMINATED`；同 boundary 零 retry，新尝试必须重新取得 plan-level
  有界授权；
- distinct R14 artifacts覆盖 targeted 41、authoritative full RunTests、App/release
  builds、release/DEBUG seam、双 SQLite full matrix、source/privacy/scope/hash/
  diff、fresh isolated preview、true PNG、BEGIN/END 与 `impl-report-r14.md`；
- Review02 由新的职责隔离 implementation reviewer 只写
  `reviews/02-p1-a2-review.md`，零 P0/P1 后才打开 acceptance；
- acceptance 必须同时披露 R13 incident 与 mutation unknown，只能声明 R14
  boundary 内 zero normal-data access，不得声称整个 A2 历史零访问；
- Stage §29、total Plan §19、leaf §13 的 Open Questions 均精确为“无。”；
- total Plan §11 的旧通用 `scripts/run-app.sh --preview` 命令，已被 total Plan
  §3.3 与 leaf §11.1 的 R14 专属明确禁令排除；本 Review 不把旧通用命令解释为
  R14 可执行授权。

## 6. P1 finding

### P1-01 — R14 没有定义如何生成并证明将被 direct-launch 的 exact repository App bundle

R14 正确禁止了造成前次 incident 的 LaunchServices 路径，但冻结计划没有给出一个
decision-complete、可重复的非 LaunchServices bundle 生成/溯源步骤：

1. leaf §10（lines 749–764）规定先完成 BEGIN，再依次运行 tests、`swift build
   --product AgentLoopApp` 等门；
2. leaf §11.1（lines 857–861）要求 BEGIN 记录稍后将使用的
   `/Users/muzi/Agent-loop/.build/AgentLoop.app/Contents/MacOS/AgentLoop`
   realpath/hash，并禁止 `scripts/run-app.sh --preview`；
3. leaf §11.2（lines 868–880）随后 direct-launch 该 exact bundle executable；
4. `Package.swift:29-33,51-55` 只定义 SwiftPM executable product
   `AgentLoopApp`。仓库的实际 bundle 组装逻辑位于
   `scripts/run-app.sh:43-86`：它在 `swift build` 后删除并重建
   `.build/AgentLoop.app`，复制 debug executable/resources，并 ad-hoc codesign；
   同一 script 在 lines 88–103 无条件进入被 R14 禁止的 `open`/LaunchServices
   启动；
5. R14 canonical/leaf既没有冻结一个 expected bundle/executable hash，也没有要求
   将 just-built `.build/debug/AgentLoopApp` 及 resources 与即将启动的 signed
   bundle建立可验证 provenance；当前现存 bundle只是未纳入 freeze 的 `.build`
   状态。

因此 implementer 只能在两种未获计划决定的行为中自选：复用一个未冻结、未证明与
本轮 App build对应的既有 `.build/AgentLoop.app`，或自行拆抄/发明
`run-app.sh` 的 bundle-copy/Info.plist/codesign步骤。前者允许 stale/wrong
repository bundle 在 path/hash/PID 都“正确”的情况下把 preview gate洗绿；后者
违反 `AGENTS.md` 的 no-unplanned-decisions 与冻结的 exact command/artifact
边界。若 `.build/AgentLoop.app` 被正常清理，当前 one-shot计划也无法从冻结输入
重新产生规定的 launch target。

这是 P1：它不证明已经发生新的数据污染或产品缺陷，但直接使 R14 clean completion
evidence 的 source→build→launched-executable traceability 不闭合，且执行者无法
在不作计划外选择的情况下可靠完成唯一一次 boundary。

关闭本 finding 需要在 canonical/leaf 中冻结一个明确、非 LaunchServices、
零产品/test/script语义扩张的 bundle 生成与 provenance gate，并重新冻结 exact
hashes接受职责隔离 plan review。本 reviewer 不替 planner 选择具体实现。

## 7. Verdict

- P0：**0**
- P1：**1**
- P2：**0**

**CHANGES REQUIRED — 0 P0 / 1 P1**

Review14 未打开 R14 clean re-verification。继续禁止任何 R14 targeted/full test、
build、matrix、source gate、preview、产品/test/script修改、Review02/acceptance、
A3、commit、push、merge、release、normal-data、外部与真实用户操作。
