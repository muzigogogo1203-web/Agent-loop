# P1-A2 R18/R18-A RanchArt + Tombstone Plan Review

> Verdict：**CHANGES REQUIRED — 0 P0 / 1 P1**
>
> 日期：2026-08-02
>
> Review 对象：R18/R18-A final six surfaces、reviewed BEGIN-only driver、
> immutable Bash 3.2 probe、119-entry static manifest 与 R18 freeze

## 1. Scope and independence

本 reviewer 未参与 R18/R18-A 六个 canonical/control surfaces、
`r18-begin.sh`、`r18-entry.sha256` 或 `plan-freeze-r18.md` 的修订或生成，也未参与
R15–R17 predecessor 的规划、执行或证据生成。本次从当前 filesystem 独立读取并
审查真实 bytes；唯一写入是本 Review18 文件。本 Review 不记录或预填自身 SHA-256。

本次没有运行 R18 external caller、`r18-begin.sh`/BEGIN、targeted/full test、build、
migration matrix、source gate、bundle assembly/sign 或 preview；没有创建 runtime
artifact、state root 或 bundle parent；没有修改产品、测试、App/matrix script、六面、
driver、manifest、freeze、R15–R17 evidence、Review02、acceptance 或 A3。

审查快照为 branch `codex/personal-ai-ranch-p0`、HEAD
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`。已有 large dirty/untracked candidate
tree 被视为用户工作并保持不动。

## 2. Exact identities reviewed

### 2.1 R18 final planning identities

| Artifact | Absolute path | Current SHA-256 | Result |
|---|---|---|---|
| canonical Stage | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `aaaf94f0e487c56bf584149ea26b451ba2dd45766e704c71a4e3991a895b5faa` | exact, regular non-symlink |
| canonical total Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `ebb31600488d35a56bbbb7e0217e823c4b3eb8a1e1a358947fd2f9939aa4d79b` | exact, regular non-symlink |
| A2 leaf Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `ecf7c99e8c9e87a7d808fe18722851bdbbf68e04c8e4e379098e72b8c69b0f44` | exact, regular non-symlink |
| A2 blocked/control history | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/blocked.md` | `74ac2288e9ddad6f63108804cd8594fe421f5478893284a142ab98afb00cb235` | exact, regular non-symlink |
| P1 Stage control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md` | `ba7e278a485c460c3ca1418ce51ea499f1e3f3267e8e35c1b41731ebc4259c47` | exact, regular non-symlink |
| P1 Plan control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md` | `8fcd18b630dce4a7ded43435038d407d06e34ee93bb9269477d78a99bcfc3a9d` | exact, regular non-symlink |
| R18 driver | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r18-begin.sh` | `911bbbc70556e41122cfdcc90048e504eee3480246b338131153856d524d7af9` | exact, regular non-symlink |
| immutable Bash 3.2 probe | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r17-bash32-probes.sh` | `5ee154b56d10322fd70ad34698a7f0fd81122862d25b9bbb05b1db18bee67199` | exact, regular non-symlink |
| R18 static manifest | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r18-entry.sha256` | `71e512a25e6e9bc0d024a53ad2502b55a378a82b39044a341930e1df440cfc2a` | exact, regular non-symlink |
| R18 freeze | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/plan-freeze-r18.md` | `62bbf93031371659e7ad2d4c60aac002eb13ed0915854f741e40251c9c2c1e76` | exact, regular non-symlink |

