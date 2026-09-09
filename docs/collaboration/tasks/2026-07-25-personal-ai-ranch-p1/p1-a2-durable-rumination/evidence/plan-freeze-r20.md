# P1-A2 R20 Deterministic-Time Plan Freeze

> 状态：R20 Deterministic-Time Candidate Frozen；Review20 Pending；全部执行继续禁止
>
> 日期：2026-08-02
>
> 分支：`codex/personal-ai-ranch-p0`
>
> HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. 授权范围与停止线

R19已按牧场主提供的四个terminal hashes进入clean invocation
`r19-daef1dab-0fbe-4a03-bab1-422adc18b3d4`。BEGIN、pre/post static manifest与
41/41 targeted均通过；紧接的唯一一次未过滤authoritative `swift run RunTests`
为651/652，唯一失败是`slowActiveStreamDoesNotIdleTimeout`，终态错误为
`idle script exhausted`。R19因此永久`REJECTED_CONTAMINATED`且
`retry_same_boundary=false`，后续build/release、matrix、source、bundle/sign、
preview与END均未运行。

planner随后提出只关闭该full-suite wall-clock nondeterminism的R20 planning-only
方案。牧场主在紧接的新用户turn回复：

> 继续，授权R20

该授权只允许：

1. 同步六个canonical/control surfaces；
2. 新增BEGIN-only `evidence/r20-begin.sh`；
3. 生成精确140项的`evidence/r20-entry.sha256`；
4. 生成本freeze；
5. 由未参与上述修订/生成的职责隔离reviewer唯一写
   `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/20-p1-plan-review.md`。

本授权不允许运行external caller、`r20-begin.sh`/BEGIN、任何test、build、migration
matrix、source gate、bundle assembly/sign或preview；不允许修改两个未来授权
source/test文件或任何其他产品/test/App/RunTests/matrix script；不允许创建Review02、
acceptance、进入A3、commit、push、merge、release、normal-data、外部或真实用户操作。

Review20达到`APPROVED — 0 P0 / 0 P1`本身也不执行。仍须牧场主在Review20之后的
新用户turn按`freeze, Review20, driver, manifest`顺序逐字提供四个最终SHA-256并明确
授权，才可打开future R20 caller/BEGIN与精确两文件实施。

## 2. Final planning identities

### 2.1 Six canonical/control surfaces

| Surface | Absolute path | SHA-256 |
|---|---|---|
| canonical Stage | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `ece5e3635753e4087a4a56d5f35eea84a70c1e1fec3450e832394459f06e8f4e` |
| canonical total Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `b190a2d479087167a4d685630ba6d7786eb99975051002293f36f5bfc839b2b3` |
| A2 leaf Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `c84a2271479f4127be8a924eb0c4d3baceb99ff61043b02d24bde6df6f424d58` |
| A2 blocked/control history | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/blocked.md` | `fa5b4825cb4fe7af2bc8eeb278a0e1df40d7e5fcad30a2873616a1dc4b304407` |
| P1 Stage control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md` | `eb6055ddffa90f6b5038af58c3a7ba1b55d7bd8ec04acb7acdb8a966d1ab2dd4` |
| P1 Plan control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md` | `409b1c0bcb5111bda88cfe461c86cf36a0204fc482135b67fecdd3c8acc507a3` |

六面header的current status逐字一致：

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18/R18-A PLAN CHANGES REQUIRED — NOT EXECUTED；R19 BEGIN REJECTED_CONTAMINATED — AUTHORITATIVE FULL TEST 651/652；R20 Deterministic-Time Candidate Frozen；Review20 Pending；A2 Clean Re-verification Frozen`

该完整字符串在六面共出现9次；每面header均恰有一次。canonical Stage §29、total
Plan §19与A2 leaf §13的Open Questions均精确为`无。`。全部临时final-hash
placeholder数量为0；两个control indexes中的canonical Stage/Plan/leaf hashes均为上表
最终值。leaf §11已把全部R19 recipe明确冻结为不可执行历史并以R20 current override
取代；§12只指向future `impl-report-r20.md`、Review20、Review02与acceptance门。

