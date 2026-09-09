# P1-A2 R17 Status-Capture Plan Review

> Verdict：**CHANGES REQUIRED — 0 P0 / 1 P1**
>
> 日期：2026-07-29
>
> Review 对象：R17 final frozen planning bytes、Bash 3.2 status-capture probe、
> reviewed BEGIN driver 与 static entry manifest

## 1. Scope and independence

本 reviewer 未参与 R17 六面修订、`r17-begin.sh`、`r17-bash32-probes.sh`、
`r17-entry.sha256` 或 `plan-freeze-r17.md` 的生成。本次完整只读审查当前真实
bytes；唯一写入是本 Review17 文件。

本次没有运行 R17 external caller、driver/BEGIN、targeted/full test、build、
migration matrix、source gate、bundle assembly/sign 或 preview；没有创建 runtime
artifact/fresh root，没有修改产品/test/App/matrix script、R15/R16 evidence、
Review02 或 acceptance。

允许的静态检查结果：

- `/bin/bash --noprofile --norc -n evidence/r17-begin.sh`：PASS；
- `/bin/bash --noprofile --norc -n evidence/r17-bash32-probes.sh`：PASS；
- clean-environment Bash 3.2 probe：PASS；
- `/usr/bin/shasum -a 256 --strict -c evidence/r17-entry.sha256`：
  115/115 PASS；
- `git diff --check`：PASS；
- R17/R16 runtime artifacts、R17/R16 fresh-root globs 与本 Review 在审查开始时
  均不存在。

审查快照为 branch `codex/personal-ai-ranch-p0`、HEAD
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`。已有 large P0/P1 dirty/untracked
candidate tree 被视为用户工作并保持不动。

## 2. Exact identities reviewed

| Artifact | Current SHA-256 | Result |
|---|---|---|
| canonical Stage | `e996dd58188213be9551a9641076c55cf7a11e489d42b90a978cf8cfaae8cecb` | exact |
| canonical total Plan | `453993e160573cf0d08167732c35a08f0d250262aa446d7ffa66a9d3c40701c1` | exact |
| A2 leaf Plan | `68f3353bbb2126a3216afa79d0a18177358b1dd89a91fc034777403df5f67277` | exact |
| A2 blocked/history | `f1792641707c34e6d346e1b8f684548e548ef2712ee9ca0dd4f06a08d4ef965d` | exact |
| P1 Stage control | `821691ef6650318aad0e9c388050e2ce9615b3c678142072a894a5fa467b36d8` | exact |
| P1 Plan control | `5a2914c869fd9325eaebf5b834fd9788055eb1603195cb3cb7c8ff93424bb20c` | exact |
| `evidence/r17-begin.sh` | `cf1baab60b3e799b1780b20d1dfc7887bdd2c7e85e241fdb8abcd4ad8c04321f` | exact |
| `evidence/r17-bash32-probes.sh` | `5ee154b56d10322fd70ad34698a7f0fd81122862d25b9bbb05b1db18bee67199` | exact |
| `evidence/r17-entry.sha256` | `7d10c5c6747cdf0e557befc76a62ea101f2fc4168a49d8076bedd3331d8cbd17` | exact |
| `evidence/plan-freeze-r17.md` | `bdbbbd025bbe7cf57032ae2276a6a559043f60e47cebad1ceac43f992e644e1f` | exact |

六个 canonical/control surfaces 的 current gate 均包含且没有 stale current
opening：

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 Status-Capture Candidate Frozen；Review17 Pending；A2 Clean Re-verification Frozen`

canonical Stage §29、total Plan §19、A2 leaf §13 的 `Open Questions` 均精确为
`无。`。四个 terminal hashes 的顺序在 surfaces/freeze/driver 中一致为
`freeze, Review17, driver, manifest`；driver positional arguments `$1`–`$4`
亦为该顺序。本 Review 不记录或预填自身 hash。

## 3. R16 stopped boundary and R15 rejected boundary

R16 immutable predecessor identities：

