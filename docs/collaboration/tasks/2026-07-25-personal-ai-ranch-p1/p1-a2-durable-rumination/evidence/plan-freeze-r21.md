# P1-A2 R21 Release-Configuration Plan Freeze

> 状态：R21 Release-Configuration Candidate Frozen；Review21 Pending；全部执行继续禁止
>
> 日期：2026-08-03
>
> 分支：`codex/personal-ai-ranch-p0`
>
> HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. 授权范围与停止线

R20已在Review20批准且牧场主提供四个terminal hashes后进入clean invocation
`r20-98452cde-0ff4-4b66-b3f6-8085eb045a6f`。BEGIN、唯一一次未过滤full RunTests
652/652、同一日志46/46、debug App build及POST_BUILD/PRE_SIGN/LAUNCH_READY均通过；
随后冻结的`swift build -c release --product AgentLoopCore`因SwiftPM automatic-product
fallback进入default graph，并在release TestSuite caller调用DEBUG-only Core callee时以
`extra argument 'idleClockForTesting' in call`失败。R20因此永久
`REJECTED_CONTAMINATED`，phase=`release_core_build`、
reason=`release_AgentLoopCore_build_failed_rc_1`、exit=1、
`retry_same_boundary=false`。后续release/debug symbol、matrix、source、preview与END门均
未运行；已有652/652、46/46及LAUNCH_READY只是真实partial evidence，不能洗绿R20。

牧场主随后逐字授权R21 planning-only。该授权只允许：

1. 同步六个current surfaces；六面的定义已经包含A2 leaf Plan与blocked history；
2. 新增BEGIN-only `evidence/r21-begin.sh`；
3. 生成精确155项的`evidence/r21-entry.sha256`；
4. 生成本freeze；
5. 由未参与上述修订、driver、manifest或freeze生成的职责隔离reviewer唯一写
   `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/21-p1-plan-review.md`。

本轮只关闭同一个根因：

`SwiftPM automatic-product fallback + DEBUG caller/callee configuration mismatch`

本授权不允许运行external caller、`r21-begin.sh`/BEGIN、任何test/build/matrix/source
gate、bundle assembly/sign或preview；不允许现在实施TestSuite guards；不允许修改
`Package.swift`、产品逻辑、public/package API、target/dependency/package edge、schema/
migration或其他产品/test/App/RunTests/matrix script；也不允许Review02、acceptance、A3、
commit、push、merge、release、normal-data、外部或真实用户操作。

Review21达到`APPROVED — 0 P0 / 0 P1`本身仍不执行。只有牧场主在Review21之后的新用户
turn按`freeze, Review21, driver, manifest`顺序逐字提供四个最终SHA-256并明确授权，才可
打开future R21 caller/BEGIN与精确one-file guard实施。

## 2. Final planning identities

### 2.1 Six canonical/control surfaces

| Surface | Absolute path | SHA-256 |
|---|---|---|
| canonical Stage | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `819c37d6181b54be71031f0300d89aa5d30c26af5ec12975c296b8c7316c6704` |
| canonical total Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `83644e0958e8f0486578d655175982d95ee9b5a5997bc385f49789c21e12da1e` |
| A2 leaf Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `1d4ea207855241e21a4df01b001dfef8da37684e19f9d4cee1c844fb26a19777` |
| A2 blocked/control history | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/blocked.md` | `4485cb5d14ed8d06b17b7a00cc82595ab774f3bf47a6a95bd6a3ae9b5a200baa` |
| P1 Stage control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md` | `2bc19c1c93d5a4d3fd30131caf521326b811d14455f488371ee60a99e4143a1a` |
| P1 Plan control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md` | `4a209b3dd6157ff5890b6a63ea3e08de7d65b7b39f670899b4bd4ad292174e75` |

六面header的current status逐字一致：

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18/R18-A PLAN CHANGES REQUIRED — NOT EXECUTED；R19 BEGIN REJECTED_CONTAMINATED — AUTHORITATIVE FULL TEST 651/652；R20 BEGIN REJECTED_CONTAMINATED — RELEASE CORE BUILD FAILURE AFTER AUTHORITATIVE FULL 652/652；R21 Release-Configuration Candidate Frozen；Review21 Pending；A2 Clean Re-verification Frozen`

