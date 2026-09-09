# P1-A2 R19 Pathname-Exact Plan Review

> Verdict：**APPROVED — 0 P0 / 0 P1**
>
> 日期：2026-08-02
>
> Review 对象：R19 final six surfaces、reviewed BEGIN-only driver、immutable Bash 3.2
> probe、123-entry static manifest 与 R19 freeze

## 1. Scope and independence

本 reviewer 未参与 R19 six-surface、`r19-begin.sh`、`r19-entry.sha256` 或
`plan-freeze-r19.md` 的修订或生成。本次从当前 filesystem 独立读取并审查真实 bytes；
唯一写入是本 Review19 文件。本 Review 不记录或预填自身 SHA-256。

本次没有运行 external caller、`r19-begin.sh`/BEGIN、targeted/full test、build、
migration matrix、source gate、bundle assembly/sign 或 preview；没有创建 runtime
artifact、state root 或 bundle parent；没有修改产品、测试、App/matrix script、六面、
driver、manifest、freeze、R15–R18 evidence、Review02、acceptance 或 A3。

只读/静态动作限于 hash、path/type/status、文本审计、`/bin/bash -n`、已冻结的
`r17-bash32-probes.sh`，以及只使用 memory/stdin、零文件写入的 Bash 3.2 NUL
micro-probes。审查快照为 branch `codex/personal-ai-ranch-p0`、HEAD
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`。已有 large dirty/untracked candidate
tree 被视为用户工作并保持不动。

## 2. Exact identities reviewed

### 2.1 R19 terminal candidate and six surfaces

| Artifact | Absolute path | Current SHA-256 | Result |
|---|---|---|---|
| canonical Stage | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `e80b7758531a49e33ef22cb87aca33677885869fcd846eb9524b1e7ab62384c0` | exact, regular non-symlink |
| canonical total Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `83e5ca281ab5d20e74fc934f7e4af55b5d75e762b6cb5c80fa7cd1d899cf830e` | exact, regular non-symlink |
| A2 leaf Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `08eae4795500b96a2aeba9c57f66009a058c6e6e792bc09fbe53374fc087df53` | exact, regular non-symlink |
| A2 blocked/control history | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/blocked.md` | `55259ea7cdbf7fc2d72f991cadcad0483262f01e165034b36a07ef6bd15067ce` | exact, regular non-symlink |
| P1 Stage control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md` | `6ec8358c9a6ebdcdc0b664ae201af0b5c66bf078684f6863528ec25bc81d5faa` | exact, regular non-symlink |
| P1 Plan control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md` | `e5182bf4d0fb70ab7c72301f1c4d7545de070c6191645a1a74796b1faa2b181f` | exact, regular non-symlink |
| R19 driver | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r19-begin.sh` | `95a29f4452502a236bd73ac42a9741bf31e66fa6108bcdf4572b5fcc1eef190d` | exact, regular non-symlink; Bash syntax PASS |
| immutable Bash 3.2 probe | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r17-bash32-probes.sh` | `5ee154b56d10322fd70ad34698a7f0fd81122862d25b9bbb05b1db18bee67199` | exact, regular non-symlink |
| R19 static manifest | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r19-entry.sha256` | `71dede4ad9a86c52e853d36af8629a491e84854badfaf0962054f06e86fcfb43` | exact, regular non-symlink |
| R19 freeze | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/plan-freeze-r19.md` | `d7869b0531f5dc868a1e8d92b2aec9f0abf3cd84e0d3857b481f8fcc3807d03f` | exact, regular non-symlink |

