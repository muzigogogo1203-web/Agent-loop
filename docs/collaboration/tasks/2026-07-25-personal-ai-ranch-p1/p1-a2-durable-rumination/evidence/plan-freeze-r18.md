# P1-A2 R18/R18-A RanchArt + Tombstone Plan Freeze

> 状态：R18-A Tombstone Candidate Frozen；Review18 Pending；全部执行继续禁止
>
> 日期：2026-08-02
>
> 分支：`codex/personal-ai-ranch-p0`
>
> HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. 授权范围与停止线

牧场主先授权R18关闭Review17 P1-01：同一phase-aware RanchArt verifier必须在
授权消费前执行zero-write exact-27/zero-nonregular preflight，并在消费后从
filesystem重新读取、写结构证据。preflight是boundary前最后一个fallible
precondition；post verifier后才独立重跑119-entry content manifest。

在本freeze生成前，两个R15 exact volatile roots从R15 containment时的historical
canonical-empty观察漂移为current `ABSENT`。牧场主随后明确授权R18-A按
`blocked.md` §24：

- 保留R15 historical evidence，不伪造连续保全；
- 把两个current `ABSENT` identities冻结为absorbing tombstones；
- 使用成功的exact `/private/tmp` parent enumeration证明两个basenames都不存在；
- 任何node重现或indeterminate都fail closed；
- 一对一替换preserved-root `realpath` C，保持capture计数与immutable R17 probe；
- 只同步current six surfaces与`r18-begin.sh`，生成同一路径集的119-entry manifest、
  本freeze和职责隔离Review18。

本授权不允许运行R18 external caller、driver/BEGIN、targeted/full test、build、
migration matrix、source gate、bundle assembly/sign或preview，不允许修改任何
产品/test/App script，不允许创建Review02/acceptance、进入A3、commit、push、merge、
release、normal-data、外部或真实用户操作。Review18通过本身也不执行；仍须等待后续
新的用户turn按`freeze, Review18, driver, manifest`顺序逐字给出四个terminal hashes
并另行授权。

## 2. Final planning identities

### 2.1 Six canonical/control surfaces

| Surface | Absolute path | SHA-256 |
|---|---|---|
| canonical Stage | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `aaaf94f0e487c56bf584149ea26b451ba2dd45766e704c71a4e3991a895b5faa` |
| canonical total Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `ebb31600488d35a56bbbb7e0217e823c4b3eb8a1e1a358947fd2f9939aa4d79b` |
| A2 leaf Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `ecf7c99e8c9e87a7d808fe18722851bdbbf68e04c8e4e379098e72b8c69b0f44` |
| A2 blocked/control history | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/blocked.md` | `74ac2288e9ddad6f63108804cd8594fe421f5478893284a142ab98afb00cb235` |
| P1 Stage control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md` | `ba7e278a485c460c3ca1418ce51ea499f1e3f3267e8e35c1b41731ebc4259c47` |
| P1 Plan control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md` | `8fcd18b630dce4a7ded43435038d407d06e34ee93bb9269477d78a99bcfc3a9d` |

六面current状态逐字一致：

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18-A Tombstone Candidate Frozen；Review18 Pending；A2 Clean Re-verification Frozen`

canonical Stage §29、total Plan §19与A2 leaf §13的Open Questions均精确为`无。`；
全部`PENDING_R18_FINAL_FREEZE` marker已经替换，数量为0。

### 2.2 Driver, immutable probe and static manifest

| Artifact | Absolute path | SHA-256 / invariant |
|---|---|---|
| reviewed BEGIN-only driver | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r18-begin.sh` | `911bbbc70556e41122cfdcc90048e504eee3480246b338131153856d524d7af9`；Bash 3.2 syntax PASS；independent static audit `PASS — 0 P0 / 0 P1 / 0 P2` |
| immutable Bash 3.2 micro-probe | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r17-bash32-probes.sh` | `5ee154b56d10322fd70ad34698a7f0fd81122862d25b9bbb05b1db18bee67199`；clean-environment PASS |
| static entry manifest | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r18-entry.sha256` | `71e512a25e6e9bc0d024a53ad2502b55a378a82b39044a341930e1df440cfc2a`；119 entries；`shasum --strict -c` 119/119 PASS |

immutable probe输出：

```text
PASS: Bash 3.2.57(1)-release S/P/C status capture; pgrep=1 diff=1 indeterminate=2 pipeline=(7 0) command_substitution=9 command_substitution_pipeline=7
```

## 3. Acyclic trust chain

唯一信任链为：

```text
immutable predecessors + final six surfaces
  + immutable r17-bash32-probes.sh + reviewed r18-begin.sh
  + immutable r17-entry.sha256 + R17 freeze + Review17
  → static r18-entry.sha256
  → plan-freeze-r18.md
  → reviews/18-p1-plan-review.md
  → later user authorization carrying four terminal hashes
