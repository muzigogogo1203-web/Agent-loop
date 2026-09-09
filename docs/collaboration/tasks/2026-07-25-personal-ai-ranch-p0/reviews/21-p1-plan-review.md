# P1-A2 R21 Release-Configuration Plan Review

> Verdict：**APPROVED — 0 P0 / 0 P1**
>
> 日期：2026-08-03
>
> Review 对象：R21 final six surfaces、BEGIN-only driver、155-entry static manifest
> 与 R21 freeze

## 1. Scope and independence

本 reviewer 未参与 R21 six-surface、`r21-begin.sh`、`r21-entry.sha256` 或
`plan-freeze-r21.md` 的修订或生成。本次从当前 filesystem 独立读取并审查真实 bytes；
本 Review 创建前目标路径为 `ABSENT`，唯一写入是本 Review21 文件。本 Review 不记录或
预填自身 SHA-256。

本次没有运行 external caller、`r21-begin.sh`/BEGIN、任何 test、build、migration
matrix、source gate、bundle assembly/sign/verify/launch 或 preview；没有实施 TestSuite
guards，没有创建 R21 runtime artifact/fresh root，也没有修改产品、测试、App、RunTests、
matrix script、六面、driver、manifest、freeze、R20 evidence、Review02、acceptance 或 A3。
本轮没有遍历或操作 retained R20 App，只核对 repository evidence 与 frozen driver 合同。

只读/静态动作限于 branch/HEAD/status/diff、hash、path/type/text、manifest strict check 与
`/bin/bash -n`。审查快照为 branch `codex/personal-ai-ranch-p0`、HEAD
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`。已有 large dirty/untracked tree 被视为用户
工作并保持不动。

## 2. Exact identities and six-surface routing

### 2.1 Final R21 identities

| Artifact | Current SHA-256 | Result |
|---|---|---|
| canonical Stage | `819c37d6181b54be71031f0300d89aa5d30c26af5ec12975c296b8c7316c6704` | exact |
| canonical total Plan | `83644e0958e8f0486578d655175982d95ee9b5a5997bc385f49789c21e12da1e` | exact |
| A2 leaf Plan | `1d4ea207855241e21a4df01b001dfef8da37684e19f9d4cee1c844fb26a19777` | exact |
| A2 blocked/control history | `4485cb5d14ed8d06b17b7a00cc82595ab774f3bf47a6a95bd6a3ae9b5a200baa` | exact |
| P1 Stage control | `2bc19c1c93d5a4d3fd30131caf521326b811d14455f488371ee60a99e4143a1a` | exact |
| P1 Plan control | `4a209b3dd6157ff5890b6a63ea3e08de7d65b7b39f670899b4bd4ad292174e75` | exact |
| R21 BEGIN-only driver | `c56db7b465ae3d54923d958892e07e5575d4cf67b8b4946c7d6793e4f1bfb835` | exact；Bash syntax PASS |
| R21 static manifest | `d5567a05e61e61a94b732814e24a89ecdb8e2a988d970dac33939f31798a9d86` | exact；155 entries |
| R21 freeze | `82ec117359bb0172867ed476c0da4a8d7d0fc60c5bd24f25c0f42e360f7996a4` | exact |

上述九项均为 canonical regular non-symlink file，realpath 等于 frozen absolute path，
并有末尾 LF。`/bin/bash -n r21-begin.sh` 返回 0。

### 2.2 Current status, routing and Open Questions

六面 header 去除 Markdown emphasis 后逐 byte 一致：

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18/R18-A PLAN CHANGES REQUIRED — NOT EXECUTED；R19 BEGIN REJECTED_CONTAMINATED — AUTHORITATIVE FULL TEST 651/652；R20 BEGIN REJECTED_CONTAMINATED — RELEASE CORE BUILD FAILURE AFTER AUTHORITATIVE FULL 652/652；R21 Release-Configuration Candidate Frozen；Review21 Pending；A2 Clean Re-verification Frozen`