六面顶端 current status 逐字一致：

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18-A Tombstone Candidate Frozen；Review18 Pending；A2 Clean Re-verification Frozen`

canonical Stage §29、total Plan §19 与 A2 leaf §13 的 `Open Questions` 均精确为
`无。`；六面中 `PENDING_R18_FINAL_FREEZE` marker 数量为 0。

### 2.2 Immutable predecessor identities

| Artifact | Current SHA-256 / state |
|---|---|
| `evidence/r17-begin.sh` | `cf1baab60b3e799b1780b20d1dfc7887bdd2c7e85e241fdb8abcd4ad8c04321f` |
| `evidence/r17-entry.sha256` | `7d10c5c6747cdf0e557befc76a62ea101f2fc4168a49d8076bedd3331d8cbd17`；115 entries |
| `evidence/plan-freeze-r17.md` | `bdbbbd025bbe7cf57032ae2276a6a559043f60e47cebad1ceac43f992e644e1f` |
| `reviews/17-p1-plan-review.md` | `c6838d3c5a9fcfef80dc9db4abf560af712e3175372a163edccb72197daf3dbe`；`CHANGES REQUIRED — 0 P0 / 1 P1` |
| `evidence/plan-freeze-r15.md` | `e5ad3967f2e2b26a2bbf8b2ef7be405e8430cc30a82d51a7cb5f51926a99e3d7` |
| `reviews/15-p1-plan-review.md` | `fbaa9612588c39cb5d99e95d9b68e00a234510e325abf5823c15f0b1eb8ecc05` |
| `evidence/r15-clean-boundary.log` | `53eb91b840c5c8997fbc9da02d391f210f27b45d73b5e2431a6280a36110ab3b`；permanent `REJECTED_CONTAMINATED` |
| `evidence/r15-hash-manifest.log` | `1589d8d29cf3f8ca9e558c4ac6d4008bdd591194c7e975ecf2fd045e6a935399` |
| `impl-report-r15.md` | `e6b0226b3440da997f7e08571d8e5e5229d66069ea5ad6485ee146c249dbe72e` |

Review17 的唯一 P1-01 确为 RanchArt exact-set/nonregular structure gate 位于授权消费
之后；Review17 没有 plan approval 或执行权。R17 的 12 个 runtime paths 与两类
fresh-root glob 当前仍 absent，caller/BEGIN 与后续门保持 not executed。

## 3. Read-only/static checks performed

1. 对 §2 全部 identities 执行 SHA-256、regular-file、non-symlink 与 absolute-path
   检查；branch/HEAD 只读检查与 freeze 一致。
2. 对 `r18-entry.sha256` 独立检查 119 行、lowercase 64-hex、恰好 two spaces、absolute
   path、`LC_ALL=C` path sort、full-line/path unique、regular non-symlink target 与
   `shasum -a 256 --strict -c`：119/119 PASS。
3. 将 R18 manifest path set 与 R17 的 115 项逐 path 比较：无删除，仅增加 reviewed
   `r18-begin.sh`、immutable `r17-entry.sha256`、immutable R17 freeze 与 Review17，
   得到精确 119 项。
4. 逐项重算 R17 manifest 对 current filesystem 的 hashes：恰好 six surfaces 六个
   mismatch；其余 109/115 全部匹配。§2.5 的 13 个产品、2 个测试和两条 App scripts
   另行逐项与 current bytes、leaf hash 和 R18 manifest 交叉检查，17/17 匹配；因此
   产品/test/App scripts 为零 delta。R17 manifest 绑定的 matrix、Package、runner、
   sentinels 与历史证据也都包含在其余 109 个未漂移项中。
5. `/bin/bash -n evidence/r18-begin.sh`：PASS。只读统计得到一个
   `r18_check_ranch_art_structure` definition、两次 phase 调用、一个 27-literal expected
   set；27 个 literal 唯一且与 manifest 中 27 个 RanchArt basenames 一致。
6. immutable `r17-bash32-probes.sh` 在 clean macOS `/bin/bash` 3.2.57 环境实际返回 0：

   ```text
   PASS: Bash 3.2.57(1)-release S/P/C status capture; pgrep=1 diff=1 indeterminate=2 pipeline=(7 0) command_substitution=9 command_substitution_pipeline=7
   ```

   probe 没有调用 driver 或任何产品执行门。
7. `/private/tmp` 当前是 non-symlink directory。一次不带 `-type` 的 exact-basename
   parent enumeration 返回 0 且零匹配；两个 exact R15 paths 的 final `-e || -L`
   classification 均为 `ABSENT`。R16/R17/R18 六类 fresh-root glob 零匹配。
8. 36 个 R16/R17/R18 runtime paths 全部 absent；R15 eight reserved gate logs 均为
   regular non-symlink zero-byte files，R15 screenshot/planned App absent；Review02 与
   A2 acceptance absent。`pgrep -x AgentLoop` 与 `pgrep -x AgentLoopApp` 均为预期
   absence `rc=1`。

## 4. Static manifest and acyclic trust chain

R18 manifest 的 format、type、119/119 content 与 path coverage 本身均通过。manifest
不包含自身、R18 freeze、Review18 或任何 runtime R18 artifact；R18 freeze 不包含自身
hash，也没有预填 Review18 hash。本 Review 不记录自身 hash。driver positional args、
anchor emission 与 surfaces/freeze 约定的四个 terminal identities 均按：

`freeze, Review18, driver, manifest`

因此 frozen file-level chain 在结构上保持无环：

`immutable predecessors + final six surfaces + immutable probe + reviewed driver + R17 manifest/freeze/Review17 → R18 manifest → R18 freeze → Review18 → later user authorization`

该无环/identity 结论不消除 §8 的 driver semantic finding。

## 5. R15 historical observation and current tombstones

R15 durable boundary 继续记录 containment 时
`containment_state_root_empty=true`、`containment_bundle_parent_empty=true` 与
`containment_app_absent=true`；immutable R15 freeze/Review/log/report 保留当时的
canonical non-symlink empty observation。current filesystem 则独立证明两个 exact
identities 均为 `ABSENT`。六面与 freeze 没有把这两个事实混为连续保全，disappearance
原因只写 `UNKNOWN`，且把 `CANONICAL_EMPTY → ABSENT` 后的 `ABSENT` 定义为 absorbing
tombstone；任何 node 重现均拒绝。

driver 静态实现同时具备：

1. 两个 basename 非空、非 `.`/`..`、互异并与 frozen literals 精确匹配；
2. absolute path 由 non-symlink `/private/tmp` directory 与 basename 精确重建；
3. 单个 Bash 3.2-safe command-substitution 对两个 exact basenames 联合执行 parent
   enumeration，且没有 `-type` 过滤；
4. parent 异常、enumeration nonzero、任何输出或 final `-e || -L` 重检发现 node 均在
   consumption 前 fail closed；
5. boundary 初始化恰好包含两个 observed-state 字段、两个 current-absent 字段、
   `r15_absence_proof_identity=private_tmp_parent_enumeration_exact_basename_v1` 与
   `disappearance_cause=UNKNOWN`；driver 中没有 `preserved_empty` 或
   `continuously_preserved` 字段；
6. 不创建物理 tombstone，也不把 R15 roots 用作 fresh R18 roots。

该部分满足 R18-A frozen tombstone contract，并未发现独立 P0/P1/P2。

## 6. Bash 3.2 capture inventory

R18 driver 的 inherited inventory 静态分类仍精确为 `2P / 4S / 7C = 13`：

- P：pre-BEGIN terminal anchors、post-activation terminal anchors；
- S：pre-BEGIN static manifest、process `pgrep`、RanchArt exact-set `diff`、
  post-activation static manifest；
- C：fresh-root empty-directory probe、联合 R15 tombstone parent enumeration、fresh-root
  `realpath`、RanchArt regular-file `find`、path-transform pipeline、nonregular-node
  `find`、regular-count pipeline。

联合 tombstone enumeration 是对 R17 preserved-root `realpath` C 的一对一职责替换；
另计 R16/R17/R18 root-glob absence C 后，driver total 为 `2P / 4S / 8C = 14`。两类
pipeline 均在 then/else 首条复制 `PIPESTATUS`；S 直接在 conditional 捕获；C 在
subshell 先解除 inherited ERR trap再由外层 conditional 捕获。唯一 `set +e` 位于先
解除 ERR/signal traps 的 active-failure 路径。immutable probe 的 hash 与实际 PASS
输出均匹配。

该计数结论不等于 RanchArt pathname serialization 本身正确；后者见 §8。

## 7. Boundary ordering and failure semantics

driver 的 source order 精确为：

```text
pre-BEGIN metadata + format validation
  → pre-consumption RanchArt verifier
  → exclusive-create boundary + authorization_consumed=true
  → exclusive-create fresh hash log
  → post-activation same verifier filesystem reread
  → four terminal anchors
  → 119-entry strict manifest + worktree evidence
  → remaining eight text logs
  → fresh state root + fresh bundle parent
  → BEGIN finalization
