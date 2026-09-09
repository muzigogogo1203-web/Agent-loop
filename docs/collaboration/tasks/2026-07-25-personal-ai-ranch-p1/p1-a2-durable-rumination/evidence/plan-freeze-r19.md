# P1-A2 R19 Pathname-Exact Plan Freeze

> 状态：R19 Pathname-Exact Candidate Frozen；Review19 Pending；全部执行继续禁止
>
> 日期：2026-08-02
>
> 分支：`codex/personal-ai-ranch-p0`
>
> HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. 授权范围与停止线

Review18在immutable R18/R18-A chain上判定
`CHANGES REQUIRED — 0 P0 / 1 P1`。唯一P1-01指出RanchArt verifier先把macOS
合法pathname串行化为newline-delimited text，再按行比较；因此含LF的单一pathname
可以伪装成两个expected lines，表示不是injective，stable contaminated tree可能误过
exact-set gate。

Review18 immutable identities为：

| Artifact | SHA-256 / verdict |
|---|---|
| `evidence/plan-freeze-r18.md` | `62bbf93031371659e7ad2d4c60aac002eb13ed0915854f741e40251c9c2c1e76` |
| `reviews/18-p1-plan-review.md` | `e0ee95f3703d73810d756410373c1da65fb1e08b08f6d7f74555e8095a12608b`；`CHANGES REQUIRED — 0 P0 / 1 P1` |
| `evidence/r18-begin.sh` | `911bbbc70556e41122cfdcc90048e504eee3480246b338131153856d524d7af9` |
| `evidence/r18-entry.sha256` | `71e512a25e6e9bc0d024a53ad2502b55a378a82b39044a341930e1df440cfc2a`；119 entries |

R18从未执行；全部R18 runtime paths与fresh roots保持absent。牧场主在紧接完整R19
有界方案的用户turn中授权：

> 继续，授权

该授权只允许：

1. 用single `find -P ... -print0 | /bin/bash -c 'read -r -d "" ...'`
   NUL pipeline关闭上述pathname serialization根因；
2. 同步六个current canonical/control surfaces并新增fresh `r19-begin.sh`；
3. 生成R18 119项加四个immutable/new planning targets的123-entry static manifest；
4. 生成本freeze并执行职责隔离Review19。

本授权不允许运行external caller、`r19-begin.sh`/BEGIN、targeted/full test、build、
migration matrix、source gate、bundle assembly/sign或preview；不允许修改任何
产品/test/App script，不允许创建Review02/acceptance、进入A3、commit、push、merge、
release、normal-data、外部或真实用户操作。Review19通过本身也不执行；仍须等待后续
新的用户turn按`freeze, Review19, driver, manifest`顺序逐字提供四个terminal hashes
并另行授权。

## 2. Final planning identities

### 2.1 Six canonical/control surfaces

| Surface | Absolute path | SHA-256 |
|---|---|---|
| canonical Stage | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `e80b7758531a49e33ef22cb87aca33677885869fcd846eb9524b1e7ab62384c0` |
| canonical total Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `83e5ca281ab5d20e74fc934f7e4af55b5d75e762b6cb5c80fa7cd1d899cf830e` |
| A2 leaf Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `08eae4795500b96a2aeba9c57f66009a058c6e6e792bc09fbe53374fc087df53` |
| A2 blocked/control history | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/blocked.md` | `55259ea7cdbf7fc2d72f991cadcad0483262f01e165034b36a07ef6bd15067ce` |
| P1 Stage control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md` | `6ec8358c9a6ebdcdc0b664ae201af0b5c66bf078684f6863528ec25bc81d5faa` |
| P1 Plan control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md` | `e5182bf4d0fb70ab7c72301f1c4d7545de070c6191645a1a74796b1faa2b181f` |

六面current状态逐字同义且唯一current gate均指向R19/Review19：

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18/R18-A PLAN CHANGES REQUIRED — NOT EXECUTED；R19 Pathname-Exact Candidate Frozen；Review19 Pending；A2 Clean Re-verification Frozen`

