# P1-A2 Leaf Plan — Durable Rumination

> 状态：**R27 永久 REJECTED_CONTAMINATED — 唯一 full 651/652；Shell timeout 测量边界失败；无 later gates/END；R28 Measurement-Boundary Candidate Frozen；fresh driver/235-entry manifest/freeze present；Review28 pending；A2 blocked**
>
> 日期：2026-08-10
>
> 分支：`codex/personal-ai-ranch-p0`
>
> 进入 HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> 上位权威：P1 Stage §6.4/§20–§22/§28 与 P1 总 Plan §3.3/§10–§13/§18

本 leaf 记录已完成但被Review01判为`REJECTED_CONTAMINATED`的R13 implementation、
Review14对R14 candidate的immutable changes-required结论、Review15批准的R15
plan，以及随后在BEGIN attestation中因executor false negative而永久
`REJECTED_CONTAMINATED`的R15 invocation。Review16虽批准R16 plan，但获四哈希授权的
R16 caller在pre-BEGIN进程缺席探针发生新的Bash `ERR` trap false positive；授权未
消费且整轮零写入。R17虽关闭该已定位的status-capture根因类，但Review17以
`CHANGES REQUIRED — 0 P0 / 1 P1`确认RanchArt结构门仍错误位于授权消费后；R17从未
执行。R18把同一phase-aware RanchArt verifier的零写入preflight移到消费前的最后
一个门，并在activation后重新读取及记录证据；R18-A再把R15 containment时
canonical-empty观察与2026-08-02 current `ABSENT`分层，把两个exact identities冻结为
absorbing tombstones，以联合parent enumeration fail closed。职责隔离Review18
`e0ee95f3703d73810d756410373c1da65fb1e08b08f6d7f74555e8095a12608b`随后以
`CHANGES REQUIRED — 0 P0 / 1 P1`证明R18的newline pathname transport不是单射；R18
从未获plan approval、四-hash授权或执行。R19以单一NUL pipeline关闭该同根P1，
获Review19批准及后续四hash执行授权并成功BEGIN；41/41 A2 tests通过，但权威full
RunTests 651/652，唯一`slowActiveStreamDoesNotIdleTimeout`以
`idle script exhausted`失败，故R19永久`REJECTED_CONTAMINATED`。11个actual
artifacts、缺失screenshot、两个exact empty roots及zero-product/test drift全部
immutable。R20以两个具名文件内的debug-only package-internal deterministic Clock seam
关闭该wall-clock nondeterminism，唯一full RunTests 652/652、46/46与LAUNCH_READY
通过；但release Core `--product`在automatic product上退化default graph，并因release
TestSuite caller/callee配置错配永久失败。R21只修该release configuration根因：Core
保持R20 final bytes，TestSuite只增加三对matching DEBUG guards，同时以target-exact
Core/TestSuite release build和四object双向symbol门重新打开fresh verification；不
产生第二套产品决定。任一文字冲突、清单外 requirement、unknown failure或
Open Questions非空都必须写`blocked.md`并停止；implementer不得自行解释。

## 1. 进入门与停止门

A2 只有在以下全部成立后才可开始产品/测试实施：

1. A1b implementation Review
   `8c96b742285da1c1999c5360071728cbdf287cfeffeb6b25e281485336e0b1a0`
   为 `APPROVED — 0 P0 / 0 P1`；
2. A1b acceptance
   `efe4d20a7cb4dc3f61d028637a6705d3ed56d4fdd5596ebc3cb993d94481bf1e`
   为 `ACCEPTED`，22/22 PASS；
3. R15 freeze
   `e5ad3967f2e2b26a2bbf8b2ef7be405e8430cc30a82d51a7cb5f51926a99e3d7`、
   Review15
   `fbaa9612588c39cb5d99e95d9b68e00a234510e325abf5823c15f0b1eb8ecc05`
   及全部R15失败证据保持immutable；R16–R18 chains/absence、Review19 approved plan、
   R19 failed boundary/11 artifacts/两个exact empty roots保持immutable；R20
   freeze/Review/driver/manifest、永久release failure、11 repository artifacts、缺失
   screenshot、empty state root与含exact signed App的bundle parent保持immutable；
   `evidence/plan-freeze-r21.md`生成后记录的Stage、总Plan、leaf、blocked、两个control、
   reviewed BEGIN-only driver与155-entry static manifest exact hashes匹配当前bytes；R12–R14
   全部freeze/Review、R13
   `impl-report.md`、全部old logs/evidence/screenshot与Review01保持immutable
   history。Review01 SHA-256
   `5b6a171515404a644abcd05e3afc3840cb1dd4d84d7993f74af48de0692b4dd5`
   且verdict仍为`CHANGES REQUIRED — 0 P0 / 1 P1`；
4. Review14保持immutable
   `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2` predecessor，SHA-256为
   `5bc0adf787dabd1451c53c7fc13df817325b323b030478443f62030bbf28e405`；
   Review15与Review16都是immutable approved plan predecessors；Review17与Review18
   都是immutable `CHANGES REQUIRED — 0 P0 / 1 P1` predecessors；Review19与Review20
   是immutable `APPROVED — 0 P0 / 0 P1` predecessors。未参与R21六面、driver、manifest或freeze
   修订的reviewer只写
   `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/21-p1-plan-review.md`
   并在R21 exact hashes上判定`APPROVED — 0 P0 / 0 P1`。Review21必须核对155/155、
   R20 manifest 132+8 preservation、完整R20 failure/partial-success evidence、Core
   immutable + TestSuite one-file guard exception、target-exact builds、source-strip proof、
   release-zero/debug-positive四object symbol gates、fresh names与无环链；
5. current production single-writer entry invariant可静态验证：AppStore
   lifetime-held `StateDirectoryLock`在同state root唯一production
   `AppDatabase(path:)`之前成功取得，两个lock文件匹配§2.4冻结hash；任一项漂移
   都立即停止，不得开始红测/实施；
6. branch/HEAD/worktree、允许文件 baseline 与 immutable manifest 已记录；
7. 没有 commit、push、merge、release、normal/preview 数据重置或真实用户操作；
8. §2.5冻结的15个R13产品/test hashes及§2.7两个R20-final R21 entry baselines逐项
   匹配，matrix与两条App脚本仍为entry hashes；Review21批准后仍须由**后续新的
   用户turn**按`freeze, Review21, driver, manifest`顺序提供四个final hash并明确
   授权；此前不得实施TestSuite guard或执行任何test、build、matrix、source gate、bundle、sign
   或App launch。

Review12 已对旧 candidate 判定 `CHANGES REQUIRED — 0 P0 / 2 P1`；Review12A
已对 R12-C candidate 判定 `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，immutable
SHA-256 为
`a102c49138fcfc1f40b0c780990d8c3ad5ec2302b175b043bde9457164331337`。Review12B
已对 R12-D candidate 判定 `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，immutable
SHA-256 为
`66b81e9e5ea0f74e08706c7367f2e80180601a000c9e84c1bbd4357a9c3b4ec5`。
Review12C已是R12-F历史approved predecessor；Review13在R13 exact hashes上判定
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，immutable SHA-256为
`5203057f2a4a7f04827d9f5e0f20b717e08a31125404483b11f5cad722bda66b`。
Review13B已批准R13 implementation；R13技术门全绿，但其首次preview因display-name
lookup启动installed PID 74836并打开normal lock/DB/SHM/WAL，整个R13 invocation
固定为`REJECTED_CONTAMINATED`，mutation为`UNKNOWN`。后续成功retry不构成任何
clean evidence，也不改变Review01。R14随后只定义前瞻性clean boundary；Review14确认
其incident处置诚实，但以P1-01指出source/build→bundle→executable provenance
不闭合，因此R14从未打开任何执行，也没有创建任何`r14-*`执行artifact。

Review15随后批准R15 plan；牧场主在新的turn授权后，R15 BEGIN创建fresh roots并
消费授权，但自定义zsh hash helper在Review12C expected/actual逐字相同的情况下
错误进入mismatch分支。R15因此永久为`REJECTED_CONTAMINATED`；没有运行
test/build/matrix/source/bundle/preview，没有创建planned App，也没有打开
Review02/acceptance。其更底层micro-trigger证据不足，R19没有宣称修复该未知机制，
而是用reviewed Bash driver、static manifest与`shasum --strict -c`整体替换该风险类。

Review16随后以
`71f16eceef429f7d02fe8908c4609b9bd0b0b98b44c68b579a75ced2ac9d9824`
判定R16 plan `APPROVED — 0 P0 / 0 P1`。牧场主在后续新turn逐字提供freeze、
Review16、driver、manifest四个terminal hashes并授权R16 clean execution；external
caller的四anchors与110/110 static manifest均通过。driver进入
`pre_begin_processes`后，第一个`/usr/bin/pgrep -x AgentLoop`以正常“进程不存在”
返回`rc=1`，但全局继承的`ERR` trap在赋值和`case`处理前退出。由此确认R16失败是
reviewed driver status capture根因，而非进程存在、仓库漂移或清单失败。
`evidence/r16-clean-boundary.log`从未创建，唯一授权消费点未到达；12个R16 runtime
paths与`/private/tmp/agentloop-r16-state.*`、`/private/tmp/agentloop-r16-bundle.*`
均不存在，且没有运行任何test/build/matrix/source/bundle/sign/preview。R16不得
写成BEGIN或`REJECTED_CONTAMINATED`，也不得重跑当前caller。

Review17随后判定`CHANGES REQUIRED — 0 P0 / 1 P1`，R17从未执行；Review18同样拒绝
R18/R18-A且未执行。Review19批准后R19获四hash授权并BEGIN，41/41通过但full 651/652；
其boundary永久失败，后续门未运行。R20随后通过Review20并获四hash授权；full
652/652与LAUNCH_READY后在release Core build永久失败。R21 Review21未通过时，本文件
只可被读取，不可据此运行R21 caller/BEGIN、实施test guard或修改任何其他
产品/test/script、写Review02/acceptance。Review21通过也不自动执行，只允许牧场主
在后续新用户turn提供四个terminal hashes并授权一次fresh one-file guard
implementation/clean re-verification。该
boundary内任一unfiltered full test/build/matrix/source/preview red、compile/discovery
error、未知错误、hash/scope drift、A1b regression、normal-root access、第三个source
delta、第二App、wrong path/env/PID或证据缺口都使整个invocation永久失败；不得在同一
boundary retry，也禁止A3。

## 2. 精确允许范围

### 2.1 产品文件

以下13个文件是R13 historical implementation allowlist。R21不允许再修改其中任何
byte，只以§2.5 current hash作为clean re-verification输入：

1. `Sources/AgentLoopCore/Work/DurableWork.swift`
2. `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`
3. `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
4. `Sources/AgentLoopCore/Database/AppDatabase.swift`
5. `Sources/AgentLoopCore/Ingestion/IngestionRecords.swift`
6. `Sources/AgentLoopCore/Ingestion/FeedService.swift`
7. `Sources/AgentLoopCore/Rumination/RuminationService.swift`
8. `Sources/AgentLoopCore/Rumination/RuminationParser.swift`
9. `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
10. `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
11. `Sources/AgentLoopApp/AppStore.swift`
12. `Sources/AgentLoopApp/CodingRanchContracts.swift`
13. `Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift`

### 2.2 测试文件

以下两个文件是R13 historical test allowlist。R21同样要求byte-identical：

1. `Sources/AgentLoopTestSuite/CodingRanchTests.swift`
2. `Sources/AgentLoopTestSuite/DurableWorkTests.swift`

不得新增 test target、test file 或 AgentLoopApp dependency。

### 2.3 Control tooling 与 task artifacts

R13当前matrix script SHA-256为
`75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`。
R21 planning/Review21期间它必须逐字不变。Review21批准且后续新的用户授权turn以
BEGIN消费后、R21 matrix前只可继承R12-A例外，机械更新line 115唯一
`expected_stage_hash` 64-hex为最终R21 Stage hash；matrix完成或失败后的mandatory
containment必须恢复predecessor Stage
`a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f`
并恢复上述entry script hash，其他byte不得改变。该exact临时单值delta必须单列
报告，不得表述为absolute zero-script drift；恢复不是retry，不得继续失败的门。

以下R13 artifact与Review01全部immutable，不得覆盖、追加或重命名：

- `red-tests.log`
- `verify.log`
- `build.log`
- `migration-matrix.log`
- `impl-report.md`
- `evidence/source-gates.log`
- `evidence/hash-manifest.log`
- `evidence/preview-bootstrap.log`
- `evidence/preview-cold-start.log`
- `evidence/preview-smoke.png`
- `reviews/01-p1-a2-review.md`

以下R15 planning/execution evidence同样全部immutable，不得覆盖、追加、删除、
truncate、重命名或作为R19输入/输出root复用：

- `r15-targeted-tests.log`
- `r15-verify.log`
- `r15-build.log`
- `r15-migration-matrix.log`
- `impl-report-r15.md`
- `evidence/r15-clean-boundary.log`
- `evidence/r15-bundle-provenance.log`
- `evidence/r15-source-gates.log`
- `evidence/r15-hash-manifest.log`
- `evidence/r15-preview-bootstrap.log`
- `evidence/r15-preview-cold-start.log`
- `evidence/plan-freeze-r15.md`
- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/15-p1-plan-review.md`

`evidence/r15-preview-smoke.png`必须继续不存在。R15 durable evidence只证明
containment时roots
`/private/tmp/agentloop-r15-state.Zq6Jvm`与
`/private/tmp/agentloop-r15-bundle.2xROcy`被观察为canonical empty；2026-08-02
pre-freeze只读复核确认两个exact paths当前均为`ABSENT`，消失原因固定记录为
`UNKNOWN`，不得声称连续保全。R18-A把当前absence冻结为absorbing tombstone：任何
node重现，即使是canonical empty directory，也必须fail closed。planned
`AgentLoop.app`继续不存在；R21同样禁止访问、写入、创建、删除、清理或复用这两个root。

以下R16 planning chain全部immutable，不得覆盖、追加、删除、truncate、重命名或
回写新hash：

- `evidence/r16-begin.sh`：
  `ffa61fa7c8c281cdb8dfb853b38aafce9536ddcc276e18d64c082de8887b55b0`
- `evidence/r16-entry.sha256`：
  `0c2f5dc59e5f0e193214d1c8532a91818a339abdfb3150177c680fe61f8a0b1e`
- `evidence/plan-freeze-r16.md`：
  `c10ae51ad78b414aab18c3785b79aac49feb73c47ac5fdcb896ca874ae319867`
- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/16-p1-plan-review.md`：
  `71f16eceef429f7d02fe8908c4609b9bd0b0b98b44c68b579a75ced2ac9d9824`

R16 external caller的四锚点与110/110 manifest通过，但driver在pre-BEGIN
`pgrep rc=1`处停止；`evidence/r16-clean-boundary.log`及其余11个runtime paths
全部不存在，`/private/tmp/agentloop-r16-state.*`与
`/private/tmp/agentloop-r16-bundle.*`也不存在。该absence是R19–R21必须保全并在BEGIN前
重证的负事实；不得补写R16日志、创建R16 root、复用R16 runtime names或把
`authorization_consumed=false`改写为已消费。

以下R17 planning chain全部immutable，不得覆盖、追加、删除、truncate、重命名或
回写新hash：

- `evidence/r17-begin.sh`：
  `cf1baab60b3e799b1780b20d1dfc7887bdd2c7e85e241fdb8abcd4ad8c04321f`
- `evidence/r17-bash32-probes.sh`：
  `5ee154b56d10322fd70ad34698a7f0fd81122862d25b9bbb05b1db18bee67199`
- `evidence/r17-entry.sha256`：
  `7d10c5c6747cdf0e557befc76a62ea101f2fc4168a49d8076bedd3331d8cbd17`
- `evidence/plan-freeze-r17.md`：
  `bdbbbd025bbe7cf57032ae2276a6a559043f60e47cebad1ceac43f992e644e1f`
- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/17-p1-plan-review.md`：
  `c6838d3c5a9fcfef80dc9db4abf560af712e3175372a163edccb72197daf3dbe`，
  `CHANGES REQUIRED — 0 P0 / 1 P1`

R17没有执行授权，也没有运行caller/BEGIN或任何后续门；12个R17 runtime paths与
`/private/tmp/agentloop-r17-state.*`、`/private/tmp/agentloop-r17-bundle.*`全部
absent。该absence与Review17唯一P1-01是R19–R21必须保全并在BEGIN前重证的immutable
历史；不得补写R17日志、创建R17 root、复用R17 runtime names或把R17写成执行过。

以下R18/R18-A planning chain与Review18 verdict全部immutable，不得覆盖、追加、删除、
truncate、重命名、重跑或作为R19–R21输入/输出root复用：

- `evidence/r18-begin.sh`：
  `911bbbc70556e41122cfdcc90048e504eee3480246b338131153856d524d7af9`
- `evidence/r18-entry.sha256`：
  `71e512a25e6e9bc0d024a53ad2502b55a378a82b39044a341930e1df440cfc2a`
- `evidence/plan-freeze-r18.md`：
  `62bbf93031371659e7ad2d4c60aac002eb13ed0915854f741e40251c9c2c1e76`
- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/18-p1-plan-review.md`：
  `e0ee95f3703d73810d756410373c1da65fb1e08b08f6d7f74555e8095a12608b`，
  `CHANGES REQUIRED — 0 P0 / 1 P1`

R18/R18-A从未获得plan approval、四-hash授权，也没有运行external caller/BEGIN或任何
后续门；12个R18 runtime paths与`/private/tmp/agentloop-r18-state.*`、
`/private/tmp/agentloop-r18-bundle.*`全部absent。上述四项只构成immutable失败审计链，
永不构成R19、R20或R21执行授权；不得补写R18日志、创建R18 root或把Review18改写为approved。

R19 freeze/Review/driver/manifest与实际11个artifacts全部immutable。后者精确为：

- 非空：`r19-targeted-tests.log`、`r19-verify.log`、`impl-report-r19.md`、
  `evidence/r19-clean-boundary.log`、`evidence/r19-hash-manifest.log`；
- empty：`r19-build.log`、`r19-migration-matrix.log`、
  `evidence/r19-bundle-provenance.log`、`evidence/r19-source-gates.log`、
  `evidence/r19-preview-bootstrap.log`、`evidence/r19-preview-cold-start.log`；
- `evidence/r19-preview-smoke.png`保持absent；exact roots
  `/private/tmp/agentloop-r19-state.dNgUXh`与
  `/private/tmp/agentloop-r19-bundle.49xVDm`保持real non-symlink empty。

不得覆盖、append、truncate、补写、删除、清理、重命名或复用上述R19 evidence/roots。

R20 planning/Review/implementation chain与actual artifacts现均为immutable history。其
四hash精确为freeze
`0b698b59f214f23c26db88fd53763c4a600becaf898a716344f9d666ac2e8e07`、Review20
`e70ea918e00c334a452f87e4fa8f44d5bfc754b042872a9f0a0ec13015e7c68e`、driver
`840edee2dad7710f17e1b9bb8dcaa1484224ba0784b636f472bc2934f7e7eaeb`、manifest
`2f8a6f4f786a2b5f432b2dbf7dcdc7208788d0b9ef5b9cdaa9de422bfaf88e81`。invocation
`r20-98452cde-0ff4-4b66-b3f6-8085eb045a6f`永久为`REJECTED_CONTAMINATED`，失败
phase=`release_core_build`、reason=`release_AgentLoopCore_build_failed_rc_1`、exit=1、
retry=false；唯一full RunTests 652/652、同log 46/46、debug App build、LAUNCH_READY及
全部runtime evidence仍是真实partial-success evidence，不构成A2完成。

R20 actual 11个repository artifacts全部immutable，不得覆盖、append、truncate、删除、
清理、重命名或作为R21输出复用：

- `r20-targeted-tests.log`
- `r20-verify.log`
- `r20-build.log`
- `r20-migration-matrix.log`
- `impl-report-r20.md`
- `evidence/r20-clean-boundary.log`
- `evidence/r20-bundle-provenance.log`
- `evidence/r20-source-gates.log`
- `evidence/r20-hash-manifest.log`
- `evidence/r20-preview-bootstrap.log`
- `evidence/r20-preview-cold-start.log`

`evidence/r20-preview-smoke.png`保持absent；state root
`/private/tmp/agentloop-r20-state.3QwlQa`保持real non-symlink empty；bundle parent
`/private/tmp/agentloop-r20-bundle.30V5RH`保持real non-symlink directory且direct child
只能是exact `AgentLoop.app`。该signed App executable SHA-256固定为
`d55fc10e674b77b480a85de46137eff40d40bd94b27c8e33b0d49f55d40a049c`，Info.plist为
`5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58`，signed bundle
manifest为`06e063d4fdd541a808c78eacc5b34ddfd64874a3ab1648bbfe6bf74646db8170`。

R21 planner只可创建或修订：

- `evidence/r21-begin.sh`
- `evidence/r21-entry.sha256`
- `evidence/plan-freeze-r21.md`
- 本leaf及freeze列出的另外五个canonical/control surfaces

未参与R21修订的职责隔离plan reviewer唯一写
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/21-p1-plan-review.md`。
Review21批准本身不执行。只有牧场主在后续新turn按`freeze, Review21, driver,
manifest`顺序用四个final hashes明确授权后，implementer才可运行reviewed driver、
只实施§2.7的TestSuite三对matching guards并exclusive-create：