| Artifact | Current SHA-256 / state |
|---|---|
| `evidence/plan-freeze-r16.md` | `c10ae51ad78b414aab18c3785b79aac49feb73c47ac5fdcb896ca874ae319867` |
| `reviews/16-p1-plan-review.md` | `71f16eceef429f7d02fe8908c4609b9bd0b0b98b44c68b579a75ced2ac9d9824` |
| `evidence/r16-begin.sh` | `ffa61fa7c8c281cdb8dfb853b38aafce9536ddcc276e18d64c082de8887b55b0` |
| `evidence/r16-entry.sha256` | `0c2f5dc59e5f0e193214d1c8532a91818a339abdfb3150177c680fe61f8a0b1e` |
| 12 R16 runtime paths | absent |
| `/private/tmp/agentloop-r16-state.*` | absent |
| `/private/tmp/agentloop-r16-bundle.*` | absent |

R16 static manifest 对 current tree 有且仅有六个 mismatch，正好是 R17 合法修订的
six surfaces；其余 104/110 entries 均匹配。因而既有 product/test/App/matrix 与
historical evidence 没有被 R17 漂移。

R15 rejected boundary 继续保持：

| Artifact | Current SHA-256 / state |
|---|---|
| `evidence/plan-freeze-r15.md` | `e5ad3967f2e2b26a2bbf8b2ef7be405e8430cc30a82d51a7cb5f51926a99e3d7` |
| `reviews/15-p1-plan-review.md` | `fbaa9612588c39cb5d99e95d9b68e00a234510e325abf5823c15f0b1eb8ecc05` |
| `evidence/r15-clean-boundary.log` | `53eb91b840c5c8997fbc9da02d391f210f27b45d73b5e2431a6280a36110ab3b`；`REJECTED_CONTAMINATED` |
| `evidence/r15-hash-manifest.log` | `1589d8d29cf3f8ca9e558c4ac6d4008bdd591194c7e975ecf2fd045e6a935399` |
| `impl-report-r15.md` | `e6b0226b3440da997f7e08571d8e5e5229d66069ea5ad6485ee146c249dbe72e` |
| eight reserved gate logs | 各 0 bytes；empty SHA `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `/private/tmp/agentloop-r15-state.Zq6Jvm` | canonical non-symlink empty directory |
| `/private/tmp/agentloop-r15-bundle.2xROcy` | canonical non-symlink empty directory；planned App absent |
| R15 screenshot | absent |

`AgentLoop` 与 `AgentLoopApp` process absence probes 均得到预期 `rc=1`。Review02
与 A2 acceptance 仍不存在；R15 没有被洗绿，R16 的
`AUTHORIZATION_NOT_CONSUMED`/zero-write 状态也没有被误报为执行成功。

## 4. Static manifest and acyclic trust chain

`r17-entry.sha256` 当前为 115 行，全部使用 lowercase 64-hex、two spaces 和
`/Users/muzi/Agent-loop/...` absolute path；path 集合按 `LC_ALL=C` bytewise
顺序排列且唯一。全部 target 均为 regular non-symlink files，115/115 strict check
全绿。

相对 R16 的 110-entry path set，R17 只增加以下五项，且无删除：

1. Review16；
2. R16 freeze；
3. immutable `r16-entry.sha256`；
4. R17 Bash 3.2 probe；
5. R17 driver。

manifest 不包含自身、R17 freeze、Review17 或任何 runtime R17 artifact。其覆盖的
27 个 RanchArt paths 当前均为 regular files、零 nonregular/symlink node；derived
manifest SHA 为
`4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab`。
因此冻结的文件级信任链本身无环：

`immutable predecessors + final six surfaces + driver + probe → manifest → freeze → Review17 → later user authorization`

## 5. Bash 3.2 status capture

R17 driver 的 13 个 inherited status-capture blocks 分类为精确
`2 pipeline / 4 simple / 7 command-substitution`：

- pipeline：lines 145–151、357–363；
- simple：lines 201–207、210–227、379–385、466–474；
- command substitution：lines 238–249、266–274、327–335、436–444、
  451–460、479–487、498–507。

另有 lines 294–304 的新 R16 fresh-root absence check，使用相同安全
command-substitution pattern。pipeline 的 then/else 两路均在首条命令复制
`PIPESTATUS`；command substitution 在 subshell 首先执行 `trap - ERR`，再由外层
conditional 捕获真实 status；simple conditional 直接保存 `$?`。driver 中没有
`|| true`，唯一 `set +e` 位于 active-failure handler，且其前先执行
`trap - ERR HUP INT TERM`，不属于被禁止的 bare status capture。

clean environment 中实际运行：

```text
/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  /bin/bash --noprofile --norc evidence/r17-bash32-probes.sh
PASS: Bash 3.2.57(1)-release S/P/C status capture; pgrep=1 diff=1 indeterminate=2 pipeline=(7 0) command_substitution=9 command_substitution_pipeline=7
```

probe 返回 0，覆盖 `pgrep rc=1`、`diff rc=1`、indeterminate `rc=2`、pipeline
component nonzero、command-substitution nonzero，并安装全局 `ERR` trap 验证这些
expected nonzero 不被抢占。probe 未调用 R17 driver 或任何产品执行门。

## 6. Driver boundary review

除 Findings 中的顺序冲突外，driver 静态控制流具备以下性质：

1. Bash 3.2 syntax PASS；使用 `set -Eeuo pipefail`、`set -f`、固定 `IFS` 与
   `umask 077`，没有 silent fallback。
2. activation 前验证 terminal anchors、115-entry manifest shape/strict hashes、
   branch/HEAD、R17/R16 runtime absence、R16 fresh-root absence、process absence
   与 R15 preserved roots/App/screenshot。
3. boundary log 使用 noclobber exclusive-create；其初始化写
   `authorization_consumed=true`，之后才 exclusive-create 九个 text logs 并创建
   两个 fresh roots。
4. activation 后重新检查 anchors/manifest，记录 raw `OK`/`FAILED`、真实 producer/
   shasum return codes、exact count 与 worktree status。
5. active error/signal 路径记录 phase、真实 command/rc、root identity、
   `REJECTED_CONTAMINATED` 与 `retry_same_boundary=false`。
6. driver 本身不执行 test/build/matrix/source/bundle/sign/preview；12 个 runtime
   artifact names 均为全新 R17 names。

matrix script current SHA 为
`75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`；
唯一 `expected_stage_hash` 仍是 predecessor
`a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f`。
冻结合同未提前运行或改写该门。

## 7. Findings

### P0

无。

### P1

#### P1-01 — canonical pre-BEGIN RanchArt gate is implemented after authorization consumption

canonical Stage §28.4.3 lines 8883–8895 明确要求 R17 driver 在 pre-BEGIN 证明
`RanchArt结构`，并规定只有此后 exclusive-create boundary log 才消费授权。

但其余 frozen surfaces 与实际 driver 采用相反顺序：

- A2 leaf §11.1 lines 1023–1034：step 2 先 exclusive-create boundary、写
  `authorization_consumed=true`，step 4 才执行 RanchArt structural check；
- R17 freeze §8 lines 269–282：step 2 消费授权，step 5 才执行结构门；
- `r17-begin.sh` lines 633–660：创建 boundary、写
  `authorization_consumed=true` 并设置 `R17_BOUNDARY_ACTIVE=true`；
- 同一 driver lines 727–739：activation 后才调用
  `r17_check_ranch_art_structure`。

这不是静态 115-entry manifest 已经覆盖的等价验证。manifest 只绑定列出的 27 个
regular files；如果 Review17 后 RanchArt 出现额外 regular 或 nonregular node，
四 anchors 与 115 hashes 仍可全绿，driver 会先消费一次性授权，再由 exact-set/
zero-nonregular structure gate 拒绝。结果是 canonical Stage 所承诺的
pre-consumption zero-write failure 被实现为不可重试的
`REJECTED_CONTAMINATED`。

该冲突同时触发 canonical/control 的“文本冲突即停止”原则，故冻结候选当前不可
批准。最小修订边界是由 planner 在允许的 planning surfaces/driver/freeze/manifest
链内选择并统一一个权威顺序；按当前 canonical Stage 语义，应在 boundary
exclusive-create 之前完成 exact RanchArt path-set 与 nonregular/symlink 结构
验证。修订后必须重新冻结受影响 bytes、重建无环 manifest/trust chain，并由新的
职责隔离 reviewer 审查。Review17 不修改这些 planner artifacts，也不替 planner
作新的产品或架构决策。

### P2

无。

## 8. Verdict and authorization boundary

**CHANGES REQUIRED — 0 P0 / 1 P1**

由于 P1-01 未关闭，R17 candidate 未获 plan approval；本 Review 不打开四-hash
authorization，也不批准或执行 external caller/BEGIN、test、build、matrix、
source gate、bundle/sign、preview、产品/test/App-script修改、Review02、
acceptance 或 A3。

当前四-hash链不得被用于执行。所有 R17 execution paths/fresh roots 必须继续
absent；任何后续修订都必须由 planner 重新形成完整 freeze/manifest/review
boundary。

## Open Questions

无。