六面顶端 current status 去除 Markdown emphasis 后逐 byte 一致：

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18/R18-A PLAN CHANGES REQUIRED — NOT EXECUTED；R19 Pathname-Exact Candidate Frozen；Review19 Pending；A2 Clean Re-verification Frozen`

canonical Stage §29、total Plan §19 与 A2 leaf §13 的 `Open Questions` 均精确为
`无。`。R19/R18 temporary-final-freeze placeholder 数量为 0；所有 current-gate/
next-action prose 都指向 Stage §28.6、R19/Review19 与本职责隔离 writer，旧 R18
future-tense 文字均被明确限定为 historical predecessor。

### 2.2 Immutable predecessor identities

独立重算的 R15–R18 关键 identities 为：

| Round | Artifact | Current SHA-256 / state |
|---|---|---|
| R15 | `evidence/plan-freeze-r15.md` | `e5ad3967f2e2b26a2bbf8b2ef7be405e8430cc30a82d51a7cb5f51926a99e3d7` |
| R15 | `reviews/15-p1-plan-review.md` | `fbaa9612588c39cb5d99e95d9b68e00a234510e325abf5823c15f0b1eb8ecc05`; `APPROVED — 0 P0 / 0 P1` |
| R15 | `evidence/r15-clean-boundary.log` | `53eb91b840c5c8997fbc9da02d391f210f27b45d73b5e2431a6280a36110ab3b`; permanent `REJECTED_CONTAMINATED` |
| R15 | `evidence/r15-hash-manifest.log` | `1589d8d29cf3f8ca9e558c4ac6d4008bdd591194c7e975ecf2fd045e6a935399` |
| R15 | `impl-report-r15.md` | `e6b0226b3440da997f7e08571d8e5e5229d66069ea5ad6485ee146c249dbe72e` |
| R16 | freeze / Review / driver / manifest | `c10ae51ad78b414aab18c3785b79aac49feb73c47ac5fdcb896ca874ae319867` / `71f16eceef429f7d02fe8908c4609b9bd0b0b98b44c68b579a75ced2ac9d9824` / `ffa61fa7c8c281cdb8dfb853b38aafce9536ddcc276e18d64c082de8887b55b0` / `0c2f5dc59e5f0e193214d1c8532a91818a339abdfb3150177c680fe61f8a0b1e` |
| R17 | freeze / Review / driver / manifest | `bdbbbd025bbe7cf57032ae2276a6a559043f60e47cebad1ceac43f992e644e1f` / `c6838d3c5a9fcfef80dc9db4abf560af712e3175372a163edccb72197daf3dbe` / `cf1baab60b3e799b1780b20d1dfc7887bdd2c7e85e241fdb8abcd4ad8c04321f` / `7d10c5c6747cdf0e557befc76a62ea101f2fc4168a49d8076bedd3331d8cbd17` |
| R18 | freeze / Review / driver / manifest | `62bbf93031371659e7ad2d4c60aac002eb13ed0915854f741e40251c9c2c1e76` / `e0ee95f3703d73810d756410373c1da65fb1e08b08f6d7f74555e8095a12608b` / `911bbbc70556e41122cfdcc90048e504eee3480246b338131153856d524d7af9` / `71e512a25e6e9bc0d024a53ad2502b55a378a82b39044a341930e1df440cfc2a` |

Review17 与 Review18 的 verdict 均为 `CHANGES REQUIRED — 0 P0 / 1 P1`；两轮都未
获得 execution authority。Review18 的唯一 P1-01 确为 newline-delimited pathname
serialization 非单射；本 Review 不借用其 closure 结论，而在 §4 独立审查 R19 source。

## 3. Static manifest and acyclic trust chain

对 `r19-entry.sha256` 的独立静态检查结果：

1. 123 行；每行精确满足 `<64 lowercase hex><two spaces><absolute path>`，无 control
   byte、非 canonical segment 或 repository 外路径；
2. pure path stream 按 `LC_ALL=C` bytewise sorted unique，full-line/path duplicate 均为
   0；123 个 targets 全部 regular non-symlink；
3. `shasum -a 256 --strict -c` 为 123/123 PASS；sorted pure-path set SHA-256 为
   `d43c82bcc59e5f86d794fa3cca070debf50baa4771170953030dff49f0baa097`；
4. 27 个 RanchArt manifest basenames 与 driver 唯一 expected array 的 27 个 ASCII
   literals 数量、唯一性、bytes 和固定顺序完全一致；
5. path coverage 的 11 类计数精确为
   `6 + 5 + 2 + 15 + 14 + 27 + 14 + 14 + 12 + 11 + 3 = 123`，与 freeze §6
   一致。

R19 path set 相对 immutable R18 119-path set无删除，唯一增加：

1. `evidence/r19-begin.sh`；
2. `evidence/r18-entry.sha256`；
3. `evidence/plan-freeze-r18.md`；
4. `reviews/18-p1-plan-review.md`。

对旧 R18 manifest 的 current strict check 独立得到 113 OK / 6 FAILED；六个 FAILED
精确为 six surfaces。按 path 比较两个 manifests 的 119 个 common entries同样得到
113 identical hashes / 6 current-surface hashes changed。由此 designated product/test/
App/matrix scripts、RanchArt bytes、R15–R18 history 与其余 sentinels均零 delta。

manifest 排除自身、R19 freeze、Review19、12 个 runtime R19 artifacts 与 R19 fresh
roots；freeze 记录 driver/manifest 等 upstream hashes，但不记录 freeze 自身或未来
Review19 hash；本 Review 不记录自身 hash。driver 只从未来 caller 的四个 positional
anchors取得 `freeze, Review19, driver, manifest`，不回写 upstream。因此文件级信任链
保持无环：

```text
immutable predecessors including complete R18 chain
  + final six surfaces + immutable probe + reviewed r19-begin.sh
  → static r19-entry.sha256
  → plan-freeze-r19.md
  → reviews/19-p1-plan-review.md
  → later user authorization carrying four terminal hashes