pre-freeze semantic audit曾发现canonical Plan与leaf把R19的capture inventory 9/10
误称为R20 current inventory。该P1只在同一R20 planning范围内修订并重新审计：R19
historical `3P/3S/3C=9`、driver-total `3P/3S/4C=10`保持immutable；R20 current
core为`5P/3S/7C=15`，driver total为`5P/3S/8C=16`。最终六面只读复审为
`0 P0 / 0 P1 / 0 P2`。

### 2.2 Driver, manifest and source baselines

| Artifact | Absolute path | SHA-256 / invariant |
|---|---|---|
| R20 BEGIN-only driver | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r20-begin.sh` | `840edee2dad7710f17e1b9bb8dcaa1484224ba0784b636f472bc2934f7e7eaeb`；`/bin/bash -n` PASS；final static audit `0 P0 / 0 P1` |
| R20 static manifest | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r20-entry.sha256` | `2f8a6f4f786a2b5f432b2dbf7dcdc7208788d0b9ef5b9cdaa9de422bfaf88e81`；140 entries；strict 140/140 PASS |
| manifest pure path set | 140 absolute paths in the manifest | `a126c9ae5da093078dfe29d32047e2b57fe51712a267ef90f89aa9f481433448` |
| future implementation core baseline | `/Users/muzi/Agent-loop/Sources/AgentLoopCore/Loop/AgentLoop.swift` | `5ec55a86b4548410b3f9ae876f7f8356d4a89e1024ef92f173412164c194a1bc` |
| future implementation test baseline | `/Users/muzi/Agent-loop/Sources/AgentLoopTestSuite/AgentLoopTests.swift` | `28f5b4287a1004daaca962db375c9ea24ac0f06d0f6abbd0c6ecd277696abfb2` |

上述driver只是冻结的BEGIN-only candidate，不是已执行driver，也没有获得Review20批准。
两个source baselines在本freeze生成时仍逐byte匹配；R20 planning没有修改它们。

## 3. Acyclic trust chain

唯一信任链为：

```text
immutable predecessors + final six surfaces + complete immutable R19 chain
  + two source baselines + frozen r20-begin.sh
  → static r20-entry.sha256
  → plan-freeze-r20.md
  → reviews/20-p1-plan-review.md
  → later user authorization carrying four terminal hashes
```

- manifest排除自身、本freeze、Review20、全部R20 runtime artifacts与temp roots；
- 本freeze只记录upstream hashes，不记录自身hash或尚未生成的Review20 hash/verdict；
- Review20可绑定本freeze hash，但不得记录自身hash；
- driver不硬编码freeze、Review20、driver或manifest hash，只在future caller调用时按
  四个positional parameters取得并核对；
- Review20生成后不得回填本freeze或六面；任何上游bytes漂移都使candidate失效；
- 后续完整四元组只能由Review20后的新用户turn提供，不能由planner/reviewer推导、
  预填或回写。

## 4. Immutable R19 rejection and containment

### 4.1 Terminal identities and result

| Artifact | SHA-256 / state |
|---|---|
| `evidence/plan-freeze-r19.md` | `d7869b0531f5dc868a1e8d92b2aec9f0abf3cd84e0d3857b481f8fcc3807d03f` |
| `reviews/19-p1-plan-review.md` | `4588cd645edd47c7648f9c8e372fb4de42f2b8dd3a2bfeb31282aba2d6e7c41c`；`APPROVED — 0 P0 / 0 P1` |
| `evidence/r19-begin.sh` | `95a29f4452502a236bd73ac42a9741bf31e66fa6108bcdf4572b5fcc1eef190d` |
| `evidence/r19-entry.sha256` | `71dede4ad9a86c52e853d36af8629a491e84854badfaf0962054f06e86fcfb43`；123 entries |
| R19 invocation | `r19-daef1dab-0fbe-4a03-bab1-422adc18b3d4` |

R19 BEGIN、pre/post RanchArt/manifest gates与41/41 targeted通过。唯一未过滤full run
为651/652；`slowActiveStreamDoesNotIdleTimeout`以`idle script exhausted`失败。
boundary永久`REJECTED_CONTAMINATED`且`retry_same_boundary=false`。build/release、
matrix、source、bundle/sign、preview与END未运行；planned App与screenshot未创建；
产品/test/matrix script零漂移；R19 boundary内normal-data access count为0。R19不能被
重跑、继续或由R20成功洗绿。

### 4.2 Eleven immutable artifacts and two retained roots

| R19 artifact | SHA-256 |
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