```

- manifest不包含自身、本freeze、Review18或任何runtime R18 artifact；
- 本freeze记录upstream hashes，但不记录自身hash或尚未生成的Review18 hash；
- Review18只绑定本freeze及其predecessors，不记录自身hash；
- 完整`freeze + Review18 + driver + manifest`四元组只能来自Review18后的新用户turn；
- 不允许upstream自填、推导或回写self/downstream hash。

## 4. Immutable R17 rejection and earlier history

R17 chain精确保持：

| Artifact / invariant | SHA-256 / state |
|---|---|
| `evidence/r17-begin.sh` | `cf1baab60b3e799b1780b20d1dfc7887bdd2c7e85e241fdb8abcd4ad8c04321f` |
| `evidence/r17-bash32-probes.sh` | `5ee154b56d10322fd70ad34698a7f0fd81122862d25b9bbb05b1db18bee67199` |
| `evidence/r17-entry.sha256` | `7d10c5c6747cdf0e557befc76a62ea101f2fc4168a49d8076bedd3331d8cbd17`；115 entries |
| `evidence/plan-freeze-r17.md` | `bdbbbd025bbe7cf57032ae2276a6a559043f60e47cebad1ceac43f992e644e1f` |
| `reviews/17-p1-plan-review.md` | `c6838d3c5a9fcfef80dc9db4abf560af712e3175372a163edccb72197daf3dbe`；`CHANGES REQUIRED — 0 P0 / 1 P1` |
| 12 R17 runtime paths | all absent |
| `/private/tmp/agentloop-r17-state.*` | absent |
| `/private/tmp/agentloop-r17-bundle.*` | absent |
| execution | caller/BEGIN and all later gates never ran |

Review17 P1-01只指出RanchArt exact-27/nonregular结构门位于授权消费后；Review17没有
plan approval或执行权。R18以single phase-aware verifier关闭该P1，但不修改上述
R17 bytes或倒写R17历史。

R16 freeze/Review16/driver/manifest及其pre-BEGIN零写入、授权未消费事实继续
immutable；R15 freeze/Review15/rejected boundary/logs/report及containment时两个root
canonical-empty观察继续immutable。R13 installed-App normal-root incident、mutation
unknown与Review01也继续immutable。119-entry manifest逐文件绑定这些durable facts。

## 5. R15 historical observation and current tombstones

R15 durable evidence identities：

| Artifact / invariant | SHA-256 / state |
|---|---|
| `evidence/plan-freeze-r15.md` | `e5ad3967f2e2b26a2bbf8b2ef7be405e8430cc30a82d51a7cb5f51926a99e3d7` |
| `reviews/15-p1-plan-review.md` | `fbaa9612588c39cb5d99e95d9b68e00a234510e325abf5823c15f0b1eb8ecc05` |
| `evidence/r15-clean-boundary.log` | `53eb91b840c5c8997fbc9da02d391f210f27b45d73b5e2431a6280a36110ab3b`；permanent `REJECTED_CONTAMINATED` |
| `evidence/r15-hash-manifest.log` | `1589d8d29cf3f8ca9e558c4ac6d4008bdd591194c7e975ecf2fd045e6a935399` |
| `impl-report-r15.md` | `e6b0226b3440da997f7e08571d8e5e5229d66069ea5ad6485ee146c249dbe72e` |
| eight reserved gate logs | each zero bytes |
| `evidence/r15-preview-smoke.png` | absent |
| R15 containment observation | both exact roots were canonical non-symlink empty directories |
| current state root | `/private/tmp/agentloop-r15-state.Zq6Jvm` is `ABSENT` |
| current bundle parent | `/private/tmp/agentloop-r15-bundle.2xROcy` is `ABSENT` |
| disappearance cause | `UNKNOWN` |
| planned R15 App | absent |

当前absence不修改historical observation。禁止归因于reboot、OS cleanup、用户或
agent，也禁止写`continuously preserved`。`CANONICAL_EMPTY → ABSENT`只描述已观察的
历史单向lifecycle；本freeze后`ABSENT`是absorbing state，任何exact identity重现都
fail closed，即使重现为canonical empty directory。

driver必须：

1. 验证两个basenames非空、非`.`/`..`、互不相同并匹配冻结literal；
2. 验证absolute paths精确由regular non-symlink `/private/tmp` parent重建；
3. 以单个Bash 3.2-safe command-substitution capture执行不带`-type`过滤的
   parent enumeration；
4. enumeration nonzero、任何输出、parent异常或final `-e || -L`重检发现任一node
   都在pre-consumption零写入、授权未消费状态停止；
5. 不创建物理tombstone，不访问、创建、删除、清理或复用旧root。

boundary初始化精确记录：

- `r15_state_root_pre_begin_observed_state=ABSENT`
- `r15_bundle_parent_pre_begin_observed_state=ABSENT`
- `r15_state_root_current_absent=true`
- `r15_bundle_parent_current_absent=true`
- `r15_absence_proof_identity=private_tmp_parent_enumeration_exact_basename_v1`
- `disappearance_cause=UNKNOWN`

不得记录`preserved_empty`或`continuously_preserved`。

## 6. RanchArt verifier and activation order

`r18-begin.sh`只有一个phase-aware RanchArt verifier与一个immutable exact 27-path
expected set。pre-consumption与post-activation两次调用都从filesystem重新读取：

- expected 27 paths均为regular non-symlink files；
- actual regular-file relative-path set与expected bytewise exact；
- nonregular/symlink/special/directory node count为0；
- regular-file count精确27；
- 任一find/transform/diff/count unexpected或indeterminate status都fail closed。

pre-consumption sink固定为`/dev/stderr`，成功输出：

- `phase=pre_consumption`
- block-delimited actual exact relative-path set
- `nonregular_count=0`
- `regular_count=27`

post-activation使用同一函数、同一字段写入全新的R18 hash log，其中phase为
`post_activation`。exact path block只在真实`diff=0`后写入；`regular_count=27`只在
真实count验证通过后写入。verifier不计算或冒充content hash；随后独立119-entry
strict manifest逐文件重校包括27个RanchArt files在内的bytes。

pre-BEGIN先完成metadata生成与format validation，再调用RanchArt verifier；该调用是
boundary前最后一个fallible precondition。调用返回后下一条命令直接尝试noclobber
exclusive-create boundary，不存在uuid/date/substitution或其他gate。canonical post
顺序精确为：

```text
boundary authorization_consumed=true
  → exclusive-create hash log
  → post-activation same-verifier filesystem reread + structure evidence
  → four terminal anchors
  → 119-entry strict manifest + worktree evidence
  → remaining eight text logs
  → fresh state root + fresh bundle parent
  → BEGIN finalization