- `r21-targeted-tests.log`
- `r21-verify.log`
- `r21-build.log`
- `r21-migration-matrix.log`
- `impl-report-r21.md`
- `evidence/r21-clean-boundary.log`
- `evidence/r21-bundle-provenance.log`
- `evidence/r21-source-gates.log`
- `evidence/r21-hash-manifest.log`
- `evidence/r21-preview-bootstrap.log`
- `evidence/r21-preview-cold-start.log`
- `evidence/r21-preview-smoke.png`

fresh roots只能是`/private/tmp/agentloop-r21-state.*`与
`/private/tmp/agentloop-r21-bundle.*`；两者由reviewed driver在授权消费后创建，初始
为空、互不嵌套且不得复用任何旧root。上述12个paths与两个root globs在BEGIN前必须
全部absent。

新的independent implementation reviewer唯一写`reviews/02-p1-a2-review.md`；
acceptance owner只在Review02零P0/P1后写`acceptance.md`。implementer不写Review/
acceptance；planner/reviewer不回写实现或验证日志。任何R21 execution path在BEGIN前
已存在都立即停止；不得覆盖、truncate或把旧失败boundary改名复用。

### 2.4 Immutable 文件与结构

以下必须逐字不变：

| Path / boundary | A2 entry SHA-256 / invariant |
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
| `scripts/run-app.sh` | `5b34e5e98a0e91b4087e20525c3aba81e7955475865d2af70e6ae65736e7997b`；只作immutable机械来源，禁止执行/截取/source |
| `scripts/package-app.sh` | `7891aef62cfe26caef766572b5258f0fe206b7ccd8b6f039700834276e6a1705`；禁止执行 |
| `scripts/run-app.sh` lines 45–86 | `6d6daeccd905540f9b59ecdb426da33c11b22029a5d37c91dd8a987421821c83`；R21 inline recipe不得运行该slice |
| `scripts/run-app.sh` lines 88–103 | `8d3f091cdc2916ec42fcaacf980b285c6fa3acc586c82fe9d24598b70b4fc9fa`；LaunchServices forbidden sentinel |
| dev `Info.plist` exact literal | `5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58` |
| `Sources/AgentLoopApp/Views/CodingRanch/RanchArtView.swift` | `3ebed0ed43157459a0d137bc296f875fdebc4f2eba6397007ccc86ac35e70754` |
| `Sources/AgentLoopApp/Resources/RanchArt` canonical 27-file manifest | `4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab`；算法见§11.2 |
| AppDatabase migrator block | `5bbb555016a64801c25be3634b0fcfcca0da8fe3b4d3cda493b0df3851a8ccff` |
| Stage §18.1 literal | 187 lines；`fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2` |

不得新增/修改 migration、schema、DDL、trigger、EventKind、target/dependency、
RunTests graph、persistent phase、第二 supervisor 或 provider-returned checkpoint。

### 2.5 Immutable R19 implementation candidate

R19 clean invocation曾逐项匹配以下bytes；R21仍要求这15项byte-identical：

| Path | R19 entry SHA-256 |
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

R19还锁定以下incident/review chain，不得以clean evidence替换：

| Historical artifact | SHA-256 |
|---|---|
| `impl-report.md` | `4702259ad90b367538ede4cc4a7a98cfee131b3724f60d1a0ac54cfdeed50afc` |
| `reviews/01-p1-a2-review.md` | `5b6a171515404a644abcd05e3afc3840cb1dd4d84d7993f74af48de0692b4dd5` |
| `evidence/preview-bootstrap.log` | `9ec0fd18369e4d7f3e9f78afb59e55a8072dbee7e0611f5c74c68df414589bd0` |
| `evidence/preview-cold-start.log` | `04f0b602b465a7c8521a8ef9af058ce47477ba380f4ef4243ef33ce323017795` |
| `evidence/preview-smoke.png` | `8623453541c08c538eab784bac1872fee86e1e497c553ce9576b50ae4f84a9c3` |
| `evidence/plan-freeze-r14.md` | `66436eeeedba03e3e0a4411e208c3dd7993f5c2968952c7bff64446232ca011d` |
| `reviews/14-p1-plan-review.md` | `5bc0adf787dabd1451c53c7fc13df817325b323b030478443f62030bbf28e405`；`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2` |
| `evidence/plan-freeze-r15.md` | `e5ad3967f2e2b26a2bbf8b2ef7be405e8430cc30a82d51a7cb5f51926a99e3d7` |
| `reviews/15-p1-plan-review.md` | `fbaa9612588c39cb5d99e95d9b68e00a234510e325abf5823c15f0b1eb8ecc05`；`APPROVED — 0 P0 / 0 P1` |
| `evidence/r15-clean-boundary.log` | `53eb91b840c5c8997fbc9da02d391f210f27b45d73b5e2431a6280a36110ab3b`；`REJECTED_CONTAMINATED` |
| `evidence/r15-hash-manifest.log` | `1589d8d29cf3f8ca9e558c4ac6d4008bdd591194c7e975ecf2fd045e6a935399` |
| `impl-report-r15.md` | `e6b0226b3440da997f7e08571d8e5e5229d66069ea5ad6485ee146c249dbe72e` |
| eight zero-byte R15 gate logs | each `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`；tests/build/matrix/source/bundle/preview均未运行 |

### 2.6 Historical R20 exact two-file deterministic-time exception

R20是shared verification prerequisite，不打开P1-F1，也不改变§2.1/§2.2 historical
13+2 allowlist。Review20与后续四hash授权后唯一可修改：

| Path | R20 entry SHA-256 | Exact role |
|---|---|---|
| `Sources/AgentLoopCore/Loop/AgentLoop.swift` | `5ec55a86b4548410b3f9ae876f7f8356d4a89e1024ef92f173412164c194a1bc` | private factory + single generic `IdleWatchdog<C: Clock>`；public init不变，production默认`ContinuousClock`，仅`#if DEBUG` package generic init以external label `idleClockForTesting`注入 |
| `Sources/AgentLoopTestSuite/AgentLoopTests.swift` | `28f5b4287a1004daaca962db375c9ea24ac0f06d0f6abbd0c6ecd277696abfb2` | conforming `ManualAgentLoopClock`、controlled provider与五项exact deterministic tests |

`ManualAgentLoopClock`以`NSLock`保护monotonic instant、unique waiter IDs与checked throwing
continuations；只允许clock storage使用`@unchecked Sendable`，必须锁外resume，advance/
cancel exactly-once且零waiter leak。`AgentLoop.swift`内`idleClockForTesting`全部
occurrences必须位于matching `#if DEBUG`；release `AgentLoop.swift.o`经
`nm -j | xcrun swift-demangle` count=0、debug count>0。禁止fake watchdog、第二timeout算法、新file/target/
dependency/public API/release testing symbol、真实sleep/轮询、timeout/间隔余量放大、
`.serialized`、skip/filter、RunTests并发修改、script-step复制、吞错或失败重跑。

R20 frozen 140-entry manifest在implementation前为140/140；implementation后exact两path
mismatch、其余138/140 unchanged。R20两文件final SHA-256精确为Core
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`与TestSuite
`66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`。这些actual bytes与
全部R20 runtime evidence现均immutable；本节不再授权任何R20执行或修改。

### 2.7 R21 exact one-file release-configuration exception

R21只关闭R20已证实的同一根因：SwiftPM对automatic library product执行
`--product AgentLoopCore`时退化为default graph，进而让release TestSuite caller面对
release Core中已移除的DEBUG-only callee。它不改变R20 deterministic-clock逻辑、产品
行为或package graph。

唯一source实施合同如下：

1. `Sources/AgentLoopCore/Loop/AgentLoop.swift`必须保持R20 final bytes及SHA-256
   `c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`，不得修改；
2. `Sources/AgentLoopTestSuite/AgentLoopTests.swift`的R21 entry必须为R20 final bytes及
   SHA-256
   `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`；只允许原地新增
   三对direct、matching `#if DEBUG`/`#endif`：
   - 第一对精确包围从`ManualAgentLoopClock`开始，连续覆盖
     `ControlledIdleProviderError`、`ControlledIdleProvider`、`AgentEventProbe`、
     `OneShotGate`，并在`runLoop`之前结束；
   - 第二对只包围完整`startControlledLoop` declaration/body；
   - 第三对精确包围五个连续exact tests：`turnTimeoutRetriesOnceThenBlocks`、
     `cancelWinsOverIdleTimeout`、`timeoutThenSuccessDoesNotAccumulate`、
     `slowActiveStreamDoesNotIdleTimeout`、`turnCompletesUnderTimeout`；
3. 不移动、不重排、不改写上述helpers、function或tests的任何既有logic、whitespace或
   annotation；不得加`#else`/`#elseif`、嵌套conditional、额外directive或第四对guard；
4. final TestSuite source删除且只删除上述六行exact direct directives后，bytes必须逐字
   还原R20 final TestSuite source并重新得到
   `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`；否则立即失败；
5. R21 155-entry manifest在implementation前必须155/155；实施后必须exact 154 unchanged
   + `AgentLoopTests.swift` one authorized mismatch。`AgentLoop.swift`仍匹配entry hash；
   第二个source mismatch、任一Package.swift/target/dependency/package edge、public/package
   API、schema/migration、其他产品/test/App/RunTests/matrix script delta均立即永久失败。

source gate必须以line-state parser证明Core source仍只有其R20既有一对direct DEBUG guard，
且`idleClockForTesting`全部位于其中；TestSuite final source恰有上述三对direct、non-nested
DEBUG regions，11个tokens全部位于这些regions，除此之外没有conditional directive：

- `ManualAgentLoopClock`
- `ControlledIdleProviderError`
- `ControlledIdleProvider`
- `AgentEventProbe`
- `OneShotGate`
- `startControlledLoop`
- `turnTimeoutRetriesOnceThenBlocks`
- `cancelWinsOverIdleTimeout`
- `timeoutThenSuccessDoesNotAccumulate`
- `slowActiveStreamDoesNotIdleTimeout`
- `turnCompletesUnderTimeout`

## 3. A2 唯一数据与命令合同

### 3.1 Normal input/start

- `RuminationWorkInput` exact keys：
  `model,runtimeProfileId,pipelineVersion`；missing/extra/blank identity拒绝，
  pipeline 精确 `coding-ranch-v1`，只用 `CanonicalJSONV1`。
- work 精确为 `rumination/ingestion/<ingestionId>`、`maxAttempts=4`；
  normal key
  `rumination-start:<ingestionId>:<checked previous attempt + 1>:v1`。
  Ingestion.attempt 只计用户 generation，durable retry 不增加。
- App MainActor 第一次 Task/await 前同步调用 preparation，并一次捕获
  key/trace/default profile/profile-scoped distill model；distill 空时只使用同 profile
  defaultModel。replay 不读取 current default/resolver。
- 只允许 queued/failed 新开工。完整 active ruminating graph 返回原 work；无完整
  graph typed fail；needsReview/materialized/discarded拒绝。
- absent command 在 resolver preflight 成功后，以单一 transaction 写 queued work、
  item ruminating、attempt +1、error nil；commit 前失败可重备同 key，commit 后返回/
  kick失败重放原 work。terminal 后用户新 retry 才生成下一 generation。
- Orchestrator只作normal start/user retry façade；唯一Supervisor actor拥有absent
  preflight、specialized Store call、post-commit delivery与kick。Store返回既有
  `DurableWorkEnqueueResult`：本次实际commit才是
  `work=<resulting queued attempt0 version=1 work>, disposition=.inserted`；同一
  transaction不得二次推进new work version；same-key/完整
  active graph为`work=<original work>, disposition=.replayed`且零写。
- `.inserted`同步return后同一actor turn第一次await/reentrancy前，验证resulting
  work为exact rumination/ingestion/<ingestionId>、queued attempt0/`version=1`，并
  同时reserve attempt-zero full commit identity与
  process-local start-projection barrier。任一barrier存在时所有pump/timer/kick/
  global FIFO claim入口对planning+rumination均零DB claim且不得跨kind skip。await
  nonthrowing sink后release barrier，再重读mode/work；仅running+active才kick/
  return，cancel/halt已提交时不复活/claim。cancellation不能跳过delivery/release。
- App preparation `replay(ingestionId,workId)`绕过resolver/Store start；并发
  new-command transaction返回的Store `.replayed`是第二origin。两者汇入同一
  Supervisor workId branch：original inserted delivery仍in-flight时只等待该既有
  delivery，delivered或restart无waiter时零等待；均不得构造current-version identity、
  reserve receipt或发第二event。preflight/conflict/rollback/throw零barrier/
  reserve/sink/kick。
- replay/restart freshness必须继续依赖并验证现有current-product single-writer
  contract：`StateDirectoryLock`对同一appSupport root执行
  `flock(LOCK_EX|LOCK_NB)`，第二owner `EACCES|EAGAIN` fail-fast；AppStore以
  `private let stateDirectoryLock`完整lifetime持有，且lock acquisition先于
  production source tree唯一
  `AppDatabase(path:<same-root>/agentloop.sqlite)`。process death/deinit释放lock，
  新owner再开DB并重走target-Camp snapshot ready；因此不存在另一production
  writer在已ready snapshot后commit的TOCTOU，replay保持零milestone/零direct
  reload。A2禁止修改两个lock文件、增加第二production opener/writer或让CLI/硬件
  绕锁；multi-writer须另开stage设计cross-process coordination/outbox。

### 3.2 Resolver

- Supervisor顺序：durable running → replay/active graph → absent-only full strict provider
  construction/discard → transaction重验 running/profile kind/Camp/ingestion并写。
- claim 只按 captured profile/model 再 resolve；禁止 current default、Companion、
  global catalog fallback。
- byte-identical `StrictPlanningProviderResolver` 只读复用；其 typed errors 映射为
  Stage §6.4.2 的 11 个 exact rumination codes/safe messages。unknown error 为
  global fatal。raw body/error/credential/account/OAuth/token 不落 DB/log/UI。

### 3.3 Generic capability seal

- public no-payload
  `RuminationRequiresDurableRuminationCapabilityError`。
- public/internal generic enqueue/claim/nextDue/renew/complete/retry/cancel/
  cancelActive/adopt 全拒绝 rumination，按 Stage §6.4.3 exact validation/caller-order
  priority；read-only active/latest/id lookup 保留。
- generic test fixtures 改 `.coach`，第二 ordinary kind 用 `.inputParsing`；
  `.rumination` 只用于 specialized/capability tests。

## 4. 单一 Supervisor 与 lifecycle

### 4.1 Owner/FIFO

- Orchestrator 私有持有唯一 production `DurableWorkSupervisor`；App/Adapter/Service
  不得创建第二 instance。
- specialized global claim/nextDue 同时接受 planning+rumination；claim入口先查
  start-projection barrier，任一存在时零DB claim/零跨kind skip。无barrier才验证
  durable running，再按 `createdAt ASC,rowid ASC` 全局 FIFO；无 kind priority/starvation，
  planning-only order不变。pump concurrency cap不变。
- kick 先按 workId 排序重试 owned pending proposal，再 global claim。
- OwnedEntry 带 kind/aggregate/latest claim，只在内存保存完整 typed proposal；
  一个 actor 统一 lease/timer/generation/fatal/wait/halt/shutdown。
- 唯一新增 rumination callback exact signature 是
  `onRuminationPhase: @escaping @Sendable (RuminationPhaseCommand) async -> Void
  = { _ in }`。exact command types为：

  ```swift
  public struct RuminationPhaseIdentity: Sendable, Hashable, Equatable {
      public let ingestionId: String
      public let workId: String
      public let attempt: Int
  }
  public struct RuminationProjectionCommitIdentity:
      Sendable, Hashable, Equatable
  {
      public let phaseIdentity: RuminationPhaseIdentity
      public let workVersion: Int
  }
  public enum RuminationPhaseInvalidationReason: Sendable, Equatable {
      case controlLoss
      case globalFatal
  }
  public enum RuminationInvalidationMilestone: Sendable, Equatable {
      case phase(
          identity: RuminationPhaseIdentity,
          reason: RuminationPhaseInvalidationReason
      )
      case projectionCommitted(RuminationProjectionCommitIdentity)
  }
  package enum RuminationPhaseCommand: Sendable, Equatable {
      case set(identity: RuminationPhaseIdentity, phase: RuminationPhase)
      case invalidate(RuminationInvalidationMilestone)
  }
  ```

  identity ingestionId/workId必须nonblank；attempt允许0且不得negative，queued
  user-cancel/halt可以提交attempt0 projection。positive `.set`与`.phase`要求
  running/open attempt>=1。workVersion>=1且只能取Store实际resulting work record，
  不得从claim/expectedVersion猜测。
  command不携带raw/usage/result/Error/diagnostics；所有正向phase与invalidation共用
  一个 awaited sink，不得保留 `RuminationPhaseEmission`、新增第二callback或包
  `Task`。default no-op只保现有non-rumination tests，省略者不得拥有/派发
  rumination；production显式接Orchestrator。Orchestrator legacy snapshot默认
  `.legacyProfileUnresolved` 也只保source compatibility。AppStore production
  显式传snapshot；不得新增 current-default fallback overload或其他callback。
- Supervisor actor唯一 private
  `invalidateRuminationPhaseIfNeeded(identity:reason:) async` 在await前记录
  invalidation in-flight并revoke新set；若该identity已有set sink in-flight，先用
  checked continuation等待该set delivery返回，再调用invalidate sink，不能假设
  跨actor mailbox FIFO。reentrant duplicates等待同一invalidate delivery；sink
  返回后delivered并唤醒，first safe reason wins，exact identity只deliver一次。
  不得用Task/timeout/cancellation拥有delivery，状态只在全部producer不可达后回收。
  ownership/control、halt/shutdown只用`.controlLoss`；
  DB/invariant/其他global fatal只用`.globalFatal`。
- 唯一private
  `publishRuminationProjectionCommitIfNeeded(_:) async`只接full commit identity。
  normal start/user retry `.inserted`、success、deterministic/exhausted failure、
  retry与actual user cancel commit caller在同一actor turn第一次await前reserve。
  start caller同时登记global claim barrier并保持kick关闭；其余caller revoke
  committed claim/generation的后续set/terminal permission，等待registered set后
  await同一sink；rollback/throw/
  no-active零reserve。full identity exactly-once；exact duplicate只等待原delivery，
  same work严格更高version可继续，unseen lower或same-version/different-identity
  在sink前fail-fast。
- 每identity一个actor-isolated coordinator串行set/phase/projection。projection-first
  时later control/global phase等待；matching commit满足phase-cleared并零第二clear。
  phase-first时later真实commit仍等待后发refresh，typed
  `invalidatedPhaseIdentity=nil`。不得并发sink、互等、Task或依赖executor FIFO。
- attempt-zero start `V` sink暂停时，reentrant user cancel/halt可提交更高version，
  但同coordinator必须严格start→control delivery；start恢复后重验为非active/halted
  时零kick/claim。attempt-zero projection永不创建live phase/tombstone且typed
  optional clear固定nil。

### 4.2 Startup/halt/resume/shutdown

- startup suppressed exact order：legacy planning repair → planning adoption →
  legacy rumination repair → rumination adoption → read durable mode。
- running 只到 recoveryReady；既有 Card adopt/heal 完成后统一 activate；此前
  claim/resolver/provider/phase 全为零。
- halted：planning bulk cleanup成功后，再按 workId sorted 的单一 rumination
  transaction cancel active work/open attempts并把 items queued/error nil；两者成功
  后transaction返回每个actual-canceled full commit identity（attempt可0，version
  取resulting work），Supervisor逐个await projection delivery，全部完成才
  didCommit/`haltStateChanged`。失败保持cleanupPending/suppressed；未commit/
  no-active零milestone。resume幂等重跑且不复活canceled rumination。
