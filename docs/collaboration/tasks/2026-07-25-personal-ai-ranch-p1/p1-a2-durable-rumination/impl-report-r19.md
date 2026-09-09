# P1-A2 R19 Clean Re-verification Implementation Report

> 结论：**REJECTED_CONTAMINATED — authoritative full RunTests failure**
>
> 日期：2026-08-02
>
> Invocation：`r19-daef1dab-0fbe-4a03-bab1-422adc18b3d4`

## 1. Entry snapshot and authority

- Branch：`codex/personal-ai-ranch-p0`
- HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
- R19 freeze：
  `d7869b0531f5dc868a1e8d92b2aec9f0abf3cd84e0d3857b481f8fcc3807d03f`
- Review19：
  `4588cd645edd47c7648f9c8e372fb4de42f2b8dd3a2bfeb31282aba2d6e7c41c`
  且 verdict 为 `APPROVED — 0 P0 / 0 P1`
- reviewed driver：
  `95a29f4452502a236bd73ac42a9741bf31e66fa6108bcdf4572b5fcc1eef190d`
- 123-entry static manifest：
  `71dede4ad9a86c52e853d36af8629a491e84854badfaf0962054f06e86fcfb43`

牧场主在新的用户turn逐字提供上述四个terminal hashes，并授权只按R19 freeze与
Review19执行。external caller先以四行stdin严格核对anchors，再以123/123 strict
manifest核对全部冻结输入；两门均PASS后才以冻结clean environment调用driver。

## 2. BEGIN boundary

driver在pre-consumption阶段证明：

- branch/HEAD、四个terminal anchors与123-entry manifest全部精确匹配；
- R16/R17/R18/R19 runtime paths与fresh-root globs在BEGIN前全部absent；
- 两个R15 exact tombstones继续为`ABSENT`，proof identity为
  `private_tmp_parent_enumeration_exact_basename_v1`，disappearance cause为
  `UNKNOWN`；
- AgentLoop/AgentLoopApp process count为0；
- single NUL pathname verifier完整证明RanchArt parent是real non-symlink directory，
  actual 27项与expected bytewise exact、regular 27、nonregular 0、symlink 0；
  transport为`find_print0_bash_read_d_nul_v1`。

授权于`2026-08-03T00:21:39Z`被唯一boundary消费。fresh identities为：

- state root：`/private/tmp/agentloop-r19-state.dNgUXh`
- bundle parent：`/private/tmp/agentloop-r19-bundle.49xVDm`
- planned App：
  `/private/tmp/agentloop-r19-bundle.49xVDm/AgentLoop.app`

post-activation同一verifier重新读取filesystem并把safe structure evidence写入fresh
hash log；随后四anchors与123/123 manifest再次PASS。current capture inventory仍为
core `3P / 3S / 3C = 9`、计root-glob后driver total
`3P / 3S / 4C = 10`。

## 3. Verification results and exact failure

### 3.1 Targeted gate

冻结的41-name alternation只运行了41个A2 completion tests：

- discovery/pass count：41/41；
- suites：`A2DurableRuminationTests`与`A2CodingRanchTests`；
- result：PASS；
- log：`r19-targeted-tests.log`；
- SHA-256：
  `501957999e7a8103e553cb580d9b70f0825ee79a5c9a89e4b47e13c5db350f45`。

### 3.2 Authoritative full gate

随后按冻结顺序运行权威命令：

```text
swift run RunTests
```

结果为652 tests / 7 suites / 1 issue，process exit code为1。唯一失败：

```text
slowActiveStreamDoesNotIdleTimeout
Sources/AgentLoopTestSuite/AgentLoopTests.swift:611
Caught error: 响应流异常中断：idle script exhausted
failed after 9.924 seconds
```

full log为`r19-verify.log`，SHA-256：
`8ef56ce31c3e01c551e4ef65c98ce43e3631ad7554b56640e943cdb0ce5d5c15`。

boundary于`2026-08-03T00:24:49Z`写入：

```text
status=REJECTED_CONTAMINATED
phase=full_tests
reason=swift_run_full_failed
exit_code=1
retry_same_boundary=false
```

### 3.3 Evidence-bounded diagnosis

当前source显示该test只给`IdlePatternProvider`一个`.events` scripted step：25个events
间隔50ms，总计划时长约1.25s，production idle timeout为1s。test意图是证明每个event
会重置deadline；provider step一旦因idle timeout被取消，production retry会再次调用
provider，而第二次已没有scripted step，因此终态错误为`idle script exhausted`。

旧R13 full log中同一test曾PASS（4.724s）；本轮在full-suite并发环境下运行9.924s后
失败。结合当前source与终态错误，可以推断本轮至少出现了一次超过1s的event delivery/
scheduling idle gap，触发retry并耗尽single-step provider。该结论标记为
`INFERRED_FROM_FAILURE_LOG_AND_CURRENT_SOURCE`：现有证据足以定位为
`FULL_SUITE_IDLE_TIMING_SENSITIVITY`，但本boundary禁止重跑，因此不声称已用重现实验
区分test-only nondeterminism、host scheduling starvation或production watchdog
设计缺口，也不声称根因已修复。