```

pre-consumption verifier 是 boundary 前最后一个 fallible precondition，调用与 boundary
attempt 之间没有 uuid/date/substitution 或其他 gate。pre sink 固定为 `/dev/stderr`；
post 调用写入 fresh hash log，并且 exact path block 只在 `diff=0` 后写，
`nonregular_count=0` 只在 nonregular probe 通过后写，`regular_count=27` 只在 count
检查通过后写。post verifier 后另行执行 119-entry strict content manifest。

控制路由上，boundary 前显式/意外失败保持 `authorization_consumed=false`；boundary
成功后任一 post failure 经 active-failure path 记录 `REJECTED_CONTAMINATED` 与
`retry_same_boundary=false`。然而 §8 证明 RanchArt preflight 对合法 filesystem
pathname domain 并非真正 exact，因此“任何 pre-consumption structure failure 都在
零写入停止”的语义尚未成立。

## 8. Findings

### P0

无。

### P1

#### P1-01 — newline-delimited RanchArt enumeration is not a byte-exact pathname set and can consume authorization on a contaminated tree

canonical Stage §28.5.2、A2 leaf §11.1 与 R18 freeze §6 要求同一 verifier 对真实
filesystem 证明 exact 27 regular non-symlink pathname set、zero nonregular 与 exact
regular-node count，并把这项检查作为消费授权前最后一个 fail-closed precondition。

实际 driver `r18_check_ranch_art_structure` 的 regular path transport 是：

- lines 496–504：`find ... -type f -print` 输出 newline-delimited paths；
- lines 511–520：把完整输出放入 Bash string，再以 newline-oriented `printf | sed |
  sort` 生成所谓 relative-path set；
- lines 526–541：以 text-line `diff` 判定 exact set并序列化同一 text block；
- lines 563–581：以该 string 的输出行数作为 regular-file count；
- lines 543–561 的 nonregular probe只拒绝 `! -type f` node，无法发现 regular filename
  的分隔符歧义。

macOS filesystem filename 可以包含 newline。因而 source-level 可重复推理如下；本
Review 遵守红线，没有为复现创建任何 node 或运行 driver：

1. pre-BEGIN 119-entry content manifest 通过后、preflight 读取前，若两个 expected
   regular files（例如 `PixelBarnDay.png` 与 `PixelBarnNight.png`）被替换为一个 basename
   为 `PixelBarnDay.png\nPixelBarnNight.png` 的 regular file；
2. `find -print` 会把这一个 node 表示成两行。`sed` 只从第一行移除 RanchArt directory
   prefix，第二行已经逐字是另一个 expected basename；
3. sorted line set 因而仍可等于 27-line expected text，`wc -l` 也仍可报告 27；所有
   node 都是 regular，所以 nonregular probe 报 0；
4. preflight 在其实际观察到 contaminated tree 的同一时刻仍会返回成功，随后
   exclusive-create boundary 并消费授权。若状态持续，post structure verifier 也会写出
   虚假的 exact-path/count evidence；只有之后的 119-entry content manifest 才因两个
   frozen paths 缺失而把 boundary 永久拒绝。

这不是 freeze 已诚实披露的“读取之后仍可能变化”的理论 TOCTOU，也不要求原子
filesystem lock。这里是在 verifier 已读取一个稳定 contaminated tree 时，line-based
encoding 把不同的 filesystem node set 映射成同一 text set。结果直接恢复 Review17
P1-01 的关键后果：已存在/可见的 RanchArt structure contamination 仍可能先消费一次性
授权，再由 post-content gate 拒绝；同时 post hash log 的 exact-path/count structure
evidence可能不真实。

最小有界修订方向是保持 single verifier、single expected set 与现有 boundary order，
但让 regular pathname enumeration/comparison/count 对 filesystem pathname 使用无歧义、
lossless representation，或在任何 line serialization 前显式 fail closed 拒绝所有不能
被该 representation 无歧义表达的 pathname，并独立证明 27 个 frozen expected paths
各自为 regular non-symlink files。planner 必须同步更新受影响的 capture inventory/probe
合同（若实现导致计数或模式变化）、driver hash、manifest/freeze/surfaces，并重新交给未
参与修订的职责隔离 reviewer；不得以运行当前 driver、增加 post-only check 或说明
TOCTOU 来掩盖 pre-consumption exactness 缺口。

### P2

无。

## 9. Verdict and authorization boundary

**CHANGES REQUIRED — 0 P0 / 1 P1**

虽然 exact identities、119/119 manifest、R17 109/115 preservation、R15 tombstone、
13/14 capture count、current absence、status/Open Questions 与无环链检查均通过，
P1-01 使 R18 RanchArt pre-consumption exact-set gate 尚不能关闭 Review17 的根因。
因此当前 R18/R18-A candidate 未获 plan approval。

本 Review 不批准、请求或执行 current four-hash chain，也不打开 external caller、
driver/BEGIN、test、build、matrix、source gate、bundle/sign、preview、产品/test/App-script
修改、Review02、acceptance 或 A3。当前 R18 runtime paths/fresh roots必须继续 absent。

后续只能由 planner 在有界 planning scope 内修订并重新形成无环 manifest/freeze，再由
新的职责隔离 reviewer 审查。只有未来 review 在新的 exact bytes 上达到
`APPROVED — 0 P0 / 0 P1`，且其后的新用户 turn 按
`freeze, Review, driver, manifest` 顺序逐字给出四个 terminal SHA-256 并明确授权，
才可能打开一次新的 clean invocation；本 Review18 自身永不构成执行授权。

## Open Questions

无。