- emergency actor first turn generation +1，先capture live identities并revoke
  generation/terminal/phase-set permission→await sorted
  `.phase(.controlLoss)` obligation→才cancel两kind provider/renewal tasks→persist
  halted→planning bulk→rumination cleanup返回sorted actual commits→逐个await
  `.projectionCommitted`→didCommit/`haltStateChanged`→return。phase-first时commit
  仍发nil-clear refresh；matching projection-first时phase caller只等待且零第二clear。
  持久化/cleanup失败不为未commit row发milestone，保持suppressed/recovering且不
  恢复旧phase；`haltStateChanged`不兼任refresh owner。late provider/phase零写，
  任一kind fatal suppress全局。
- shutdown也先revoke phase-set并await invalidation，再cancel两kind tasks/timer，
  不伪造release或projection milestone；2秒后按workId report。restart可重调
  provider，但result/terminal commit只能一次。
- production 只走 unified lifecycle；planning-only compatibility path遇 active
  rumination fail-fast。唯一
  `private func latchFatalAndInvalidateRumination(_ fatal: SupervisorFatalError, operation: String, workId: String?) async` 是
  production global-fatal writer和
  revoke-all owner；所有 fatal writer、`.fatal` classification、
  `latchFatal`/`latchReadFailure` wrapper只要可能有rumination均route/await它。
  exact order是actor线性化fatal/control→在remove前捕获workId-sorted identities→
  revoke generation/token/terminal/phase-set permission→mark/await全部
  invalidation→才cancel provider/renewal tasks、remove owner、wake/return/throw。
  retained sync compatibility path在任何mutation前必须证明零
  active/owned/set-in-flight/live rumination，否则 exact capability error
  fail-fast；production不得调用。

## 5. Legacy repair

- key `legacy-rumination:<ingestionId>`；trace
  `legacy-rumination:<ingestionId>:trace:v1`。
- terminal-only `LegacyRuminationTerminalInputV1` exact keys
  `contractVersion=1,terminalCode`；只允许 Stage §6.4.6 的四个 codes。
- `LegacyRuminationStartupSnapshot` exact cases：
  `.valid(runtimeProfileId:model:)|.legacyProfileUnresolved|
  .legacyModelUnavailable|.legacyProfileCLIUnsupported`。AppStore init同步捕获
  default profile/profile-scoped distill-or-default model；invalid snapshot只形成
  exact legacy reason，不碰 credential/provider。
- snapshot构造优先级：default missing/corrupt/ambiguous→profile unresolved；
  否则CLI kind→CLI unsupported（不再检查model）；否则distill-or-default
  blank/missing→model unavailable；其余valid。捕获不读credential/catalog/endpoint，
  不构造resolver/provider。
- ingestion ID sorted，每 ID 单独 transaction，重读 status/history/Camp/ingestion
  graph；共同前置失败零写。随后先读 durable mode作为线性化点。完整状态表：

| mode | snapshot | input code/type | work | item/event/calls |
|---|---|---|---|---|
| running | valid | normal captured input | queued attempt0 | ruminating、attempt不变、error nil；domain event=0；repair external calls=0 |
| running | profile unresolved | `legacy_rumination_profile_unresolved` | failed attempt0、errorCode=code、errorMessage=nil | failed+safe error；one typed terminal failed event usage=null；external calls=0 |
| running | model unavailable | `legacy_rumination_model_unavailable` | 同上 | 同上，使用本行code/message；external calls=0 |
| running | CLI unsupported | `legacy_rumination_profile_cli_unsupported` | 同上 | 同上，使用本行code/message；external calls=0 |
| halted | valid | `emergency_halt_during_rumination` | queued attempt0→same-tx canceled、`work_canceled`/halt reason | queued/error nil；domain/attempt events=0；external calls=0 |
| halted | profile unresolved | **仍为 emergency-halt code** | 与halted valid相同 | 与halted valid相同；snapshot reason不落库 |
| halted | model unavailable | **仍为 emergency-halt code** | 与halted valid相同 | 与halted valid相同；snapshot reason不落库 |
| halted | CLI unsupported | **仍为 emergency-halt code** | 与halted valid相同 | 与halted valid相同；snapshot reason不落库 |

- 所有work使用同一legacy key/trace与canonical input/hash，maxAttempts=4、attempt=0、
  `notBefore/leaseOwner/leaseExpiresAt/outputJson=nil`，零attempt rows/events，
  item.attempt不变。running-valid finishedAt=nil；failed/canceled finishedAt=now；
  work/item updatedAt=now。running-invalid
  domain payload exact为 `workId,ingestionId,attempt=0,traceId,code,terminal=true,
  usage=null`；halted四格零domain event/credential/resolver/provider。
- rollback可重试同key；commit后的任一history让restart skip。running事实不被后来
  halt改写；halted绝对优先于snapshot。resume不复活canceled work，不重放invalid
  snapshot；halted item只能在running后由用户normal command重试。

## 6. Provider、usage 与 failure

- RuminationService 不再拥有 DB/start/cancel/process。唯一 provider API/path：
  `produceValidatedTurn(ingestion:) async throws -> RuminationValidatedTurn`。
  它每attempt恰好一次streamTurn、tools empty、maxTokens3072、无模型修复，消费完
  stream后要求exact-one-turn，再验证exact non-negative Int64 usage，才返回opaque
  turn。raw text/initializer fileprivate，Supervisor/test不能读取或自行parse。
- 唯一 pure parse API：
  `parseValidatedTurn(_:) throws -> RuminationProduction`。它只解析该opaque turn
  一次、零provider/DB/await，并逐字复用turn usage；parser failure也由Supervisor
  携同一usage收口。negative/overflow在opaque turn前成为usage_invalid+nil usage。
- 禁止 mutable lastUsage、任意provider/usage/optional callback、unowned Task、
  second provider path。唯一允许新增的rumination callback是§8的typed awaited
  phase-command sink，只能set/invalidate且看不到raw turn/usage/result。
- 错误、disposition、安全文案与 5/30/120 retry 完全按 Stage §6.4.7。
  CancellationError 不构造 failure。
- `RuminationAttemptFailure` 从同一 typed source 派生 canonical usage与
  DurableWorkFailure，不允许矛盾 initializer。

## 7. Terminal 与 pending proposal

- success transaction重验 running/latest claim/generation/input/Camp/item；
  work/attempt/event succeeded、outputJson nil；canonical result upsert保留旧
  id/createdAt并替换 pipeline/result、清 userEdited/materialized；title只填 nil；
  item needsReview/error nil；写 exact typed `rumination_completed` payload及同一
  `RuminationProduction.usage`；返回实际resulting `DurableWorkRecord`。
- transient transaction：attempt failed、work retryScheduled、item仍
  ruminating/error nil、`rumination_failed(terminal=false)`；deterministic/exhausted：
  work/item failed + safe error + terminal=true。两者都返回实际resulting work；
  usage exact object/null。
- cancel/halt specialized transaction原子关闭 matching work/attempt与 item
  queued/error nil；actual user cancel返回resulting work，halt返回sorted
  actual-canceled identities；stale claim/response/generation/no-active loser零写。
- 上述success/failure/retry/user-cancel只在commit后从resulting work构造full
  projection commit identity并交唯一publisher；rollback/throw固定零reservation/
  milestone，不从expectedVersion/claim手工`+1`。
- normal start/user retry `.inserted`也只从resulting queued attempt-zero work构造
  `workVersion=1` full identity，并由§3.1 barrier保证delivery先于任一claim；
  `.replayed`零milestone。
- terminal persistence rollback保留 OwnedEntry proposal/claim并续租；只有成功
  renewal或explicit kick重试同一 proposal，当前进程不重调 provider。进程死亡可
  adoption重调；不加 durable returned checkpoint。

## 8. Phase/UI 与 mutation fences

- KernelEvent仍只有两个process-local rumination cases：
  `ruminationChanged(RuminationChange)`与
  `ruminationPhase(ingestionId:workId:attempt:phase:)`。public
  `RuminationChange` exact cases为
  `.phaseInvalidated(RuminationPhaseIdentity)`与
  `.projectionCommitted(RuminationProjectionCommitIdentity,
  invalidatedPhaseIdentity:RuminationPhaseIdentity?)`；不增第三case、
  EventKind/schema/persistent receipt。
- valid owner经唯一 command sink发
  `.set(exact identity,.reading)`(context loaded) →
  `.set(exact identity,.extracting)`(resolver成功、stream前)。
  provider task得到opaque validated turn后只能await Supervisor
  exact private
  `handleValidatedRuminationTurn(workId:String,attempt:Int,ownershipToken:UUID,
  generation:Int,turn:RuminationValidatedTurn) async throws -> Void`：actor先验证
  running/unsuppressed/generation/token/OwnedEntry identity与当前latestClaim，再同步
  调用package read-only
  `validateRuminationPhaseOwnership(claim:ingestionId:now:) throws -> Void`，验证
  durable running与exact work/attempt/version/leaseOwner/unexpired lease/Camp/item；
  await唯一owned-set owner经同一sink发
  `.set(exact identity,.organizing)`；sink返回后用OwnedEntry届时的当前
  latestClaim完整重复两层验证；仍valid才在同一actor turn无await同步parse。
- 两次任一失权抛exact no-payload package
  `RuminationPreParseAuthorizationLostError: Error, Sendable, Equatable`（只有
  package `init()`），但必须先await同一exact identity的idempotent invalidator：
  actor `fatal` gate复用唯一global-fatal owner已标记/发送的`.globalFatal`
  first-winner delivery，其余失权使用`.controlLoss`；零parse且不记provider
  failure/retry。
  owned provider task必须显式catch该control signal并直接退出，不能进入
  failure/retry/terminal proposal路径。
  control先赢则zero organizing并清此前reading/extracting；organizing先赢而control
  在sink期间获胜，则第二次重验保证zero parse，并在throw/task cancel/return前
  exactly-once invalidate。expected stale/halted/terminal/lease-loss不记failure；
  DB/invariant error必须await唯一global-fatal owner先invalidate再cancel/throw；
  两者均zero parse/zero business write。
- Orchestrator actor唯一持有process-local
  `[ingestionId:(identity,phase)]` registry与每ingestion至少last-invalidated
  tombstone，另以full commit identity持有projection receipts并维护per-work最高
  version；callback body不含await/Task/cancellation early return：
  - `.set`在空registry只接受非tombstoned新identity的reading；已有值只允许exact
    identity同phase幂等或reading→extracting→organizing下一步。合法推进先registry
    mutation再emit phase；幂等、stale/mismatch零event，倒退/跳级programmer
    invariant fail-fast。
  - `.invalidate(.phase)`仅在ingestion/workId/attempt全匹配时先remove、记录
    tombstone，再恰好一次emit typed `.phaseInvalidated(identity)`；repeated/
    empty/stale/mismatch零event，不能清新generation。
  - `.invalidate(.projectionCommitted)`先做full receipt exactly-once与same-work
    monotonic验证。exact registry匹配时remove+tombstone并在typed event带
    `.some(identity)`；empty/tombstoned/different-newer registry逐字不动，
    optional nil但commit refresh仍恰好一次。exact duplicate零第二event；unseen
    lower或same-version/different-identity fail-fast。新identity只在旧registry
    exact clear后从reading开始；old set命中tombstone不能revive。
- AsyncStream按Orchestrator actor emit顺序FIFO。App live map存exact identity+phase；
  单一lifecycle MainActor listener以一个`for await`直接await handler，不为case另起
  Task。phase event先由Adapter读取同一DB snapshot的loaded camp、item status与
  active work identity/state；仅item ruminating+work running+exact workId/attempt
  才重建projection并overlay live。change只在typed phase identity或projection
  optional `.some(identity)` exact匹配当前live时clear；nil/stale/old version/new
  generation不能clear。无论clear与否都在同一handler serial reload persisted
  projection，并仅保留仍匹配snapshot active identity的live entry。background Camp
  只更新其cache，不切selected Camp/current UI；Adapter completion不补发refresh。
- terminal/retry/user-cancel transaction commit后经唯一projection publisher；
  phase-less也必须refresh，persistence rollback零milestone并保留proposal/live
  phase。halt/fatal作为actor control winner先phase invalidation再cancel task；
  halt cleanup实际commit后仍逐个projection refresh，即使phase已清；shutdown无
  commit所以零projection milestone。每条路径full identity exactly-once且registry
  零泄漏。
- normal start/user retry inserted也经同一publisher发attempt-zero refresh，并由
  barrier保证event emit先于claim/positive phase；replay零event。App lifecycle/
  restart必须先经同一Adapter persisted snapshot path成功加载目标ingestion所属
  Camp并标记ready，才enable该start/retry action；load failure保持disabled并显示
  既有显式failure，不能清startup pending后继续。新进程无start waiter/receipt时，
  active graph由snapshot显示recovering；background Camp readiness只更新对应cache，
  不切selected Camp。该restart freshness以§3.1 single-writer lock-before-DB-open
  entry invariant为前提；不得由Adapter completion/direct reload替代或绕锁。
- sink nonthrowing；Supervisor/Orchestrator不得用 `Task.isCancelled`、
  `CancellationError` 或early return跳过required invalidate。fatal/control owner
  只在sink返回后cancel provider task。
- App只接受 matching persisted active workId/attempt；未知重启使用
  `.recovering`/`正在恢复`。recovering list `[saved,recovering]`；live list
  `[saved,reading,extracting,organizing]`；不得 `?? .reading`。restart registry/
  tombstone为空；global fatal保持durable row逐字不变，但matching invalidation后
  相同persisted identity也只能recovering（可同时显示既有fatal error surface）。
- Adapter start/retry/cancel只delegate；不建 Task/provider，不读 default。
- Feed discard、Adapter delete、Camp archive各在同一 transaction拒绝
  item ruminating或active rumination work。needsReview不允许start，
  RuminationMaterializer/RuminationResult/EventKind/strict resolver不改。

## 9. Failure-first 与 exact named completion tests

implementer 首先只写 tests并运行 targeted gate，保存完整 `red-tests.log`。旧实现
必须因真实缺能力而失败；compile/discovery/fixture/unknown failure不接受。最终以下
41 个 exact names在 discovery/output 中各出现一次并 PASS：

1. `ruminationStartAndWorkAreAtomic`
2. `ruminationCrashIsAdoptedAndCompletesOnce`
3. `ruminationFailurePersistenceFailureRemainsRecoverable`
4. `ruminationCancelRejectsStaleResponse`
5. `legacyRuminatingRowGetsOneRepairWork`
6. `repeatedRuminationCommandReturnsExistingWork`
7. `ruminationCancelAndQueuedProjectionRollbackTogether`
8. `ruminationAttemptClosesExactlyOnce`
9. `ruminationWorkInputUsesCanonicalCapturedIdentityAndFirstTrace`
10. `ruminationSameKeyDifferentCapturedIdentityConflictsWithoutResolution`
11. `ruminationTerminalRetryCreatesReplacementWhileActiveReplayReusesWork`
12. `ruminationCapturedProfileAndModelIgnoreDefaultDrift`
13. `ruminationClaimResolutionFailureMatrixIsStableSafeAndFailClosed`
14. `ruminationResolverNeverFallsBackToCurrentDefaultOrCompanion`
15. `ruminationTransientFailureRetriesAtFiveThirtyOneTwentyThenTerminates`
16. `ruminationDeterministicFailureDoesNotRetry`
17. `ruminationTerminalFailureAndProjectionCommitOrRollbackTogether`
18. `ruminationSuccessResultProjectionAndWorkCommitOrRollbackTogether`
19. `ruminationLeaseRenewalAllowsOnlyLatestClaimToCommit`
20. `ruminationTerminalCommitFailureRetainsProposalAndDoesNotRecallProvider`
21. `ruminationProcessRestartMayRecallProviderButCommitsOneResultAndTerminal`
22. `ruminationEmergencyHaltCancelsWorkAndQueuesProjectionAtomically`
23. `ruminationEmergencyHaltRejectsClaimResolveAndProviderDispatch`
24. `ruminationLateProviderResponseCannotOverrideEmergencyHalt`
25. `ruminationResumeDoesNotReviveCanceledWork`
26. `ruminationWaitUntilIdleIncludesDueRuminationAndIgnoresFutureRetry`
27. `ruminationLivePhaseEventsAreOwnedOrderedAndProcessLocal`
28. `legacyRuminationWithoutResolvableRuntimeFailsSafelyExactlyOnce`
29. `ruminationSanitizesPersistedAndVisibleDiagnostics`
30. `ruminationInvalidOutputIsDeterministicAndPreservesSource`
31. `ruminationProviderUsesNoToolsAndProducesOneCanonicalResult`
32. `singleOrchestratorSupervisorOwnsPlanningAndRuminationLifecycle`
33. `ruminationAdapterDelegatesStartRetryCancelWithoutUnownedTask`
34. `ruminationUnknownRestartRendersRecoveringWithoutInventingReading`
35. `ruminationPhaseProjectionUsesOnlyMatchingSupervisorEvents`
36. `genericDurableWorkAPIsSealRuminationWithExactPriority`
37. `supervisedWorkPumpIsGlobalFIFOWithoutPlanningRegression`
38. `ruminationStartupRemainsSuppressedUntilOrchestratorActivation`
39. `legacyRuminationRepairCoversValidHaltedAndEveryTerminalReason`
40. `ruminationUsageIsExactOrFailsBeforeAccounting`
41. `activeRuminationFencesDiscardDeleteAndArchiveRaces`

R20已冻结且R21原样继承五个exact names：

42. `slowActiveStreamDoesNotIdleTimeout`
43. `turnTimeoutRetriesOnceThenBlocks`
44. `timeoutThenSuccessDoesNotAccumulate`
45. `cancelWinsOverIdleTimeout`
46. `turnCompletesUnderTimeout`

同一次未过滤、失败不重跑的authoritative `swift run RunTests`中，原41与新增5必须各
discovery/PASS一次。full suite全绿后才从同一`r21-verify.log`机械生成46/46 subset
audit到`r21-targeted-tests.log`；不得运行`--filter`或第二次test，46/46不替代full。

五项逐格语义：#42逻辑总时长大于timeout、每段严格小于timeout，completed、0 timeout
retry、provider callCount=1；#43两个attempt各在watchdog armed后advance到deadline，
恰好一次timeout retry，最终blocked、callCount=2；#44每个provider turn首attempt
timeout/次attempt success，timeoutCount逐turn重置；#45 watchdog armed后先cancel outer
task，等待`ManualAgentLoopClock` cancellation barrier确认waiter已移除/以
CancellationError恢复，
再advance超过deadline；必须canceled、零waiter，覆盖cancel-before-register与
register-before-cancel exactly-once且不宣称simultaneous tie；#46零advance
立即完成，watchdog取消且零waiter。controlled provider禁止`Task.sleep`；event
acknowledgment必须在真实`watchdog.beat`后才允许advance，并用barrier避开
exact-deadline race。

`DurableWorkTests.swift` owns ledger/supervisor/resolver/race；`CodingRanchTests.swift`
owns service/downstream/App source/UI。每项还必须断言总 Plan §3.3 列出的 exact
subcases，不能以 test name 代替行为。

#1/#6/#11/#22/#33/#34/#35共同覆盖：normal queued与failed user retry
`.inserted` resulting queued attempt0/exact `version=1`；同actor turn reserve+global
claim barrier；paused sink期间existing pump/timer/kick零DB claim/零跨kind skip；
delivery→release→re-read→conditional kick；两种replay origin归一、preparation
origin绕过resolver/Store、只按workId等待original in-flight且delivered/restart零第二
event；目标Camp snapshot load/ready先于command enable、load failure保持disabled/
显式失败；AppStore lifetime-held lock先于唯一production DB open、第二owner
fail-fast/释放后replacement可取得且两个lock文件byte-identical；start
`V`→cancel/halt `V+1`；rollback/conflict零barrier/reserve/sink/kick。

四项 finding-closure tests还必须逐字覆盖：

- #27：one-turn+usage validation后、parse前才 awaited emit organizing。第一次/
  第二次 revalidation 分别逐项注入 lifecycle/suppression/fatal/generation/token/
  workId/ingestion/actorAttempt/providerExited/pending proposal/current latestClaim/
  durable mode/work/kind/aggregate/Camp/item/durableAttempt/version/lease owner/expiry loss；
  每格都抛 exact `RuminationPreParseAuthorizationLostError` 并由 owned task 专门
  catch，zero parse、zero `RuminationAttemptFailure`、zero retry/failure/
  pending-or-terminal proposal/domain event/business write。每格在throw/cancel/
  return前await exact identity的exactly-once invalidation；每轮`fatal`格只复用
  unique global-fatal owner的`.globalFatal` first-winner delivery，其余格使用
  `.controlLoss`。第一次zero organizing且清已有reading/extracting，第二次清已发
  organizing。断言duplicate/reentrant
  only-one delivery、first reason wins、cancellation cannot skip、paused set时
  control/fatal必须revoke→wait set return→invalidate、old positive set cannot
  revive；无unowned Task。再覆盖per-identity coordinator两向race：
  projection-first暂停sink时later control/global phase只等待、matching commit满足
  clear且零第二phase command；phase-first暂停sink时later真实commit等待后仍发
  refresh、typed optional clear=nil；两向sink最大并发1且无deadlock。
