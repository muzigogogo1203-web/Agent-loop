# P1-A2 R20 Deterministic-Time Plan Review

> Verdict：**APPROVED — 0 P0 / 0 P1**
>
> 日期：2026-08-02
>
> Review 对象：R20 final six surfaces、BEGIN-only driver、140-entry static manifest
> 与 R20 freeze

## 1. Scope and independence

本 reviewer 未参与 R20 six-surface、`r20-begin.sh`、`r20-entry.sha256` 或
`plan-freeze-r20.md` 的修订或生成。本次从当前 filesystem 独立读取并审查真实 bytes；
本 Review 创建前目标路径为 `ABSENT`，唯一写入是本 Review20 文件。本 Review 不记录或
预填自身 SHA-256。

本次没有运行 external caller、`r20-begin.sh`/BEGIN、任何 test、build、migration
matrix、source gate、bundle assembly/sign 或 preview；没有 source、执行 App script、
创建 runtime artifact/fresh root，或修改产品、测试、App、RunTests、matrix script、
六面、driver、manifest、freeze、R19 evidence、Review02、acceptance 或 A3。

只读/静态动作限于 branch/HEAD/status、hash、path/type/text、`find`/`pgrep` absence、
`/bin/bash -n`，以及只使用 memory/stdin、零文件写入的 Bash 3.2 EOF/NUL micro-probes。
审查快照为 branch `codex/personal-ai-ranch-p0`、HEAD
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`。已有 large dirty/untracked candidate tree
被视为用户工作并保持不动。

## 2. Exact identities and six-surface routing

### 2.1 Final R20 identities

| Artifact | Absolute path | Current SHA-256 | Result |
|---|---|---|---|
| canonical Stage | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `ece5e3635753e4087a4a56d5f35eea84a70c1e1fec3450e832394459f06e8f4e` | exact, regular non-symlink |
| canonical total Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `b190a2d479087167a4d685630ba6d7786eb99975051002293f36f5bfc839b2b3` | exact, regular non-symlink |
| A2 leaf Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `c84a2271479f4127be8a924eb0c4d3baceb99ff61043b02d24bde6df6f424d58` | exact, regular non-symlink |
| A2 blocked/control history | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/blocked.md` | `fa5b4825cb4fe7af2bc8eeb278a0e1df40d7e5fcad30a2873616a1dc4b304407` | exact, regular non-symlink |
| P1 Stage control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md` | `eb6055ddffa90f6b5038af58c3a7ba1b55d7bd8ec04acb7acdb8a966d1ab2dd4` | exact, regular non-symlink |
| P1 Plan control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md` | `409b1c0bcb5111bda88cfe461c86cf36a0204fc482135b67fecdd3c8acc507a3` | exact, regular non-symlink |
| R20 BEGIN-only driver | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r20-begin.sh` | `840edee2dad7710f17e1b9bb8dcaa1484224ba0784b636f472bc2934f7e7eaeb` | exact, regular non-symlink; Bash syntax PASS |
| R20 static manifest | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r20-entry.sha256` | `2f8a6f4f786a2b5f432b2dbf7dcdc7208788d0b9ef5b9cdaa9de422bfaf88e81` | exact, regular non-symlink |
| R20 freeze | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/plan-freeze-r20.md` | `0b698b59f214f23c26db88fd53763c4a600becaf898a716344f9d666ac2e8e07` | exact, regular non-symlink |

### 2.2 Current status, routing and Open Questions

六面 header 去除 Markdown emphasis 后逐 byte 一致：

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18/R18-A PLAN CHANGES REQUIRED — NOT EXECUTED；R19 BEGIN REJECTED_CONTAMINATED — AUTHORITATIVE FULL TEST 651/652；R20 Deterministic-Time Candidate Frozen；Review20 Pending；A2 Clean Re-verification Frozen`

该完整 current-status 字符串在六面共出现 9 次，每面 header 恰有一次。canonical Stage
§29、total Plan §19 与 A2 leaf §13 的 Open Questions 均精确为 `无。`；temporary
final-hash placeholder 为 0。两个 control indexes 中 canonical Stage/Plan/leaf 的
hashes均为 §2.1 最终值。

