# R15 Bundle-Provenance Plan Freeze Evidence

> 状态：R15 Bundle-Provenance Candidate Frozen；Review15 Pending；A2 Clean Re-verification Frozen
>
> 日期：2026-07-28
>
> Owner：R15 planner

本证据只冻结牧场主以“继续”批准的Review14 P1-01有界关闭：在不使用
LaunchServices、不修改产品/test/App scripts的前提下，补齐
source→SwiftPM build→fresh `.app` bundle→ad-hoc signed executable→direct launch
的生成与provenance合同。R15 planning没有运行test/build/matrix/source/preview，
没有启动App、访问normal state root、写Review/acceptance或执行Git/发布/外部/
真实用户操作。

## 1. Authorization and bounded write set

R15 planner只写：

1. canonical Stage；
2. canonical total Plan；
3. A2 leaf；
4. A2 `blocked.md`与两个P1 control indexes；
5. 本`plan-freeze-r15.md`。

R15只关闭Review14 P1-01：

- BEGIN只冻结输入、no-process、fresh bundle/state roots与recipe identity，不冒充
  尚未build/sign的final executable hash；
- App build后、launch前依次建立POST_BUILD、PRE_SIGN、LAUNCH_READY证据；
- bundle必须在fresh `mktemp -d` parent下由唯一inline recipe生成，不能读取、
  复用、删除或覆盖现存`.build/AgentLoop.app`；
- `scripts/run-app.sh`与`scripts/package-app.sh`只作immutable sentinels，禁止执行、
  source、截取、pipe给shell或动态抽取plist；
- bootstrap/cold start只按同一signed bundle的exact executable path与own PID顺序
  direct exec；禁止`open`、display name、bundle id、Dock、NSWorkspace、
  LaunchServices或installed-path lookup；
- 任一provenance、isolation、hash、path、PID、sign或技术门失败永久拒绝整个
  boundary，同boundary零修补、重build、重签、换root或retry。

R15没有打开产品/test/schema/API/event/package语义修改，没有放宽normal data、
commit/push/merge/release、外部或真实用户权限。Review15批准本身也不执行R15；
仍需牧场主在后续新turn明确授权一次exact clean re-verification boundary。

## 2. Immutable predecessor and incident chain

### 2.1 Plan freezes

| Artifact | SHA-256 |
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
| `evidence/plan-freeze-r14.md` | `66436eeeedba03e3e0a4411e208c3dd7993f5c2968952c7bff64446232ca011d` |

### 2.2 Plan reviews

| Artifact | SHA-256 / verdict |
|---|---|
| `reviews/12-p1-plan-review.md` | `f27379bfc96a224715e7c6a59ad62fa79d8d97c4d73cf41e890a6ce16957a7c3`; changes required |
| `reviews/12a-p1-plan-review.md` | `a102c49138fcfc1f40b0c780990d8c3ad5ec2302b175b043bde9457164331337`; changes required |
| `reviews/12b-p1-plan-review.md` | `66b81e9e5ea0f74e08706c7367f2e80180601a000c9e84c1bbd4357a9c3b4ec5`; changes required |
| `reviews/12c-p1-plan-review.md` | `db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109`; approved |
| `reviews/13-p1-plan-review.md` | `5203057f2a4a7f04827d9f5e0f20b717e08a31125404483b11f5cad722bda66b`; changes required |
| `reviews/13a-p1-plan-review.md` | `edfb632ce1af2514dfe3168f87e0506fffe3a116f9cd6d3a427874933d399580`; changes required |
| `reviews/13b-p1-plan-review.md` | `b798cffd016865b9441f6c8978da96d7382feb3e5dd51c7555e635bfbca84444`; `APPROVED — 0 P0 / 0 P1` |
| `reviews/14-p1-plan-review.md` | `5bc0adf787dabd1451c53c7fc13df817325b323b030478443f62030bbf28e405`; `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2` |

Review14的唯一P1-01是：R14禁止LaunchServices，却没有冻结一个decision-complete、
可重复的non-LaunchServices bundle生成与just-built source/resources→signed
executable provenance。R14从未打开执行，且没有创建任何`r14-*` execution
artifact。

### 2.3 R13 implementation and incident evidence

| Artifact | SHA-256 |
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
| `reviews/01-p1-a2-review.md` | `5b6a171515404a644abcd05e3afc3840cb1dd4d84d7993f74af48de0692b4dd5`; `CHANGES REQUIRED — 0 P0 / 1 P1` |

R13 whole implementation/completion invocation保持immutable
`REJECTED_CONTAMINATED`：installed PID 74836实际打开normal lock/DB/SHM/WAL，
mutation因缺少incident前content hash保持`UNKNOWN`。后续fresh retry不反向洗绿
该incident；R15 acceptance只能声明R15 boundary内zero normal-data access。

## 3. Exact R15 candidate

Branch：`codex/personal-ai-ranch-p0`  
HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