- #31：`produceValidatedTurn`是唯一streamTurn callsite且调用一次/tools empty；
  0/multi-turn、usage invalid在opaque turn前失败；`parseValidatedTurn`一次parse、
  exact usage、provider调用数不增加。
- #35：对 #27 全部 expected-loss 格证明只有 persisted matching workId/attempt
  可见且迟到phase不可见。先覆盖normal queued与failed user retry `.inserted`：
  Store resulting work为queued attempt0/exact `version=1`，第一次await/reentrancy前reserve
  full identity+global claim barrier；暂停sink时全部claim入口零DB claim/零跨kind
  skip，delivery后release→re-read→conditional kick。preparation replay绕过
  resolver/Store，transaction `.replayed`汇入同一workId branch；in-flight只等待
  original delivery，delivered/restart零等待/零第二event且禁止current-version
  identity。target Camp snapshot load/ready后才enable command，failure保持disabled/
  显式失败；同root second production owner在DB open前fail-fast，release后
  replacement可取得锁；start rollback/conflict零barrier/reserve/sink/kick；cancel/halt更高version
  严格排后且start不复活。live与phase-less success、deterministic/exhausted
  failure、transient retry、actual user cancel逐格从Store resulting work/version
  构造full commit milestone；commit恰好一次refresh，rollback/throw/no-active零
  reservation/sink/event。同phase identity retry `V+1`后cancel `V+2`与retry
  `V+1`后halt `V+2`都发两个递增refresh；exact duplicate零第二sink/event且不吞
  更高version，unseen lower或same-version/different-identity在sink前fail-fast。
  并在第一次/第二次
  `validateRuminationPhaseOwnership` 分别注入 DB read failure 与 invariant
  corruption，逐格 latch global fatal、zero parse，且不得进入 provider
  failure或 `RuminationAttemptFailure`、retry/pending-or-terminal proposal/domain
  event/business write；两轮均在fatal return/task cancellation前完成
  workId-sorted exactly-once
  `.invalidate(.phase(identity:reason:.globalFatal))`，durable rows不变。halt断言
  sorted pre-clear→cancel tasks→persist halted→planning cleanup→rumination actual
  commits→projection deliveries→didCommit/`haltStateChanged`→return；cleanup失败
  不为未commit row发milestone，queued attempt0合法、no-active不伪造，
  `haltStateChanged`不替代refresh。Orchestrator断言full receipt/per-work monotonic
  与exact/empty/tombstoned/different-newer registry：exact match remove+tombstone+
  optional some；其余registry不变、optional nil但仍refresh。App phase先同一DB
  snapshot校验item/active running exact identity；change typed exact clear且always
  serial reload，old version/new generation只reload，background Camp不切selected
  Camp；same persisted identity与restart-empty均recovering，old set不能revive。
- #39：穷尽8-cell表逐格断言input类型与适用时的terminalCode、work/attempt、
  item/error、domain event、external-call=0、restart exact-once与resume；
  running+valid是normal input且没有terminalCode；三个halted-invalid一律
  emergency-halt而不是snapshot reason。

R13只允许在`DurableWorkSupervisor.swift`实现一个release-absent测试 seam。以下
type/storage/API/helper/caller全部必须完整位于matching `#if DEBUG`：

```swift
package enum A2RuminationAuthorizationCheckpointForTesting:
    Sendable, Equatable, CaseIterable
{
    case first
    case second
}

package enum A2RuminationAuthorizationLossForTesting:
    Sendable, Equatable, CaseIterable
{
    case lifecycle, suppression, fatal, generation, token, workId, ingestion
    case actorAttempt, providerExited, pendingProposal, latestClaim
    case durableMode, durableWork, durableKind, durableAggregate, durableCamp
    case durableItem, durableAttempt, durableVersion, durableLeaseOwner
    case durableExpiry, durableReadFailure, durableInvariantCorruption
}

package enum A2RuminationAuthorizationScenarioForTesting:
    Sendable, Equatable
{
    case inject(
        checkpoint: A2RuminationAuthorizationCheckpointForTesting,
        loss: A2RuminationAuthorizationLossForTesting
    )
}

package func armA2RuminationAuthorizationScenarioForTesting(
    _ scenario: A2RuminationAuthorizationScenarioForTesting,
    identity: RuminationPhaseIdentity
) throws
```

Supervisor最多single armed。arm只接valid exact identity并要求
enabled/running/unsuppressed/noFatal、already-owned exact rumination/open attempt/
coordinator、provider未退出、无pending proposal且terminal permitted；token/
generation只从OwnedEntry内部捕获。不得接Database/AppDatabase/path/provider/token/
raw row/Error/closure/String/custom payload。重复/stale/non-owned必须typed fail-fast。

唯一private `consumeA2RuminationAuthorizationScenarioForTesting`先原子清armed
storage再one-shot inject；wrong identity/checkpoint不消费。first caller在首轮真实
actor gate与真实DB validator均成功后、organizing前；second caller在awaited
organizing后、第二轮两项真实gate均成功后、service lookup/parse前。seam不得修改
OwnedEntry/durable state，不得reflection/unsafe/SQL scenario/direct Store/
validator/invalidator/fatal owner/sink/handler调用，不得构造proposal/commit/result、
调用provider/parser、发event或返回成功。consume只把closed loss抛入同一production
catch；该catch对`fatal|durableReadFailure|durableInvariantCorruption`只await唯一
async global-fatal owner，其余20格只走typed control-loss owner。

#27/#35必须各以fresh isolated DB+Supervisor表驱动覆盖每checkpoint 23格、总46格：
11个actor cases（actorAttempt独立）、10个durable cases（durableAttempt独立）及
DB-read/invariant两格。每格走真实start→owned provider→真实actor gate→真实DB
validator→consume→production catch/owner；证明single consume、exact reason/
invalidation、zero parse/failure/accounting/proposal/event/business write、durable
rows byte-identical与persisted matching visibility。不得用test-local fake或静态
source gate替代动态矩阵。

#31还须锁Supervisor production `produceValidatedTurn`/`parseValidatedTurn`各唯一
callsite及每attempt provider一次；#40经Supervisor端到端覆盖valid exact usage、
parse-failure保留同源usage，以及invalid usage在parse/accounting前以
`rumination_usage_invalid`、`usage=null`、零result/completed event收口；#41动态
覆盖discard/archive的status-only、work-only与neither（前两者零写拒绝，neither
真实允许），并以Adapter delete真实uniqueFunction transaction owner锁两道fence均
在mutation前。41 names、13+2 allowlist与所有schema/API/event边界不变。

## 10. 验证命令与证据

Review21在R21 exact canonical/control/driver/manifest/freeze hashes上判定
`APPROVED — 0 P0 / 0 P1`，且牧场主另以新turn按`freeze, Review21, driver, manifest`
顺序提供四个terminal hashes并授权clean invocation后，先完成§11 BEGIN attestation、
只实施§2.7的一文件六directive-lines guard，再按顺序执行并分别保存到§2.3的distinct
R21 artifacts：

```bash
set -euo pipefail

# 唯一一次、未过滤；非零立即永久停止，禁止重跑
swift run RunTests
swift build --product AgentLoopApp
swift build -c release --target AgentLoopCore
swift build -c release --target AgentLoopTestSuite
scripts/verify-p1-migrations-sqlite-matrix.sh --sqlite 3.51 --sqlite 3.52
git diff --check
git status --short --branch
```

- 完整RunTests只写`r21-verify.log`；full全绿后从同一log机械审计§9的46个exact
  names各discovery/PASS一次并写`r21-targeted-tests.log`，不得第二次运行或filter；
  build/release、四object symbol gates与§11.2 bundle assembly写`r21-build.log`；matrix写
  `r21-migration-matrix.log`。不得覆盖R13/R15/R19/R20
  artifact。
- authoritative test 只有 `swift run RunTests`，不得以 `swift test` 替代。
- schema 仍为 durable v12；matrix fixtures精确为
  fresh/v7/v8/v9/v10/v11/v12-durable，literal + 两条 real-GRDB lanes均须 PASS。
- 完整重跑总 Plan §11 的 A1b source/release/DEBUG seam gates；不得因 A2
  touched Supervisor/Orchestrator/App/Store而省略。
- A2 source/privacy gates必须证明：production Supervisor instance=1；
  App/Adapter无旧 service owner/provider/unowned Task/`try? await`；Service无
  DB/old bypass/`try? fail`；streamTurn只在produceValidatedTurn、opaque raw不可读、
  production produceValidatedTurn/parseValidatedTurn callsite各精确一处且都在
  Supervisor、parseValidatedTurn零provider；唯一rumination callback是typed awaited
  phase-command sink、exact enum只有set/invalidate且milestone只含phase/
  projectionCommitted、production不包Task且不走default no-op；Store terminal/
  retry/cancel返回resulting version、halt返回sorted actual commits；specialized
  Store start只有Supervisor callsite并返回既有
  `DurableWorkEnqueueResult`，Orchestrator只是façade；preparation replay绕过
  resolver/Store且两种replay origin归一为workId waiter/conditional-kick、零synthetic
  milestone；目标Camp snapshot ready前command disabled且load failure显式；无
  `?? .reading`；phase matching；App identity+phase map/单listener/direct-await/
  Adapter completion零refresh；recovering exact；planning-only production
  bypass=0；秘密/raw diagnostics=0。另须按§2.4 hash证明
  `StateDirectoryLock.swift`与`SupportTests.swift`byte-identical且不进入13+2，
  并证明AppStore `private let stateDirectoryLock` lifetime-held、
  `StateDirectoryLock(directoryURL:appSupport)`先于production唯一
  `AppDatabase(path:<same-root>/agentloop.sqlite)`；lock的
  `flock(LOCK_EX|LOCK_NB)`、`EACCES|EAGAIN` fail-fast、deinit unlock/close保持
  enclosing语义，既有
  `stateDirectoryLockRejectsSecondFileDescriptionAndReleases`在完整RunTests全绿。
- #27/#35 source-range/order gate必须解析真实 handler、owned task catch、
  validator、唯一invalidator、global fatal/control owners、Orchestrator registry
  handler与App consumer的 enclosing ranges，证明两轮 actor gate同序为
  lifecycle→suppression→fatal→generation→token→workId→ingestion→attempt→
  providerExited→pending proposal→当前 latestClaim，再同序调用 validator；
  durable graph gate同序为 durable mode→work→kind→aggregate→Camp→item→
  attempt→version→lease owner→expiry；control signal专门catch必须在failure
  mapper之前/之外，DB/invariant只进入唯一async global fatal。它还锁全部fatal
  writer/classification/latch/revoke wrapper、capture→revoke set→mark
  invalidation→await registered set-in-flight→await sorted invalidate→
  cancel/return、枚举全部production milestone callsite、one callback/unique phase
  invalidator/unique projection publisher且无direct sink/event bypass、
  commit-before-first-await reservation、rollback零reserve、per-identity
  phase/projection sink串行与two-way race无deadlock、no Task-or-cancellation early
  return。start锁Store return→validate exact kind/aggregate/ingestion+queued
  attempt0/`version=1`→reserve full identity+register process-local
  global-claim barrier（第一次await/reentrancy前）
  →await delivery→release→re-read mode/work→conditional kick→return；全部pump/
  timer/kick/global claim入口在barrier期间零DB claim/零跨kind skip。两种replay
  origin汇入同一workId branch，禁止identity construction/direct event/reload，
  delivered/restart零第二event；rollback/conflict零barrier/reserve/sink/kick。
  halt锁pre-clear→cancel→persist→planning cleanup→rumination commits→
  projection deliveries→didCommit/haltStateChanged。Orchestrator锁full receipt/
  monotonic version、exact remove→tombstone→typed optional emit、empty/tombstoned/
  new-generation nil refresh；App锁same-snapshot phase reconcile、typed exact clear、
  always-reload FIFO、old version只reload、background Camp不导航、目标Camp
  load/ready后才enable command、failure保持disabled/显式失败与restart-empty，
  并锁AppStore lock-before-DB-open enclosing order、production DB opener count=1与
  lifetime ownership。
  对上述owner、#31 production callsites与两个DEBUG caller，必须复用既有
  `PlanningTestFixtures.uniqueFunction`的masked comments/strings与唯一
  brace-enclosed range；不得使用`codingRanchSourceRange`、substring/count-only或
  复制helper。两个consume caller只能位于
  first-after-real-gates-before-organizing与
  second-after-awaited-organizing-and-real-gates-before-parse，且均有matching
  `#if DEBUG`；release caller为0。未锁owner/call order必须fail-fast。
- release Core必须用`nm -j <DurableWorkSupervisor.swift.o> | xcrun swift-demangle`
  证明所有R13 type/case/storage/arm/consume token为0；DEBUG object反向必须存在。
  source gate须解析`#if DEBUG` regions并证明Core的types/storage/arm/helper/two callers
  及两份test allowlist的全部arm callers均guarded，release无任何seam caller。任何
  reflection/unsafe/SQL scenario/direct Store/sink/handler/test-local fake命中都失败。
- R21 static entry manifest与runtime hash log同时核对所有 immutable、§2.5
  unchanged source/test bytes、§2.6 R20 final bytes与§2.7 entry/final source bytes、
  historical incident/review chain、两条App脚本零delta与matrix script临时单值
  delta/mandatory restoration；entry为155/155，implementation后必须exact 154
  unchanged + `AgentLoopTests.swift` one authorized mismatch，最终script delta必须为0，
  Core必须始终为R20 final hash。
  两个lock文件hash drift、第二production DB opener、lock order/lifetime drift、
  historical artifact drift或任何清单外diff均阻止Review02。

R21新增的release-configuration与object gate必须夹在两条release target build之后、
matrix之前，并满足以下exact contract：

1. `swift build -c release --show-bin-path`与`swift build -c debug --show-bin-path`只作
   path query，不是额外build。两者结果必须是canonical、real、non-symlink directory，
   且分别精确位于`$REPO/.build/<single-component>/release`与
   `$REPO/.build/<single-component>/debug`；layout变化即失败，禁止`find`、glob或候选
   fallback；
2. exact objects只能是
   `$releaseBin/AgentLoopCore.build/AgentLoop.swift.o`、
   `$releaseBin/AgentLoopTestSuite.build/AgentLoopTests.swift.o`、
   `$debugBin/AgentLoopCore.build/AgentLoop.swift.o`、
   `$debugBin/AgentLoopTestSuite.build/AgentLoopTests.swift.o`。每个object必须是canonical
   regular non-symlink file；其exact parent必须是canonical real non-symlink directory，
   并精确为对应bin下的`AgentLoopCore.build`或`AgentLoopTestSuite.build`；
3. release Core target成功后先记录其exact object SHA-256；release TestSuite target成功
   后同一Core object hash必须不变，证明第二条命令没有以另一配置替换Core object；
4. 每个object只运行`nm -j <exact-object> | xcrun swift-demangle`；保留`pipefail`，
   producer/demangler任一非零或空输出均失败。Core token `idleClockForTesting`在release
   object count必须为0、debug object count必须大于0；§2.7列出的11个TestSuite tokens
   在release Test object逐项count=0、debug Test object逐项count>0。count以`awk index()`
   substring机械计算，不以`grep` return code、固定临时路径或模糊symbol inference替代；
5. 同一`r21-source-gates.log`在debug App build与一次fresh bundle assembly/sign/
   LAUNCH_READY之后、两条release target build之前，先完成§2.7 direct-region parser与
   strip-to-R20-hash proof；matrix后再完成remaining source/privacy/final-hash gates。
   任一source/symbol方向错误、object缺失/多义、命令非零、hash漂移或未知状态都永久
   `REJECTED_CONTAMINATED`，不得重跑。

## 11. Isolated preview gate

R13首次preview的installed-App访问、invalid标记、后续成功retry与Review01 P1-01
全部保持historical；R14 freeze与Review14 changes-required也保持immutable。
R15 freeze/Review15与R15 BEGIN false-negative evidence同样保持immutable；R15没有
运行test/build/matrix/source/bundle/preview。旧retry、R15 failed boundary与现存
`.build/AgentLoop.app`均不满足本节。R17未执行且Review17 verdict保持immutable；
R18/R18-A也未执行，Review18 changes-required verdict与完整失败审计链保持immutable；
R19后来到达BEGIN并在权威full test 651/652后永久rejected；没有执行本节后续build/
bundle/preview阶段。R20后来到达BEGIN，完成唯一full 652/652、46/46、debug build与
LAUNCH_READY，随后在release Core `--product` command永久rejected；其完整证据和signed
App均按§2.3 immutable。以下§11.1–§11.4内所有`R19_*`、`r19-*`与Review19四hash文字只
作为R19 frozen historical recipe保留，**不得执行**；R20 driver/recipe同样只作
immutable evidence，**不得重跑**。

R21 current override是：全部fresh runtime identity机械使用`R21_*`/`r21-*`，入口固定为
`evidence/r21-begin.sh`并只接受`freeze, Review21, driver, manifest`四hash；pre-BEGIN及
post-activation static manifest均为155/155，实施后为154 unchanged + one authorized
`AgentLoopTests.swift` mismatch，Core始终匹配R20 final hash。driver继承R20全部
phase-aware NUL pathname、tombstone、R19 containment，并新增R20 11-artifact、absent
screenshot、exact empty state root、exact-one-child signed App bundle parent与三项signed
identity containment。signed App用不带`-type`过滤的all-node NUL pipeline证明exact 36
relative nodes（6 real non-symlink directories + 30 regular non-symlink files）、逐文件
hash及无额外/缺失/未知node；actual pathname不转为newline text，只有完全匹配后才输出
固定safe expected literals并复算frozen signed-manifest hash；失败只写四段safe numeric
statuses。capture inventory只统计outer driver中受全局ERR trap影响的unique parent
capture blocks，inline validator逐文件hash子状态由外层P封装且不重复计数；core为
`8P/4S/8C=20`，加fresh-root-glob check后driver-total `8P/4S/9C=21`。BEGIN、one-file
guard、唯一full与同log 46/46之后的唯一
顺序为：debug App build → fresh bundle assembly/sign及POST_BUILD/PRE_SIGN/LAUNCH_READY
→ pre-release guard-shape/strip source sub-gate → 两条release target builds → 四object
gates → matrix → remaining source/privacy/final-hash gates → same-bundle preview → END。
其他provenance、same-bundle direct exec、normal isolation与fail-once语义原样继承。任何
与Stage §28.8或本leaf§1/§2.7/§10冲突的historical template文字均由R21 current合同取代。

### 11.1 BEGIN attestation

R19不复用R15自定义zsh hash helper。reviewed入口固定为
`evidence/r19-begin.sh`，只可由以下clean environment和exact shell启动：

```bash
/usr/bin/env -i \
  LC_ALL=C LANG=C PATH=/usr/bin:/bin:/usr/sbin:/sbin TMPDIR=/private/tmp \
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
  /bin/bash --noprofile --norc \
  /Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r19-begin.sh \
  "$R19_FREEZE_SHA" "$R19_REVIEW19_SHA" "$R19_DRIVER_SHA" "$R19_MANIFEST_SHA"
```

四个64位小写hex只能来自Review19通过后的**后续新用户授权turn**。调用者在启动
driver前必须先用四行`<hash><two spaces><absolute path>` stdin执行一次
`/usr/bin/shasum -a 256 --strict -c -`，逐项核对R19 freeze、Review19、driver与
manifest，再对`evidence/r19-entry.sha256`执行一次
`/usr/bin/shasum -a 256 --strict -c`；两次均为零写入。任一非零立即停止，既不
创建R19 artifact/root，也不消费授权。

driver本身使用`set -Eeuo pipefail`，所有关键命令均为absolute path；禁止依赖用户
shell profile、alias/function、动态expected map、runtime-generated manifest、
自定义字符串hash comparator或zsh special/global变量。static
`evidence/r19-entry.sha256`必须是按absolute path字节序排序的123项固定清单。它精确
继承immutable R18 manifest的119-path coverage且无删除，以R19 final bytes重算hash，
再只增加reviewed `evidence/r19-begin.sh`、immutable `evidence/r18-entry.sha256`、
immutable `evidence/plan-freeze-r18.md`与immutable Review18；由此继续绑定
`evidence/r17-bash32-probes.sh`、六个current surfaces、全部冻结产品/test/sentinel/
script/RanchArt文件、R16–R18 planning chains和其他immutable历史链。六面更新后旧R18
manifest必须恰好six surfaces mismatch、其余113/119 unchanged；R19 manifest必须
123/123 PASS。它不包含manifest自身、R19 freeze、Review19或runtime R19 artifact，
避免hash cycle。唯一内容校验器是
`/usr/bin/shasum -a 256 --strict -c`；禁止`--ignore-missing`、`-q`或`-s`。