Stage §28.7、total Plan §18 R20、leaf §1/§2.6/§9/§10 与两个 control indexes 的
current gate 一致指向 R20/Review20。leaf §11 将全部 `R19_*`/`r19-*` recipe 明确限定为
不可执行历史，并以 R20 fresh names、140/140→138+2、single unfiltered full run 的
current override 取代；没有旧 R16–R19 future-tense 文字获得 current 开门权。

## 3. Immutable R19 failure chain and containment

### 3.1 Terminal identities and authoritative result

独立重算得到：

| R19 artifact | Current SHA-256 / state |
|---|---|
| `evidence/plan-freeze-r19.md` | `d7869b0531f5dc868a1e8d92b2aec9f0abf3cd84e0d3857b481f8fcc3807d03f` |
| `reviews/19-p1-plan-review.md` | `4588cd645edd47c7648f9c8e372fb4de42f2b8dd3a2bfeb31282aba2d6e7c41c`; `APPROVED — 0 P0 / 0 P1` |
| `evidence/r19-begin.sh` | `95a29f4452502a236bd73ac42a9741bf31e66fa6108bcdf4572b5fcc1eef190d` |
| `evidence/r19-entry.sha256` | `71dede4ad9a86c52e853d36af8629a491e84854badfaf0962054f06e86fcfb43`; 123 entries |
| invocation | `r19-daef1dab-0fbe-4a03-bab1-422adc18b3d4` |

`r19-clean-boundary.log`、full log 与 immutable report 相互闭合：BEGIN、pre/post
123-entry manifest 与 41/41 targeted PASS；唯一一次未过滤 authoritative full run 为
652 tests / 1 issue，即 651/652。唯一失败为
`slowActiveStreamDoesNotIdleTimeout`，终态 detail 为 `idle script exhausted`。
boundary 已永久写 `REJECTED_CONTAMINATED`、`phase=full_tests`、
`reason=swift_run_full_failed` 与 `retry_same_boundary=false`。

build/release、matrix、source、bundle/sign、preview 与 END 均未运行；planned App 与
screenshot 未创建。boundary/report 记录 containment product/test changes=0；当前旧
R19 manifest 的只读比较又独立得到恰好 117/123 unchanged + six-surface 6 mismatch，
没有额外产品/test/App-script 漂移。

### 3.2 Eleven artifacts and two exact retained roots

11 个 immutable R19 runtime/failure artifacts 均为 regular non-symlink，当前 hashes：