exact retained roots为：

- `/private/tmp/agentloop-r19-state.dNgUXh`
- `/private/tmp/agentloop-r19-bundle.49xVDm`

两者当前distinct、real、non-symlink、empty。所有匹配
`agentloop-r19-state.*`/`agentloop-r19-bundle.*`的direct children精确只有上述两个；
R19 planned App与`evidence/r19-preview-smoke.png`仍absent。R20 driver在授权消费前与
消费后都以lossless `find -P ... -print0`→Bash `read -r -d ""` validator重证该
exact set：find/validator status必须均为0，终止read status必须精确为normal EOF 1，
partial final record必须为空，actual count必须为2且每个exact path各一次。

R20只能验证上述artifact/root bytes、type与retention，不能把它们读作runtime input，
也不能写入、删除、清理、移动、重命名或复用。

## 5. Root-cause diagnosis and exact two-file exception

诊断置信度固定为`INFERRED_FROM_FAILURE_LOG_AND_CURRENT_SOURCE`。已确认的是现有test
依赖真实wall clock：single-step `IdlePatternProvider`产生25个events，每项以真实
`Task.sleep(50ms)`延迟，逻辑总时长约1.25秒；production idle timeout为1秒。full-suite
scheduling gap可先触发idle timeout，retry再调用已耗尽的scripted provider，于是最终
显示`idle script exhausted`。这不把未单独复现实验区分的host starvation与production
watchdog bug虚构为唯一结论。

只有Review20通过并取得后续四-hash执行授权后，implementer才可且必须只修改§2.2的
两个baseline文件。不得新增source/test file、target、dependency、package edge、schema、
migration或public API；不得修改任何其他产品/test/App/RunTests/matrix script。

未来实现必须满足：

1. `AgentLoop.swift`只增加一个private clock factory与单一
   `IdleWatchdog<C: Clock>`，并要求`C.Duration == Duration`；
2. production与test复用同一deadline、`beat`和`waitForTimeout`算法，禁止fake
   watchdog或第二套timeout逻辑；
3. 既有public `AgentLoop.init`签名、参数与默认值逐字不变；普通production path每个
   attempt仍以`ContinuousClock()`创建watchdog；
4. 只有`#if DEBUG`下的package generic initializer可注入test clock，external label
   必须精确为`idleClockForTesting`；release不得出现该symbol；
5. `ManualAgentLoopClock`只存在于test source，真实遵循`Clock`，以`NSLock`保护
   monotonic instant、unique waiter ID与checked throwing continuations；
6. continuation必须先在lock内移除、释放lock后再resume；advance与cancel必须
   exactly-once且零waiter leak；`@unchecked Sendable`只允许用于clock storage；
7. cancellation覆盖cancel-before-register与register-before-cancel；不宣称
   simultaneous tie的调度优先级。

R20禁止通过增加idle timeout、缩短逻辑流、扩大event间隔余量、`.serialized`、skip、
filter、修改RunTests并发、复制scripted provider step、吞掉错误或失败重跑来洗绿。

## 6. Five exact tests and the single authoritative run

同一次future authoritative full run必须发现并通过以下五个exact names各一次：

1. `slowActiveStreamDoesNotIdleTimeout`：逻辑总时长严格大于timeout、每段严格小于
   timeout；completed、timeout retry为0、provider `callCount == 1`；
2. `turnTimeoutRetriesOnceThenBlocks`：两个attempt各在watchdog armed后advance到
   deadline；恰好一次timeout retry、最终blocked、`callCount == 2`；
3. `timeoutThenSuccessDoesNotAccumulate`：每个provider turn首attempt timeout、次attempt
   success，证明timeoutCount逐turn重置；
4. `cancelWinsOverIdleTimeout`：watchdog armed后先cancel outer task，等待
   `ManualAgentLoopClock` cancellation barrier确认waiter已移除或以
   `CancellationError`恢复，再advance超过deadline；必须canceled、零waiter，同时覆盖
   cancel-before-register与register-before-cancel exactly-once，不声明simultaneous tie；
5. `turnCompletesUnderTimeout`：零advance立即完成，watchdog被取消且零waiter。

controlled provider禁止`Task.sleep`。每个event acknowledgment必须在真实
`watchdog.beat`完成后才允许manual clock advance；barrier必须避免exact-deadline race。