R19继续使用R17证明的status-capture安全模式，但current inventory必须按实际职责重算。
R18旧RanchArt regular-find C、transform-pipeline C、exact-set diff S、nonregular-find C
与count-pipeline C共`1S + 4C`五个blocks整体删除，由一个NUL pathname pipeline P
替代。R19 current core inventory精确为`3P / 3S / 3C = 9`；另计覆盖R16/R17/R18/R19
fresh-root glob absence的一个C后，driver total精确为`3P / 3S / 4C = 10`。R17的
`2P / 4S / 7C = 13`与R18的13/14只作为immutable历史，不得冒充current计数：

1. 禁止用`set +e`后执行bare command/pipeline/command substitution，再以`$?`
   猜测结果；`set +e`不解除全局继承的`ERR` trap；
2. simple command必须直接置于`if ...; then rc=0; else rc=$?; fi`；
3. pipeline必须直接置于`if`条件，并在then/else两个分支的第一条命令立刻复制
   `PIPESTATUS`，之后才可执行任何赋值、输出或判断；
4. command substitution必须在subshell内部先`trap - ERR`，外层再用`if
   output="$(...)"; then rc=0; else rc=$?; fi`捕获；含pipeline时继续保留
   `pipefail`；
5. 禁止`|| true`、silent fallback、`!`后读取被反转的状态、吞掉indeterminate
   return code或把specific reason改成generic unexpected failure。

联合tombstone C必须先验证parent精确为regular non-symlink `/private/tmp`、两个
basenames非空/非`.`/`..`且映射回两个冻结absolute paths并互不相同，再以不带
`-type`过滤的单次`find -mindepth 1 -maxdepth 1`证明两个basenames都不存在。
enumeration nonzero、任何输出或final `-e || -L`重检发现重现均fail closed；因此
directory、regular/special node、symlink及dangling symlink一律拒绝。该proof全程
只读、成功只写stderr，不创建物理tombstone，也不宣称消除final lstat后的理论TOCTOU。

immutable `r17-bash32-probes.sh`必须在macOS `/bin/bash` 3.2 clean environment中证明
上述simple/pipeline/substitution三类模式，并覆盖`pgrep rc=1`、`diff rc=1`、
indeterminate `rc=2`、pipeline component nonzero与command-substitution
nonzero；probe只能在planning/Review阶段运行，不调用R19 driver或任何产品执行门。
R19不得修改该probe，也不得复制或虚构`r19-bash32-probes.sh`。R19 planning/Review阶段
只允许在内存/stdin运行零文件写入的Bash 3.2 `read -d ''` micro-probe；不得新增probe
artifact，也不得调用driver或任何产品执行门。

在任何targeted/full test、build、matrix、source gate、bundle/sign或App launch前，
driver按下列顺序执行：

1. pre-BEGIN只读验证clean env、四个terminal anchors、static manifest精确123-entry
   count、branch/HEAD、全部12个R19 execution paths absent、进程数为0、R15 screenshot/
   planned App absent、两个R15 exact root identities继续为`ABSENT` absorbing
   tombstones，以及全部12个R16、12个R17与12个R18 runtime paths和
   `/private/tmp/agentloop-r16-state.*`、`agentloop-r16-bundle.*`、
   `agentloop-r17-state.*`、`agentloop-r17-bundle.*`、`agentloop-r18-state.*`、
   `agentloop-r18-bundle.*`、`agentloop-r19-state.*`与`agentloop-r19-bundle.*`仍不存在；
   该阶段禁止创建任何artifact或fresh root；
2. driver只能定义一个phase-aware RanchArt verifier与一个runtime检查为27项、bytewise
   unique的ASCII expected basename array。pre-BEGIN 123-entry static manifest先逐项核对
   27个RanchArt bytes；全部其他pre-BEGIN只读门全绿后，必须把该verifier的
   `PRE_CONSUMPTION`调用作为boundary exclusive-create和
   `authorization_consumed=true`之前的**最后一个门**。每次调用先证明RanchArt root
   是real non-symlink directory，再只以单一
   `/usr/bin/find -P <RanchArt> -mindepth 1 -maxdepth 1 -print0 | inline /bin/bash`
   pipeline重新读取全部direct children，不用`-type`缩小universe；inline Bash 3.2
   validator以`IFS= read -r -d ''`完整drain NUL stream并拒绝nonempty partial final
   record，NUL stream不得进入command substitution、line split、`for ... in $(...)`、
   `sed/sort/diff/wc -l`或raw text evidence，stderr不得混入stream；
   producer与validator的`PIPESTATUS`必须在then/else第一条命令复制，且仅两个status
   都为0才成功。validator在`LC_ALL=C`、关闭`nocasematch`后，从enumeration返回的
   full path取得actual basename bytes，禁止通过expected-path lookup推断actual spelling；
   以27-slot indexed `seen[]`与饱和到28的entry
   count证明每个actual node都`-f && ! -L`且恰好匹配一个expected literal；结束时27个
   slot各为1、count与regular count精确27、nonregular/symlink count为0。missing、extra、
   case variant、Unicode confusable、LF/CR/control name、dotfile、directory、FIFO/socket/
   device、symlink或dangling symlink一律fail closed；
   proof完成前不得raw serialize pathname。成功后parent才按safe expected ASCII固定顺序
   写`section`、`phase`、`ranch_art_verification_mode`、
   `pathname_transport=find_print0_bash_read_d_nul_v1`、
   `ranch_art_find_rc`、`ranch_art_validator_rc`、`ranch_art_expected_count=27`、
   `ranch_art_parent_type=directory_non_symlink`、
   `ranch_art_node_type=regular_non_symlink`、`ranch_art_actual_count=27`、exact-relative-
   path block、`nonregular_count=0`、`symlink_count=0`、`regular_count=27`。pre调用不得
   写repository、artifact或fresh root，失败只写`/dev/stderr`并立即停止，授权保持未消费；
3. pre-consumption verifier全绿后才可exclusive-create
   `evidence/r19-clean-boundary.log`并立即写`authorization_consumed=true`，此刻才
   消费一次授权；invocation identity固定为`R19_INVOCATION_ID=r19-<lowercase UUID>`。
   boundary初始化同时记录
   `r15_state_root_pre_begin_observed_state=ABSENT`、
   `r15_bundle_parent_pre_begin_observed_state=ABSENT`、
   `r15_state_root_current_absent=true`、
   `r15_bundle_parent_current_absent=true`、
   `r15_absence_proof_identity=private_tmp_parent_enumeration_exact_basename_v1`与
   `disappearance_cause=UNKNOWN`，不得写`preserved_empty`或
   `continuously_preserved`。
   boundary初始化后只能立即exclusive-create
   `evidence/r19-hash-manifest.log`；该hash log与接续的post-activation重读之间不得
   插入任何其他gate，也不得创建其余runtime artifact或fresh root；
4. authorization消费且hash log创建后、创建任何其他runtime artifact/root之前，
   必须立即再次调用**同一个**phase-aware verifier并从filesystem重新读取RanchArt，
   把phase、exact-path set/count与nonregular count结构证据写入已创建的hash log；
   不得复用preflight boolean、snapshot、临时清单或缓存结果。失败使整个invocation
   永久`REJECTED_CONTAMINATED`并立即停止，不得在同一boundary retry；
5. 结构证据落盘后，再以同一四行`shasum --strict -c -`核对terminal anchors，并
   独立重新执行post-activation 123-entry static manifest，把逐行raw
   `OK`/`FAILED`、producer/shasum statuses、overall return code与exact entry count
   写入同一hash log；该门逐文件重校全部bytes，包括27个RanchArt files。frozen
   derived-manifest constant只记录expected identity，不由结构verifier另行重算。
   任何失败由ERR trap记录真实phase、command和return code，禁止凭空标为“hash
   mismatch”；
6. 上述门全部通过后，才exclusive-create§2.3其余文本logs并创建两个新的absolute
   `R19_STATE_ROOT`与`R19_BUNDLE_PARENT`；两者初始为空、互不嵌套且不复用任何
   R13/R15/R16/R17/R18 root，planned bundle固定为
   `$R19_BUNDLE_PARENT/AgentLoop.app`；
7. 只有四anchor、static manifest与post-activation结构复核都通过，才在boundary写
   `begin_attestation_complete=true`并向后续executor输出同一invocation/root
   context；
8. BEGIN只记录planned bundle/executable absolute paths、`r19-dev-bundle-v1`
   recipe identity、frozen Info.plist hash与输入hash；不得记录尚未build/sign的
   final executable hash，也不得读取、删除或复用
   `/Users/muzi/Agent-loop/.build/AgentLoop.app`。

上述双读取只收窄preflight到activation之间的TOCTOU窗口；R19不宣称原子filesystem
lock、transaction或不存在剩余TOCTOU，也不扩大hardlink/inode、xattr/resource-fork或
dirfd lock合同。若未来必须提供原子filesystem lock，须另开stage与职责隔离Review，
不能在本轮driver中扩张。

明确禁止`app:"AgentLoop"`、display name、bundle id、frontmost-name、installed
path、Dock、NSWorkspace、LaunchServices fallback、`open`、`scripts/run-app.sh`
与`scripts/package-app.sh`。两个脚本只能由static manifest核hash，不得执行、
source、截取、pipe给shell或动态抽取Info.plist。

对normal root只允许从进程`lsof`输出比较open-file path；不得以`ls`、`find`、
`stat`、hash、`sqlite3`、open/export/cleanup/reset/rebuild或其他方式访问其内容。
activation后任一非零退出或证据缺口都适用§11.4，不能换root或重新BEGIN。

### 11.2 POST_BUILD、PRE_SIGN 与 LAUNCH_READY provenance

`swift build --product AgentLoopApp`成功后、任何release build/matrix/source gate
或App launch前，只允许一次如下inline `r19-dev-bundle-v1` assembly；不得执行或
修改任何仓库脚本：

```zsh
set -euo pipefail
umask 022

R19_ROOT=/Users/muzi/Agent-loop
R19_BIN_DIR="$(cd "$R19_ROOT" && swift build -c debug --show-bin-path)"
R19_BUILD_EXEC="$R19_BIN_DIR/AgentLoopApp"
R19_BUILD_RES="$R19_BIN_DIR/AgentLoop_AgentLoopApp.bundle"
R19_APP="$R19_BUNDLE_PARENT/AgentLoop.app"
R19_APP_EXEC="$R19_APP/Contents/MacOS/AgentLoop"
R19_APP_RES="$R19_APP/Contents/Resources/AgentLoop_AgentLoopApp.bundle"

test "$(/bin/realpath "$R19_ROOT")" = "$R19_ROOT"
test -f "$R19_BUILD_EXEC"
test -x "$R19_BUILD_EXEC"
test -d "$R19_BUILD_RES"
case "$R19_BIN_DIR" in
  "$R19_ROOT"/.build/*) ;;
  *) exit 1 ;;
esac
test ! -e "$R19_APP"
test ! -L "$R19_APP"

/bin/mkdir -p "$R19_APP/Contents/MacOS" "$R19_APP/Contents/Resources"
/bin/cp "$R19_BUILD_EXEC" "$R19_APP_EXEC"
/bin/cp -R "$R19_BUILD_RES" "$R19_APP/Contents/Resources/"
```

随后只用以下heredoc把literal逐字写为`$R19_APP/Contents/Info.plist`；不得从脚本
抽取或使用其他plist生成器：

```zsh
/bin/cat > "$R19_APP/Contents/Info.plist" <<'R19_PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>AgentLoop</string>
  <key>CFBundleIdentifier</key><string>com.muzi.agentloop.dev</string>
  <key>CFBundleName</key><string>AgentLoop</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key><string>com.muzi.agentloop.oauth</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>agentloop</string>
      </array>
    </dict>
  </array>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSMultipleInstancesProhibited</key><true/>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSExceptionDomains</key>
    <dict>
      <key>ai-api.jdcloud.com</key>
      <dict>
        <key>NSExceptionAllowsInsecureHTTPLoads</key><true/>
      </dict>
    </dict>
  </dict>
</dict>
</plist>
R19_PLIST
```

canonical RanchArt manifest算法固定为：

```zsh
r19_tree_manifest_sha() {
  (
    cd "$1"
    find . -type f -print0 |
      LC_ALL=C sort -z |
      xargs -0 /usr/bin/shasum -a 256 |
      /usr/bin/sed 's#  \./#  #'
  ) |
    /usr/bin/shasum -a 256 |
    /usr/bin/awk '{print $1}'
}
```

`evidence/r19-bundle-provenance.log`必须append四段证据：

1. `POST_BUILD`：
   - `R19_BIN_DIR`、build executable/resource realpaths都在repository `.build/`内；
   - build executable SHA-256与
     `/usr/bin/dwarfdump --uuid`的sorted `UUID|architecture`集合；
   - source `Sources/AgentLoopApp/Resources/RanchArt`精确27个regular files、
     零symlink，manifest为
     `4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab`；
   - generated `$R19_BUILD_RES/RanchArt`同为27 files、零symlink、同manifest；
     另记录整个generated resource bundle的sorted per-file manifest。
2. `PRE_SIGN`：
   - fresh bundle顶层只含`Contents/MacOS`、`Contents/Resources`与
     `Contents/Info.plist`，零清单外文件/symlink；
   - `/usr/bin/cmp`证明unsigned copied executable与build executable逐byte相等，
     UUID集合也相等；
   - `/usr/bin/diff -qr`证明copied generated resource bundle与build resource
     bundle相等，copied RanchArt仍为27 files且manifest相同；
   - `/usr/bin/plutil -lint`通过，Info.plist SHA-256精确为
     `5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58`，
     `CFBundleExecutable=AgentLoop`、identifier=`com.muzi.agentloop.dev`。
3. 只在全部PRE_SIGN断言通过后执行一次：

   ```zsh
   /usr/bin/codesign --force --sign - "$R19_APP"
   /usr/bin/codesign --verify --deep --strict --verbose=4 "$R19_APP"
   /usr/bin/codesign --display --verbose=4 "$R19_APP"
   ```

4. `LAUNCH_READY`：
   - bundle/executable absolute realpaths仍位于fresh `R19_BUNDLE_PARENT`；
   - signature为ad-hoc、identifier为`com.muzi.agentloop.dev`，无Developer ID、
     TeamIdentifier、entitlement plist或App Sandbox entitlement；
   - 记录post-sign executable SHA-256、CodeDirectory/CDHash、整个signed bundle的
     canonical per-file manifest/hash；post-sign executable UUID集合必须与
     POST_BUILD/PRE_SIGN相同，**不得**要求post-sign hash等于build hash；
   - resources在sign后仍与build resource bundle `diff -qr`相等；
   - `test -x "$R19_APP_EXEC"`，并再次证明全局AgentLoop进程为0。

assembly/copy/plist/sign各只允许一次。LAUNCH_READY后直到END禁止build App、
re-copy、rewrite plist、re-sign、换bundle或清理`R19_BUNDLE_PARENT`/
`R19_STATE_ROOT`。两root必须保留到Review02完成。

### 11.3 Exact-path bootstrap and cold start

1. 每次launch前重新验证LAUNCH_READY executable hash/UUID、signed bundle
   manifest、codesign与frozen inputs均未漂移；唯一启动方式是：

   ```zsh
   R19_PREVIEW_LOG="$R19_BOOTSTRAP_LOG" # cold start时唯一改为R19_COLD_START_LOG
   AGENTLOOP_STATE_DIR="$R19_STATE_ROOT" \
   AGENTLOOP_UI_PREVIEW=1 \
   "$R19_APP_EXEC" >>"$R19_PREVIEW_LOG" 2>&1 &
   R19_APP_PID=$!
   ```

   PID只能取自`$!`；`pgrep`只可验证全局zero/count，不能选择或定位进程。日志只
   记录两个安全preview env key，不得导出完整继承环境。
2. bootstrap验证exact executable realpath/hash/PID/environment、全局恰好一个
   AgentLoop进程、captured children、DB/WAL/SHM/lock只在isolated root，UI操作
   前后与退出前normal open-file count均为0；UI工具只能绑定full path/PID；
3. 退出bootstrap，仅做shell process检查，证明own PID/child为0；退出后不得调用
   任何UI状态工具；
4. 仅向isolated DB插入non-sensitive synthetic ruminating fixture，FK=0、
   integrity=ok；
5. 同root exact-path cold start，重复path/hash/PID/env/one-process/open-file检查；
6. 导航inbox/progress，截图exact`正在恢复`，无reading/extracting/organizing/
   confirm current stage；preview mode零provider dispatch；
7. 退出并仅以shell证明own PID/child与全部AgentLoop进程为0；保存true PNG和hash。

bootstrap与cold start是同一boundary内两个具名、顺序且零重叠的owned PID；第二次
是合同要求的cold start，不属于“第二App”。cold start必须复用同一bundle/executable
hash与manifest，明确记录`bundle_rebuilt=false`、`bundle_resigned=false`。

### 11.4 Fail-closed and END

任一normal-root open/read/write/reset、第二App、installed/wrong executable、
path/hash/env/PID不匹配、display-name/bundle-id/LaunchServices lookup、未知child、
post-quit UI call、provider dispatch、source/build/resource/plist/copy/signature/
UUID/manifest drift、stale bundle复用、LAUNCH_READY后rebuild/re-copy/re-sign或
证据缺口都立即把整个invocation标为
`REJECTED_CONTAMINATED`并停止。不得在同一boundary内启动fresh retry或覆盖负证据；
不得换root、修补plist、重build/copy/sign或启动未开始的后续launch；再次尝试须取得
新的plan-level有界授权与新的exclusive artifact names。若已有owned PID，只允许
按exact PID安全退出作containment，不改变失败verdict。

只有所有§10/§11 gates通过、§2.5仍匹配、§2.6两项R20 final bytes已按当前合同保全，
且§2.7精确为one authorized TestSuite delta，才在
同一boundary log写UTC END、
final LAUNCH_READY identity、bundle/executable/resource hashes、matrix script已恢复
entry hash、normal open count=0与no-process/no-child。该gate只证明R21 clean
boundary内UI truth/isolation；真实adoption/phase由named tests证明。不得读写/重置
normal DB，也不得在END前清理两fresh roots。

## 12. Implementation report 与独立完成门

R13 `impl-report.md`、Review01、R14–R18全部历史、R19 plan/Review/execution evidence，
以及R20四hash/implementation/runtime evidence、11 artifacts、缺失screenshot、exact
state root和signed App bundle parent全部immutable。R21 implementer只写
`impl-report-r21.md`，必须列出：

- branch/HEAD/worktree与所有 changed files；
- Review21/freeze/driver/155-entry static manifest与BEGIN/POST_BUILD/PRE_SIGN/LAUNCH_READY/END
  boundary identity；
- historical R13 incident、mutation unknown、Review01 verdict与旧artifact hashes；
- Review14 P1-01、R15 BEGIN false negative/no-gates truth、Review17 P1-01、Review18
  pathname-serialization P1-01与R18-A historical-empty/current-ABSENT分层、absorbing
  tombstone parent-enumeration proof、
  两个per-path observed-state/current-absent字段、proof identity、
  `disappearance_cause=UNKNOWN`、R19 historical core 9/driver-total 10、R20 historical
  core `5P/3S/7C=15`/driver-total `5P/3S/8C=16`与R21 current按outer unique parent
  block口径的core `8P/4S/8C=20`/driver-total `8P/4S/9C=21` capture计数、继承的lossless NUL
  pre/post verifier、R19 41/41/full 651/652 rejection、R20唯一full 652/652/同log46/46及
  release failure、R21唯一一次unfiltered full RunTests、同log 46-name audit、
  target-exact builds、四object symbol/matrix/source/privacy/preview结果及distinct
  artifact hashes；
- immutable/hash/scope manifest与source→SwiftPM build→unsigned copy→resources/
  plist→ad-hoc signed bundle→launched executable完整provenance；
- §2.5 15个产品/test逐项zero drift、§2.6两个R20 final hashes逐字保全、§2.7 exact one
  authorized diff及final hash、155-entry pre-edit 155/155、post-edit 154+1、TestSuite
  strip-to-R20 hash proof、`idleClockForTesting` Core release=0/debug>0、11个TestSuite
  tokens逐项release=0/debug>0、release Core object在第二条target build前后hash不变、
  两条App脚本zero drift，以及matrix script
  exact临时单值delta与END前entry-hash restoration；