该完整字符串在六面共出现9次，每面header均恰有一次。canonical Stage §29、total Plan
§19与A2 leaf §13的Open Questions均精确为`无。`。两个control indexes内的canonical
Stage、total Plan与leaf hashes均精确等于上表；placeholder数量为0。

### 2.2 Driver, manifest and immutable source baselines

| Artifact | Absolute path | SHA-256 / invariant |
|---|---|---|
| R21 BEGIN-only driver | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r21-begin.sh` | `c56db7b465ae3d54923d958892e07e5575d4cf67b8b4946c7d6793e4f1bfb835`；`/bin/bash -n` PASS |
| R21 static manifest | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r21-entry.sha256` | `d5567a05e61e61a94b732814e24a89ecdb8e2a988d970dac33939f31798a9d86`；155 entries；strict 155/155 PASS |
| manifest pure path set | 155 absolute paths in the manifest | `9150873ceaae14fae7aecf96669014b9215a98d6f28b3d909eca656b67818301` |
| immutable R20-final Core | `/Users/muzi/Agent-loop/Sources/AgentLoopCore/Loop/AgentLoop.swift` | `c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275` |
| R21 TestSuite entry / R20 final | `/Users/muzi/Agent-loop/Sources/AgentLoopTestSuite/AgentLoopTests.swift` | `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26` |

本freeze生成前，Core与TestSuite仍逐byte匹配上述R20 final hashes；R21 planning没有修改
任何产品/test/App/RunTests/matrix-script bytes。driver只是未执行的BEGIN-only candidate。

## 3. Acyclic trust chain

唯一信任链为：

```text
immutable predecessors + final six surfaces + complete R20 terminal/evidence chain
  + R20-final Core/TestSuite baselines + frozen r21-begin.sh
  → static r21-entry.sha256
  → plan-freeze-r21.md
  → reviews/21-p1-plan-review.md
  → later user authorization carrying four terminal hashes
```

- manifest排除自身、本freeze、Review21、全部R21 runtime paths与temp roots；
- 本freeze只记录upstream hashes，不记录自身hash或尚未生成的Review21 hash/verdict；
- Review21可绑定本freeze hash，但不得记录自身hash；
- driver不硬编码freeze、Review21、driver或manifest hash，只在future caller调用时按四个
  positional parameters取得并核对；
- Review21生成后不得回填本freeze、六面、driver或manifest；任何upstream bytes漂移都使
  candidate失效；
- 后续四元组只能由Review21之后的新用户turn提供，不能由planner/reviewer预填或回写。

## 4. Immutable R20 terminal result and evidence

### 4.1 R20 terminal anchors

| Artifact | SHA-256 / state |
|---|---|
| `evidence/plan-freeze-r20.md` | `0b698b59f214f23c26db88fd53763c4a600becaf898a716344f9d666ac2e8e07` |
| `reviews/20-p1-plan-review.md` | `e70ea918e00c334a452f87e4fa8f44d5bfc754b042872a9f0a0ec13015e7c68e`；`APPROVED — 0 P0 / 0 P1` |
| `evidence/r20-begin.sh` | `840edee2dad7710f17e1b9bb8dcaa1484224ba0784b636f472bc2934f7e7eaeb` |
| `evidence/r20-entry.sha256` | `2f8a6f4f786a2b5f432b2dbf7dcdc7208788d0b9ef5b9cdaa9de422bfaf88e81`；140 entries |
| invocation | `r20-98452cde-0ff4-4b66-b3f6-8085eb045a6f`；permanent `REJECTED_CONTAMINATED` |

### 4.2 Eleven immutable repository artifacts

| Artifact | SHA-256 |
|---|---|
| `r20-targeted-tests.log` | `5d438374c029ce803903b339876189ccb1d632f4e28f87ae4ee2021a3b56e775` |
| `r20-verify.log` | `1aea8510917a6a3f72b9b2ab63cc2e90bc209481bf119f6de7c3a0ea74fea4e5` |
| `r20-build.log` | `317efebd212133c292e2bc3ddc3e837f2c6acf47e450d48f1c32b9b25b26b5b4` |
| `r20-migration-matrix.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `impl-report-r20.md` | `d25ee33037e5e99946c4636724948249ac712757979163393c0d9b4077546894` |
| `evidence/r20-clean-boundary.log` | `f221507a75730a0a2cf2f0f2fd6213d26e956e0860aef70878f30bc9b4dee6df` |
| `evidence/r20-bundle-provenance.log` | `839ce977cbdace6cadd8ce2ee2a0bcc1a5f798389c4d1977a5dcb18ef63d921e` |
| `evidence/r20-source-gates.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r20-hash-manifest.log` | `5ef1e15c81dacc59872a1b9b1d8a999c19cee5516598564737cbcba764214450` |
| `evidence/r20-preview-bootstrap.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r20-preview-cold-start.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