canonical Stage §29、total Plan §19与A2 leaf §13的Open Questions均精确为`无。`；
全部临时freeze占位符数量为0。一次交叉审计发现五处historical prose
仍把current gate指向R18；它们已在同一routing根因内机械改指Stage §28.6 R19、
total Plan R19节与blocked §27 R19/Review19。只读closure audit为
`0 P0 / 0 P1 / 0 P2`。

### 2.2 Driver, immutable probe and static manifest

| Artifact | Absolute path | SHA-256 / invariant |
|---|---|---|
| reviewed BEGIN-only driver | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r19-begin.sh` | `95a29f4452502a236bd73ac42a9741bf31e66fa6108bcdf4572b5fcc1eef190d`；Bash 3.2 syntax PASS；bounded static threat audit `0 P0 / 0 P1 / 0 P2` |
| immutable Bash 3.2 micro-probe | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r17-bash32-probes.sh` | `5ee154b56d10322fd70ad34698a7f0fd81122862d25b9bbb05b1db18bee67199`；clean-environment PASS |
| static entry manifest | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r19-entry.sha256` | `71dede4ad9a86c52e853d36af8629a491e84854badfaf0962054f06e86fcfb43`；123 entries；strict 123/123 PASS |

immutable probe输出：

```text
PASS: Bash 3.2.57(1)-release S/P/C status capture; pgrep=1 diff=1 indeterminate=2 pipeline=(7 0) command_substitution=9 command_substitution_pipeline=7
```

只在memory/stdin执行的NUL full-drain与partial-final-record micro-probes均PASS；没有
创建新的probe artifact。driver的single verifier、two phase calls、single
`find -P ... -print0` pipeline、27个ASCII unique expected basenames与success evidence
字段均已静态核对。

## 3. Acyclic trust chain

唯一信任链为：

```text
immutable predecessors including the complete R18 chain
  + final six surfaces
  + immutable r17-bash32-probes.sh + reviewed r19-begin.sh
  → static r19-entry.sha256
  → plan-freeze-r19.md
  → reviews/19-p1-plan-review.md
  → later user authorization carrying four terminal hashes
```

- manifest不包含自身、本freeze、Review19或任何runtime R19 artifact；
- 本freeze记录upstream hashes，但不记录自身hash或尚未生成的Review19 hash；
- Review19只绑定本freeze及其predecessors，不记录自身hash；
- 完整`freeze + Review19 + driver + manifest`四元组只能来自Review19后的新用户turn；
- 不允许upstream自填、推导或回写self/downstream hash。

## 4. Lossless pathname transport closure

`r19-begin.sh`只保留一个phase-aware RanchArt verifier。pre-consumption与
post-activation都调用同一函数、同一27项expected set，并每次重新读取filesystem。
pathname transport精确为：

```text
/usr/bin/find -P RanchArt -mindepth 1 -maxdepth 1 -print0
  | /bin/bash -c 'while IFS= read -r -d "" path; do ...; done'
```

合同为：

1. raw pathname只作为NUL-delimited stdin record进入Bash 3.2 validator；不得先经过
   newline serialization、command substitution、line-oriented `sort`/`diff`或其他
   非injective text representation；
2. validator必须完整drain producer。正常EOF的`read` status精确为1；任何其他status、
   nonempty partial final record、producer nonzero或validator nonzero都fail closed；
3. 每个actual record先以exact directory prefix剥离basename，再用`LC_ALL=C`、
   `nocasematch`关闭后的byte equality与27个ASCII literals逐项比较；basename不得为空
   或包含`/`；
4. 27-slot seen vector保证expected每项恰好出现一次；total/regular/nonregular/symlink
   counters在28饱和，任何第28项或额外node都失败；
5. parent在validator开始和结束都必须是directory non-symlink；每个node必须满足
   `-f && ! -L`，最终精确为total 27、regular 27、nonregular 0、symlink 0；
6. pipeline进入`if` test context，并在then/else的第一条命令把完整`PIPESTATUS`复制到
   array；shape必须精确为2，find与validator两个numeric status都必须为0；
7. `find` stderr被抑制以防错误诊断泄漏raw adversarial pathname；失败reason只记录
   固定标签与两个numeric status，不输出raw actual pathname；
8. 只有全部验证成功后才输出固定safe evidence；exact-set block来自冻结的ASCII
   expected literals，不来自actual pathname。

success evidence精确包括：

- `pathname_transport=find_print0_bash_read_d_nul_v1`
- `ranch_art_find_rc=0`
- `ranch_art_validator_rc=0`
- `ranch_art_expected_count=27`
- `ranch_art_parent_type=directory_non_symlink`
- `ranch_art_node_type=regular_non_symlink`
- `ranch_art_actual_count=27`
- block-delimited fixed expected exact relative-path set
- `nonregular_count=0`
- `symlink_count=0`
- `regular_count=27`

pre-consumption sink固定为`/dev/stderr`，phase为`pre_consumption`；post-activation sink
固定为fresh R19 hash log，phase为`post_activation`。pre verifier仍是boundary前最后
一个fallible precondition；返回后下一条命令直接noclobber exclusive-create boundary。
canonical post顺序为：

```text
boundary authorization_consumed=true
  → exclusive-create hash log
  → post-activation same-verifier filesystem reread + structure evidence
  → four terminal anchors
  → 123-entry strict manifest + worktree evidence
  → remaining eight text logs
  → fresh R19 state root + fresh R19 bundle parent
  → BEGIN finalization
