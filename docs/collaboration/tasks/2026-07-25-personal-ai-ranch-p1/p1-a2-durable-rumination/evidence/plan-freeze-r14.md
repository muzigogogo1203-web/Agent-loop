# R14 Incident-Disposition Plan Freeze Evidence

> 状态：R14 Incident-Disposition Candidate Frozen；Review14 Pending；A2 Clean Re-verification Frozen
>
> 日期：2026-07-27
>
> Owner：R14 planner

本证据只冻结牧场主本轮“继续，授权”所批准的Review01 P1-01 plan-level
disposition与后续one-shot clean re-verification boundary。R14 planning没有修改
产品/test/script或任何R13 historical artifact，没有运行test/build/matrix/source/
preview，没有访问normal state root，也没有写Review/acceptance或执行Git/发布/
外部/真实用户操作。

## 1. Authorization and bounded write set

R14 planner只写：

1. canonical Stage；
2. canonical total Plan；
3. A2 leaf；
4. A2 `blocked.md`与两个P1 control indexes；
5. 本`plan-freeze-r14.md`。

R14只定义：

- R13 whole implementation/completion invocation为immutable
  `REJECTED_CONTAMINATED` historical evidence；
- installed PID 74836打开normal lock/DB/SHM/WAL是真实access，mutation因无
  pre-incident content hash保持`UNKNOWN`；
- Review14批准后才可由新的用户授权turn开始一个非追溯、one-shot、zero-product/
  test-delta clean re-verification；
- distinct R14 artifacts、exact BEGIN/END boundary、full-path/PID操作、
  fail-once/no-retry、Review02与scoped acceptance wording。

R14没有把旧incident写成未发生，没有把旧成功retry追认为clean，没有放宽normal
data、产品/test、schema/API/event/package、commit/push/merge/release或任何外部
权限。

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

这些artifact共同证明：技术门通过与R13 normal-root incident都是真实历史。R14
freeze不选择性删除任一侧。

## 3. Exact R14 candidate

Branch：`codex/personal-ai-ranch-p0`  
HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

| Artifact | SHA-256 |
|---|---|
| canonical Stage | `5a128120d8fc815c207c93dc06a9aa0c016f48ded275107564d1df6dae0d7f8b` |
| canonical total Plan | `c8f6240eb6a5622390edf58278a8a2890c06f659077babe4667a10b9b4d4b028` |
| A2 leaf | `1f9e2ea7140bf9c0daa5ab7004897fd5a97e6386f64ae7e20a4a16b5c0c08665` |
| A2 `blocked.md` | `81a5a955ed0b74261ce7e65a0afa83088119a74d154f7050e3571dd60fc69af1` |
| P1 Stage control index | `40c3cc7eeab2831eaf6582ffa83ac5bcc43be6e727fd088de79f36337244a372` |
| P1 Plan control index | `a1cde01d606e1611761a856479791e5b0163209319a6ae083e600bc06fb89a89` |

六个current surfaces的唯一状态是：

`R14 Incident-Disposition Candidate Frozen；Review14 Pending；A2 Clean Re-verification Frozen`

两个P1 control index另保留`A1a/A1b Accepted；R-01 Closed`前缀。唯一next plan
review artifact是
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/14-p1-plan-review.md`。

## 4. Frozen R14 disposition and boundary

三份canonical与三个control surfaces同义冻结：

1. R13 whole invocation为`REJECTED_CONTAMINATED`；normal access已发生，
   historical mutation unknown，Review01 verdict保持成立；
2. 旧fresh retry只证明方法可行，不构成R14 green evidence；
3. Review14通过只打开后续新的用户授权turn中的一次clean re-verification，不打开
   产品/test修改；
4. boundary在任何targeted/full test、build、matrix、source gate或App launch前
   写BEGIN，记录unique ID/UTC/branch/HEAD/hashes/no-process/fresh root/exact
   executable realpath+hash；
5. App/UI只按exact repository path/PID操作，禁止display-name/bundle-id/
   LaunchServices/installed path；退出后零UI call；
6. normal root不得被list/find/stat/hash/SQLite-open/export/cleanup/reset/rebuild；
   只允许从进程`lsof`输出比较open-file metadata；
7. 任一normal-root access、第二App、wrong path/hash/env/PID、unknown child、
   provider dispatch或证据缺口使整个boundary永久失败，零same-boundary retry；
8. targeted 41、full RunTests、App/release builds、release/debug seam、双SQLite
   full matrix、source/privacy/scope/hash/diff与fresh preview均写distinct R14
   artifacts；
9. `impl-report-r14.md`后只能由新reviewer写`reviews/02-p1-a2-review.md`；
   Review02零P0/P1后才打开acceptance；
10. acceptance同时披露R13 incident/mutation unknown，只声明R14 boundary内zero
    normal-data access，不得声明A2历史零访问。

## 5. Zero product/test drift

R14 planning前后以下15项逐项相同：

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

## 6. Immutable sentinels and control script

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
| matrix script R14 entry | `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c` |

R14 planner没有修改matrix script。Review14批准后、R14 matrix前只可机械替换唯一
`expected_stage_hash`为R14 Stage hash；恢复predecessor Stage
`a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f`
必须恢复entry script hash，其他bytes不得改变。

## 7. Control consistency and next gate

- 六个current surfaces状态、authority、next writer与stop gate同义；
- Review13B只作为immutable approved predecessor；Review01只作为immutable
  changes-required predecessor；
- Open Questions在Stage §29、总Plan §19与leaf §13均为“无。”；
- `git diff --check`通过；
- R14 planning没有运行产品/test/build/matrix/preview，也没有访问normal data。

下一步只能由未参与R14修订的职责隔离plan reviewer只写：

`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/14-p1-plan-review.md`

Review14达到`APPROVED — 0 P0 / 0 P1`前，禁止R14 clean invocation、任何
targeted/full test、build、matrix、source gate、preview、产品/test/script修改、
Review02/acceptance、A3、commit、push、merge、release、normal-data、外部与真实
用户操作。Review14通过也只打开后续新的用户授权turn中的一次clean
re-verification，不打开产品代码实施。