future authoritative test合同只有一次未过滤`swift run RunTests`：完整stdout/stderr写
`r20-verify.log`，失败立即永久拒绝且不得重跑，也不得使用`--filter`。full suite整个
发现集全绿后，才可从同一log机械提取原41项与新增5项各一次的discovery/PASS证明写入
`r20-targeted-tests.log`。46/46 subset不能替代full suite。不得在本freeze预写future
test总数或成功结果。

## 7. 140-entry static manifest and phase-aware delta

`r20-entry.sha256`包含140个absolute paths；每行精确为lowercase 64-hex、two spaces、
absolute path，按`LC_ALL=C` bytewise sorted unique，末尾LF存在。所有140 targets均为
regular non-symlink，strict check为140/140 PASS，pure sorted path-set SHA见§2.2。

| Class | Count |
|---|---:|
| six current surfaces | 6 |
| R16–R20 drivers plus immutable R17 Bash 3.2 probe | 6 |
| A1b review/acceptance anchors | 2 |
| A2 frozen product/test files | 15 |
| full-file sentinels/Package/runner/App/matrix scripts/RanchArtView | 14 |
| RanchArt exact files | 27 |
| R13 implementation/incident/Review01 evidence | 14 |
| plan freezes through R19 | 15 |
| plan reviews Review12 through Review19 | 13 |
| R15 execution/failure artifacts | 11 |
| immutable R16–R19 static entry manifests | 4 |
| immutable R19 runtime/failure artifacts | 11 |
| two R20 source baselines | 2 |
| **Total** | **140** |

path set精确等于immutable R19的123 paths，加17个互不重叠的新paths：R20 driver、
R19 manifest/freeze/Review19、11个R19 runtime/failure artifacts及两个source baselines。

六面更新后的旧R19 manifest对current filesystem精确为117/123 unchanged加six-surface
六个mismatch；不得修改旧manifest恢复123/123。R20当前pre-edit manifest为140/140；
future BEGIN activation后、任何source/test edit前仍必须重证140/140。future two-file
implementation完成后必须恰好只有§2.2两个authorized source paths mismatch、其余
138/140 unchanged，且两者仍为regular non-symlink；第三个mismatch立即失败。post-edit
138+2是future completion contract，不是本freeze已发生事实。

manifest排除自身、本freeze、Review20、全部12个R20 runtime paths与fresh roots。

## 8. BEGIN-only driver, captures and fresh identities

`r20-begin.sh`只建立一个fail-once BEGIN evidence boundary，不运行test、build、matrix、
source、bundle/sign或preview。它只接受四个小写SHA-256参数，顺序精确为
`freeze, Review20, driver, manifest`；clean Bash 3.2 environment、absolute invocation、
branch与HEAD必须匹配本freeze。

driver对manifest使用AWK logical-record count；所有line-read loops都接受并验证
unterminated final record，防止额外第141项被`wc -l`或EOF遗漏。R19 exact-root validator
同样保存最终`read` status并拒绝partial record。RanchArt仍使用single phase-aware、
lossless NUL verifier，pre-consumption是授权消费前最后一个fallible gate。

R20 current capture inventory按唯一source block计数，重复调用同一block不重复：

| Class | Responsibilities | Count |
|---|---|---:|
| P | pre anchors；R19 exact-root NUL；R19 artifact hashes；post anchors；RanchArt NUL | 5 |
| S | pre R20 manifest shasum；pgrep tri-state；post R20 manifest shasum | 3 |
| core C | pre R20 record count；R19 record count；empty-directory；R15 tombstone；fresh-root realpath；R19 retained-root realpath；post R20 record count | 7 |
| extra C | joint R16/R17/R18/R20 fresh-root-glob absence | 1 |

因此core精确为`5P / 3S / 7C = 15`，driver total精确为
`5P / 3S / 8C = 16`。R19 historical 9/10不被改写或冒充R20 current。

canonical activation order为：

```text
all fallible preconditions including R19 containment and R20 fresh absence
  → pre-consumption RanchArt verifier as final fallible precondition
  → noclobber boundary creation + authorization_consumed=true
  → exclusive-create hash log
  → post-activation RanchArt filesystem reread
  → four terminal anchors
  → 140-entry shape/strict manifest reread
  → R19 exact containment reread
  → frozen sentinel identities + worktree evidence
  → remaining fresh logs
  → fresh state root + fresh bundle parent
  → BEGIN finalization
```