该完整字符串在六面共出现 9 次，每面 header 恰有一次。canonical Stage §29、total
Plan §19 与 A2 leaf §13 的 Open Questions 均精确为 `无。`；R21 final-hash placeholder
为 0。两个 control indexes 中 canonical Stage、total Plan 与 leaf hashes均为 §2.1
最终值。

Stage §28.8、total Plan §18 R21、leaf §1/§2.7/§10–§12、blocked §29 与两个 control
indexes 的 current gate一致指向 R21/Review21。R15–R20 recipe与失败/未执行结果只作
immutable history；没有旧 gate 获得 current 开门权。

## 3. Immutable R20 result and repository evidence

### 3.1 Terminal chain and failure truth

独立重算得到 R20 terminal identities：

| Artifact | Current SHA-256 / state |
|---|---|
| `evidence/plan-freeze-r20.md` | `0b698b59f214f23c26db88fd53763c4a600becaf898a716344f9d666ac2e8e07` |
| `reviews/20-p1-plan-review.md` | `e70ea918e00c334a452f87e4fa8f44d5bfc754b042872a9f0a0ec13015e7c68e`；`APPROVED — 0 P0 / 0 P1` |
| `evidence/r20-begin.sh` | `840edee2dad7710f17e1b9bb8dcaa1484224ba0784b636f472bc2934f7e7eaeb` |
| `evidence/r20-entry.sha256` | `2f8a6f4f786a2b5f432b2dbf7dcdc7208788d0b9ef5b9cdaa9de422bfaf88e81`；140 entries |
| invocation | `r20-98452cde-0ff4-4b66-b3f6-8085eb045a6f`；permanent `REJECTED_CONTAMINATED` |

`r20-clean-boundary.log`、full log、targeted audit、build log与implementation report相互
闭合：BEGIN达到`BEGIN_ATTESTED`；唯一未过滤full RunTests的最后非空行是
`652 tests in 7 suites passed`；同一日志机械审计46个exact names均为
`discovery=1/pass=1/failure=0`。debug App build与LAUNCH_READY通过后，冻结的
`swift build -c release --product AgentLoopCore`明确发生automatic-product fallback，
编译release TestSuite并在`idleClockForTesting` caller处失败。

boundary精确保留`status=REJECTED_CONTAMINATED`、`phase=release_core_build`、
`reason=release_AgentLoopCore_build_failed_rc_1`、`exit_code=1`与
`retry_same_boundary=false`。release/debug symbol、matrix、source、preview与END均未运行；
652/652、46/46与LAUNCH_READY只是真实partial evidence，不能洗绿R20。

### 3.2 Eleven immutable artifacts and source baselines

11个R20 repository artifacts均为regular non-symlink且hash精确为：

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

`evidence/r20-preview-smoke.png`保持absent。当前source baselines逐byte为：

- `Sources/AgentLoopCore/Loop/AgentLoop.swift`：
  `c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`；
- `Sources/AgentLoopTestSuite/AgentLoopTests.swift`：
  `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`。

repository evidence冻结state root `/private/tmp/agentloop-r20-state.3QwlQa`、bundle parent
`/private/tmp/agentloop-r20-bundle.30V5RH`、唯一direct child `AgentLoop.app`、executable
`d55fc10e674b77b480a85de46137eff40d40bd94b27c8e33b0d49f55d40a049c`、Info.plist
`5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58`与signed-manifest
`06e063d4fdd541a808c78eacc5b34ddfd64874a3ab1648bbfe6bf74646db8170`。本 Review不把这些
identity改写为live-success claim；future driver仍须在消费前后重新做exact containment。

## 4. 155-entry manifest and acyclic trust chain

对`r21-entry.sha256`的独立检查结果：

1. 155 logical records，末尾byte为LF；每行精确为lowercase 64-hex、two spaces、absolute
   path；path set按`LC_ALL=C` bytewise sorted unique；
2. 155 targets全部regular non-symlink，`shasum -a 256 --strict -c`返回0且155/155 PASS；
3. pure path-set SHA-256为
   `9150873ceaae14fae7aecf96669014b9215a98d6f28b3d909eca656b67818301`；