## 4. Fail-closed containment

完整RunTests非零后严格停止，没有运行任何未开始的后续gate，也没有同boundary retry。
只读containment证明：

- AgentLoop / AgentLoopApp process count：0；
- state root仍为real non-symlink empty directory；
- bundle parent仍为real non-symlink empty directory；
- planned App不存在；
- 123-entry static manifest继续123/123 PASS，产品/test与冻结planning/history bytes
  均零delta；
- matrix script仍为entry SHA-256
  `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`；
- build/matrix/source/bundle/preview六个reserved text logs均保持empty；
- preview screenshot不存在；
- 两个fresh roots按失败证据要求保留，没有清理、删除或复用。

没有启动App或preview，没有执行display-name/bundle-id/LaunchServices lookup，没有
执行/source两条App scripts，也没有读写、重置或清理normal application-data root。

## 5. Gate ledger

| Gate | Result |
|---|---|
| four terminal anchors | PASS |
| pre/post 123-entry manifest | PASS / PASS |
| pre/post lossless RanchArt NUL verifier | PASS / PASS |
| BEGIN | `BEGIN_ATTESTED` |
| 41-name targeted tests | PASS, 41/41 |
| authoritative `swift run RunTests` | **FAIL**, 651 passed / 1 failed |
| standalone App debug build | NOT RUN |
| Core release build / nm gates | NOT RUN |
| migration matrix | NOT RUN |
| source/privacy gates | NOT RUN |
| bundle assembly / Info.plist / codesign | NOT RUN |
| POST_BUILD / PRE_SIGN / LAUNCH_READY | NOT REACHED |
| bootstrap preview | NOT RUN |
| cold-start preview | NOT RUN |
| screenshot | NOT CREATED |
| END | NOT WRITTEN |

因此本报告不声称full RunTests、build、matrix、source gates、bundle provenance、
isolated preview或A2 completion通过，也不打开Review02、acceptance或A3。

## 6. New artifacts and hashes

| Artifact | SHA-256 / state |
|---|---|
| `evidence/r19-clean-boundary.log` | `a5e1b1b8edda476204f4b0fbcc01f90e3e6bced1dee07daf4d58b9f4e143ca30`；permanent `REJECTED_CONTAMINATED` |
| `evidence/r19-hash-manifest.log` | `43e9d2eb00c0a63d5071b0c17f2cdc4c5809530788e893b4ffb0381e60e1aff8` |
| `r19-targeted-tests.log` | `501957999e7a8103e553cb580d9b70f0825ee79a5c9a89e4b47e13c5db350f45`；41/41 PASS |
| `r19-verify.log` | `8ef56ce31c3e01c551e4ef65c98ce43e3631ad7554b56640e943cdb0ce5d5c15`；652 tests / 1 failure |
| `r19-build.log` | empty；`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `r19-migration-matrix.log` | empty；same empty-file hash |
| `evidence/r19-bundle-provenance.log` | empty；same empty-file hash |
| `evidence/r19-source-gates.log` | empty；same empty-file hash |
| `evidence/r19-preview-bootstrap.log` | empty；same empty-file hash |
| `evidence/r19-preview-cold-start.log` | empty；same empty-file hash |
| `evidence/r19-preview-smoke.png` | not created |

本报告是本轮最后一个implementation artifact；其SHA-256在报告落盘后外部记录。

## 7. Historical truth and scope

- R13 whole invocation继续是`REJECTED_CONTAMINATED`；installed-App normal-root
  incident、mutation `UNKNOWN`与Review01 verdict没有被本轮改变；
- Review14 P1与R15 BEGIN false-negative/no-later-gates truth保持immutable；
- R16 pre-BEGIN zero-write/authorization-unconsumed事实保持immutable；
- Review17 P1与R17 never-executed、Review18 pathname-serialization P1与R18/R18-A
  never-executed facts保持immutable；
- R15 historical empty/current `ABSENT`分层、absorbing tombstones与
  `disappearance_cause=UNKNOWN`没有被改写为连续保全；
- Review19只批准R19 plan，不会把本次full-test失败洗绿；
- 本轮没有commit、push、merge、release、付款、公开沟通、外部或真实用户操作。

## 8. Deviations and next gate

- 没有获得或使用任何扩大范围的deviation authorization。
- full RunTests失败后严格停止；未因41/41 targeted green或旧full-suite PASS绕过
  authoritative gate。
- 没有在本boundary重跑失败test、完整suite或任何后续gate，也没有修改
  `AgentLoopTests.swift`、production watchdog或execution recipe。

新的尝试必须先取得plan-level有界授权，使用全新exclusive artifact/root names，并在
职责隔离plan review前明确决定如何对上述wall-clock/full-suite timing根因进行可观测、
可重复的确定性关闭。不得复用、覆盖或补写本R19 boundary作为成功证据。
