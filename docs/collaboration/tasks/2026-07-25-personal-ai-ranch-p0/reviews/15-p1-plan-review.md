# Review15 — P1-A2 R15 Bundle-Provenance Plan Review

> 结论：**APPROVED — 0 P0 / 0 P1**
>
> 日期：2026-07-28
>
> Reviewer：职责隔离 independent plan reviewer

## 1. 职责隔离、范围与方法

本 reviewer 未参与 R15 修订、bundle assembly 或 preview，也未默认继承 planner
freeze 的自评结论。审阅前完整读取了仓库根 `AGENTS.md`。本轮唯一写入是本
Review15；没有修改 canonical、control、freeze、blocked、产品、测试、Package、
script、旧 Review、实现日志或 acceptance，没有 commit、push、merge、release、
外部操作或真实用户操作。

本轮没有运行 test、build、migration matrix、source gate、bundle assembly/sign 或
preview，没有启动 AgentLoop App，也没有读取或访问 normal state root。只进行了
`sed`、`rg`、`nl`、`shasum -a 256`、只读文件/清单检查、`git status` 与
`git diff --check`；没有执行两条 App scripts。

审阅快照：

| 项 | 独立核对值 |
|---|---|
| Branch | `codex/personal-ai-ranch-p0` |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` |
| Worktree | 已有大量用户/前序修改及 untracked task tree；本 reviewer 未改写它们 |
| Review15 写入前 | 目标路径不存在；未覆盖既有文件 |
| `git diff --check` | 无输出 |

## 2. R15 exact candidate 与 immutable predecessor

以下 SHA-256 均由本 reviewer 从当前 bytes 独立重算：

| Artifact | Verified SHA-256 | 结果 |
|---|---|---|
| R15 freeze `evidence/plan-freeze-r15.md` | `e5ad3967f2e2b26a2bbf8b2ef7be405e8430cc30a82d51a7cb5f51926a99e3d7` | 匹配 |
| canonical Stage | `e66fba4cca62a20fae155591384d426fac446eb2e0ccb510820f13fe8fe11289` | 匹配 |
| canonical total Plan | `fc4ca360e2705e8ed3ce00b068c309536efd99f4ac6df2e8d6b1e7cc5606b75d` | 匹配 |
| A2 leaf | `42aeab70d6595358dd22b3474c459b4b05c7c42cf504e396d1e0342ff5398b6e` | 匹配 |
| A2 `blocked.md` | `d944f52221fd6b9bb2efc7c5c34d7ae4800edb052937199164827a1c41bd23d9` | 匹配 |
| P1 Stage control | `5d43587b2b867c452eb72a6d4b587442a34fd51f86ed7a2bce6d416dcd7d1256` | 匹配 |
| P1 Plan control | `276ead262d2dbe7cac3ee51162386bf3291bfdd223ab458422942c4fa88c6180` | 匹配 |
| immutable R14 freeze | `66436eeeedba03e3e0a4411e208c3dd7993f5c2968952c7bff64446232ca011d` | 匹配 |
| immutable Review14 | `5bc0adf787dabd1451c53c7fc13df817325b323b030478443f62030bbf28e405` | 匹配 |

R12–R13B predecessor chain 也逐项匹配 R15 freeze：

| Artifact | Verified SHA-256 |
|---|---|
| `evidence/plan-freeze.md` | `652c71bd9d47d7ba7fe86651dd4e0422ed2edaf744cdbd1dd55c4d81d3e466a5` |
| `evidence/plan-freeze-r12b.md` | `85bceed6cc1083b0c76527b8d0b4f3b960434760f46bdec0b87700406ca3a37b` |
| `evidence/plan-freeze-r12c.md` | `ba4b5bf18644e75befddb2df86e75d593ef85fdbd08c50f720f8f5a1c5255ae0` |
| `evidence/plan-freeze-r12d.md` | `9d4e3bfa2c244b925db9c3bdbde1d30cf86ad42f05453ca5bee9efb5d553c66b` |
| `evidence/plan-freeze-r12e.md` | `2f9f3c494ab2d37c3d503f1ec65e97013d5edd2f08f9f300f15928145924c431` |
| `evidence/plan-freeze-r12f.md` | `d88c14815b08aaa9187ae4053b33c8bfa45b1b03b0f2d2d61adf24e76bebbf41` |
| `evidence/plan-freeze-r13.md` | `9bcfd9a6a430899bb51e164121e48ae7fb23f8e8454694b47ea30fcf7d6132d0` |
| `evidence/plan-freeze-r13a.md` | `a79e577ecb14978fd5097ce05d9c012711427ea50d3b16ce9ea2b67e57691138` |
| `evidence/plan-freeze-r13b.md` | `b9ff965be2477e68d70b2d938a3e496ff47409a20efae710a971b0a96322b8d1` |
| `reviews/12-p1-plan-review.md` | `f27379bfc96a224715e7c6a59ad62fa79d8d97c4d73cf41e890a6ce16957a7c3` |
| `reviews/12a-p1-plan-review.md` | `a102c49138fcfc1f40b0c780990d8c3ad5ec2302b175b043bde9457164331337` |
| `reviews/12b-p1-plan-review.md` | `66b81e9e5ea0f74e08706c7367f2e80180601a000c9e84c1bbd4357a9c3b4ec5` |
| `reviews/12c-p1-plan-review.md` | `db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109` |
| `reviews/13-p1-plan-review.md` | `5203057f2a4a7f04827d9f5e0f20b717e08a31125404483b11f5cad722bda66b` |
| `reviews/13a-p1-plan-review.md` | `edfb632ce1af2514dfe3168f87e0506fffe3a116f9cd6d3a427874933d399580` |
| `reviews/13b-p1-plan-review.md` | `b798cffd016865b9441f6c8978da96d7382feb3e5dd51c7555e635bfbca84444` |

## 3. Review14 P1-01 closure audit

Review14 的唯一 finding 精确是：R14 禁止 LaunchServices，却没有冻结一个
decision-complete、可重复的 non-LaunchServices
source/build→bundle→signed-executable provenance。R15 对该 finding 的关闭是完整
且同根的：

1. **时序闭合。** BEGIN 位于任何 test/build/matrix/source/launch 之前，只记录
   frozen inputs、no-process、recipe identity 与 planned roots，不伪造尚未生成的
   executable identity；App build 后、launch 前严格进入
   `POST_BUILD → PRE_SIGN → LAUNCH_READY`。
2. **fresh roots 与 stale-bundle 隔离。** `R15_STATE_ROOT` 与
   `R15_BUNDLE_PARENT` 是两个新的、absolute、互不嵌套的 `mktemp -d` roots；
   planned App 在 BEGIN 时不存在。现存
   `/Users/muzi/Agent-loop/.build/AgentLoop.app` 明确不得读取、复用、删除或覆盖。
3. **唯一可重复 recipe。** leaf §11.2 冻结了 exact inline
   `r15-dev-bundle-v1`：从同一 repository SwiftPM debug bin dir复制
   `AgentLoopApp` 与 `AgentLoop_AgentLoopApp.bundle` 到 fresh
   `$R15_BUNDLE_PARENT/AgentLoop.app`。两条仓库 App scripts 只能核 hash，禁止
   execute/source/截取/pipe/动态抽取 plist。
4. **source/resource/plist provenance。** Package 只声明
   `Resources/RanchArt`；source、generated 与 copied RanchArt 均被要求为 27 个
   regular files、零 symlink、同一 canonical manifest
   `4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab`。
   整个 generated resource bundle另记录 sorted per-file manifest，PRE_SIGN 再以
   `diff -qr`证明 copied/build resources 相等。inline Info.plist literal独立重算为
   `5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58`，
   且冻结 executable=`AgentLoop`、identifier=`com.muzi.agentloop.dev`。
5. **executable 与签名 provenance。** POST_BUILD 记录 build executable
   realpath/hash/sorted UUID；PRE_SIGN 以 `cmp` 与 UUID equality证明 fresh
   copied executable等于该 build output。全部断言通过后只允许一次
   `codesign --force --sign -`，随后 strict verify/display。LAUNCH_READY记录
   post-sign executable realpath/hash、UUID、CodeDirectory/CDHash 与整个 signed
   bundle manifest。计划正确区分 codesign 会改变 Mach-O bytes，不错误要求
   post-sign hash 等于 build hash，同时继续要求 UUID 与 resources 相等。
6. **launch identity 闭合。** bootstrap/cold start在每次 launch 前重核
   LAUNCH_READY identity，只以 exact `$R15_APP_EXEC` direct exec，PID只取 `$!`。
   两次 launch顺序、零重叠并复用同一 signed bundle/hash/manifest；cold start明确
   记录 `bundle_rebuilt=false`、`bundle_resigned=false`。禁止 `open`、display
   name、bundle ID、frontmost/Dock、NSWorkspace、LaunchServices、name lookup 与
   installed-path fallback。
7. **证据与失败语义闭合。** 四个关键 evidence log path被固定为 absolute paths，
   所有 R15 artifacts须先不存在并 exclusive-create，不得 truncate/覆盖/复用。
   LAUNCH_READY后到 END 零 App rebuild/re-copy/plist rewrite/re-sign。任一
   provenance、path/hash/env/PID、isolation、normal-root、signature、manifest、
   unknown-child/provider 或技术门失败都永久标记整个 boundary 为
   `REJECTED_CONTAMINATED`；同 boundary 禁止换 root、修补、重做或 retry。两个
   fresh roots均保留到 Review02。

因此 implementer不再需要在“复用 stale `.build/AgentLoop.app`”与“自行发明 bundle
assembly”之间作计划外选择；Review14 P1-01 已一次性关闭。

## 4. Current gate、历史链与 zero drift

六个 current surfaces 的唯一 current 状态均逐字为：

`R15 Bundle-Provenance Candidate Frozen；Review15 Pending；A2 Clean Re-verification Frozen`

两个顶层 controls 只额外保留已成立的
`A1a/A1b Accepted；R-01 Closed`前缀。R14 freeze 与 Review14只作为 immutable
changes-required predecessors；没有重新成为 current authority。Stage §29、total
Plan §19、leaf §13 的 Open Questions 均精确为“无。”。Review15写入前，A2 task
tree中的 R14/R15 文件只有两个 plan freezes，没有 `r14-*` 或 `r15-*` execution
artifacts。

Matrix control也完整一致：

| 项 | 独立核对值 |
|---|---|
| matrix script current SHA-256 | `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c` |
| line 115 current predecessor | `a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f` |
| future temporary value | final R15 Stage `e66fba4cca62a20fae155591384d426fac446eb2e0ccb510820f13fe8fe11289` |

该单值替换只有在 Review15批准、后续新用户授权且 BEGIN 已写后才可执行；matrix
成功或失败都必须恢复 predecessor value与 entry hash，其他 bytes 不得改变，最终
script delta必须为 0。恢复只是 containment，不能继续失败的 gate。

15 个 frozen产品/test bytes均匹配 R15 freeze，也与 R14 predecessor中相同基线
一致：

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

Package、runner、sentinels、App inputs 与 slices也全部匹配：

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
| `scripts/run-app.sh` | `5b34e5e98a0e91b4087e20525c3aba81e7955475865d2af70e6ae65736e7997b` |
| `scripts/run-app.sh` lines 45–86 | `6d6daeccd905540f9b59ecdb426da33c11b22029a5d37c91dd8a987421821c83` |
| `scripts/run-app.sh` lines 88–103 | `8d3f091cdc2916ec42fcaacf980b285c6fa3acc586c82fe9d24598b70b4fc9fa` |
| `scripts/run-app.sh` plist lines 52–84 | `5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58` |
| leaf inline plist lines 950–982 | `5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58` |
| `scripts/package-app.sh` | `7891aef62cfe26caef766572b5258f0fe206b7ccd8b6f039700834276e6a1705` |
| `RanchArtView.swift` | `3ebed0ed43157459a0d137bc296f875fdebc4f2eba6397007ccc86ac35e70754` |
| RanchArt exact algorithm | 27 regular files、0 symlink；`4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab` |

R13 incident/implementation artifacts均保持 immutable：

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

这些值证明 R15 planning 没有对冻结的产品/test、Package、runner、sentinels、两条
App scripts或历史证据造成 drift。R13 whole invocation仍为
`REJECTED_CONTAMINATED`，historical mutation仍为 `UNKNOWN`；R15没有用旧 successful
retry 或新的前瞻性合同反向洗绿该 incident。

## 5. Findings 与 verdict

- P0：**0**
- P1：**0**
- P2：**0**

**APPROVED — 0 P0 / 0 P1**

本批准只关闭 Review14 P1-01，并只允许在**后续新的用户 turn**由牧场主另行授权一次
exact R15 clean re-verification。它不自动开始 test/build/matrix/source gate、
bundle assembly/sign 或 preview，不打开产品/test/App script实施、normal data、
Review02/acceptance、A3、commit、push、merge、release、外部或真实用户权限。