| Artifact | SHA-256 |
|---|---|
| canonical Stage | `e66fba4cca62a20fae155591384d426fac446eb2e0ccb510820f13fe8fe11289` |
| canonical total Plan | `fc4ca360e2705e8ed3ce00b068c309536efd99f4ac6df2e8d6b1e7cc5606b75d` |
| A2 leaf | `42aeab70d6595358dd22b3474c459b4b05c7c42cf504e396d1e0342ff5398b6e` |
| A2 `blocked.md` | `d944f52221fd6b9bb2efc7c5c34d7ae4800edb052937199164827a1c41bd23d9` |
| P1 Stage control index | `5d43587b2b867c452eb72a6d4b587442a34fd51f86ed7a2bce6d416dcd7d1256` |
| P1 Plan control index | `276ead262d2dbe7cac3ee51162386bf3291bfdd223ab458422942c4fa88c6180` |

六个current surfaces的唯一状态是：

`R15 Bundle-Provenance Candidate Frozen；Review15 Pending；A2 Clean Re-verification Frozen`

两个P1 control index另保留已成立的`A1a/A1b Accepted；R-01 Closed`前缀。唯一
next plan-review artifact是：

`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/15-p1-plan-review.md`

## 4. Frozen R15 bundle-generation and provenance contract

三份canonical与三个control surfaces同义冻结：

1. **BEGIN before execution**：在任何targeted/full test、build、matrix、source
   gate或App launch前exclusive-create R15 artifacts、写unique invocation ID/
   UTC/branch/HEAD/frozen hashes/no-process，并分别创建fresh absolute
   `R15_STATE_ROOT`与`R15_BUNDLE_PARENT`；planned App在BEGIN时必须不存在。
2. **No stale repository bundle**：不得读取、复用、删除或覆盖
   `/Users/muzi/Agent-loop/.build/AgentLoop.app`。现存bundle不属于R15输入。
3. **One exact inline recipe**：`swift build --product AgentLoopApp`成功后，只从
   同一repository `.build` bin dir取`AgentLoopApp`与
   `AgentLoop_AgentLoopApp.bundle`，一次性copy到fresh
   `$R15_BUNDLE_PARENT/AgentLoop.app`；不得调用或修改仓库脚本。
4. **Exact plist**：只写leaf §11.2冻结的inline literal；SHA-256必须为
   `5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58`，
   executable=`AgentLoop`、identifier=`com.muzi.agentloop.dev`。
5. **POST_BUILD**：记录SwiftPM executable realpath/hash/sorted UUID集合；
   source与generated RanchArt均须27 regular files、零symlink、manifest
   `4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab`，
   并记录完整generated resource bundle manifest。
6. **PRE_SIGN**：fresh bundle零清单外文件/symlink；unsigned copied executable
   与build executable逐byte及UUID相等；copied/build resources `diff -qr`相等；
   plist lint/key/hash全部相等。
7. **Single ad-hoc sign**：PRE_SIGN全绿后只执行一次leaf冻结的`codesign --force
   --sign -`，随后`--verify --deep --strict`与`--display --verbose=4`；禁止
   Developer ID、entitlements、timestamp、notary、DMG或zip。
8. **LAUNCH_READY**：记录post-sign executable realpath/hash、UUID、CodeDirectory/
   CDHash与整个signed bundle canonical manifest。codesign会改变Mach-O，
   post-sign hash不与build hash强行相等，但UUID必须相等；resources仍须相等。
9. **Exact artifact paths**：boundary/provenance/bootstrap/cold-start日志分别固定为
   leaf §11.1的四个absolute paths；§2.3全部R15 paths必须先不存在并
   exclusive-create，禁止自选、truncate、覆盖或复用。
10. **Direct launch only**：bootstrap与cold start每次launch前重核
    LAUNCH_READY identity，只以`AGENTLOOP_STATE_DIR=<fresh root>`、
    `AGENTLOOP_UI_PREVIEW=1`和exact `$R15_APP_EXEC`启动，PID只取`$!`；
    `pgrep`不得用于选择进程。
11. **Same signed bundle**：bootstrap退出且own PID/child/global process归零后，
    cold start复用同一bundle/executable hash与manifest，明确
    `bundle_rebuilt=false`、`bundle_resigned=false`；两个launch顺序且零重叠。
12. **No LaunchServices or name lookup**：禁止`open`、`scripts/run-app.sh`、
    `scripts/package-app.sh`、display name、bundle ID、frontmost-name、Dock、
    NSWorkspace、LaunchServices fallback、installed-path lookup与post-quit UI call。
13. **Fail closed**：任一source/build/resource/plist/copy/signature/UUID/manifest/
    path/hash/env/PID/isolation/normal-root/unknown-child/provider/evidence mismatch，
    整个boundary立即`REJECTED_CONTAMINATED`；同boundary不得换root、修补、
    rebuild、recopy、resign、重启或覆盖负证据。