```

## 4. Review18 P1-01 closure: lossless pathname verifier

### 4.1 Single transport and full drain

`r19-begin.sh` source 中只有一个 `r19_check_ranch_art_structure` definition、两次固定
phase call、一个 `-print0` producer、一个 inline `/bin/bash -c` consumer，以及一份
27-item expected array。pre/post 每次调用都重新执行：

```text
/usr/bin/find -P <fixed RanchArt directory> -mindepth 1 -maxdepth 1 -print0
  | /bin/bash -c '<Bash 3.2 NUL validator>'
```

NUL stream没有经过 command substitution、newline split、`sed`、`sort`、`diff`、
`wc -l` 或 raw text log。producer 不带 `-type`，所以全部 direct children 都进入同一
universe。

consumer 的 `while :` 不在发现 bad node 时 break；它只累计 `r19_invalid` 并继续读取，
直到 `IFS= read -r -d ""` 失败。每次 read 前清空 `r19_path`；终止 read 的实际 status
被立即保存，必须精确等于正常 EOF `1`。EOF 留下 nonempty value 时设置
`r19_partial_final_record=1` 并失败。find 的 nonzero status则由外层
`PIPESTATUS[0]` 独立保留，因而 producer failure不能被正常 consumer EOF掩盖。

在 macOS `/bin/bash` 3.2.57 的 memory/stdin probe 中独立确认：

- normal NUL stream完整 drain后 `read_rc=1`、partial=0；
- validator 已标记 invalid 后仍读到最终 record；
- producer末尾返回7时 first-copy pipeline status精确为 `(7 0)`；
- `one\0partial` 得到 normal read EOF status 1、nonempty partial，并由validator拒绝；
- 30-record stream被完整 drain，安全计数饱和为28且invalid；
- 含 LF 的一个 basename保留为一个 Bash value，不会拆成两个 expected names。

### 4.2 Actual-byte equality, type and exact cardinality

validator 在 `LC_ALL=C` 且显式 `shopt -u nocasematch` 下：

1. 开始与完整 drain 后都检查 parent 为 directory non-symlink；
2. 把 fixed directory prefix作为 quoted literal pattern前缀核对，再用 quoted parameter
   expansion剥离它；actual basename必须 nonempty 且不含 `/`；
3. 将该 actual basename直接与27个 quoted ASCII expected literals比较，不通过
   expected-path lookup重建 actual spelling；
4. 每个 record 必须 `-f && ! -L`；nonregular 与 symlink分别饱和计数；
5. 27-slot `seen[]` 对 duplicate fail closed；total/regular/nonregular/symlink counters
   在28饱和，最终必须精确为 `27/27/0/0`，且27个 slots各为1。

因此 stable tree 中的 LF/CR/control pathname、case variant、Unicode confusable、dotfile、
extra/missing/duplicate entry、symlink/dangling symlink、directory/FIFO/socket/device都会
在授权消费前返回 validator nonzero；Review18 的“一个 LF basename伪装成两行”路径已
被关闭。hardlink/inode/xattr/resource-fork 与 observation 后 TOCTOU 未被虚构为已解决，
仍保持 freeze 明示的 stage boundary。

### 4.3 Pipeline status and safe evidence

RanchArt pipeline位于 `if` test context；then/else 的第一条命令都把完整
`PIPESTATUS`复制到 array。随后先要求 shape精确为2，再要求 find/validator两个 numeric
status都为0。find stderr固定丢弃；validator不打印 actual path；失败 reason只含固定
label和两个 numeric status。

只有上述 exact/type/count/status 全部成功后，parent才输出 fixed safe evidence：
transport id、两个 zero statuses、expected/actual count 27、parent/node type、固定
expected ASCII exact-set block与 `regular=27/nonregular=0/symlink=0`。没有 raw actual
pathname进入 success 或 failure evidence。

## 5. Bash 3.2 capture inventory and activation order

R19 current core capture inventory静态分类精确为 `3P / 3S / 3C = 9`：

- P：pre terminal anchors、post terminal anchors、single RanchArt NUL pipeline；
- S：static-manifest `shasum`、process `pgrep`、post static-manifest `shasum`；
- C：fresh-root empty-directory probe、joint R15 tombstone enumeration、fresh-root
  `realpath`。

再计 R16/R17/R18/R19 fresh-root glob absence C，driver total精确为
`3P / 3S / 4C = 10`。旧 R18 RanchArt 的 `1S + 4C` 五个 line-oriented blocks已整体
删除。三个 P blocks都在 then/else 第一条命令复制 `PIPESTATUS`；S 在 conditional
捕获；C subshell先解除 inherited ERR trap。driver 中没有 `|| true`，唯一 `set +e`
位于先解除 ERR/HUP/INT/TERM traps 的 active-failure负证据路径。

immutable probe在 clean macOS Bash 3.2 环境实际返回0：

```text
PASS: Bash 3.2.57(1)-release S/P/C status capture; pgrep=1 diff=1 indeterminate=2 pipeline=(7 0) command_substitution=9 command_substitution_pipeline=7
```

source order独立核对为：

```text
all fallible preconditions + invocation metadata
  → pre-consumption same verifier (last fallible precondition)
  → noclobber exclusive-create boundary + authorization_consumed=true
  → exclusive-create hash log
  → post-activation same verifier filesystem reread + structure evidence
  → four terminal anchors
  → 123-entry shape/strict manifest + worktree evidence
  → remaining eight text logs
  → fresh state root + fresh bundle parent
  → BEGIN finalization
