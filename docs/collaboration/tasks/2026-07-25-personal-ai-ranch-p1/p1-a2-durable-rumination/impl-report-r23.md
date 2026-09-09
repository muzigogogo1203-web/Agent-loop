# P1-A2 R23 Erosion-Snapshot and Release-Configuration Implementation Report

> 结论：**REJECTED_CONTAMINATED — authoritative full-test pipeline status was not captured**
>
> 日期：2026-08-10
>
> Invocation：`r23-7d645213-1588-40f6-95bd-f723729429eb`

## 1. Entry snapshot and reviewed authority

- Branch：`codex/personal-ai-ranch-p0`
- HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
- R23 freeze：
  `9c791a1bab22026ed2930eb120b9c82923390d42fad61a78f53b40080c6cef9a`
- Review23：
  `13bd182b8701df2b83fa63c58e978b440ed55c75c0c4a6c3ac936116d411a8bc`
  且唯一 verdict 为 `APPROVED — 0 P0 / 0 P1`
- reviewed driver：
  `0d82a6cf04d4391117d0095bc3b7439f7402d965b45e4396fce50811f4ed4c6c`
- 163-entry static manifest：
  `1776c5694ce8799258c5f4b37b623d230f3f37218d54817c25489c8dd63a4006`
- manifest path-set SHA-256：
  `2e1cd3b7e7292510077225db8661140b6ab942e72eb43d5b8bc16deb2a6d9e0f`

standing Goal 与用户最新的“不需要哈希逐步确认、完整落地”指令只取消重复的用户
hash echo，并未取消freeze、独立Review、branch/HEAD、manifest、exclusive boundary、
fail-once、完成门或红线。external caller的四个terminal anchors、Review23 machine
authority与163/163 static manifest通过后，才以冻结clean environment调用reviewed
driver。

## 2. BEGIN boundary

R23于`2026-08-10T17:30:03Z`唯一消费授权，并在`2026-08-10T17:30:05Z`
完成BEGIN attestation。boundary明确记录：

```text
authorization_consumed=true
begin_attestation_complete=true
status=BEGIN_ATTESTED
```

fresh identities为：

- state root：`/private/tmp/agentloop-r23-state.GsQHd1`
- bundle parent：`/private/tmp/agentloop-r23-bundle.PuKOJy`
- planned App：`/private/tmp/agentloop-r23-bundle.PuKOJy/AgentLoop.app`
- planned executable：
  `/private/tmp/agentloop-r23-bundle.PuKOJy/AgentLoop.app/Contents/MacOS/AgentLoop`

BEGIN前后，driver证明R19 tombstone、R20 erosion lifecycle、R21/R22零写入与未执行
事实、RanchArt结构、进程absence、implementation entry hashes及全部静态anchors满足
freeze。R23 boundary一旦被消费即不可重用。

## 3. Exact implementation delta

本轮唯一source/test变化是
`Sources/AgentLoopTestSuite/AgentLoopTests.swift`中的六行direct directive：三组
matching `#if DEBUG` / `#endif`，分别包围冻结的helper block、
`startControlledLoop`与五个exact tests。没有移动或修改其中逻辑，也没有第四个guard、
`#else`或`#elseif`。

| Path | R23 entry SHA-256 | R23 current SHA-256 | Result |
|---|---|---|---|
| `Sources/AgentLoopCore/Loop/AgentLoop.swift` | `c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275` | `c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275` | byte-identical |
| `Sources/AgentLoopTestSuite/AgentLoopTests.swift` | `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26` | `37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6da1d615ad87967` | only the six authorized directives |

失败后的只读核对表明，移除当前文件中恰好三组、六行direct DEBUG directives后，
stream SHA-256恢复为entry hash
`66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`。
没有修改`Package.swift`、其他产品/test文件、App script、RunTests runner、matrix
script、public/package API、target/dependency/package edge、schema或migration。

## 4. Authoritative full-test evidence and exact failure

R23只启动了一次、未过滤的：

```text
swift run RunTests
```

`r23-verify.log`完整写到终端摘要：

```text
Test run with 652 tests in 7 suites passed
```

该日志事实只能证明test process输出了`652/652`终端摘要，不能证明冻结的权威
pipeline gate通过。负责运行implementation chain并在`swift run RunTests | tee ...`
之后捕获status的外层exec wrapper实际由zsh承载；它读取了Bash-only的
`${PIPESTATUS[@]}`，而该参数在zsh中未定义。wrapper因此以exit 1失败，既没有取得
Swift status，也没有取得tee status：

```text
authoritative_pipeline_status=UNKNOWN_NOT_CAPTURED
authoritative_swift_rc=UNKNOWN_NOT_CAPTURED
authoritative_tee_rc=UNKNOWN_NOT_CAPTURED
wrapper_failure=zsh_PIPESTATUS_parameter_unset
```

这不是test assertion failure，也不能被日志末行“洗绿”；真实根因是status-capture
harness的shell配置与其Bash-only实现不一致。freeze要求Swift与tee两个status都被
可靠捕获，因此R23在`authoritative_full_test_status_capture`阶段fail closed，并于
`2026-08-10T17:32:47Z`永久记录：

```text
status=REJECTED_CONTAMINATED
phase=authoritative_full_test_status_capture
reason=outer_shell_zsh_PIPESTATUS_unset_after_terminal_652_of_652_log
exit_code=1
authorization_consumed=true
retry_same_boundary=false
full_test_rerun_forbidden=true
```

## 5. Gates not run

失败发生后没有同boundary retry，也没有继续执行任何后续gate：

