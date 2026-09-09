# P1-A2 R20 Deterministic Clock Repair Implementation Report

> 结论：**REJECTED_CONTAMINATED — release Core build failure**
>
> 日期：2026-08-03
>
> Invocation：`r20-98452cde-0ff4-4b66-b3f6-8085eb045a6f`

## 1. Entry snapshot and authority

- Branch：`codex/personal-ai-ranch-p0`
- HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
- R20 freeze：
  `0b698b59f214f23c26db88fd53763c4a600becaf898a716344f9d666ac2e8e07`
- Review20：
  `e70ea918e00c334a452f87e4fa8f44d5bfc754b042872a9f0a0ec13015e7c68e`
  且 verdict 为 `APPROVED — 0 P0 / 0 P1`
- reviewed driver：
  `840edee2dad7710f17e1b9bb8dcaa1484224ba0784b636f472bc2934f7e7eaeb`
- 140-entry static manifest：
  `2f8a6f4f786a2b5f432b2dbf7dcdc7208788d0b9ef5b9cdaa9de422bfaf88e81`
- manifest path-set SHA-256：
  `a126c9ae5da093078dfe29d32047e2b57fe51712a267ef90f89aa9f481433448`

牧场主在新的用户 turn 逐字提供上述四个 terminal hashes，并授权只按 R20 freeze 与
Review20 执行。external caller 的四-anchor strict check 与 140/140 static manifest
均通过后，才以冻结 clean environment 调用 reviewed driver。

## 2. BEGIN boundary

driver 在 pre-consumption 与 post-activation 阶段证明：

- branch/HEAD、四个 terminal anchors 与 140-entry manifest 精确匹配；
- R16/R17/R18 runtime paths 与 fresh-root globs保持 absent；
- R19 11 artifacts 保持 immutable，R19 invocation 仍为
  `REJECTED_CONTAMINATED`，两个 retained roots仍为real non-symlink empty；
- 两个 R15 exact tombstones继续为`ABSENT`，proof identity为
  `private_tmp_parent_enumeration_exact_basename_v1`，disappearance cause为
  `UNKNOWN`；
- AgentLoop/AgentLoopApp process count为0；
- 同一个 lossless NUL pathname verifier在消费前、消费后都证明 RanchArt actual
  direct-child set精确27项、regular 27、nonregular 0、symlink 0；transport为
  `find_print0_bash_read_d_nul_v1`。

授权于`2026-08-03T15:07:27Z`被唯一boundary消费。fresh identities为：

- state root：`/private/tmp/agentloop-r20-state.3QwlQa`
- bundle parent：`/private/tmp/agentloop-r20-bundle.30V5RH`
- planned App：`/private/tmp/agentloop-r20-bundle.30V5RH/AgentLoop.app`
- planned executable：
  `/private/tmp/agentloop-r20-bundle.30V5RH/AgentLoop.app/Contents/MacOS/AgentLoop`

R20 current capture inventory为core `5P / 3S / 7C = 15`，计fresh-root glob后
driver total `5P / 3S / 8C = 16`。R16 pre-BEGIN零写入、R17/R18未执行与R19失败
containment事实均未被改写。

## 3. Exact two-file implementation

本轮只修改了两个授权文件：

| Path | Entry SHA-256 | R20 final SHA-256 |
|---|---|---|
| `Sources/AgentLoopCore/Loop/AgentLoop.swift` | `5ec55a86b4548410b3f9ae876f7f8356d4a89e1024ef92f173412164c194a1bc` | `c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275` |
| `Sources/AgentLoopTestSuite/AgentLoopTests.swift` | `28f5b4287a1004daaca962db375c9ea24ac0f06d0f6abbd0c6ecd277696abfb2` | `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26` |

实现形状：

- public `AgentLoop.init` declaration保持逐字不变；production factory在每个attempt
  新建`ContinuousClock`；
- `idleClockForTesting`仅在matching `#if DEBUG`的package generic initializer中；
- production与test共用唯一`IdleWatchdog<C: Clock>` deadline/beat/wait算法；
- `ManualAgentLoopClock`使用NSLock、unique waiter IDs、checked throwing
  continuations、锁外resume、四态取消状态机和post-removal cancellation barrier；
- 两条取消顺序分别有独立completion计数，所有五项测试最终断言全部sleep state为0；
- controlled provider没有真实sleep；slow-active测试以24次50ms手动推进证明逻辑总时长
  1.2s大于1s timeout，且每次advance前都先收到真实watchdog beat之后的event ack。