```

pre-consumption失败保持零repository/runtime write与
`authorization_consumed=false`；只有boundary成功消费后的失败才把该invocation永久
标为`REJECTED_CONTAMINATED`并禁止同boundary retry。

双读不声称atomic filesystem snapshot/lock/transaction，也不声称消除final lstat或
第二次RanchArt读取后的理论TOCTOU；任何扩张必须另开stage。

## 7. Bash 3.2 capture contract

R18 inherited capture合同仍精确为`2P / 4S / 7C = 13`：

| # | Block | Safe class |
|---:|---|---|
| 1 | pre-BEGIN terminal-anchor pipeline | P |
| 2 | pre-BEGIN static-manifest `shasum` | S |
| 3 | process-absence `pgrep` | S |
| 4 | empty-directory `find`，只服务fresh R18 roots | C |
| 5 | joint R15 exact-basename tombstone parent enumeration | C |
| 6 | fresh R18 root `realpath` | C |
| 7 | post-activation terminal-anchor pipeline | P |
| 8 | post-activation static-manifest `shasum` | S |
| 9 | RanchArt regular-file `find` | C |
| 10 | RanchArt path-transform pipeline substitution | C |
| 11 | RanchArt exact path-set `diff` | S |
| 12 | RanchArt nonregular-node `find` | C |
| 13 | RanchArt regular-file count pipeline substitution | C |

第5项是一对一替换R17 preserved-root `realpath` C；其他12项职责不变。另有一个
R16/R17/R18 root-glob absence C，因此driver total精确为
`2P / 4S / 8C = 14`。不得新增probe；immutable `r17-bash32-probes.sh`继续证明
Bash 3.2-safe S/P/C status capture。禁止`|| true`、silent fallback、status inversion
或bare `set +e` capture；唯一`set +e`只可位于先解除ERR/signal traps的active-failure
负证据路径。

## 8. 119-entry static manifest

`r18-entry.sha256`使用`<lowercase 64-hex><two spaces><absolute path>`，按absolute path
`LC_ALL=C` bytewise sorted unique。119项覆盖：

| Class | Count |
|---|---:|
| six current surfaces | 6 |
| R16/R17/R18 reviewed drivers plus R17 Bash 3.2 probe | 4 |
| A1b review/acceptance entry anchors | 2 |
| A2 product/test frozen files | 15 |
| full-file sentinels/Package/runner/App/matrix scripts/RanchArtView | 14 |
| RanchArt exact regular files | 27 |
| R13 implementation/incident/Review01 evidence | 14 |
| original through R17 plan freezes | 13 |
| Review12 through Review17 plan reviews | 11 |
| R15 execution/failure artifacts | 11 |
| immutable R16 and R17 static entry manifests | 2 |
| **Total** | **119** |

path set精确等于R17的115项，加：

1. reviewed `evidence/r18-begin.sh`；
2. immutable `evidence/r17-entry.sha256`；
3. immutable `evidence/plan-freeze-r17.md`；
4. immutable `reviews/17-p1-plan-review.md`。

manifest generation前对R17 manifest的current strict check只有且恰有six-surface六个
mismatch；其余109/115 entries逐byte未漂移。新增manifest全部119 targets都是regular
non-symlink files，path count/unique count均119，format/sort验证通过，119/119 strict
hash check通过。它不包含自身、本freeze、Review18或runtime R18 artifacts。

## 9. Review18 completion gate

未参与six-surface/driver/manifest/freeze修订或生成的职责隔离reviewer唯一可写：

`/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/18-p1-plan-review.md`

Review18必须至少重新核对：

1. six surfaces、driver、probe、manifest与本freeze exact hashes；
2. manifest 119/119、strict format/sort/unique/type/path coverage与无环链；
3. R15 historical-empty/current-ABSENT分层、absorbing tombstone、parent enumeration、
   exact evidence fields、任何node重现/indeterminate fail closed及零连续保全表述；
4. inherited 13/driver-total 14 capture inventory与immutable Bash 3.2 probe；
5. single RanchArt verifier、unique expected set、pre-consumption final-precondition、
   post-activation exact structure serialization与独立119-entry byte recheck；
6. boundary→hash log→post verifier→anchors→manifest→remaining logs→roots顺序；
7. pre-consumption zero-write/unconsumed与post-consumption permanent rejection分层；
8. R15/R16/R17 immutable history、fresh R18 names、zero product/test/App-script delta；
9. Open Questions精确为空、Review18 owner分离与全部禁止线。

Review18达到`APPROVED — 0 P0 / 0 P1`只允许请求后续新的用户turn提供四个terminal
hashes；Review18本身不调用external caller/driver/BEGIN或任何执行门。

## 10. Current pre-Review18 absence facts

本freeze生成时：

- `reviews/18-p1-plan-review.md`不存在；
- 全部12个runtime R18 paths不存在；
- `/private/tmp/agentloop-r18-state.*`与`/private/tmp/agentloop-r18-bundle.*`零匹配；
- 全部R16/R17 runtime paths与fresh-root globs仍不存在；
- 两个exact R15 tombstone paths仍为`ABSENT`；
- AgentLoop/AgentLoopApp process absence保持为预期状态；
- 没有运行caller/driver/BEGIN、test、build、matrix、source、bundle/sign或preview；
- 没有修改产品/test/App scripts，没有创建Review02/acceptance或进入A3。

任一上游hash、path/type、tombstone、structure、capture、absence或scope事实在Review18
前漂移，都使本candidate失效并阻止Review18 approval与后续四-hash授权。