```

pre verifier返回与boundary attempt之间没有 UUID/date/substitution或其他 gate。post
hash-log create与verifier之间只有phase assignment；post verifier之后才是anchors与
manifest。pre失败保持零repository/runtime write和authorization未消费；boundary成功后
任一失败进入 permanent `REJECTED_CONTAMINATED`、`retry_same_boundary=false`。

## 6. History, current absences and red lines

只读 current-state核对结果：

1. R15 boundary仍记录 `authorization_consumed=true`、
   `status=REJECTED_CONTAMINATED`、containment时两个roots empty/App absent与
   `retry_same_boundary=false`；八个 reserved gate logs仍为regular non-symlink
   zero-byte files，screenshot/planned App absent；
2. `/private/tmp` 是 directory non-symlink；两个 exact R15 roots当前都为 `ABSENT`，
   disappearance cause仍只允许 `UNKNOWN`，没有伪造连续保全；
3. R16、R17、R18、R19各12个 runtime paths共48项全部 absent；
4. `agentloop-r16/r17/r18/r19-{state,bundle}.*` 八类fresh-root glob匹配数为0；
5. R16的pre-BEGIN zero-write/authorization-unconsumed事实、R17与R18 not-executed事实
   与相应 immutable freeze/Review/driver/manifest chain一致；
6. Review19在本 Review创建前 absent；Review02、A2 acceptance均 absent，P1 task root
   没有 A3 slice；
7. `pgrep -x AgentLoop`与`pgrep -x AgentLoopApp`均为预期 absence `rc=1`；
8. branch/HEAD、fresh R19 names、owner separation、Open Questions和禁止线均与freeze
   一致。

本 Review没有打开或执行 caller/BEGIN/test/build/matrix/source/bundle/sign/preview，
没有授权产品/test/App-script修改、Review02、acceptance、A3、commit、push、merge、
release、normal-data、付款、公开沟通、外部或真实用户操作。

## 7. Findings

### P0

无。

### P1

无。

### P2

无。

## 8. Verdict and authorization boundary

**APPROVED — 0 P0 / 0 P1**

R19 exact identities、six-surface current gate、123/123 manifest、R18 only-six/113
preservation、Review18 pathname-serialization root-cause closure、Bash 3.2 full-drain/
EOF/partial-record/status semantics、actual-byte exactness、type/count saturation、safe
evidence、9/10 capture inventory、pre/post ordering、R15–R18 history、fresh absences、
Open Questions、red lines与无环链均通过独立审查。

本批准只允许请求后续新的用户 turn 按
`freeze, Review19, driver, manifest` 顺序逐字提供四个 terminal SHA-256并明确授权。
它绝不调用或打开 external caller、driver/BEGIN 或任何执行门，也不自行构成 execution
authority。取得该后续四-hash授权前，R19 runtime paths与fresh roots必须继续 absent。

## Open Questions

无。