- bootstrap/cold start复用同一LAUNCH_READY bundle/executable hash，明确
  `bundle_rebuilt=false`、`bundle_resigned=false`；
- single-writer lock-before-DB-open source proof与既有exclusive/release test结果；
- start/resolver/generic seal/supervisor/lifecycle/legacy/service/terminal/phase/fence
  对 Stage §6.4 的逐项映射；
- 任一 deviation及其 prior authorization；没有则写“无”。

Review12C/13B/15、Review19及Review20只保留为immutable approved plan predecessors；各
changes-required历史不变。R19与R20 invocations都永久`REJECTED_CONTAMINATED`。
Review21必须先在`evidence/plan-freeze-r21.md` exact hashes上判定
`APPROVED — 0 P0 / 0 P1`，才可由后续新用户turn提供final
`freeze, Review21, driver, manifest` hashes并执行R21。

未参与R13–R21规划、实施、bundle assembly或preview的职责隔离implementation
reviewer只写
`reviews/02-p1-a2-review.md`，核对真实current bytes、全部new logs/preview、
完整provenance/BEGIN–END boundary、historical chain、exact one authorized source delta
与其余zero product/test/final script drift。Review02零P0/P1才可交给独立acceptance owner。

acceptance必须逐项证明unfiltered full全绿、46-name audit、完整R21 gates、R-02关闭与
零权限扩大，并同时写：

1. R13 `REJECTED_CONTAMINATED` invocation确实访问normal lock/DB/SHM/WAL，
   mutation为unknown，Review01未被推翻；
2. R15 BEGIN false-negative boundary没有运行任何后续gate且没有证明A2完成；
3. R17/R18从未执行；R19虽41/41 targeted green，仍因full 651/652永久rejected；R20虽
   full 652/652、46/46与LAUNCH_READY通过，仍因release Core build永久rejected；两轮
   artifacts/roots均未被改变；被accept的是后续独立R21 clean boundary，且只在
   该boundary内证明zero normal-data access。

禁止写“整个A2历史零normal-data access”“R13 retry修复/消除了incident”或
“已证明historical zero mutation”。通过前不进入A3，不commit/push/merge/release。

## 13. R22 current override — volatile containment and automatic attestation

本节取代本leaf所有把R21/Review21/后续用户四hash turn称为current gate的文字；它们只保留
immutable history。R21 exact四锚为freeze
`82ec117359bb0172867ed476c0da4a8d7d0fc60c5bd24f25c0f42e360f7996a4`、Review21
`13f75ac2979a25c8cf643e83f264663087c6bc18836696c518b247d7f6d3176b`、driver
`c56db7b465ae3d54923d958892e07e5575d4cf67b8b4946c7d6793e4f1bfb835`、manifest
`d5567a05e61e61a94b732814e24a89ecdb8e2a988d970dac33939f31798a9d86`。external caller四锚与
155/155通过；driver在`pre_begin_r19_containment`以70停止，发生在boundary/UUID/fresh
root及任何runtime artifact写入前。因此R21 authority未消费、12 paths与root globs absent，
不得补写或重跑；Core/TestSuite继续精确为R20 final SHA。

### 13.1 Historical volatile-root state contract

R19 state/bundle exact roots及R20 state exact root从历史`CANONICAL_EMPTY`单向进入
`ABSENT_TOMBSTONE`，原因记录`UNKNOWN`，ABSENT absorbing。R20 bundle parent只允许
`VERIFIED_RETAINED → VERIFIED_RETAINED|ABSENT_TOMBSTONE`与
`ABSENT_TOMBSTONE → ABSENT_TOMBSTONE`。R19/R20每次验证均须用
`find -P /private/tmp -mindepth 1 -maxdepth 1 -print0`完整drain top-level universe并带
`-e || -L`前后bookends；alternate/reappeared/wrong-type nodes失败。R20 retained候选只有在
canonical parent、exact child、36-node NUL universe、30 file hashes、aggregate与strict
codesign全部通过后才可成为`VERIFIED_RETAINED`；任何verification failure不得重新分类为
ABSENT。第一次完整观测另存immutable first-observed state；重复pre与所有post逐次走同一
单向表。同一次initial/verification/late-bookend只允许retained→retained或absent→absent；
pre retained/post absent可记录跨完整观测的monotonic disappearance，pre absent/post retained失败。

### 13.2 Review22 standing authority and entry

牧场主standing Goal已明确“不需要哈希值每步确认，继续完整落地”。Review22必须由未参与
R22六面/driver/manifest/freeze写作的职责隔离reviewer唯一写，并给出唯一exact verdict行
`Verdict: APPROVED — 0 P0 / 0 P1`、零个其他`Verdict:`行及唯一machine block。block内部恰有12行：

```text
authority_mode=standing_goal_automatic_after_review22
standing_goal_authority_verified=true
reviewer_independence_attested=true
reviewer_write_scope=review22_only
user_hash_echo_required=false
review_verdict=APPROVED_0_P0_0_P1
freeze_sha=<lowercase-64-hex>
driver_sha=<lowercase-64-hex>
manifest_sha=<lowercase-64-hex>
branch=codex/personal-ai-ranch-p0
head=02334ec8d21533be81d93d39191bc7d9b9c24f7f
manifest_count=159
```

Review22零P0/P1后，不再请求用户echo hashes。automatic caller先确认没有更新用户turn撤销
standing authority，再计算Review22 current SHA，以冻结clean env和absolute path只传该一个
参数给driver。driver独立解析唯一machine block及唯一human verdict，核对四current anchors、
branch/HEAD、159 manifest和containment。该self-attestation只证明local consistency，不
冒充human anti-rewrite、外部签名或独立身份的密码学证明。

### 13.3 Manifest, fresh names, implementation and completion

`r22-entry.sha256`精确159项：R21 155路径零删除，再加R22 driver、R21 manifest/freeze/
Review21；排除自身、R22 freeze/Review22、runtime与temp roots。六面变化后旧R21 manifest
必须149 unchanged + exact six mismatches；R22 pre-edit 159/159，post-edit 158 unchanged +
`AgentLoopTests.swift`唯一mismatch，`AgentLoop.swift`继续匹配R20 final。R22 fresh identity为
12个`r22-*`/`impl-report-r22.md` paths及两个`agentloop-r22-*` roots；pre-BEGIN零写入不消费，
本进程短暂signal-masked exclusive-create boundary成功才消费；EEXIST零append，成功并设ACTIVE
后立即恢复signal handlers；partial init/signal永久rejected并补写recovery authority evidence。
消费后第一批只读动作立即复证R21/R19/R20，之后仍重复复证；fail once且不得retry。

产品实现仍只允许在R20-final `AgentLoopTests.swift`增加§2.7冻结的三对/六行matching direct
DEBUG directives；Core与其余bytes不变。执行顺序仍为一次unfiltered full RunTests → same-log
46/46 → debug App/fresh bundle/sign/LAUNCH_READY → guard shape/strip → 两条target-exact release
→ 四objects → matrix/restoration → remaining source/privacy/hash → same-bundle preview → END。

R22 implementer只写`impl-report-r22.md`并将§12所有R21措辞机械更新为R22，同时必须明确记录：
R21 caller/manifest已通过但pre-BEGIN exit70、未消费/零写入；R19/R20 tombstone transitions与
UNKNOWN cause；R20 bundle pre/post terminal observed state；159→158+1；Review22 machine/caller
authority；全部R22 artifacts/hashes与只在R22 boundary内的zero normal-data claim。Review02由
未参与R13–R22规划/实施/preview的新reviewer在R22 END后唯一写；acceptance必须保留R19 651/652、
R20 release failure、R21未执行事实。Review22前禁止全部execution gates及产品/test/App-script
修改；A3/commit/push/merge/release/normal-data/外部/真实用户操作继续关闭。

## 14. R23 current override — monotonic historical-bundle erosion snapshot

本节取代§13全部current-gate措辞；R22转为immutable changes-required predecessor。
Review22
`bf007443ac2b1932fbde93cf908a99b50cb4878de3e485118092bb24552050b5`
以`CHANGES REQUIRED — 0 P0 / 1 P1`证明exact R20 bundle parent/App仍存在，但App只剩
六个historical directories、零regular files，故R22无法把它分类为
`VERIFIED_RETAINED`或`ABSENT_TOMBSTONE`。R22无approval machine block、未运行caller/
driver/BEGIN/任何gate，authority未消费、12 runtime paths与fresh roots均ABSENT；
R22六面、driver、manifest、freeze与Review22不得改写、补写、重跑或复用。

### 14.1 Review22 baseline and fixed universe

R23将R20 exact bundle压缩为不可变顺序的38-bit safe mask：bit0 bundle parent、bit1 App，
bits2–37沿用R20冻结36-node数组顺序。该node顺序依次从`Contents`、Info.plist、MacOS、
executable、Resources、inner bundle、RanchArt，经27项frozen RanchArt files，到
CodeSignature与CodeResources。Review22的exact current observation机械映射为：

`11101011100000000000000000000000000010`

它恰为38 bits/8 ones，即parent、App与六个目录。首次runtime pair提交前先验证
`REVIEW22_BASELINE → A`；baseline中任一0重现立即fail，因此FIRST虽然固定为A，也不能吸收
Review22后的reconstruction/reappearance。合法snapshot只有全0 bundle-absent、
`10+36 zeros` parent-only，或`11+baseline-node-subset` App partial；`01`非法。每个present
directory必须为exact non-symlink directory，每个present file必须为exact regular
non-symlink且hash等于R20冻结值；任何extra/alternate/symlink/special/wrong type/hash失败。

### 14.2 Complete-capture transaction

`r23-begin.sh`的每次observation必须连续完成capture A和B。每个capture均：

1. full-drain `/private/tmp` NUL universe并用前后presence/type/realpath bookends证明exact
   R20 identities及state-root tombstone；
2. parent存在时full-drain direct child universe，只接受zero child或exact App；
3. App存在时由单一child validator full-drain完整subtree，验证fixed membership/type/hash，
   并直接输出36-bit mask、node/dir/file counts；外层不得再次读filesystem拼mask；
4. subtree drain后再次重验parent/App presence、type、canonical realpath及exact-child；
5. 捕获每个outer parent完整status。find/read/hash/shape、partial EOF、missing status或
   indeterminate result一律fatal，不得变成mask 0。

首pair先比`BASELINE→A`，以后比`LATEST→A`；每pair再比`A→B`，逐bit只允许1→0或不变。
CAPTURE/counts是诊断working registers，A/B capture会在比较前reset/mutate，失败时可保留
incomplete/A/B staging，不能视为accepted lifecycle state。全部比较成功后才commit：第一次
`FIRST=A/LATEST=B`，以后只推进LATEST，pre/post accepted mode各保存B，并把诊断
CAPTURE/counts最终normalize为B。capture/comparison/bookend失败时只保证FIRST/LATEST与
accepted mode-B保持pair开始前的已提交值；诊断CAPTURE/counts必须保留失败点staging。
仅在FIRST/LATEST、final CAPTURE/count normalization与accepted mode-B assignments期间，
HUP/INT/TERM handler临时改为只记录deferred signal；全部赋值后立即恢复fail handler，并立刻
按任一deferred signal永久拒绝。authorization消费后的failure evidence保存safe global
baseline/FIRST/LATEST与diagnostic CAPTURE。只有all-one、36/6/30、aggregate与strict
codesign全过才能写current signed claim；在本冻结baseline下该分支不可达，partial evidence
只写historical signed hashes。

R23不提供filesystem transaction、filesystem lock或atomic snapshot，也不证明
inode/hardlink、xattr或resource fork不变，不能消除TOCTOU；完全发生并消失在两个capture
可见窗口之外的短暂节点可能不被观察到。本文的“原子”只指所有比较通过后，当前进程一次性
提交FIRST/LATEST变量。若未来要求原子文件系统保证，必须另开stage并重新Review。

### 14.3 R23 artifacts, Review23 and entry

R23 planner只新增`evidence/r23-begin.sh`，随后生成`evidence/r23-entry.sha256`与
`evidence/plan-freeze-r23.md`。manifest精确
`163 = complete R22 159 + R23 driver + immutable R22 manifest/freeze/Review22`；
排除自身、R23 freeze、Review23、runtime/temp roots。六面更新后R22 manifest必须153 pass+
exact six mismatches；R23实施前163/163，实施后162+TestSuite唯一mismatch。

R22的12 runtime paths与两类root globs在pre、final-pre、immediate-post与post-root均必须
ABSENT。R23 fresh runtime只可为12个`r23-*`/`impl-report-r23.md` paths及两个distinct
`agentloop-r23-{state,bundle}.*` roots。driver capture inventory为
`8P / 4S / 13C = 25`。R23 boundary名为
`R23_EROSION_SNAPSHOT_AND_RELEASE_CONFIGURATION_REPAIR`，exclusive-create前零写、成功后
才消费；signal/partial-init/fail-once语义不变。

Review23由未写本轮六面/driver/manifest/freeze的职责隔离reviewer唯一写。正文须有且仅有
`Verdict: APPROVED — 0 P0 / 0 P1`，并含唯一12-line machine block：

```text
authority_mode=standing_goal_automatic_after_review23
standing_goal_authority_verified=true
reviewer_independence_attested=true
reviewer_write_scope=review23_only
user_hash_echo_required=false
review_verdict=APPROVED_0_P0_0_P1
freeze_sha=<lowercase-64-hex>
driver_sha=<lowercase-64-hex>
manifest_sha=<lowercase-64-hex>
branch=codex/personal-ai-ranch-p0
head=02334ec8d21533be81d93d39191bc7d9b9c24f7f
manifest_count=163
```

Review23零P0/P1且无更新用户turn撤销standing Goal后，agent自动计算Review23 SHA，以冻结
clean env只传该一个参数给driver；不再要求用户echo四hash。该block只提供local consistency，
不冒充外部signature或human anti-rewrite。

### 14.4 Implementation, report and completion

future source delta仍且仅为R20-final `AgentLoopTests.swift`三对matching direct
`#if DEBUG/#endif`六行；Core、Package graph、API、schema、migration与其他产品/test/
App-script bytes不变。BEGIN后顺序仍是唯一unfiltered full RunTests、same-log 46/46、
debug build、fresh bundle/sign与LAUNCH_READY、guard-shape/strip、target-exact releases、
four-object gates、matrix/restoration、remaining source/privacy/hash、same-bundle preview、
END。任何failure永久reject且不得retry/patch/root swap/object swap。

implementer只写fresh `impl-report-r23.md`及R23 runtime evidence；report必须披露Review22
partial skeleton/8-bit baseline、R22未执行零写、FIRST/PRE/POST/LATEST masks、当前count与
signed-claim布尔、163→162+1、R19/R20/R21历史以及只在R23 boundary内的zero normal-data
结论。Review02与acceptance只在R23 END后按既有职责隔离顺序打开，并继续披露R19 651/652、
R20 release failure、R21/R22未执行。Review23前禁止全部execution gates和产品/test/App
script改动；A3、commit/push/merge/release、R20 mutation、normal-data、外部与真实用户操作
继续关闭。

## 15. R24 current override — in-driver Bash full-test status capture

本节取代§14全部current-gate措辞。R23以approved四锚完成BEGIN并落地唯一六行DEBUG
directives；Core current hash仍为
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`，Test current hash为
`37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967`。唯一unfiltered full
test log终端652/652，但外层zsh wrapper无法读取Bash `PIPESTATUS`，Swift/tee rc均为
UNKNOWN；R23永久rejected，same-log audit与全部后续门未运行。十个R23 logs、final report、
两个exact empty roots、planned App/executable absence及screenshot absence均immutable。

R24 product/source delta精确为0。fresh R24 driver/178-entry manifest/freeze及Review24构成
唯一入口。manifest方程为`178 = R23完整163 + R24 driver + immutable R23 manifest/freeze/
Review23 + R23十个runtime logs + impl-report-r23.md`；R24 manifest自身、freeze、Review24、
R24 runtime/temp均排除。旧R23 manifest只允许156 unchanged + Test与六面七个mismatch。
source delta=0只指产品/test/App与永久script bytes；entry、每个mutation前、matrix恢复后与END
必须178/178。既有matrix窗口只允许matrix script line115 Stage hash单值临时delta，精确
177+script唯一mismatch；success/error/signal均mandatory恢复，恢复失败只能恢复并永久reject。

R23 state/bundle roots按fixed two-bit baseline `11`。每个capture先证明`/private/tmp`为exact
real non-symlink canonical directory，再full-NUL drain top-level universe并拒绝alternate；
present root必须exact real non-symlink canonical empty并有terminal bookends。每轮双capture，
首次baseline→A、以后LATEST→A，且A→B均只允1→0；FIRST/LATEST/accepted mode-B在defer-only
signal section一次commit。UNCHANGED cause=`NOT_OBSERVED`，ERODED cause=`UNKNOWN`。R20 fixed
38-bit erosion、R19 tombstone与R16–R18/R21/R22 zero-write/root absence继续逐轮复证；
final pre-END也必须从handoff LATEST继续，禁止重置baseline或静默吸收disappearance。
R24不提供filesystem transaction/lock/atomic snapshot，也不证明inode/hardlink/xattr/resource
fork不变或消除capture窗口外TOCTOU；变量commit不等于filesystem atomicity。

R24 caller必须是clean `env -i`加绝对`/bin/bash --noprofile --norc`，固定PATH/locale/TMPDIR/
Git config且BASH_ENV/ENV/CDPATH unset。driver验证canonical `$0`/`BASH_SOURCE`、Bash 3.2、
branch/HEAD、Review24、178/178、all predecessors与source baselines。exclusive BEGIN后driver
自己创建fresh zero-byte verify log，在exact `cd -P` repo中无条件运行一次full-test pipeline；
then/else第一句复制exact `PIPESTATUS`，禁止`!`/`$?`/`set +e`/`|| true`。shape=2且两个numeric
status最后commit captured flag，只有0/0和唯一652/652 summary继续；log SHA/bytes随handoff冻结。

Review24须职责隔离且只写`reviews/24-p1-plan-review.md`，唯一verdict为
`Verdict: APPROVED — 0 P0 / 0 P1`，唯一12-line machine block固定standing Goal automatic
authority、reviewer scope、no hash echo、三hash、branch/HEAD与count 178。Review24通过且Goal
未撤销后自动caller无需用户回传hash。

driver success后执行same-log 46/46（读前后复证log SHA/bytes）、debug App/fresh bundle/sign/
LAUNCH_READY、formal guard-shape/strip-to-R20、两条target-exact release、four objects、matrix/
restoration、remaining source/privacy/final hashes、same-bundle preview、final lifecycle、END。
所有Bash-only status capture留在显式clean Bash 3.2；任一failure fail once。R24 implementer只写
fresh 12 paths、两fresh roots及`impl-report-r24.md`；Review02/acceptance只在END后打开。

### 15.1 R24 final single-process clean-execution contract

本段是六个控制面的同一份最终 current override；它取代本轮较早的 R24 `handoff`、普通
`mv`、`kill -0` ownership 与 boundary 忽略信号措辞，但不改写 R15–R23 immutable 历史。
R24 仍是 source delta 0：Core 固定
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`，TestSuite 固定
`37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967`；178-path manifest
方程、R23 的 156 unchanged + 7 expected mismatches、R23 163 paths + 15 additions、
R20/R23/R15 历史与 zero-write red lines 全部保持。R24 manifest 排除自身、freeze、Review24、
12 个 R24 runtime paths、两个 fresh roots，以及 invocation-owned hidden publish stages。

1. caller 只可用冻结的 clean `env -i` 与 system Bash 3.2 调用 driver，并只传 Review24 SHA。
   从 BEGIN、唯一 full test、全部 mechanical gates、两次 preview 到 END 必须在同一个 reviewed
   Bash process 内完成，不存在 caller continuation 或 handoff。canonical cwd/self、exact env、
   branch/HEAD、Review24 machine block、178/178、predecessors 与 source hashes 在 preflight 和
   final pre-BEGIN 重证。BEGIN boundary 使用 defer-only HUP/INT/TERM window 与 O_EXCL；成功后先
   `BOUNDARY_ACTIVE=true`、恢复 fail traps并立即消费 deferred signal。EEXIST 只 pre-BEGIN fail，
   不 append、不消费 authority；成功消费后的任一普通 signal/failure永久
   `REJECTED_CONTAMINATED`。