implementation后的static manifest精确为138项unchanged + 2项授权mismatch；140个目标
仍全部是regular non-symlink。四terminal anchors保持不变；旧R19 manifest仍为117项
unchanged + six historical surface mismatch。没有第三个产品/test/script delta。

## 4. Authoritative tests

唯一一次、未过滤的权威命令：

```text
swift run RunTests
```

结果：`652 tests / 7 suites`全部通过，Swift与tee的pipeline statuses均为0；没有filter、
第二次test或失败重跑。完整日志：

- `r20-verify.log`
- SHA-256：`1aea8510917a6a3f72b9b2ab63cc2e90bc209481bf119f6de7c3a0ea74fea4e5`

只有full green后，才从同一日志机械审计冻结的46个exact names。46项各自
discovery/pass/failure count均为`1/1/0`，full summary是日志最后一个非空行：

- `r20-targeted-tests.log`
- SHA-256：`5d438374c029ce803903b339876189ccb1d632f4e28f87ae4ee2021a3b56e775`

这关闭了R19的wall-clock nondeterminism，但不越过后续release gate。

## 5. Debug build and LAUNCH_READY provenance

`swift build --product AgentLoopApp`成功。随后在任何release/matrix/source/launch前，
按`r20-dev-bundle-v1`只组装一次fresh bundle、只写一次冻结literal Info.plist、只执行
一次ad-hoc sign，并完成POST_BUILD、PRE_SIGN与LAUNCH_READY：

- Info.plist SHA-256：
  `5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58`
- source/generated/copied RanchArt均为27 regular、0 symlink，manifest：
  `4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab`
- signed identifier：`com.muzi.agentloop.dev`
- signature：ad-hoc；TeamIdentifier not set；无Developer ID、entitlement plist或
  App Sandbox entitlement；
- signed executable SHA-256：
  `d55fc10e674b77b480a85de46137eff40d40bd94b27c8e33b0d49f55d40a049c`
- signed bundle manifest SHA-256：
  `06e063d4fdd541a808c78eacc5b34ddfd64874a3ab1648bbfe6bf74646db8170`
- build/pre-sign/post-sign UUID集合保持一致；resources在签名前后均与SwiftPM build
  resources逐字相等；LAUNCH_READY时AgentLoop/AgentLoopApp进程数为0。

没有读取、删除或复用repository的`.build/AgentLoop.app`，没有执行或source
`scripts/run-app.sh`与`scripts/package-app.sh`。

## 6. Exact release failure

LAUNCH_READY之后，按冻结顺序唯一运行：

```text
swift build -c release --product AgentLoopCore
```

命令返回1。`r20-build.log`中的直接证据为：

```text
warning: '--product' cannot be used with the automatic product 'AgentLoopCore'; building the default target instead
[8/13] Compiling AgentLoopTestSuite AgentLoopTests.swift
Sources/AgentLoopTestSuite/AgentLoopTests.swift:671:30: error: extra argument 'idleClockForTesting' in call
```

证据边界内的根因是：`AgentLoopCore`是SwiftPM automatic library product；当前SwiftPM
没有把冻结的`--product AgentLoopCore`解释为只构建Core，而是转为production配置的
default-target build，因此额外编译`AgentLoopTestSuite`。production配置不定义
`DEBUG`，所以Core中正确被`#if DEBUG`隔离的`idleClockForTesting` initializer不可见，
而test target中的R20 caller仍参与release compilation，最终形成上述编译错误。

这是release gate的target-selection/test-guard合同缺口，不是full-suite行为失败。
当前boundary禁止失败后修改或重跑，因此本轮没有给test-only R20 fixtures/callers增加
release guard，也没有把冻结命令改成target-scoped命令，不声称根因已经修复。

boundary于`2026-08-03T15:36:40Z`写入：

```text
status=REJECTED_CONTAMINATED
phase=release_core_build
reason=release_AgentLoopCore_build_failed_rc_1
exit_code=1
retry_same_boundary=false
```

## 7. Fail-closed containment

release build非零后严格停止，没有运行任何未开始的后续gate，也没有同boundary retry。
只读containment证明：

- AgentLoop / AgentLoopApp process probe均为rc=1（不存在）；
- state root仍为real non-symlink empty directory；
- bundle parent仍为real non-symlink directory，唯一fresh signed App按失败证据要求保留；
- matrix script仍为entry SHA-256
  `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`，未发生临时delta；
- matrix/source/bootstrap/cold-start五个reserved text logs均保持empty；
- preview screenshot不存在；
- 两个fresh roots与全部R20 evidence均未清理、删除、覆盖或复用。