```

pre-consumption失败保持零repository/runtime write且authorization未消费；boundary成功
消费后的任何失败都把invocation永久标为`REJECTED_CONTAMINATED`并禁止same-boundary
retry。双读不声称atomic filesystem snapshot/lock/transaction，也不声称消除第二次
读取后的理论TOCTOU；任何扩张必须另开stage。

## 5. Bash 3.2 capture inventory

R19 current core capture合同精确为`3P / 3S / 3C = 9`：

| # | Block | Safe class |
|---:|---|---|
| 1 | pre-BEGIN terminal-anchor pipeline | P |
| 2 | pre-BEGIN static-manifest `shasum` | S |
| 3 | process-absence `pgrep` | S |
| 4 | empty-directory `find`，只服务fresh R19 roots | C |
| 5 | joint R15 exact-basename tombstone parent enumeration | C |
| 6 | fresh R19 root `realpath` | C |
| 7 | post-activation terminal-anchor pipeline | P |
| 8 | post-activation static-manifest `shasum` | S |
| 9 | RanchArt NUL pathname pipeline | P |

另有一个R16/R17/R18/R19 fresh-root glob absence C，因此driver total精确为
`3P / 3S / 4C = 10`。R19删除了R18五个line-oriented RanchArt capture职责并用一个
NUL pipeline P取代；没有新增probe artifact。immutable `r17-bash32-probes.sh`继续
证明Bash 3.2-safe S/P/C status capture。禁止`|| true`、silent fallback、status
inversion或bare `set +e` capture；唯一`set +e`只位于先解除ERR/signal traps的
active-failure负证据路径。

## 6. 123-entry static manifest

`r19-entry.sha256`格式为`<lowercase 64-hex><two spaces><absolute path>`，按absolute
path以`LC_ALL=C` bytewise sorted unique。所有123个targets均为regular non-symlink，
strict hash check为123/123 PASS。sorted pure-path set SHA-256为
`d43c82bcc59e5f86d794fa3cca070debf50baa4771170953030dff49f0baa097`。

| Class | Count |
|---|---:|
| six current surfaces | 6 |
| R16–R19 reviewed drivers plus immutable R17 Bash 3.2 probe | 5 |
| A1b review/acceptance entry anchors | 2 |
| A2 product/test frozen files | 15 |
| full-file sentinels/Package/runner/App/matrix scripts/RanchArtView | 14 |
| RanchArt exact regular files | 27 |
| R13 implementation/incident/Review01 evidence | 14 |
| original through R18 plan freezes | 14 |
| Review12 through Review18 plan reviews | 12 |
| R15 execution/failure artifacts | 11 |
| immutable R16/R17/R18 static entry manifests | 3 |
| **Total** | **123** |

path set精确等于R18的119项，加：

1. fresh reviewed `evidence/r19-begin.sh`；
2. immutable `evidence/r18-entry.sha256`；
3. immutable `evidence/plan-freeze-r18.md`；
4. immutable `reviews/18-p1-plan-review.md`。

manifest generation前后对R18 manifest的current audit都只有且恰有six-surface六个
mismatch；其余113/119 entries逐byte不变，type failures为0。R19 manifest排除自身、
本freeze、Review19与全部runtime R19 artifacts。

## 7. Immutable history and fresh R19 identities

R15 freeze/Review15/rejected boundary/logs/report及containment时两个root
canonical-empty观察继续immutable；两个current R15 exact roots继续为absorbing
`ABSENT` tombstones，disappearance cause仍为`UNKNOWN`。R16 freeze/Review16/driver/
manifest及其pre-BEGIN零写入、authorization未消费事实保持immutable。R17 freeze/
Review17/driver/probe/manifest与not-executed事实保持immutable。R18完整四哈希chain、
Review18 P1 verdict及not-executed事实保持immutable。R13 installed-App normal-root
incident、mutation unknown与Review01也继续保留。

R19使用12个fresh runtime paths：

- task root：`r19-targeted-tests.log`、`r19-verify.log`、`r19-build.log`、
  `r19-migration-matrix.log`、`impl-report-r19.md`；
- evidence root：`r19-clean-boundary.log`、`r19-bundle-provenance.log`、
  `r19-source-gates.log`、`r19-hash-manifest.log`、`r19-preview-bootstrap.log`、
  `r19-preview-cold-start.log`、`r19-preview-smoke.png`；
- fresh roots：`/private/tmp/agentloop-r19-state.XXXXXX`与
  `/private/tmp/agentloop-r19-bundle.XXXXXX`。

不得复用、覆盖、追加、补写或重命名R15–R18 artifacts，也不得复用任何旧root。

## 8. Review19 completion gate

未参与R19 six-surface/driver/manifest/freeze修订或生成的职责隔离reviewer唯一可写：

`/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/19-p1-plan-review.md`

Review19必须至少重新核对：

1. six surfaces、driver、probe、manifest与本freeze exact hashes；
2. manifest 123/123、strict format/sort/unique/type/exact path coverage与无环链；
3. Review18唯一P1的lossless NUL transport根因closure；single verifier、two calls、
   one producer-consumer pipeline，无line serialization或command substitution；
4. full drain、normal EOF status 1、partial-final-record rejection、actual-byte prefix/
   basename equality、27-slot seen、type/parent/count saturation与safe evidence；
5. core 9/driver-total 10 capture inventory、`PIPESTATUS` first-copy与immutable Bash 3.2
   probe/memory-only NUL probes；
6. pre-consumption final-precondition与post-activation verifier→anchors→manifest顺序；
7. R15 tombstones、R16 pre-BEGIN零写入、R17/R18 not-executed immutable history；
8. R18 old manifest six mismatch/113 unchanged、fresh R19 names、zero product/test/App
   script delta；
9. Open Questions精确为空、Review19 owner分离与全部禁止线。

Review19达到`APPROVED — 0 P0 / 0 P1`只允许请求后续新的用户turn提供四个terminal
hashes；Review19本身不调用external caller/driver/BEGIN或任何执行门。

## 9. Current pre-Review19 absence facts

本freeze生成前的只读核对为：

- `reviews/19-p1-plan-review.md`不存在；
- 全部12个runtime R19 paths不存在；
- `/private/tmp/agentloop-r19-state.*`与`/private/tmp/agentloop-r19-bundle.*`零匹配；
- 全部R16/R17/R18 36个runtime paths与六类fresh-root globs仍不存在；
- 两个exact R15 tombstone paths仍为`ABSENT`；
- AgentLoop/AgentLoopApp process absence均以`pgrep rc=1`确认；
- branch与HEAD精确为本freeze header identities；
- 没有运行caller/driver/BEGIN、test、build、matrix、source、bundle/sign或preview；
- 没有修改产品/test/App scripts，没有创建Review02/acceptance或进入A3。

任一上游hash、path/type、pathname transport、capture、absence或scope事实在Review19
前漂移，都使本candidate失效并阻止Review19 approval与后续四-hash授权。