2. driver 独占创建 fresh verify log，并在同一顶层 Bash 运行唯一 unfiltered
   `swift run RunTests | tee`；then/else 第一条都复制 exact two-element `PIPESTATUS`，随后在
   defer-only commit 中写 Swift rc、tee rc、`status_captured=true`。只允许 `0/0`、唯一
   `652/652`、7 suites/0 failures 与 same-log 46/46 继续。之后顺序固定为 debug build → fresh
   signed bundle → guard strip → target-exact Core/TestSuite release → four object symbol gates →
   matrix 177+1 window及mandatory restore → source/privacy → same-bundle preview → final reproof →
   staged report/END。matrix backup、mutated stage、restore stage各有独立 OWNED flag，只能在各自
   O_EXCL成功后置true；禁止预删，copy/write只落到owned path，成功publish/cleanup即清flag；
   EEXIST保留unowned path并reject。success/error/signal只按exact ownership恢复或清理；恢复失败
   只能继续containment并永久reject。

3. R24 fresh state/bundle roots初始都必须 exact real non-symlink empty。current phase 只允许：
   `empty`；`bundle_ready`；`preview_live` 时 state exact
   `{.agentloop.lock, agentloop.sqlite, agentloop.sqlite-shm, agentloop.sqlite-wal}`；
   `preview_quiescent` 时 exact base two，且 WAL/SHM 必须成对同时 absent 或同时为 regular file，
   禁止 extra。R23 two-bit baseline `11`与R20 38-bit universe继续以完整 A/B capture只允
   1→0；R15 exact tombstones、alternate identities与全部 predecessor zero-write逐门 fail closed。

4. fresh bundle 使用 invocation-unique合法 `CFBundleIdentifier`，signed `Info.plist` 只带 exact
   `LSEnvironment` 的 isolated state root 与 preview=1；bootstrap 与 cold 都直接执行同一个 exact
   signed executable，显式传两项 env、stdin `/dev/null`、PID 只取 `$!`，不得用 `open`、display
   name、bundle-id fallback或 `pgrep` 建立 ownership。launch 前将 signals 改成 defer-only，覆盖
   fork、`$!` assignment、PPID/lstart capture；identity commit后恢复 fail traps并消费 deferred。
   containment与正常 Quit 都以两轮稳定 `jobs -pr`/`jobs -ps` running+stopped membership为 Bash
   active-job gate；TERM/KILL 前即时再验 `PPID==driver $$`，已 commit 时还须 exact `lstart`。
   pre-exec command mismatch只作诊断，不能阻止已证明 owned child的containment；active set absent
   才消费 cached `wait`，禁止用 `kill -0` 对可能已复用的 OS PID 作 kill authorization。

5. bootstrap B01–B06 exact flow 为 onboarding → `进入我的营地` → dashboard 唯一 feed hero且
   `查看全部` 0 → App menu → 唯一 `Quit AgentLoop` → Quit；随后只在 isolated DB 事务安装
   `a2-preview-ingestion-recovering` / `a2-preview-work-recovering` fixture，标题`隔离恢复验证`、
   raw text `A2 isolated synthetic rumination fixture`、ruminating attempt 1、queued attempt 0/
   max 4、canonical input/trace/idempotency/nullables/FK/integrity均 exact。cold C01–C09 为
   dashboard `查看全部 1`唯一 → inbox fixture/`查看进度`唯一 → recovering detail；C05 exact
   metrics 是标题1、`保存原文，已完成` 2、`正在恢复，正在进行` 3、后三阶段0；C06只复制 C05
   已有 screenshot URL 到 exact raw path，不再读取 UI 或执行 UI action；随后 menu/Quit。
   每个观察使用完整 app path、full state、`disableDiff=true`、nonce exact reply、unique label
   count；坐标与 fallback 禁止，B06/C09 后不得再调 UI。

6. screenshot raw file先验 magic/bytes/SHA；normalization stage必须在 evidence 同目录以
   invocation path O_EXCL 创建并标记 owned，`sips`只写该 owned path，随后完成 PNG header/IHDR、
   dimensions、full decode/MIME/SHA。publish 前即时重证 fixed final absent，使用 `mv -n`，且
   stage absent、final regular non-symlink、final SHA等于 staged SHA才发布成功。no-op/EEXIST
   只能清本 invocation owned stage，绝不覆盖或删除 unowned final；成功后 raw/stage清理，failure
   的 isolated raw保留为 contaminated evidence。

7. `impl-report-r24.md`同样先写 task 同目录 invocation-owned O_EXCL hidden stage，完成内容、
   privacy、type 与 SHA 后才发布。final 前即时 absent，`mv -n`后必须 stage absent、final regular
   non-symlink且 exact staged SHA；active failure只可删除 owned stage，或在 END 尚未 commit 且
   published final仍匹配 exact staged SHA时删除，绝不删除 unowned/tampered final。report publish
   window 的 deferred signals在 postconditions 后恢复 normal traps并立即永久reject。唯一
   commit-wins 例外只从随后 fresh tiny END-append window 开始：一次写入以 `status=END`、
   `result=PASS`结尾的完整 block；成功后同一 simple command设置 `END_COMMITTED=true` 与
   `BOUNDARY_ACTIVE=false`，再清 traps。END 前或 append failure都清理未提交 PASS report并写
   `REJECTED_CONTAMINATED`；END commit后不得再追加 rejected。

8. evidence 只允许声称所有已观察 preview processes 为 exact isolated direct children、normal
   root observed-open count为0、未观察到replacement；不得声称覆盖未观察区间、filesystem
   transaction/lock、零 preference write或绝对没有 TOCTOU。invocation-unique UserDefaults
   onboarding write必须在report披露。Review24仍须职责隔离、唯一 `APPROVED — 0 P0 / 0 P1`
   与唯一12-line machine block（standing Goal automatic/no hash echo、three hashes、branch/
   HEAD、count 178）。Review24与新 freeze/manifest完成前继续禁止 caller/BEGIN、所有 execution
   gates、Review02/acceptance/A3及任何产品/test/App/permanent-script修改；commit/push/merge/
   release、normal-data、外部沟通与真实用户操作始终未授权。

## 16. R25 current override — numeric-rendering root-cause closure

本段是六个控制面的同一份最终 current override；它不改写 R15–R24 immutable
历史，只把 R24 已证明的 harness false negative 与 R25 的唯一修订路线设为 current。
R25 的 source/product/test/App/permanent-script delta 精确为 0；Core 固定
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`，TestSuite 固定
`37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967`，matrix script 固定
`75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`。R25 不重新解释、
补写、清理、删除、重命名或复用任何 R24 evidence/root。

1. R24 freeze `f22a7ffd954ddf6d9b2d804a5f3be58807373c388634b9200d260f1a8eb66746`、
   Review24 `a9ef2cab24afa65290f563b85ac03022b958d39253c025017d1c91b689926c0e`、
   driver `1b224f442d1fdea856433d12141e5ea9f74190a380e554e4ec94872ba0b8655f`
   与 178-entry manifest
   `55a6c2e8a657166de8b983cd0edfb2a7b1ae1943dc291819c0c2ea417338a80c`
   均 immutable。R24 唯一 BEGIN 内的 authoritative Swift/tee rc 是 `0/0`，terminal
   `652/652`、7 suites/0 failures、same-log `46/46`、debug build、fresh signed bundle 与
   `LAUNCH_READY`均通过；随后 guard gate 以
   `reason=core_guard_shape_1:1::0:1:1`、phase `guard_shape_and_strip`、exit 70
   永久 `REJECTED_CONTAMINATED`。这些 partial green 既不等于 END，也不得替代 R25 的
   full rerun、Review02 或 acceptance。

2. 同一根因是 awk 未初始化数字在字符串拼接时渲染为空：Core parser 的 `bad` 实际为数值
   0，却输出 `1:1::0:1:1`；未到达的 TestSuite parser 具有同样潜在输出
   `3:3:6::0:1`。R25 只做 render-only numeric closure，不改变任何 predicate、token、
   guard line、source byte、test logic、build command、API、schema、migration 或产品语义：
   Core 六字段 `opens/closes/bad/depth/token/guarded`、TestSuite 六字段
   `opens/closes/directives/bad/depth/ok`均以 `+ 0`输出；same-log 顶层七个计数
   `run_started/test_started/test_passed/suite_started/suite_passed/failure_markers/summary`
   同样以 `+ 0`输出；matrix 两个 line scanner 只把 diagnostic
   `count/line`渲染为 `(count + 0):(line + 0)`。逻辑条件与失败语义逐字保持。

3. Core 与 TestSuite guard parser 各只有一个 pure helper。preflight 与 final pre-BEGIN
   都复用同一 helper，必须在 authority consumption、verify-log 创建和 full test 前分别得到
   exact `1:1:0:0:1:1`与`3:3:6:0:0:1`；active
   `guard_shape_and_strip`再次调用同一 helper，不复制第二套 parser。任何空字段、非 exact
   output、read failure 或 source drift 都在对应边界 fail closed；pre-BEGIN failure保持
   零 repository write且不消费 authority，BEGIN 后 failure永久reject。

4. R24 的十个既有 runtime files由 R25 逐一以 exact SHA、regular/non-symlink type和关键
   boundary事实重证：唯一 rejection、captured `0/0`、652/652、46/46、launch-ready、
   matrix restore-attempt count 0、matrix未mutation、无preview owned process、无END。
   `r24-migration-matrix.log`、source、bootstrap与cold logs是合法zero-byte historical
   artifacts；`impl-report-r24.md`与`r24-preview-smoke.png`必须继续 absent。R24 state root
   `/private/tmp/agentloop-r24-state.Qko2Y3`与bundle root
   `/private/tmp/agentloop-r24-bundle.OPfuVv`只作为historical observation，不是R25运行输入。

5. R24 root lifecycle固定39-bit universe：state root、bundle parent、App与exact 36个
   descendants（6 directories、30 regular files），planning baseline为39个`1`。present
   state必须exact canonical empty；present bundle/App/node必须exact identity、type与每文件hash，
   无extra/symlink/special/wrong type/hash；full 36-node set另须aggregate
   `1871d346bed8b7978f7456e2893218a97cad7b8dc643c84bba9cd87cb81c8b5e`、
   strict codesign与CDHash
   `17bd20ada27ef9e69d0de007b49c53d01ddf48a6`。每次observation完整A/B双capture，
   `BASELINE/LATEST→A→B`只允1→0；FIRST/LATEST/accepted-B只在全部比较通过后的同一
   defer-signal commit写入，0→1、alternate、indeterminate或substitution永久reject。R25从不
   mutate/clean这些roots；R23 two-bit、R20 38-bit、R15 tombstones及所有zero-write
   predecessor gates继续保留。该观察不提供filesystem transaction/lock，不证明inode/hardlink、
   xattr/resource fork或消除TOCTOU；未观察区间不能外推。

6. R25 static manifest精确为`192 = R24 178 + 14`：完整R24 path set，加fresh R25 driver、
   immutable R24 manifest/freeze/Review24及十个R24 runtime files。六面同步后旧R24 manifest
   必须精确`172 unchanged + 6 expected control-surface mismatches`；TestSuite不再是mismatch。
   manifest排除自身、R25 freeze、Review25、12个R25 runtime paths、两个fresh roots与全部
   invocation-owned hidden stages。entry、每个mutation边界、matrix restore后与END必须
   `192/192`；唯一matrix窗口只允许`191 unchanged + matrix script 1 expected mismatch`，
   三个independent OWNED flags、O_EXCL、no-pre-delete、owned-stage replacement/exact
   restoration与fail-once
   containment合同全部继承且不放宽。

7. R25 caller只可用冻结的clean `env -i`与system Bash 3.2调用fresh
   `r25-begin.sh`，只传自动计算的current Review25 SHA。R25使用全新的12个runtime names、
   `agentloop-r25-state.*`/`agentloop-r25-bundle.*` roots、invocation ID、bundle identifier、
   hidden stages与boundary；不得复用R24 root、bundle、binary、verify log或测试结论。从BEGIN、
   唯一unfiltered `swift run RunTests | tee`及即时two-element `PIPESTATUS` capture、
   same-log 46/46、debug build/fresh signed bundle、guard/strip、target-exact releases、
   four-object gates、191+1 matrix/restoration、source/privacy、same-bundle bootstrap/cold
   preview、staged report到END，必须在同一个reviewed Bash process内完整重跑，禁止handoff、
   caller continuation、重跑、patch-on-failure或换root/object。

8. R24 final contract中的O_EXCL boundary与deferred-signal consumption、fresh-root phase/type
   gates、direct `$!` launch、stable Bash jobs + PPID/lstart containment、禁止以`kill -0`
   授权kill、exact B01–B06/C01–C09 UI与isolated fixture、screenshot/report `mv -n`
   no-clobber publish、
   privacy/source gates以及唯一tiny END commit-wins window全部逐字继承。R25 evidence只能声称
   已观察process为exact isolated direct child、已观察normal-root open count为0且未观察到
   replacement；不得声称覆盖未观察区间、绝对无TOCTOU或zero preference write，且report必须
   披露invocation-unique UserDefaults onboarding write。

9. Review25必须职责隔离：reviewer不得写R25六面、driver、manifest或freeze，唯一repository
   write只能是`reviews/25-p1-plan-review.md`；正文只可有一个
   `Verdict: APPROVED — 0 P0 / 0 P1`及唯一12-line `R25_MACHINE_BLOCK`，authority mode为
   `standing_goal_automatic_after_review25`、`reviewer_write_scope=review25_only`、
   `user_hash_echo_required=false`，并绑定current freeze/driver/manifest三hash、固定
   branch/HEAD与`manifest_count=192`。Review25通过且无更新user turn撤销standing Goal后，
   root agent自动计算Review25 SHA并调用冻结caller，不再要求用户echo hashes。

10. R25 manifest、freeze与独立Review25完成前，caller/BEGIN、test/build/matrix/source/
    bundle/preview及任何产品/test/App/permanent-script修改继续禁止。只有R25 exact END及全部
    technical gates通过后，才可由新的职责隔离reviewer写`reviews/02-p1-a2-review.md`；只有
    Review02零P0/P1才打开独立acceptance，A3及以后slice始终关闭。commit、push、merge、
    release、数据重置、normal-data access、付款、公开沟通、外部操作与真实用户操作均未授权。
    任何新架构、范围、依赖、测试门、语义或证据缺口必须重新进入正式有界修订与职责隔离Review，
    不得由本段或standing Goal自行扩权。


## 17. R26 current override — ERR-subshell root-cause closure

本段是六个控制面的同一份 current override；它不改写 R15–R25 immutable 历史，只把
R25 已证明的 Bash `ERR` trap/status-capture 根因与 R26 唯一有界路线设为 current。
R26 的 source/product/test/App/Package/schema/migration/permanent-script delta 精确为 0；Core、
TestSuite 与 matrix script bytes 分别继续固定为
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`、
`37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967`与
`75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`。R26 不重新解释、
补写、清理、删除、重命名或复用任何 R25 evidence/root。

1. R25 freeze `8e6d97aca80591f544b40a8b645c01f1c5624f0f120d5ac12cedf37b94ffbeca`、
   Review25 `65b738e9c977e97ec6acdfbadad938d43ff97213c42e3b56297e67998dec237e`、
   driver `1eee61d199c5bb1c5b0149989f17508e9a75eacfbc2bac3b1a2f0063f0ab68bb`与
   192-entry manifest
   `462be6ff554b3d38bea76ac8351a77f780b575a1a9aeae4a461e42dd303655ba`均
   immutable。R25 唯一 BEGIN 内 full test 是 captured Swift/tee `0/0`、terminal
   `652/652`、7 suites/0 failures；same-log `46/46`、debug build、fresh signed bundle、
   guard/strip、Core/TestSuite target-exact releases、four-object symbols、SQLite 3.51/3.52
   matrix restore、source/privacy/final hashes与pre-preview `192/192`均通过。R25 未收到任何
   UI challenge，未写 screenshot/report，且无 END，因此永久 `REJECTED_CONTAMINATED`，不得
   替代 R26 full rerun、Review02 或 acceptance。

2. R25 在 `preview_bootstrap_direct_start`依次留下三个 rejection blocks：child substitution
   内 `/usr/bin/pgrep -x "${r25_name}"` rc 1、同一 child function 的显式
   `return "${r25_rc}"` rc 1，随后 root caller 因 app 已被 child containment终止而以
   `preview_command_read_failed_bootstrap_ready` exit 70。根因不是产品、bundle、SQLite、UI或
   process identity失败，而是全局 `set -E`把 root `ERR` trap继承进 command-substitution
   subshell；child将预期 absent/transient nonzero误当成 root failure并执行root-owned cleanup。
   R25 final containment最终reap exact child，AgentLoop/AgentLoopApp均不存在，但三次reject与
   no-END事实不可合并、删除或美化成一次成功边界。

3. R26 的唯一 causal fix 位于 fresh `r26_err_trap`最前：先保存真实`$?`与
   `${BASH_COMMAND}`，随后在任何日志、active/pre-BEGIN failure或cleanup之前执行
   `if (( BASH_SUBSHELL != 0 )); then trap - ERR; exit "${r26_status}"; fi`。child只把原始
   status传播给root caller，绝不执行active/pre-BEGIN containment；root shell
   `BASH_SUBSHELL == 0`时仍逐字走原 fail-fast 路径。禁止增加child-local `EXIT` trap、全局
   关闭ERR、`|| true`、吞错、改caller分类或packet/fallback旁路。该一处root fix统一覆盖
   exact-name absent/caller、`pgrep -P` no-child、launch identity `ps` retry、startup
   readiness `ps/lsof`、signal authorization/live-proof与quit-wait `ps` disappearance；
   rc > 1、malformed、duplicate、unexpected payload与identity mismatch仍fail closed。

4. final pre-BEGIN必须通过一个静态guard/inventory门与八类system Bash 3.2 micro-probes。
   静态门证明guard在root cleanup之前、全driver无`EXIT` trap，并把同根nested capture精确
   清点为15个`/bin/ps`、2个`/usr/bin/pgrep`、3个`/usr/sbin/lsof`。micro-probes必须证明：
   legacy形态产生两次child cleanup；fresh guard下exact-name absent、exact-name present、
   no-child、transient ps retry、transient lsof safe subset与rc 2 indeterminate分别保留原rc/
   payload且child active side-effect为0；最后raw未捕获`x="$(false)"`向root传播并恰好触发
   一次root fail-fast。任何probe/inventory/guard-order偏差在BEGIN前零repository-write停止且
   不消费authority。

5. R25 的十个实际runtime files继续以exact SHA、regular/non-symlink type及关键boundary
   事实重证：targeted、verify、build、matrix、boundary、bundle、source、hash、bootstrap与
   cold logs分别固定为
   `538cf3ff68d95318ab7da9dc7a685648f4c7651668ca0c6fcf4dc35c8a48e532`、
   `9a0d772ac0f36cf56b2340c741d237dfbc2a4a6a9ecd4314bb5b95319f7b8b5f`、
   `cc50f7f484bb397052dae2be64307361e99255fd27169648cb4ac36aa75dd703`、
   `7c0e55705520fe79281e7a38b409177515f00fedc89eb8c8bf68fc0f4f74dca9`、
   `2d1dabc7872b31b7d330700c0979857563af84491ff39391b3bf9279ff50c0d4`、
   `5bdfdad577d4f9c0c029463c59cf442b83122939f76e59c435e89371e682e3d5`、
   `8d995eeb44fbccd42d9f83a0b64088d35f326ac8dd0051198327320ca2f0466f`、
   `bba9e1ffd51e2f8fb066d00226fc18f9e4f66b9c32f1917129522b471706564a`及
   两个empty SHA。`impl-report-r25.md`与`r25-preview-smoke.png`必须继续absent；任何R26
   evidence不得声称R25到达UI或END。

6. R25结束后，一次职责隔离evidence audit用SQLite read-only URI打开了R25 WAL-mode state
   database；它未改repository、bundle、normal-data或用户root，但可能更新`-shm`，且缺少
   before hash/mtime，故R25 state root从此明确标记
   `POST_REJECTION_READ_PROBE_CONTAMINATED`。R26对R25 state root
   `/private/tmp/agentloop-r25-state.fs7Cz2`与bundle root
   `/private/tmp/agentloop-r25-bundle.Ozi6d3`只允许coarse two-bit root-entry lstat/type A/B
   observation：baseline `11`，每轮完整A/B，仅允许equality或1→0，0→1、alternate、symlink、
   wrong type或indeterminate拒绝。本项的alternate只指这两个exact path的root-entry shape不是
   约定real directory；固定two-bit universe不扩张到parent/glob扫描，也不声称检测same-type
   inode replacement。严禁进入、枚举、hash、open或clean任一R25 root/descendant，
   严禁把R25 state contents/hash当作original terminal evidence或R26运行输入；FIRST/LATEST/
   accepted-B仍只在全部比较通过后同一defer-signal commit。R23、R24、R20 lifecycle与R15
   tombstones继续按既有合同观察。