`evidence/r20-preview-smoke.png`保持absent。不得覆盖、追加、补写、删除、清理、移动、
重命名或复用上述artifact，也不得把empty downstream logs补成成功证据。

### 4.3 Retained roots and signed App

- state root：`/private/tmp/agentloop-r20-state.3QwlQa`；real non-symlink empty directory；
- bundle parent：`/private/tmp/agentloop-r20-bundle.30V5RH`；real non-symlink directory，
  direct child精确为`AgentLoop.app`；
- executable SHA-256：
  `d55fc10e674b77b480a85de46137eff40d40bd94b27c8e33b0d49f55d40a049c`；
- Info.plist SHA-256：
  `5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58`；
- signed-bundle manifest SHA-256：
  `06e063d4fdd541a808c78eacc5b34ddfd64874a3ab1648bbfe6bf74646db8170`。

R21 driver在授权消费前后都必须以`find -P ... -mindepth 1 -print0`枚举retained App的
all-node universe，不得用`-type`缩小集合。Bash 3.2 indexed-seen validator必须完整drain
NUL records并精确证明36个relative nodes：6个real non-symlink directories及30个regular
non-symlink files；每个file逐项比对literal SHA-256。unknown、extra、missing、duplicate、
wrong type、symlink、special node、abnormal EOF或partial record都失败。actual pathname
不得转成newline text；只有exact set全绿后才按固定safe expected literals输出30条manifest
records并复算上述aggregate hash。外层四段find/validator/shasum/hash-validator statuses
必须立即捕获，失败reason只写safe numeric statuses或固定`MISSING`，不得泄漏actual path；
随后还须strict `codesign --verify --deep`。

R20 roots/App不得写入、删除、清理、移动、重签、启动、重命名或复用。R15 tombstone、
R16 pre-BEGIN零写入、R17/R18未执行与R19 rejected containment继续按immutable predecessor
链保留。

## 5. Exact one-file implementation exception

future implementation必须保持
`Sources/AgentLoopCore/Loop/AgentLoop.swift`的R20 final bytes/hash完全不变。唯一source
delta是在R20-final `Sources/AgentLoopTestSuite/AgentLoopTests.swift`原地增加三对direct、
matching `#if DEBUG`/`#endif`，且不移动、不删除、不重排、不修改既有logic、whitespace、
annotation或其他bytes：

1. 第一对从`ManualAgentLoopClock`前开始，在`OneShotGate`完整结束后、既有`runLoop`前
   结束；连续覆盖`ManualAgentLoopClock`、`ControlledIdleProviderError`、
   `ControlledIdleProvider`、`AgentEventProbe`、`OneShotGate`；
2. 第二对只包围完整`startControlledLoop` declaration/body；
3. 第三对只包围五个连续exact tests：
   `turnTimeoutRetriesOnceThenBlocks`、`cancelWinsOverIdleTimeout`、
   `timeoutThenSuccessDoesNotAccumulate`、`slowActiveStreamDoesNotIdleTimeout`、
   `turnCompletesUnderTimeout`。

禁止`#else`、`#elseif`、nested conditional、第四对guard、新file/target/dependency/package
edge、release-visible test seam、Package.swift、public/package API、schema/migration或任何
其他产品/test/App/RunTests/matrix-script修改。

future source sub-gate必须以direct-region line-state parser证明TestSuite恰有上述三段
non-nested DEBUG regions，上述11个tokens全部且只在其授权region内，除此之外没有
conditional directive；Core既有DEBUG region及`idleClockForTesting`位置必须不变。删除且
只删除新加的六行exact directives后，TestSuite bytes/hash必须精确恢复
`66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`。

## 6. Exact release and four-object symbol gates

两条release命令顺序精确为：

```bash
swift build -c release --target AgentLoopCore
swift build -c release --target AgentLoopTestSuite
```