4. path set精确为immutable R20的140 paths、零删除，再增加15个non-overlapping paths：
   R21 driver、R20 manifest/freeze/Review20及§3.2的11个R20 artifacts；无missing、extra或
   overlap；
5. immutable R20 manifest对current filesystem独立得到132/140 unchanged + 8 exact
   mismatch；八项只能且确为final six surfaces、`AgentLoop.swift`与
   `AgentLoopTests.swift`；
6. manifest排除自身、R21 freeze、Review21、全部12个future R21 runtime paths与fresh
   roots；12个repository runtime paths在本Review创建前均absent。

因此future edit前合同为155/155；只加入六行guard directives后必须为154 unchanged +
`AgentLoopTests.swift`唯一authorized mismatch，Core继续匹配entry。第二个mismatch或旧
R20 manifest被改写都必须失败。

manifest不依赖自身/freeze/Review21/runtime；freeze只记录upstream hashes，不记录自身或
Review21 hash；本 Review不记录自身hash；driver只从later caller positional parameters
取得四anchors。信任链无环：

```text
immutable predecessors + final six surfaces + complete R20 evidence
  + R20-final Core/TestSuite + frozen r21-begin.sh
  -> static r21-entry.sha256
  -> plan-freeze-r21.md
  -> reviews/21-p1-plan-review.md
  -> later user authorization carrying four terminal hashes
```

## 5. Exact one-file exception and release/object gates

当前Core只有一对既有direct DEBUG region，`idleClockForTesting`全部位于其中；当前
TestSuite没有conditional directive。R20新增源码在当前file中形成可机械界定的三个
连续区域：

1. `ManualAgentLoopClock`至`OneShotGate`完整结束，并在既有`runLoop`前停止；
2. 完整且仅有`startControlledLoop` declaration/body；
3. 从`turnTimeoutRetriesOnceThenBlocks`至`turnCompletesUnderTimeout`的五个连续exact
   tests，并在下一项既有test前停止。

R21只允许原地新增三对direct matching`#if DEBUG/#endif`，不得移动、重排或修改既有
logic/whitespace/annotation，不得增加else/elseif/nesting/第四对guard。future line-state
parser须证明11个冻结tokens全部且只在授权regions内；删除且只删除六行directives后必须
恢复TestSuite R20-final hash。`AgentLoop.swift`必须全程保持R20-final bytes。

release顺序精确冻结为：

```bash
swift build -c release --target AgentLoopCore
swift build -c release --target AgentLoopTestSuite
```

第一条后记录release Core exact object hash，第二条后必须不变。release/debug
`--show-bin-path`只作path query并须精确匹配`$REPO/.build/<single-component>/release|debug`；
四个objects只能是对应bin下的`AgentLoopCore.build/AgentLoop.swift.o`与
`AgentLoopTestSuite.build/AgentLoopTests.swift.o`。bin、parent及object必须canonical、
real、non-symlink且类型精确；禁止find/glob/fallback/shared tmp。

每项只以`nm -j <exact-object> | xcrun swift-demangle`并保留pipefail；非零或空输出失败。
Core `idleClockForTesting`必须release=0/debug>0；TestSuite五helpers、
`startControlledLoop`与五tests共11项逐项release=0/debug>0，count机械使用
`awk index()` substring。该合同同时证明target selection与caller/callee配置隔离，不扩大
产品逻辑、public/package API、target/dependency/package edge、schema或migration。

## 6. BEGIN-only driver and retained-App contract

driver只接受四个lowercase SHA-256 arguments，顺序精确为
`freeze, Review21, driver, manifest`；它核对absolute invocation、clean Bash 3.2 env、
branch/HEAD、four anchors、155 manifest、R15 tombstones、R16–R18 absence以及R19/R20
containment。全部12个R21 runtime paths与`agentloop-r21-{state,bundle}.*`使用fresh names；
pre-consumption失败零runtime write且授权未消费，boundary写入
`authorization_consumed=true`后任一失败永久`REJECTED_CONTAMINATED`且零retry。