| Artifact | SHA-256 |
|---|---|
| `r19-targeted-tests.log` | `501957999e7a8103e553cb580d9b70f0825ee79a5c9a89e4b47e13c5db350f45` |
| `r19-verify.log` | `8ef56ce31c3e01c551e4ef65c98ce43e3631ad7554b56640e943cdb0ce5d5c15` |
| `r19-build.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `r19-migration-matrix.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `impl-report-r19.md` | `cddaffeaf553ff72b8f40ea1748baad649d98f747ff2210722f8fd1c388aceec` |
| `evidence/r19-clean-boundary.log` | `a5e1b1b8edda476204f4b0fbcc01f90e3e6bced1dee07daf4d58b9f4e143ca30` |
| `evidence/r19-bundle-provenance.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r19-source-gates.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r19-hash-manifest.log` | `43e9d2eb00c0a63d5071b0c17f2cdc4c5809530788e893b4ffb0381e60e1aff8` |
| `evidence/r19-preview-bootstrap.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r19-preview-cold-start.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

`/private/tmp` 下两个 R19 globs 的 direct-child exact set 只有：

- `/private/tmp/agentloop-r19-state.dNgUXh`
- `/private/tmp/agentloop-r19-bundle.49xVDm`

两者 distinct、real、non-symlink、empty；planned
`/private/tmp/agentloop-r19-bundle.49xVDm/AgentLoop.app` 与
`evidence/r19-preview-smoke.png` 均 absent。独立 NUL micro-probe 与 driver source 均
证明 exact-root enumeration 以 `find -P ... -print0` 直接进入 Bash 3.2
`read -r -d ""`，完整 drain 后只接受 terminal read rc=1、partial final record=0、
actual count=2 且两个 expected path 各一次。validator 不输出 actual pathname，失败只
暴露固定 reason 与 numeric statuses，因此 raw adversarial R19 pathname 不进入证据。

## 4. R20 BEGIN-only driver review

### 4.1 Invocation, Bash 3.2 and logical records

当前 `/bin/bash` 为 3.2.57；`/bin/bash -n r20-begin.sh` 返回 0。driver 仅接受四个
64-character lowercase SHA-256 positional parameters，顺序精确为
`freeze, Review20, driver, manifest`。`$0` 与 `BASH_SOURCE[0]` 都必须等于 frozen
absolute regular non-symlink realpath，因而不能以 source 方式消费边界。

driver 验证 frozen clean-environment keys：`LC_ALL=C`、`LANG=C`、固定 `PATH`、
`TMPDIR=/private/tmp`、Git system/global config controls，并拒绝 `BASH_ENV`、`ENV`、
`CDPATH`；四 anchors 由 caller parameters 生成，不硬编码本 freeze、Review20、driver
或 manifest hash。

R20 与 R19 manifest count 均使用 AWK logical-record `NR`，不会把末尾无 LF 的 record
漏掉；所有 manifest line loops 均使用 `read ... || [[ -n value ]]`。Bash 3.2 stdin
micro-probe确认 complete NUL stream终止为 rc=1/partial=0，`one\0partial` 为
rc=1/partial=1 并被拒绝；unterminated newline record同时被 AWK 与 line loop计入。

manifest shape source要求 R20=140、R19=123、两者 path sets sorted unique；逐项继承
完整 R19 path set并要求 17 个 frozen additions各存在且不与 R19 overlap。140 exact
count + complete 123 union + 17 distinct reviewed additions使 extra path无容纳空间。

### 4.2 Status captures, containment and activation order

R20 current core capture inventory按唯一 source block精确为：

- P=5：pre anchors、R19 exact-root NUL、R19 artifact hashes、post anchors、single
  phase-aware RanchArt NUL pipeline；
- S=3：pre manifest shasum、`pgrep` tri-state、post manifest shasum；
- C=7：pre R20 logical count、R19 logical count、empty-directory probe、R15 tombstone
  enumeration、fresh-root realpath、R19 retained-root realpath、post R20 logical count。

因此 core 为 `5P / 3S / 7C = 15`；另计 joint R16/R17/R18/R20 fresh-root-glob
absence C 后 driver total 为 `5P / 3S / 8C = 16`。六面将 R19 historical
`3P/3S/3C=9`、driver-total `3P/3S/4C=10` 保留为历史，没有冒充 R20 current。

P captures 均在 pipeline 的 then/else 第一条命令复制完整 `PIPESTATUS`；S 直接置于
conditional；C command substitutions在 subshell 内先 `trap - ERR`。driver 没有
`|| true` 或 silent fallback；`set +e`只出现在解除 error/signal traps后的永久负证据
写入路径。`pgrep rc=1` 被明确识别为 absence，其他非 0/1 status fail closed。

pre-BEGIN 依次验证四 anchors、140 shape/strict bytes、branch/HEAD、R16–R18 的各 12 个
runtime paths、R19 pre-containment、joint R16–R18/R20 fresh-root absence、12 个 R20
runtime paths、两个 process、R15 absorbing tombstones与 planned App/screenshot absence。
R19 containment核 11 artifacts的 type/hash、两个 exact roots、planned App/screenshot、
boundary immutable lines，并在 activation 后完整重跑及写 safe summary。

single RanchArt verifier使用：

```text
find -P <fixed RanchArt root> -mindepth 1 -maxdepth 1 -print0
  | /bin/bash -c '<Bash 3.2 NUL validator>'
```

它不以 `-type`缩小 universe，不经 command substitution/newline serialization，完整 drain
并要求 EOF rc=1、partial=0、27 exact ASCII basenames各一次、27 regular non-symlink、
0 nonregular、0 symlink；find/validator statuses独立保留。actual raw pathname不写 stdout/
stderr/hash log，只有成功后才写 fixed safe expected names。

调用顺序与 canonical freeze 一致：

```text
all fallible preconditions including R19 containment and R20 fresh absence
  -> pre-consumption RanchArt verifier as final fallible precondition
  -> noclobber boundary creation + authorization_consumed=true
  -> exclusive-create hash log
  -> post-activation RanchArt filesystem reread
  -> four terminal anchors
  -> 140-entry shape/strict manifest reread
  -> R19 exact containment reread
  -> frozen sentinel identities + worktree evidence
  -> remaining logs
  -> fresh state root + fresh bundle parent
  -> BEGIN finalization