禁止`--product AgentLoopCore`及automatic-product fallback。第一条返回0后先记录exact
release Core object hash；第二条返回0后该hash必须不变。

`swift build -c release --show-bin-path`与
`swift build -c debug --show-bin-path`只作path query。bin paths必须是canonical real
non-symlink directories，并分别精确匹配
`$REPO/.build/<single-component>/release|debug`。四个object只能是：

- `$releaseBin/AgentLoopCore.build/AgentLoop.swift.o`；
- `$releaseBin/AgentLoopTestSuite.build/AgentLoopTests.swift.o`；
- `$debugBin/AgentLoopCore.build/AgentLoop.swift.o`；
- `$debugBin/AgentLoopTestSuite.build/AgentLoopTests.swift.o`。

每个object必须是canonical regular non-symlink file；其exact parent必须是canonical real
non-symlink directory，并精确为对应bin下的`AgentLoopCore.build`或
`AgentLoopTestSuite.build`。禁止`find`、glob、candidate fallback或fixed shared temp。

每项只运行`nm -j <exact-object> | xcrun swift-demangle`并保留`pipefail`；producer或
demangler非零、空输出、object/path/type/layout异常均fail closed。count必须用`awk
index()` substring机械计算：

- Core `idleClockForTesting`：release=0，debug>0；
- TestSuite以下11个tokens逐项：release=0，debug>0：
  `ManualAgentLoopClock`、`ControlledIdleProviderError`、`ControlledIdleProvider`、
  `AgentEventProbe`、`OneShotGate`、`startControlledLoop`及五个exact test names。

## 7. 155-entry manifest and phase-aware delta

`r21-entry.sha256`包含155个absolute paths；每行精确为lowercase 64-hex、two spaces、
absolute path，按`LC_ALL=C` bytewise sorted unique且末尾LF存在。所有155 targets均为
regular non-symlink，strict check为155/155 PASS，pure path-set SHA见§2.2。

path set精确等于immutable R20的140 paths，零删除，再增加15个互不重叠的新paths：

1. R21 driver；
2. immutable R20 manifest、freeze与Review20；
3. §4.2的11个R20 runtime/failure artifacts。

manifest排除自身、本freeze、Review21、12个future R21 runtime paths与fresh roots。

六面同步且R20两文件实施已经发生后，immutable R20 manifest对current filesystem精确为
132 unchanged + 8 mismatch；八项只能是final six surfaces、`AgentLoop.swift`与
`AgentLoopTests.swift`。旧R20 manifest不得被修改来洗绿。

R21 future implementation前必须再次155/155；guards实施后必须精确154 unchanged +
`AgentLoopTests.swift`唯一authorized mismatch，且Core继续匹配entry。第二个mismatch或
任何target type/path漂移立即永久失败。

## 8. BEGIN-only driver, capture scope and fresh identities

`r21-begin.sh`只建立一个fail-once BEGIN boundary，不运行test、build、matrix、source、
bundle/sign或preview。它只接受四个lowercase SHA-256 arguments，顺序精确为
`freeze, Review21, driver, manifest`；clean Bash 3.2 environment、absolute invocation、
branch与HEAD必须匹配本freeze。

capture inventory只统计outer driver中受全局ERR trap影响的unique parent source blocks；
inline child validator的逐文件`shasum`子状态由外层P完整封装，不重复计数：

| Scope | Count |
|---|---:|
| outer P | 8 |
| outer S | 4 |
| outer core C | 8 |
| **outer core total** | **20** |
| fresh-root-glob extra C | 1 |
| **driver total** | **21 = 8P / 4S / 9C** |

driver完整继承R20 phase-aware ERR handling、R15 tombstone、R16–R18 absence、R19/R20
containment与RanchArt lossless NUL contract；pre-consumption失败保持零R21 runtime write且
不消费授权，boundary写入`authorization_consumed=true`后任一失败都永久
`REJECTED_CONTAMINATED`且不得retry。

R21 fresh 12 paths为：

- task root：`r21-targeted-tests.log`、`r21-verify.log`、`r21-build.log`、
  `r21-migration-matrix.log`、`impl-report-r21.md`；
- evidence root：`r21-clean-boundary.log`、`r21-bundle-provenance.log`、
  `r21-source-gates.log`、`r21-hash-manifest.log`、`r21-preview-bootstrap.log`、
  `r21-preview-cold-start.log`、`r21-preview-smoke.png`；