对R20 retained App的driver source做了独立静态重算：expected array恰有108 literals，即
36个unique triples；类型为6个directory与30个regular file。固定safe file literals按冻结
顺序复算aggregate精确为
`06e063d4fdd541a808c78eacc5b34ddfd64874a3ab1648bbfe6bf74646db8170`。

all-node source pipeline为不带`-type`的
`find -P <exact App> -mindepth 1 -print0`直接进入Bash 3.2 indexed-seen validator。它完整
drain NUL stream，拒绝abnormal EOF/partial record、unknown/extra/missing/duplicate、
wrong type/symlink/special node或file-hash mismatch；proof完全通过后才输出fixed safe
expected literals。actual pathname不转成newline evidence。外层立即捕获
find/validator/shasum/hash-validator四个statuses；失败reason只包含四个safe numeric status
或`MISSING`，随后仍要求strict codesign verify。

current capture inventory按ERR-trap-facing outer unique parent blocks精确为：

- P=8：pre/post anchors、R19 roots/artifacts、R20 roots/exact-child/all-node manifest、
  RanchArt NUL pipeline；
- S=4：pre/post manifest shasum、process tri-state、R20 codesign；
- C=8：R21/R20 logical counts、empty-directory probe、R15 tombstone enumeration、fresh-root
  realpath、R19/R20 retained-root realpaths、post-manifest logical count。

因此core为`8P/4S/8C=20`；另计R16/R17/R18/R21 fresh-root-glob C，driver total为
`8P/4S/9C=21`。八个P在then/else第一条语句复制完整`PIPESTATUS`；S直接置于conditional；
C在subshell内先`trap - ERR`。driver没有运行任何test/build/matrix/source/bundle/sign/
preview命令，只建立fail-once BEGIN boundary。

## 7. Fail-once order, completion gates and red lines

Review21后的唯一future顺序冻结为：external four-anchor caller → BEGIN → exact one-file
guards → one unfiltered full RunTests → only after full green, same-log 46/46 → debug App build →
one fresh bundle assembly/sign + POST_BUILD/PRE_SIGN/LAUNCH_READY → pre-release guard-shape/strip
source sub-gate → Core target → TestSuite target → four exact-object gates → matrix with mandatory
script restoration → remaining source/privacy/final-hash gates → same-bundle isolated preview → END。

任一步unknown/nonzero/invariant failure都永久拒绝同一boundary；不得重跑、补丁、换root/
object或覆盖负证据。R20的652/652与46/46不能替代R21唯一full run。

Review21批准本身不运行或打开任何execution gate。只有牧场主在本Review之后的新用户turn
按`freeze, Review21, driver, manifest`顺序逐字提供四个final SHA-256并明确授权，才可
请求future caller/BEGIN与one-file guard实施。此前继续禁止test/build/matrix/source/
bundle/sign/preview、Package.swift、其他产品/test/App/RunTests/matrix-script修改、
Review02、acceptance、A3、commit、push、merge、release、normal-data、外部与真实用户操作。

## 8. Findings

### P0

无。

### P1

无。

### P2

无。

## 9. Verdict and authorization boundary

**APPROVED — 0 P0 / 0 P1**

R21 exact identities、six-surface routing、immutable R20 permanent rejection与partial evidence、
155=140+15 strict manifest、R20 current 132+8、Core immutable/TestSuite six-line exception、
target-exact release、four-object bidirectional symbols、36-node all-node NUL validator、safe
aggregate/four-status diagnostics、20/21 capture inventory、fresh identities、fail-once order、
acyclic trust chain与权限红线均通过独立静态审查。

本批准不调用caller/driver/BEGIN、不实施guards，也不自行构成execution authority。后续四个
terminal hashes到达前，R21状态仍是`PLAN_FROZEN — REVIEW21_APPROVED — EXECUTION_NOT_AUTHORIZED`。

## Open Questions

无。