7. R26 static manifest必须精确为`206 = R25 192 + 14`：完整R25 path set，加fresh R26
   driver、immutable R25 manifest/freeze/Review25及十个实际R25 runtime files；R25 driver已在
   old 192内，不得重复。六面同步后旧R25 manifest分区必须精确
   `186 unchanged + 6 expected control-surface mismatches`。R26 manifest排除自身、R26
   freeze、Review26、12个fresh runtime/report paths、两个fresh roots与全部invocation-owned
   hidden stages。entry、mutation边界、restore后与END必须`206/206`；唯一matrix窗口只允许
   `205 unchanged + 1 owned matrix-script mismatch`，既有O_EXCL、no-pre-delete、三OWNED flags、
   exact restoration与fail-once containment均不放宽。

8. R26使用全新12个runtime names、`agentloop-r26-state.*`/
   `agentloop-r26-bundle.*` roots、invocation ID、bundle identifier、hidden stages与boundary。
   从BEGIN、唯一unfiltered `swift run RunTests | tee`及即时two-element`PIPESTATUS`、same-log
   46/46、debug build/fresh signed bundle、guard/strip、target-exact releases、four-object gates、
   205+1 matrix/restoration、source/privacy、same-bundle B01–B06/C01–C09 preview、staged
   screenshot/report到tiny commit-wins END，必须在同一reviewed Bash 3.2 process完整重跑。
   禁止复用R25 root/binary/log/result，禁止handoff、caller continuation、retry、patch-on-failure
   或换root/object；UI evidence claim继续限制为observed intervals，不外推绝对无TOCTOU、绝对
   zero normal-root open或zero preference write。

9. Review26必须职责隔离：reviewer不得写R26六面、driver、manifest或freeze，唯一repository
   write只能是`reviews/26-p1-plan-review.md`；正文只可有一个
   `Verdict: APPROVED — 0 P0 / 0 P1`及唯一12-line`R26_MACHINE_BLOCK`，authority mode为
   `standing_goal_automatic_after_review26`、`reviewer_write_scope=review26_only`、
   `user_hash_echo_required=false`，并绑定current freeze/driver/manifest、branch/HEAD与
   `manifest_count=206`。Review26通过且无更新user turn撤销standing Goal后，root agent自动
   计算Review26 SHA并调用冻结caller，不要求用户echo任何hash。

10. R26六面、fresh driver、exact 206-entry manifest与freeze均已冻结；Review26此刻仍absent，
    caller/BEGIN、test/build/matrix/source/bundle/preview、Review02、acceptance及任何产品/test/
    App/Package/permanent-script修改继续禁止。只有manifest/freeze完成并由独立Review26零P0/P1
    批准后才自动执行；只有R26 exact END及全部technical gates通过后才可创建独立Review02；
    只有Review02零P0/P1才打开A2 acceptance，A3及以后slice仍关闭。commit、push、merge、
    release、数据重置、normal-data access、付款、公开沟通、外部操作与真实用户操作均未授权。
    任何新架构、范围、依赖、测试门、语义或证据缺口必须重新进入正式有界修订与职责隔离Review，
    不得由本段或standing Goal自行扩权。

## 18. Open Questions

无。

## R27 current override — compound-if status capture root-cause closure

本段是六个 current control surfaces 的 byte-identical override。R15–R25 历史继续
immutable；R26 也永久保留为 `REJECTED_CONTAMINATED`。R27 不重新解释、补写、清理、删除、
重命名或复用任何 R26 evidence/root，且 source/product/test/App/Package/schema/migration/
permanent-script delta 精确为 0。Core、TestSuite 与 matrix script bytes 继续固定为
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`、
`37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967`与
`75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`。

1. R26 predecessor 四锚固定为 freeze
   `0306f000961e6ed7b129307475495cb3a798df2adb833a9da830e5ddc70ef7cb`、Review26
   `8d9cc6b3acaeda72204b1a71f209996344215b61747b8c516d7afbf067880ba9`、driver
   `937a8cb4e737480f5cf44409d9dedbcdd581f627c46726957352a7b56f5c296d`与206-entry manifest
   `f9d697f35227e6db7df1e8e1b87c4969a184b0a7f65a3d6c70f7c8bfe5d7a22d`。R26 唯一 BEGIN
   已 captured Swift/tee `0/0`、terminal `652/652`、7 suites/0 failures；same-log `46/46`、
   debug build、fresh signed bundle、guard/strip、target-exact releases、four-object gates、
   SQLite 3.51/3.52 matrix restore、source/privacy/final hashes及pre-preview `206/206`均通过。

2. R26 到达真实 same-bundle bootstrap preview，B01–B06 的六个 challenge 与六个 result
   全部 PASS；B06 后 App 已正常退出。随后在 `preview_bootstrap_direct_start`以唯一
   `quit_wait_job_table_indeterminate_bootstrap_0`拒绝。cold log empty；C01–C09、fixture、
   screenshot、impl report与END均未发生，因此上述结果不能替代R27 full rerun、Review02或
   acceptance。R26 final containment后exact child已reap，且无残留AgentLoop/AgentLoopApp。

3. 唯一根因是Bash 3.2 compound-`if` status语义：生产路径精确五处采用
   `if r26_preview_active_job_exact; then ...; fi`后再读`$?`。当helper真实返回1（stable
   `ABSENT`）时，无`else`且未执行then-body的compound `if`自身状态为0，故caller读到0并误报
   indeterminate；这不是job-table classification、UI、process identity、bundle或产品错误。
   R27只把这五处改为`else`分支第一语句立即保存`r27_job_rc="$?"`。其余8处既有explicit-else
   capture、helper的0/1/2分类、signal/kill/wait/containment算法及所有fail-closed边界逐字保留。

4. 为关闭R26 evidence audit指出的P1可观测性缺口，job-table helper只新增三个安全global
   diagnostics：last previous state、last latest state与returned rc；state值只来自
   `UNOBSERVED/RUNNING/STOPPED/ABSENT/TRANSITION`，rc只来自`UNSET/0/1/2`，绝不保存或输出
   任意jobs/ps/lsof payload。正常quit log必须记录真实job rc与state pair；rejection boundary
   必须记录containment后的latest diagnostic。诊断不改变任何classification、retry、signal、
   cleanup或acceptance语义，rc 2继续indeterminate fail closed。

5. 两轮final pre-BEGIN（均在caller/BEGIN及任何repository write前）各自依次执行既有
   ERR-subshell static guard与八类Bash 3.2 probes，再执行fresh compound-if static gate与
   Bash 3.2 probes。fresh static gate必须证明production helper精确13 calls/13 immediate
   else captures、上述五个causal sites精确存在、production中`fi`后或同一行后读`$?`为0，
   diagnostics assignment只属于安全enum。fresh probes必须证明rc 0、rc 1、rc 2逐字捕获，
   rc 1 diagnostics为stable absence，rc 2 diagnostics与classification保持fail closed，并以
   legacy no-else probe证明helper rc 2会被compound `if`错误映射为0。任何偏差pre-BEGIN零写入
   停止，且不消费standing Goal authority。

6. R26十个runtime files必须以regular/non-symlink type、exact SHA与exact bytes重证，顺序为
   boundary `814ad7bfc50dfa6e5de65b10f470c8dee3bdbfed3ee2532776ad7011658b2280`
   /14381，hash `7041b3fc36c6fcc5a0686d9deb95cb4c6738425579f62b904dfbcd83aebf3198`
   /6063，verify `212a205b2baaf8d052513f148199ea8679ab625d0d607255e58a2d6807b61ea8`
   /96130，targeted `24b321736976667737b38eefcd79c11ecfc90322b9a495e63d7f6fcf52436fea`
   /4718，build `068e012ddb71725eac797c2b76f56972a403048ff0fed5010a7d14ad0ffc6fc6`
   /729，matrix `124b28b317581ea19b7647dfa084ebc7e3c3394fe02c9a40fd80d2de20006932`
   /44058，bundle `c5604214b12c265fe0100a500491a08eeff7ab95d543b753d2ee433ad459d906`
   /2661，source `58c90e5840c6c14d529ecb53f1b6ada95d2707a4b99d4c18fedee1c253767b76`
   /2998，bootstrap `d10ee7940284ccb289ba48a40284e3c539f421054e39718b02d7a94499b53733`
   /6557及cold empty SHA/0 bytes。`impl-report-r26.md`与`r26-preview-smoke.png`必须absent；
   boundary的BEGIN/652/652/46/46/launch/source/206/206/B01–B06/rejection/no-END关键事实必须重证。

7. R27对R26 state root `/private/tmp/agentloop-r26-state.JlHsbi`与bundle root
   `/private/tmp/agentloop-r26-bundle.mCj70H`只允许按此固定顺序对两个exact root entries执行
   `os.lstat` A/B，baseline为`11`；只接受real directory或absent，允许equality或1→0，拒绝
   0→1、symlink、wrong type与indeterminate。固定two-entry universe不扩张到parent/glob扫描，
   也不声称检测same-type inode replacement。严禁进入、枚举、hash、open、clean或复用任何
   R26 root/descendant；FIRST/LATEST/accepted-B仍只在整轮比较通过后的defer-signal窗口提交。

8. R27 static manifest必须精确为`220 = R26 206 + 14`：完整R26 path set，加fresh R27
   driver、immutable R26 manifest/freeze/Review26及十个R26 runtime files；R26 driver已在old
   206内不得重复。六面同步后old partition必须`200 unchanged + 6 expected control-surface
   mismatches`。manifest排除自身、R27 freeze、Review27、12个fresh runtime/report paths、
   两个fresh roots与全部invocation-owned hidden stages。normal/restore/END为`220/220`；唯一
   matrix窗口为`219 unchanged + 1 owned matrix-script mismatch`，既有O_EXCL、no-pre-delete、
   ownership与exact restore/fail-once containment不放宽。

9. R27使用全新12个runtime names、`agentloop-r27-state.*`/`agentloop-r27-bundle.*`、
   invocation ID、bundle identifier、hidden stages与boundary；从BEGIN、唯一unfiltered full
   test及即时two-element `PIPESTATUS`到same-log、build、release/object/matrix/source/privacy、
   B01–B06/C01–C09、staged screenshot/report与tiny commit-wins END，仍须在同一reviewed Bash
   3.2 process完整重跑。禁止复用R26 root/binary/log/result、handoff、caller continuation、
   retry、换root/object或patch-on-failure；UI claim仍只限observed intervals。

10. Review27必须职责隔离：reviewer不得写六面、driver、manifest或freeze，唯一repository
    write为`reviews/27-p1-plan-review.md`；正文只允许一个`Verdict: APPROVED — 0 P0 / 0 P1`
    及唯一12-line `R27_MACHINE_BLOCK`，authority mode为
    `standing_goal_automatic_after_review27`、scope为`review27_only`、
    `user_hash_echo_required=false`，并绑定current freeze/driver/manifest、branch/HEAD与
    `manifest_count=220`。Review27通过且standing Goal未撤销后，root agent自动计算review SHA
    并调用冻结caller，不要求用户echo hash。

11. R27六面、fresh `r27-begin.sh`、exact 220-entry manifest与R27 freeze均已冻结；Review27、
    所有R27 runtime/report/root/stage仍absent pending。独立Review27批准前，
    禁止caller/BEGIN、test/build/matrix/source/bundle/preview、Review02、acceptance及产品/test/
    App/Package/schema/migration/permanent-script修改。只有R27 exact END及全部technical gates
    通过后才可创建独立Review02；只有Review02零P0/P1才打开A2 acceptance，A3及以后仍关闭。
    commit、push、merge、release、数据重置、normal-data access、付款、公开沟通、外部操作与
    真实用户操作均未授权；任何超出本段的决策必须重新进入有界修订与职责隔离review。

## R28 current override — Shell timeout measurement-boundary root-cause closure

本 override 是六个 control surface 的唯一 current R28 入口；此前全部 R15–R27 历史与
immutable evidence 保留且不得重解释、补写、清理、删除或用后继结果替代。

1. R27 clean invocation 已永久 `REJECTED_CONTAMINATED`。四个 immutable anchors 为：

   - freeze `6d45ecf515861c9aa022ebeea994fc309350e4f33fb7425d01a700777425dd41`；
   - Review27 `74d20ed9909ba576beaba86659672c423686a7f798adf5bfbc6929607f606e5f`；
   - driver `770d0a413b449e4ea14db4bd8f7dc880f134c20a013b3ef76f684ba3e0f7432d`；
   - manifest `178af4f5f5fa30fd4a070125b8eafbfc0268fc74ad9703293e5dca124a37262e`。

   R27 的十个 actual runtime files 均为 immutable regular non-symlink evidence：

   | Runtime evidence | Bytes | SHA-256 |
   |---|---:|---|
   | `r27-targeted-tests.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `r27-verify.log` | 96,330 | `6279dadbdfbd37d6fb6730fbf037a0d0dfd40fbfab8acb4f91b01967f79297ea` |
   | `r27-build.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `r27-migration-matrix.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `evidence/r27-clean-boundary.log` | 8,066 | `f7807793b9cea03b0611af134918380cd4521d687fe0a3bb1e4c2955dd874310` |
   | `evidence/r27-bundle-provenance.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `evidence/r27-source-gates.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `evidence/r27-hash-manifest.log` | 3,091 | `01b8cb95805e52703fb394d56b8c38f344286a02ed7b7a443ed886b2ed6c3a21` |
   | `evidence/r27-preview-bootstrap.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `evidence/r27-preview-cold-start.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

   `evidence/r27-preview-smoke.png` 与 `impl-report-r27.md` 均 absent。R27 只有唯一
   unfiltered authoritative full test：651/652，唯一 issue 为
   `shellTimeoutTerminatesProcess()` 的 elapsed assertion；targeted、build、release、
   object、matrix、source、privacy、bundle、UI、screenshot、report 与 END 均未发生。
   Exact predecessor roots 仅为 `/private/tmp/agentloop-r27-state.rc7ama` 与
   `/private/tmp/agentloop-r27-bundle.6Q3UjM`；fixed exact-root `lstat`-only baseline
   固定为 state=1、bundle=1，即 `11`。R28 只允许对这两个已解析 exact pathname 做 fixed
   `lstat` lifecycle observation；绝不进入、枚举、打开、读取或哈希任何 descendant，也绝不
   把 root contents 当作 R28 input。

2. R27 的同一根因被精确限定为 measurement-boundary contamination。现有
   `shellTimeoutTerminatesProcess()` 在调用 `tool.execute` 前启动 `ContinuousClock`；而
   `ShellTool.execute` 会先 `await LoginShellEnvironment.shared.environment()`，再
   `process.run()`，真正的 command deadline 在环境解析与 process start 之后建立。
   Login-shell capture 自身有合法的 5 秒 safety guard，command timeout 为 300ms，终止 grace
   仍为 300ms；因此 cold environment capture 加 command timeout/grace 合法超过测试的 5 秒
   wall-clock ceiling。R27 实测 elapsed 为 5.13908825 秒，只有 `< .seconds(5)` 这一断言
   记录 issue；这不证明 ShellTool 的 300ms command deadline 失效。

3. R28 唯一允许的实施文件为
   `Sources/AgentLoopTestSuite/ShellToolTests.swift`。其 exact pre-patch SHA-256 必须为
   `c4c75d66540c2cc0760f0edaef0650a93e2e589a45a5d8b932ab3b2bdc091350`。只允许在
   `shellTimeoutTerminatesProcess()` 内、现有 `let clock = ContinuousClock()` 的正前方
   新增且只新增以下一行：

   ```swift
   _ = await LoginShellEnvironment.shared.environment()
   ```

   Exact final SHA-256 必须为
   `37b9e97c567cc599b98899fe1ca6c1deb9383b2889d52c2c42d3236dd2535a29`。
   从 final bytes 删除且只删除这一条 exact newline-terminated line 必须恢复 exact pre-patch
   SHA；这就是 mandatory strip proof。既有 `< .seconds(5)`、300ms timeout、300ms grace、
   error/message/output/registry assertions、函数位置与其余 bytes 全部不变。

4. `Sources/AgentLoopCore/Tools/ShellTool.swift` 必须保持 SHA-256
   `e5980b4fb7d756656a7271ea646a54d49355c7a64f683245c6689254d76f2faf`；
   `Sources/AgentLoopCore/Support/ShellProcessRegistry.swift` 必须保持 SHA-256
   `260896d845d031e5cf46865303cfd00e944fa1c212278482c0d9a29d1001e6d1`。
   禁止提高或删除 threshold，禁止修改 timeout/grace，禁止为 environment 引入 injection、
   single-flight、public/package API 或产品逻辑，禁止修改 test order/filter，禁止 retry、
   sleep、重复 full run 或其他产品/test/App/Package/schema/migration/permanent-script 改动。
   Login-shell capture single-flight 只登记为 P2 后续候选，不属于 R28。

5. 实施顺序固定为：先同步本六面、生成 fresh R28 driver、exact 235-entry manifest 与
   R28 freeze；再由职责隔离 reviewer 执行 Review28；Review28 exact approval 后，root agent
   才能用 `apply_patch` 在 pre-BEGIN 窗口应用第 3 项 exact one-line change。若 pre-patch
   SHA、唯一上下文、final SHA 或 strip proof 任一不符，必须 fail closed 且不得 BEGIN。
   Frozen driver 不得写源码；它只在内部重新证明 final SHA、strip proof、两个 immutable
   product hashes 与 phase-aware manifest，然后由同一个 reviewed Bash 3.2 process 完成
   BEGIN 至 terminal END 的 full chain。

6. R28 static manifest 必须精确为 `235 = R27 220 + 15`。十五个 additions 只能是：fresh
   R28 driver；immutable R27 manifest、freeze、Review27；十个 R27 runtime files；以及
   `ShellToolTests.swift` pre-patch baseline。六面同步后相对旧 R27 manifest 的 partition
   必须为 `214 unchanged + 6 expected control-surface mismatches`；应用 one-line 后该 old
   partition 仍必须为 `214 + 6`。R28 pre-patch gate 为 `235/235`；实施后正常 phase 只能是
   `234 unchanged + 1 ShellToolTests mismatch`；matrix mutation window 只能是
   `233 unchanged + 1 ShellToolTests mismatch + 1 owned matrix-script mismatch`；exact
   restore 与 END 只能回到 `234 + 1`。任何额外 missing、addition、type drift 或 mismatch
   都必须拒绝。Manifest 排除自身、R28 freeze、Review28、fresh R28 runtime/report paths、
   两个 fresh roots与全部 invocation-owned hidden stages；既有 O_EXCL、no-pre-delete、
   ownership、no-clobber publication、exact restore 与 fail-once containment 不放宽。

7. R28 必须使用全新 runtime/report names、`agentloop-r28-state.*`、
   `agentloop-r28-bundle.*`、invocation ID、bundle identifier、hidden stages 与 boundary。
   同一 Bash process 必须运行唯一 unfiltered `swift run RunTests` 并得到 full 652/652、
   same-log exact 46/46、debug build、release Core/TestSuite targets、debug/release object
   symbol gates、migration matrix、source/privacy、bundle provenance、B01–B06、C01–C09、
   staged screenshot、implementation report 与 tiny commit-wins END。禁止复用 R27 root、
   binary、log 或结果，禁止 handoff、caller continuation、换 root/object、patch-on-failure
   或任何 retry；UI claim 仍只限 observed intervals。

8. Review28 必须职责隔离。Reviewer 不得写六面、driver、manifest、freeze、source 或
   runtime evidence，唯一 repository write 为
   `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/28-p1-plan-review.md`。
   Review 必须只含一个 `Verdict: APPROVED — 0 P0 / 0 P1` 与唯一 machine block，并绑定
   current six-body identity、freeze、driver、manifest、branch、HEAD、
   `authority_mode=standing_goal_automatic_after_review28`、`scope=review28_only`、
   `user_hash_echo_required=false`、`manifest_count=235`。Review28 通过且 standing Goal
   未撤销后，root agent 自动执行 exact pre-BEGIN patch 与 frozen caller，不要求用户 echo
   hash。

9. Review28 exact approval 前，禁止 one-line implementation、caller/BEGIN、test、build、
   matrix、source、bundle、preview、Review02、acceptance 及任何其他产品/test/App/Package/
   schema/migration/permanent-script 修改。只有 R28 exact END 与全部 technical gates 通过后
   才能创建职责隔离 Review02；只有 Review02 零 P0/P1 才打开 A2 acceptance。A3 及以后仍
   关闭。Commit、push、merge、release、数据重置、normal-data access、付款、公开沟通、
   外部操作与真实用户操作均未授权；任何超出本 override 的架构、依赖、语义、测试或证据
   决策都必须重新进入有界修订与职责隔离 review。