- roots：`/private/tmp/agentloop-r21-state.*`与
  `/private/tmp/agentloop-r21-bundle.*`。

pre-BEGIN必须证明12 paths及R16/R17/R18/R21 fresh-root globs absent。创建后的R21 roots
必须distinct、real、non-symlink、empty、互不嵌套，且不复用任何R15/R19/R20 identity。

## 9. Future fail-once order

Review21通过且后续四-hash用户授权到达后，唯一future顺序为：

```text
external caller four-anchor check
  → BEGIN attestation
  → exact TestSuite three-guard implementation
  → one unfiltered `swift run RunTests`
  → only after full green, mechanical 46/46 extraction from the same log
  → debug AgentLoopApp build
  → one fresh bundle assembly/sign + POST_BUILD/PRE_SIGN/LAUNCH_READY
  → pre-release guard-shape/strip source sub-gate
  → release AgentLoopCore target
  → release AgentLoopTestSuite target
  → four exact-object bidirectional symbol gates
  → migration matrix with mandatory script restoration
  → remaining source/privacy/final-hash gates
  → same-bundle isolated preview
  → END
```

任一步未知、非零或不满足exact invariant，都永久拒绝同一boundary且不得重跑、补丁、
换root/object、覆盖负证据或继续下游门。R20的652/652与46/46不能替代R21唯一full run。

## 10. Pre-freeze static verification

本freeze生成前只运行了planning-safe read/static checks：

- six-surface hash/status/Open Questions/control-index consistency；
- Core/TestSuite R20-final hashes；
- `/bin/bash -n r21-begin.sh`；
- R21 manifest shape/count/path-set/type及strict 155/155；
- immutable R20 manifest current result精确132/140 unchanged + 8 exact mismatch；
- R20 11 artifacts及terminal hashes；
- all-node validator的Bash 3.2、NUL、exact 36-node、safe serialization、four-status及
  fail-closed静态审计；
- whitespace/final-LF/placeholder及planning write-scope checks。

两条职责分离的pre-freeze只读审计在最终候选上均归零，合并结论为：

`0 P0 / 0 P1 / 0 P2`

没有运行caller/BEGIN、test、build、matrix、source gate、bundle/sign或preview；没有实施
TestSuite guard；没有修改任何产品/test/App/RunTests/matrix-script文件。

## 11. Review21 completion gate

未参与R21 six-surface、driver、manifest或本freeze修订/生成的职责隔离reviewer唯一可写：

`/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/21-p1-plan-review.md`

Review21必须至少独立核对：

1. reviewer职责隔离、唯一写入路径及没有运行任何execution gate；
2. branch/HEAD、six surfaces、driver、manifest与本freeze exact hashes/types；
3. 六面定义、current status、current-gate routing、三个Open Questions与零placeholder；
4. R20 permanent rejection、唯一652/652与46/46、11 artifacts、absent screenshot、retained
   roots及signed App identities完整且未被改写；
5. Core/TestSuite仍为R20 final hashes，future delta只允许TestSuite六行direct directives；
6. three-region source contract、strip-to-R20 proof与Package/API/graph/schema等全部red lines；
7. 两条target-exact release命令、canonical bins/parents/objects、Core hash stability及
   release/debug双向symbol gates；
8. 155=140+15、strict 155/155、旧R20 manifest精确132+8及future 154+1合同；
9. driver four-anchor、manifest、fresh names、R15–R20 containment、all-node NUL validator、
   outer capture taxonomy、safe four-status diagnostics与BEGIN-only边界；
10. §9唯一fail-once顺序、Review02/acceptance关闭及无环四-hash授权链。

只有`APPROVED — 0 P0 / 0 P1`可请求后续四-hash用户授权；任何P0/P1、hash drift、未知状态、
职责污染或证据缺口都必须`CHANGES REQUIRED`并继续停止。Review21不得执行、不得修改本
freeze或任何upstream artifact，也不得预写自身hash。

## 12. Current terminal state

R21现阶段终态是：

`PLAN_FROZEN — REVIEW21_PENDING — EXECUTION_NOT_AUTHORIZED`

Review21与后续新用户四-hash授权前，caller/BEGIN、test/build/matrix/source/bundle/sign/
preview、TestSuite guard实施、其他产品/test/App-script修改及全部后续门继续禁止。