| Gate | Result |
|---|---|
| four terminal anchors / 163-entry pre-activation manifest | PASS |
| BEGIN | `BEGIN_ATTESTED` |
| six direct DEBUG directive lines | APPLIED |
| one unfiltered full-test process | terminal log says 652/652; pipeline statuses **UNKNOWN_NOT_CAPTURED** |
| authoritative full-test gate | **FAIL，wrapper exit 1** |
| same-log 46/46 mechanical audit | NOT RUN |
| debug App build | NOT RUN |
| bundle assembly/sign and POST_BUILD/PRE_SIGN/LAUNCH_READY | NOT RUN |
| guard-shape / strip-to-R20 formal source gate | NOT RUN |
| release Core/TestSuite target builds | NOT RUN |
| release/debug object symbol gates | NOT RUN |
| migration matrix/restoration | NOT RUN |
| remaining source/privacy/final-hash gates | NOT RUN |
| same-bundle bootstrap/cold-start preview | NOT RUN |
| screenshot | NOT CREATED |
| END | NOT WRITTEN |

`r23-targeted-tests.log`、`r23-build.log`、`r23-migration-matrix.log`、
`r23-bundle-provenance.log`、`r23-source-gates.log`、
`r23-preview-bootstrap.log`与`r23-preview-cold-start.log`全部保持empty；
`r23-preview-smoke.png`不存在。这些空证据不能被解释为对应gate通过。

## 6. Fresh roots and fail-closed containment

失败后的只读核对证明：

- `/private/tmp/agentloop-r23-state.GsQHd1`仍为real directory，direct-child count为0；
- `/private/tmp/agentloop-r23-bundle.PuKOJy`仍为real directory，direct-child count为0；
- planned App与planned executable均未创建；
- 两个fresh roots和全部R23 runtime evidence均未清理、删除、覆盖、重命名或复用。

没有启动AgentLoop/AgentLoopApp，没有组装或签名bundle，没有插入synthetic fixture，
没有访问、读写、重置或清理normal application-data root。没有commit、push、merge、
release、付款、公开沟通、外部动作或真实用户动作。

## 7. Preserved predecessor truth

- R19继续是永久`REJECTED_CONTAMINATED`，权威full test为651/652；其11个历史
  artifacts保持immutable，两个historical roots当前为`ABSENT_TOMBSTONE`，
  disappearance cause为`UNKNOWN`，不能重跑同一boundary。
- R20继续是永久`REJECTED_CONTAMINATED`：历史证据包含full 652/652、same-log
  46/46与LAUNCH_READY，随后在release Core build失败。其state root保持
  `ABSENT_TOMBSTONE`；bundle parent当前只保留Review22冻结的8/38 mask：
  `11101011100000000000000000000000000010`，即parent、App与六个historical
  directories，0 regular files。它不是当前signed或launchable App，不能据此重算或
  声称current signed-bundle hash。
- R21继续是pre-BEGIN exit 70、`AUTHORIZATION_NOT_CONSUMED`、runtime write count 0；
  它没有BEGIN，也没有产品/test修改或执行门。
- R22继续是`CHANGES REQUIRED — 0 P0 / 1 P1`、未执行、authorization未消费、
  runtime write count 0；全部R22 runtime paths和fresh roots保持absent。

本轮没有改写、补造或升级任何上述历史事实。R23只在自己的exclusive boundary内
产生新证据，并永久保留自身失败状态。

## 8. New R23 artifacts and hashes

| Artifact | Bytes | SHA-256 / state |
|---|---:|---|
| `evidence/r23-clean-boundary.log` | 8493 | `4b17b1e7e8536fa88b7b41e68efc089f3b300dd801d42729a375fe2284cd5a78`；permanent `REJECTED_CONTAMINATED` |
| `evidence/r23-hash-manifest.log` | 27215 | `cdb9776b645f0db4b059d2c4e44a974da3788c565653741e1ff2635c22e3afeb` |
| `r23-verify.log` | 99938 | `c0f5fe79792c60eacfa266a12d53f79abdf3cea53d6e8c9e1f6bc42337100762`；terminal 652/652，pipeline statuses unknown |
| `r23-targeted-tests.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `r23-build.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `r23-migration-matrix.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r23-bundle-provenance.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r23-source-gates.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r23-preview-bootstrap.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r23-preview-cold-start.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r23-preview-smoke.png` | — | not created |

上述十个已创建runtime artifacts均为regular files；两个fresh roots为空目录。本报告
是本轮最后一个implementation artifact，其SHA-256只能在最终bytes落盘后由外部计算，
不能自嵌而不产生hash cycle。

## 9. Required next route

R23已经消费授权并永久失败，不能原地修改wrapper、覆盖negative evidence、清理roots、
补跑46-name audit或重跑任何test/build/matrix/source/bundle/preview/END gate。

- Deviation：失败后运行过一次path-scoped、stdout-only的
  `grep -v -E '^#(if DEBUG|endif)$' Sources/AgentLoopTestSuite/AgentLoopTests.swift | shasum -a 256`
  ad hoc诊断；命令rc为0，stdout hash为
  `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`；它没有写入
  文件，不替代、不消费，也不证明formal source gate。

下一轮只能建立全新的R24 plan、职责隔离review、freeze、driver、manifest、exclusive
runtime artifacts与fresh roots，并把R23全部失败证据作为immutable predecessor纳入。
R24必须将整个test invocation与双status capture harness显式置于
`/bin/bash --noprofile --norc`之下，不能依赖调用方的默认shell，也不能在zsh中读取
Bash-only `${PIPESTATUS[@]}`。在R24独立review通过与全新BEGIN之前，继续禁止新的
test/build/matrix/source/bundle/preview、Review02、acceptance、A3及任何未授权外部动作。