pre-consumption失败保持零runtime write且授权未消费；boundary成功后任一失败都永久
`REJECTED_CONTAMINATED`且same-boundary不得retry。driver不声称atomic filesystem
snapshot/lock或消除最终读取后的理论TOCTOU。

R20 fresh 12 paths为：

- task root：`r20-targeted-tests.log`、`r20-verify.log`、`r20-build.log`、
  `r20-migration-matrix.log`、`impl-report-r20.md`；
- evidence root：`r20-clean-boundary.log`、`r20-bundle-provenance.log`、
  `r20-source-gates.log`、`r20-hash-manifest.log`、`r20-preview-bootstrap.log`、
  `r20-preview-cold-start.log`、`r20-preview-smoke.png`；
- fresh roots：`/private/tmp/agentloop-r20-state.*`与
  `/private/tmp/agentloop-r20-bundle.*`。

pre-BEGIN必须证明12个paths与两类root glob全部absent。创建后的roots必须distinct、
real、non-symlink、empty、互不嵌套，且不得复用R15或R19 identity。

## 9. Review20 completion gate

未参与R20 six-surface、driver、manifest或本freeze修订/生成的职责隔离reviewer唯一可写：

`/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/20-p1-plan-review.md`

Review20必须至少独立核对：

1. reviewer职责隔离、唯一写入路径及没有运行任何execution gate；
2. branch/HEAD、six surfaces、driver、manifest与本freeze exact hashes/type；
3. 六面current status、current-gate routing、三个Open Questions与零placeholder；
4. driver Bash syntax、四参数、clean environment、fail-fast与BEGIN-only scope；
5. manifest 140 records、format/LF/sort/unique/type、strict 140/140与path-set hash；
6. R19 123 paths加exact 17 additions，无删除、overlap或extra；
7. old R19 manifest exact six mismatch/117 unchanged及无环信任链；
8. R19四hash、invocation、651/652 rejection、11 artifact hashes、planned
   App/screenshot absence与two exact retained roots；
9. R19 root-glob exact-set NUL verifier、artifact type/hash与pre/post containment；
10. R20 current `5P/3S/7C=15`、total `5P/3S/8C=16`，且R19 historical 9/10未被
    误称为current；
11. 两个source baselines、private factory/single generic watchdog、public-init不变、
    DEBUG-only initializer与release symbol isolation；
12. `ManualAgentLoopClock`的lock/continuation/advance/cancel exactly-once合同；
13. 五个exact test names及逐项语义、controlled-provider/beat/barrier ordering；
14. single unfiltered RunTests、no filter/no retry与same-log 46-name extraction；
15. entry 140/140、future exact 138+2与third-mismatch fatal；
16. fresh 12 paths/roots、R15 tombstones、R16–R18 absence与R19 immutable retention；
17. Review02、acceptance、A3及全部产品/外部权限红线。

Review20只有达到`APPROVED — 0 P0 / 0 P1`才允许请求后续四-hash授权；Review20本身
绝不调用caller/driver/BEGIN或任何执行门，也不授权产品/test修改。

## 10. Current pre-Review20 facts

本freeze生成前后的只读核对为：

- Review20在本freeze生成前不存在；
- 12个R20 runtime paths全部absent，两类R20 fresh-root glob匹配数为0；
- R16、R17、R18各12个runtime paths及对应fresh roots仍absent；
- R15两个exact tombstone paths仍为`ABSENT`，disappearance cause仍为`UNKNOWN`；
- R19 11 artifacts逐byte匹配，两个exact roots为real non-symlink empty且glob集合精确为2；
- `AgentLoop`与`AgentLoopApp`均以`pgrep rc=1`确认absence；
- 两个future source/test baselines逐byte匹配，其他R19-manifest coverage只有六面漂移；
- branch/HEAD精确为header identities；
- 没有运行caller/driver/BEGIN、test、build、matrix、source、bundle/sign或preview；
- 没有修改产品/test/App scripts，没有创建Review02/acceptance或进入A3。

任一上游hash、path/type、capture、manifest、R19 containment、fresh absence或scope事实在
Review20前漂移，都使本candidate失效并阻止Review20 approval与后续四-hash授权。

## Open Questions

无。