没有启动App或preview，没有插入synthetic fixture，没有访问、读写、重置或清理normal
application-data root。没有写END，也没有打开Review02、acceptance或A3。

## 8. Gate ledger

| Gate | Result |
|---|---|
| four terminal anchors | PASS |
| pre/post activation 140-entry manifest | PASS / PASS |
| pre/post lossless RanchArt NUL verifier | PASS / PASS |
| BEGIN | `BEGIN_ATTESTED` |
| two-file post-edit manifest | PASS，138 unchanged + 2 authorized mismatch |
| authoritative unfiltered `swift run RunTests` | PASS，652/652，7/7 |
| same-log 46-name audit | PASS，46/46 |
| standalone App debug build | PASS |
| POST_BUILD / PRE_SIGN / LAUNCH_READY | PASS / PASS / PASS |
| Core release build | **FAIL，exit 1** |
| release/debug nm symbol gates | NOT RUN |
| migration matrix | NOT RUN |
| source/privacy/final hash gates | NOT RUN |
| bootstrap preview | NOT RUN |
| synthetic isolated fixture | NOT INSERTED |
| cold-start preview | NOT RUN |
| screenshot | NOT CREATED |
| END | NOT WRITTEN |

## 9. New artifacts and hashes

| Artifact | SHA-256 / state |
|---|---|
| `evidence/r20-clean-boundary.log` | `f221507a75730a0a2cf2f0f2fd6213d26e956e0860aef70878f30bc9b4dee6df`；permanent `REJECTED_CONTAMINATED` |
| `evidence/r20-hash-manifest.log` | `5ef1e15c81dacc59872a1b9b1d8a999c19cee5516598564737cbcba764214450` |
| `r20-targeted-tests.log` | `5d438374c029ce803903b339876189ccb1d632f4e28f87ae4ee2021a3b56e775`；46/46 PASS |
| `r20-verify.log` | `1aea8510917a6a3f72b9b2ab63cc2e90bc209481bf119f6de7c3a0ea74fea4e5`；652/652 PASS |
| `r20-build.log` | `317efebd212133c292e2bc3ddc3e837f2c6acf47e450d48f1c32b9b25b26b5b4`；debug/LAUNCH_READY PASS，release FAIL |
| `evidence/r20-bundle-provenance.log` | `839ce977cbdace6cadd8ce2ee2a0bcc1a5f798389c4d1977a5dcb18ef63d921e`；POST_BUILD/PRE_SIGN/LAUNCH_READY PASS |
| `r20-migration-matrix.log` | empty；`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r20-source-gates.log` | empty；same empty-file hash |
| `evidence/r20-preview-bootstrap.log` | empty；same empty-file hash |
| `evidence/r20-preview-cold-start.log` | empty；same empty-file hash |
| `evidence/r20-preview-smoke.png` | not created |

本报告是本轮最后一个implementation artifact；其SHA-256在报告落盘后外部记录。

## 10. Historical truth, deviations, and next gate

- R13 invocation继续是`REJECTED_CONTAMINATED`；normal lock/DB/SHM/WAL incident、
  mutation `UNKNOWN`与Review01 verdict没有被本轮改写；
- R15 BEGIN false-negative仍没有运行后续gate；R16保持pre-BEGIN零写入；R17/R18从未
  执行；R19仍为authoritative full 651/652的永久rejection；
- Review20只批准R20 plan，不会把本次release build失败洗绿；
- 本轮没有commit、push、merge、release、付款、公开沟通、外部或真实用户操作；
- implementation静态审查期间曾额外执行一次path-scoped、只读、无输出、rc=0的
  `git diff --check -- <two authorized files>`。它没有写evidence，scope与冻结的最终
  whole-repository `git diff --check`不同，不能替代或消费正式gate；正式whole-repo
  gate在release failure后没有运行。该流程偏差在此如实披露；
- release failure后没有修改两个source/test文件，没有重跑build/test，也没有运行
  matrix、source、preview或END。

新的尝试必须先取得plan-level有界授权、使用全新exclusive artifact/root names，并由
职责隔离review明确选择和冻结一种根因修复：要么把release Core gate改为真正只构建
`AgentLoopCore` target的命令，要么让所有R20 test-only fixtures/callers在production
configuration中不参与编译；不能在本R20 boundary原地补丁或重跑。Review通过和新的
四-hash execution授权前，继续禁止caller/BEGIN、产品/test修改、test/build/matrix/
source/bundle/preview、Review02/acceptance、A3、commit/push/merge/release与normal-data
操作。