```

pre-consumption failure保持零 runtime write且授权未消费；boundary创建后任何失败写永久
`REJECTED_CONTAMINATED`与`retry_same_boundary=false`。driver未声称 atomic filesystem
snapshot/lock或消除理论 TOCTOU。source 中没有 test、build、matrix、source、bundle、
sign、preview命令；它只建立 fail-once BEGIN evidence boundary。

## 5. Static manifest and acyclic trust chain

对 `r20-entry.sha256` 的独立检查结果：

1. 140 logical records，末尾 byte为 LF；每行精确为 `<64 lowercase hex><two spaces><absolute path>`；
2. 140 paths均在 repository内、无 `.`/`..` non-canonical segment，按 `LC_ALL=C`
   bytewise sorted unique；
3. 140 targets全部 regular non-symlink；逐项 current hash为140/140，
   `shasum -a 256 --strict -c`返回0；
4. pure sorted path-set SHA-256为
   `a126c9ae5da093078dfe29d32047e2b57fe51712a267ef90f89aa9f481433448`；
5. path set精确为 immutable R19 123 paths + 17 non-overlapping additions：R20 driver、
   R19 manifest/freeze/Review19、11个 R19 runtime/failure artifacts与两个 source baselines；
   无删除、overlap、missing或extra；
6. old R19 manifest对current filesystem精确为117 unchanged + six current-surface mismatch；
7. manifest排除自身、R20 freeze、Review20、12个 R20 runtime paths与fresh roots。

两个 future source baselines当前仍为 regular non-symlink并逐 byte匹配：

- `Sources/AgentLoopCore/Loop/AgentLoop.swift`：
  `5ec55a86b4548410b3f9ae876f7f8356d4a89e1024ef92f173412164c194a1bc`；
- `Sources/AgentLoopTestSuite/AgentLoopTests.swift`：
  `28f5b4287a1004daaca962db375c9ea24ac0f06d0f6abbd0c6ecd277696abfb2`。

`Package.swift`、`Sources/RunTests/main.swift`、两条 App scripts、matrix script及 manifest
内全部产品/test/sentinel paths同样匹配 frozen bytes；R20 planning未造成 product/test/
App-script delta。

manifest不依赖其自身/freeze/Review20/runtime；freeze只记录 upstream hashes，不记录自身
hash或已生成的 Review20 hash/verdict/future runtime result；本 Review不记录自身 hash。
driver只从 later caller positional parameters取得四 anchors。因此信任链无环：

```text
immutable predecessors + final six surfaces + complete immutable R19 chain
  + two source baselines + reviewed r20-begin.sh
  -> static r20-entry.sha256
  -> plan-freeze-r20.md
  -> reviews/20-p1-plan-review.md
  -> later user authorization carrying four terminal hashes
```

## 6. Exact two-file implementation and deterministic tests

### 6.1 Source boundary and shared algorithm

future implementation只允许修改上述两个 baseline files；不得新增 source/test file、
target、dependency、package edge、schema、migration、public API或release testing symbol。

`AgentLoop.swift`合同冻结为一个 private clock factory与单一
`IdleWatchdog<C: Clock>`、`C.Duration == Duration`。production与test复用同一 deadline、
`beat`、`waitForTimeout`算法；existing public `AgentLoop.init`签名、参数、默认值逐字不变，
normal production每 attempt以`ContinuousClock()`创建 watchdog。只有 matching
`#if DEBUG`下 package generic initializer可用 exact external label
`idleClockForTesting`注入 test clock。

release gate同时要求 `AgentLoop.swift` 内该 token全部位于 matching DEBUG region，release
`AgentLoop.swift.o`经`nm -j | xcrun swift-demangle` token count=0、debug count>0；
`ManualAgentLoopClock`只存在 test source。该合同排除 fake watchdog、第二套 timeout算法与
manual time release leakage。

`ManualAgentLoopClock`必须真实 conform `Clock`，以`NSLock`保护 monotonic instant、unique
waiter ID与checked throwing continuations。continuation先在 lock内 remove，释放 lock后
resume；advance与cancel路径 exactly-once、零waiter leak。cancellation必须覆盖
cancel-before-register与register-before-cancel，且不虚构 simultaneous tie的调度优先级；
`@unchecked Sendable`仅允许用于clock storage。

### 6.2 Five exact tests and authoritative gate

同一次 future authoritative full run须发现并通过以下五个 exact names各一次：