14. **END and preservation**：仅全部gates通过后写UTC END、final identity、
    matrix restoration、normal-open count=0与no-process/no-child；fresh bundle与
    state roots在Review02前不清理。

## 5. Zero product/test drift

R15 planning前后以下15项逐项相同：

| Path | Before = After SHA-256 |
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

## 6. Immutable sentinels, App inputs, and control-script exception

| Artifact / boundary | SHA-256 |
|---|---|
| `Sources/AgentLoopCore/Support/StateDirectoryLock.swift` | `863819791bbbead28c7fb0ba80540703fa275977682c846fbb8b415ce512c363` |
| `Sources/AgentLoopTestSuite/SupportTests.swift` | `eb5f8392870a8cca3a0e9729cc17082d259346b8187ff68cde9ee71ff1497386` |
| `Sources/AgentLoopCore/Work/PlanningProviderResolver.swift` | `094319b38c287a9265311fa60eb3c0e289555c6676dd0e3cfc0345cf289907c5` |
| `Sources/AgentLoopCore/Rumination/RuminationResult.swift` | `7ec1e5a45bc99d6af0270e84c535e59aa04cd57ae02e9f60537ec94c699b8be7` |
| `Sources/AgentLoopCore/Rumination/RuminationMaterializer.swift` | `f0cd523ddf43789a9b0485bbcd0ee7b860b43a129795e06b1483c077d522623f` |
| `Sources/AgentLoopCore/Database/EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` |
| `Sources/P1MigrationMatrixRunner/main.swift` | `db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267` |
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| AppDatabase migrator lines 21–612 | `5bbb555016a64801c25be3634b0fcfcca0da8fe3b4d3cda493b0df3851a8ccff` |
| Stage §18.1 lines 3850–4036 predecessor boundary | `fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2` |
| `scripts/verify-p1-migrations-sqlite-matrix.sh` entry | `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c` |
| `scripts/run-app.sh` | `5b34e5e98a0e91b4087e20525c3aba81e7955475865d2af70e6ae65736e7997b` |
| `scripts/run-app.sh` lines 45–86 | `6d6daeccd905540f9b59ecdb426da33c11b22029a5d37c91dd8a987421821c83` |
| `scripts/run-app.sh` lines 88–103 | `8d3f091cdc2916ec42fcaacf980b285c6fa3acc586c82fe9d24598b70b4fc9fa` |
| dev Info.plist literal, lines 52–84 | `5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58` |
| `scripts/package-app.sh` | `7891aef62cfe26caef766572b5258f0fe206b7ccd8b6f039700834276e6a1705` |
| `Sources/AgentLoopApp/Views/CodingRanch/RanchArtView.swift` | `3ebed0ed43157459a0d137bc296f875fdebc4f2eba6397007ccc86ac35e70754` |
| `Sources/AgentLoopApp/Resources/RanchArt` canonical 27-file manifest | `4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab` |

R15 planning与Review15期间matrix script逐字不变，line 115继续锁predecessor Stage
`a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f`。
只有Review15批准且后续新用户授权以BEGIN消费后，R15 matrix前可继承已冻结的唯一
例外：机械替换line 115唯一64-hex值为最终R15 Stage
`e66fba4cca62a20fae155591384d426fac446eb2e0ccb510820f13fe8fe11289`。
matrix无论成功或失败都必须恢复predecessor值与entry script hash；其他byte不得
改变。该临时单值delta必须单列，不能声称absolute zero-script delta；最终script
delta必须为0。

## 7. Control consistency and next gate

- 六个current surfaces状态、authority、next writer与stop gate同义；
- Review14及R14 freeze保持immutable changes-required predecessors；
- R13 incident、Review01与全部implementation artifacts保持immutable；
- Open Questions在Stage §29、总Plan §19与leaf §13均精确为“无。”；
- `git diff --check`通过；
- R15 planning没有运行产品/test/build/matrix/source/preview，没有启动App或访问
  normal data；
- 产品/test、Package、runner与两条App scripts全部zero drift；matrix script仍为
  planning-entry hash。

下一步只能由未参与R15修订、bundle assembly或preview的职责隔离plan reviewer
只写：

`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/15-p1-plan-review.md`

Reviewer必须独立重算本freeze中的canonical/control/product/test/script/
historical hashes，并检查Review14 P1-01、BEGIN→POST_BUILD→PRE_SIGN→
LAUNCH_READY时序、fresh bundle、exact plist/resources/codesign、absolute artifact
paths、direct-exec/PID、matrix临时例外与mandatory restoration、one-shot failure
contract及current gate。

Review15达到`APPROVED — 0 P0 / 0 P1`前，禁止R15 targeted/full test、build、
matrix、source gate、bundle assembly/sign、preview、产品/test/script修改、
Review02/acceptance、A3、commit、push、merge、release、normal-data、外部与真实
用户操作。Review15通过也只打开后续新用户授权turn中的一次clean
re-verification，不自动开始执行。