1. `slowActiveStreamDoesNotIdleTimeout`：逻辑总时长严格大于timeout、每段严格小于timeout；
   completed、0 timeout retry、provider `callCount == 1`；
2. `turnTimeoutRetriesOnceThenBlocks`：两个attempt各在watchdog armed后advance到deadline；
   恰好一次timeout retry、最终blocked、`callCount == 2`；
3. `timeoutThenSuccessDoesNotAccumulate`：每个provider turn首attempt timeout、次attempt
   success，证明timeoutCount逐turn重置；
4. `cancelWinsOverIdleTimeout`：armed后先cancel outer task，等待clock cancellation
   barrier确认waiter已移除/以`CancellationError`恢复，再advance超过deadline；必须
   canceled、零waiter，并覆盖两种cancel/register顺序而不声明simultaneous tie；
5. `turnCompletesUnderTimeout`：零advance立即完成，watchdog取消且零waiter。

controlled provider禁止`Task.sleep`。event acknowledgment只有在真实
`watchdog.beat`完成后才允许 manual clock advance；barrier必须避开 exact-deadline race。

authoritative test合同仅允许一次未过滤`swift run RunTests`，完整 stdout/stderr写
`r20-verify.log`；非零立即永久拒绝、不得重跑、不得使用`--filter`。只有full suite整个
discovery set全绿，才可从同一log机械提取既有41项+上述5项各一次的discovery/PASS证据，
写`r20-targeted-tests.log`。46/46 subset不替代full green。

entry manifest在source edit前须140/140；实施后只能上述两path mismatch、其余138/140
unchanged且两path仍regular non-symlink，第三个mismatch立即失败。source/release symbol
gates、diff与后续 Review02负责验证两项授权delta语义，而不是要求修改后的source回匹配
entry hash。

## 7. Current absences, completion gates and red lines

Review20创建前的current只读核对：

1. 12个 R20 runtime paths全部 absent；`agentloop-r20-state.*`与
   `agentloop-r20-bundle.*`匹配数均为0；
2. R16、R17、R18各12个runtime paths均 absent，六类相应fresh-root glob总匹配数为0；
3. R15两个exact tombstone paths均 absent，disappearance cause仍为`UNKNOWN`；
4. R19 11 artifacts、两个exact roots、planned App/screenshot状态均与 §3精确匹配；
5. `pgrep -x AgentLoop`与`pgrep -x AgentLoopApp`均为预期 absence rc=1；
6. Review02、A2 acceptance均 absent，P1 task root没有 A3 slice；
7. branch/HEAD、六面、driver、manifest、freeze与两个source baselines在Review写入前再次
   重算仍匹配。

R20 future runtime使用12个fresh paths：task root五项、evidence root七项，以及两类fresh、
distinct、real、non-symlink、empty、non-nested roots；不得复用 R15/R19 identity。Review20
批准本身只允许请求后续四-hash授权，不执行任何门。

只有后续 fresh R20 boundary到达 END且全部技术门完成，新的职责隔离 implementation
reviewer才可写 Review02；其零P0/P1后才打开 independent acceptance。acceptance必须披露
R19 651/652 rejection，只能声明 R20 boundary内zero normal-data access，不得把 R19
artifacts/roots改写为 R20 success。此前不得进入 A3，也没有 commit、push、merge、
release、normal-data、付款、公开沟通、外部或真实用户操作权限。

## 8. Findings

### P0

无。

### P1

无。

### P2

无。

## 9. Verdict and authorization boundary

**APPROVED — 0 P0 / 0 P1**

R20 exact identities、six-surface current routing、immutable R19 rejection/containment、
driver Bash 3.2/EOF/NUL/status/fail-once semantics、15/16 capture inventory、140/140
manifest、R19 123+17 union、117+6 historical comparison、acyclic trust chain、two-file
generic-clock exception、five deterministic tests、single authoritative run、140→138+2、
fresh absences、Review02/acceptance/A3 gates与权限红线均通过独立审查。

本批准不调用或打开 external caller、driver/BEGIN、source edit或任何执行门，也不自行
构成 execution authority。只有牧场主在本 Review之后的新用户 turn按
`freeze, Review20, driver, manifest`顺序逐字提供四个最终 SHA-256并明确授权，才可
请求 future R20 caller/BEGIN。此前上游bytes、R19 containment、R20 fresh absence与
全部scope事实必须继续不漂移。

## Open Questions

无。
