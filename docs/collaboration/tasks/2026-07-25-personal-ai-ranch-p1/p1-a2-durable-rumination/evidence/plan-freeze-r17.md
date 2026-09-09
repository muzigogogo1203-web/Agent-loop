# P1-A2 R17 Status-Capture Plan Freeze

> 状态：R17 Status-Capture Candidate Frozen；Review17 Pending；全部执行继续禁止
>
> 日期：2026-07-29
>
> 分支：`codex/personal-ai-ranch-p0`
>
> HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. 授权范围与停止线

牧场主授权R17只关闭R16暴露的同一Bash `ERR` trap/status-capture根因：

- 有界修订全部13个继承的status-capture blocks；
- 增加零repository-write的Bash 3.2 S/P/C micro-probes；
- 保留R16 pre-BEGIN零写入、授权未消费事实与全部R15历史；
- 使用全新R17 driver、manifest、freeze与runtime names；
- 同步六个canonical/control surfaces，并执行职责隔离Review17。

本授权不允许运行R17 external caller、driver/BEGIN、targeted/full test、build、
migration matrix、source gate、bundle assembly/sign或preview，不允许修改任何
产品/test/App/matrix script，不允许创建Review02/acceptance、进入A3、commit、
push、merge、release、normal-data、外部或真实用户操作。Review17通过本身也不
执行；必须等待后续新的用户turn按`freeze, Review17, driver, manifest`顺序逐字
给出四个terminal hashes并另行授权。

## 2. R17 final planning identities

### 2.1 Six canonical/control surfaces

| Surface | Absolute path | SHA-256 |
|---|---|---|
| canonical Stage | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `e996dd58188213be9551a9641076c55cf7a11e489d42b90a978cf8cfaae8cecb` |
| canonical total Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `453993e160573cf0d08167732c35a08f0d250262aa446d7ffa66a9d3c40701c1` |
| A2 leaf Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `68f3353bbb2126a3216afa79d0a18177358b1dd89a91fc034777403df5f67277` |
| A2 blocked/history | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/blocked.md` | `f1792641707c34e6d346e1b8f684548e548ef2712ee9ca0dd4f06a08d4ef965d` |
| P1 Stage control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md` | `821691ef6650318aad0e9c388050e2ce9615b3c678142072a894a5fa467b36d8` |
| P1 Plan control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md` | `5a2914c869fd9325eaebf5b834fd9788055eb1603195cb3cb7c8ff93424bb20c` |

六面current状态同义：

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 Status-Capture Candidate Frozen；Review17 Pending；A2 Clean Re-verification Frozen`

### 2.2 Driver, micro-probe and static manifest

| Artifact | Absolute path | SHA-256 / invariant |
|---|---|---|
| reviewed BEGIN-only driver | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r17-begin.sh` | `cf1baab60b3e799b1780b20d1dfc7887bdd2c7e85e241fdb8abcd4ad8c04321f`；Bash 3.2 `-n` PASS；13-block static audit `PASS — 0 P0 / 0 P1 / 0 P2` |
| Bash 3.2 micro-probe | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r17-bash32-probes.sh` | `5ee154b56d10322fd70ad34698a7f0fd81122862d25b9bbb05b1db18bee67199`；Bash 3.2 `-n` PASS；clean-environment probe PASS |
| static entry manifest | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r17-entry.sha256` | `7d10c5c6747cdf0e557befc76a62ea101f2fc4168a49d8076bedd3331d8cbd17`；115 entries；`shasum --strict -c` 115/115 PASS |

micro-probe的冻结输出为：

```text
PASS: Bash 3.2.57(1)-release S/P/C status capture; pgrep=1 diff=1 indeterminate=2 pipeline=(7 0) command_substitution=9 command_substitution_pipeline=7
```

`r17-entry.sha256`使用`<lowercase 64-hex><two spaces><absolute path>`，按absolute
path bytewise sorted unique。115项覆盖：

| Class | Count |
|---|---:|
| six current surfaces | 6 |
| R16/R17 reviewed drivers plus R17 Bash 3.2 probe | 3 |
| A1b review/acceptance entry anchors | 2 |
| A2 product/test frozen files | 15 |
| full-file sentinels/Package/runner/App/matrix scripts/RanchArtView | 14 |
| RanchArt exact regular files | 27 |
| R13 implementation/incident/Review01 evidence | 14 |
| original through R16 plan freezes | 12 |
| Review12 through Review16 plan reviews | 10 |
| R15 execution/failure artifacts | 11 |
| immutable R16 static entry manifest | 1 |
| **Total** | **115** |

manifest继承R16全部110项coverage，重新计算全部current hashes，并增加immutable
`r16-entry.sha256`、R16 freeze、Review16、R17 driver与R17 probe。它明确不包含
自身、本freeze、Review17或任何runtime `r17-*` artifact。

## 3. Acyclic trust chain

唯一信任链为：

```text
immutable predecessors + final six surfaces
  + reviewed r17-begin.sh + r17-bash32-probes.sh
  → static r17-entry.sha256
  → plan-freeze-r17.md
  → reviews/17-p1-plan-review.md
  → later user authorization carrying four terminal hashes
```

- 本freeze记录surfaces、driver、probe与manifest hashes，但不记录自身hash或尚未
  生成的Review17 hash；
- Review17只绑定本freeze及其predecessors，不记录自身hash；
- 完整`freeze + Review17 + driver + manifest`四元组只能由Review17后的新用户
  authorization提供；
- 不允许upstream自填、推导或回写self/downstream hash。

## 4. Immutable R16 pre-BEGIN zero-write outcome

R16 plan chain与实际outcome均保持immutable：

| Artifact / invariant | SHA-256 / state |
|---|---|
| `evidence/plan-freeze-r16.md` | `c10ae51ad78b414aab18c3785b79aac49feb73c47ac5fdcb896ca874ae319867` |
| `reviews/16-p1-plan-review.md` | `71f16eceef429f7d02fe8908c4609b9bd0b0b98b44c68b579a75ced2ac9d9824`；`APPROVED — 0 P0 / 0 P1` plan predecessor |
| `evidence/r16-begin.sh` | `ffa61fa7c8c281cdb8dfb853b38aafce9536ddcc276e18d64c082de8887b55b0` |
| `evidence/r16-entry.sha256` | `0c2f5dc59e5f0e193214d1c8532a91818a339abdfb3150177c680fe61f8a0b1e`；110 entries |
| four terminal anchors | PASS |
| R16 static manifest | 110/110 PASS |
| first process-absence probe | `pgrep -x AgentLoop` returned normal absence `rc=1` |
| actual stop | inherited global `ERR` trap intercepted before status assignment/case |
| `evidence/r16-clean-boundary.log` | absent |
| 12 R16 runtime paths | all absent |
| `/private/tmp/agentloop-r16-state.*` | absent |
| `/private/tmp/agentloop-r16-bundle.*` | absent |
| authorization | `authorization_consumed=false` |
| later gates | caller entered driver, but BEGIN/test/build/matrix/source/bundle/preview did not run |

R16没有创建BEGIN log、execution log、report、screenshot或fresh root，没有修改任何
产品/test/App/matrix script。R17不得补写、重跑、覆盖、删除、清理、重命名或把
R16 outcome改判为`REJECTED_CONTAMINATED`。R16 failure是pre-consumption false
positive；它不证明A2完成。

## 5. Immutable R15 rejected boundary

Review15只批准R15 plan，不洗绿随后失败的execution：

| Artifact / invariant | SHA-256 / state |
|---|---|
| `evidence/plan-freeze-r15.md` | `e5ad3967f2e2b26a2bbf8b2ef7be405e8430cc30a82d51a7cb5f51926a99e3d7` |
| `reviews/15-p1-plan-review.md` | `fbaa9612588c39cb5d99e95d9b68e00a234510e325abf5823c15f0b1eb8ecc05`；`APPROVED — 0 P0 / 0 P1` plan predecessor |
| `evidence/r15-clean-boundary.log` | `53eb91b840c5c8997fbc9da02d391f210f27b45d73b5e2431a6280a36110ab3b`；permanent `REJECTED_CONTAMINATED` |
| `evidence/r15-hash-manifest.log` | `1589d8d29cf3f8ca9e558c4ac6d4008bdd591194c7e975ecf2fd045e6a935399` |
| `impl-report-r15.md` | `e6b0226b3440da997f7e08571d8e5e5229d66069ea5ad6485ee146c249dbe72e` |
| eight reserved gate logs | each zero bytes；`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r15-preview-smoke.png` | absent |
| state root | `/private/tmp/agentloop-r15-state.Zq6Jvm` exists, non-symlink, empty |
| bundle parent | `/private/tmp/agentloop-r15-bundle.2xROcy` exists, non-symlink, empty |
| planned R15 App | absent |

R15在任何targeted/full test、build、matrix、source gate、bundle/sign或preview之前
失败；matrix Stage literal从未替换，产品/test/App scripts零delta，normal root没有
被该invocation访问。R17不得覆盖、追加、补齐、删除、清理、重命名或复用上述任何
文件、absence或root。

R15已定位的上位根因为expected/actual都等于
`db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109`
时自定义zsh helper false-negative；更底层micro-trigger未复现。R16用standard
strict manifest替换该风险类，但又暴露独立的Bash `ERR` trap/status-capture根因。
R17只关闭后者，不宣称已解释或修复R15未知micro-trigger。

## 6. Thirteen-block root-cause contract

R17一次关闭全部13个继承status-capture blocks：

| # | Block | Safe class |
|---:|---|---|
| 1 | pre-BEGIN terminal-anchor pipeline | P |
| 2 | pre-BEGIN static-manifest `shasum` | S |
| 3 | `pgrep` process-absence probe | S |
| 4 | preserved-root empty-directory `find` substitution | C |
| 5 | preserved R15 root `realpath` substitution | C |
| 6 | fresh R17 root `realpath` substitution | C |
| 7 | post-activation terminal-anchor pipeline | P |
| 8 | post-activation static-manifest `shasum` | S |
| 9 | RanchArt regular-file `find` substitution | C |
| 10 | RanchArt path-transform pipeline substitution | C |
| 11 | RanchArt exact path-set `diff` | S |
| 12 | RanchArt nonregular-node `find` substitution | C |
| 13 | RanchArt regular-file count pipeline substitution | C |

安全模式固定为：

- **S — simple command**：只在`if command; then rc=0; else rc=$?; fi`分支中直接
  捕获真实status；
- **P — pipeline**：then/else的第一条语句立即复制完整`PIPESTATUS`，任何输出、
  assignment或helper都不得先执行；
- **C — command substitution**：subshell第一条执行`trap - ERR`，由外层
  conditional直接捕获status并保留stdout/stderr。

禁止在全局`ERR` trap仍启用时用bare `set +e; command; rc=$?`，也禁止`|| true`、
silent fallback、status inversion、只修绿色路径必现的`pgrep`或把unexpected
failure降级为generic success。唯一保留的`set +e`位于已解除
`ERR/HUP/INT/TERM` traps的`r17_active_fail`负证据写入路径，不属于status capture。

`r17-bash32-probes.sh`只在planning/Review阶段运行，覆盖：

- expected absence/mismatch：`pgrep=1`、`diff=1`；
- indeterminate failure：`rc=2`；
- pipeline component nonzero：`(7 0)`；
- simple command substitution nonzero：`9`；
- pipeline command substitution nonzero：`7`；
- unprotected unexpected failure仍由global `ERR` handler fail-fast。

probe不得调用R17 driver或任何产品执行门，不写repository artifact。

## 7. Exact zero-write external caller

Review17通过且后续新用户提供四个final hashes后，只可用下列clean caller。argument
顺序固定为`freeze, Review17, driver, manifest`：

```bash
/usr/bin/env -i \
  LC_ALL=C LANG=C PATH=/usr/bin:/bin:/usr/sbin:/sbin TMPDIR=/private/tmp \
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
  /bin/bash --noprofile --norc -c '
set -Eeuo pipefail
set -f
IFS=$'"'"' \t\n'"'"'

readonly r17_root=/Users/muzi/Agent-loop
readonly r17_task="$r17_root/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination"
readonly r17_freeze="$r17_task/evidence/plan-freeze-r17.md"
readonly r17_review="$r17_root/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/17-p1-plan-review.md"
readonly r17_driver="$r17_task/evidence/r17-begin.sh"
readonly r17_manifest="$r17_task/evidence/r17-entry.sha256"

r17_anchor_fail() {
  /usr/bin/printf \
    "R17_ANCHOR_REJECTED code=%s reason=%s authorization_consumed=false\n" \
    "$1" "$2" >&2
  exit "$1"
}

[[ "$#" -eq 4 ]] || r17_anchor_fail 64 invalid_argument_count
for r17_hash in "$@"; do
  [[ "${#r17_hash}" -eq 64 ]] || r17_anchor_fail 64 malformed_terminal_hash
  case "$r17_hash" in *[!0-9a-f]*) r17_anchor_fail 64 malformed_terminal_hash ;; esac
done
for r17_path in "$r17_freeze" "$r17_review" "$r17_driver" "$r17_manifest"; do
  [[ -f "$r17_path" && ! -L "$r17_path" ]] ||
    r17_anchor_fail 65 invalid_terminal_artifact_type
done

if ! /usr/bin/printf "%s  %s\n%s  %s\n%s  %s\n%s  %s\n" \
  "$1" "$r17_freeze" \
  "$2" "$r17_review" \
  "$3" "$r17_driver" \
  "$4" "$r17_manifest" |
  /usr/bin/shasum -a 256 --strict -c -; then
  r17_anchor_fail 65 terminal_anchor_failure
fi
if ! /usr/bin/shasum -a 256 --strict -c "$r17_manifest"; then
  r17_anchor_fail 66 static_manifest_failure
fi

exec /bin/bash --noprofile --norc "$r17_driver" "$1" "$2" "$3" "$4" ||
  r17_anchor_fail 74 driver_exec_failure
' r17-anchor \
  '<R17_FREEZE_SHA>' '<REVIEW17_SHA>' '<R17_DRIVER_SHA>' '<R17_MANIFEST_SHA>'
```

caller不重定向、不创建temp/artifact/root，不运行driver以外的任何gate。anchor或
static-manifest任一失败只写console、`authorization_consumed=false`、不进入driver。

## 8. Reviewed driver and runtime contract

`r17-begin.sh`只建立BEGIN boundary，不运行测试、构建、matrix、source、bundle、
sign或preview：

1. pre-BEGIN验证exact clean env、四anchors、115-entry static manifest、absolute/
   sorted/unique/regular/non-symlink shape、branch/HEAD、全部R17 runtime paths
   absent、全部R16 runtime paths和两类R16 fresh-root glob仍absent、
   AgentLoop/AgentLoopApp进程为0、R15 screenshot/planned App absent及两个R15
   roots存在且为空；失败零写入、不消费授权；
2. 只在pre-BEGIN全绿后exclusive-create`evidence/r17-clean-boundary.log`并在同一
   初始化写current invocation ID与`authorization_consumed=true`；该点是唯一
   消费点；
3. consumption后exclusive-create九个text logs，创建两个fresh、absolute、
   non-symlink、empty、distinct、non-nested且不复用R15/R16的state/bundle roots；
4. activation后再次检查四anchors、manifest shape与全部115 hashes，将raw
   `OK`/`FAILED`、producer/shasum return codes、exact count与worktree status写入
   `evidence/r17-hash-manifest.log`；
5. 结构门证明RanchArt exact 27 regular-file path set、零nonregular/symlink node，
   并记录frozen Info.plist
   `5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58`
   与RanchArt derived manifest
   `4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab`；
6. 只有上述全绿才写`begin_attestation_complete=true`与
   `status=BEGIN_ATTESTED`；consumption后任一error/signal/indeterminate probe永久
   写`REJECTED_CONTAMINATED`、phase、真实command/rc、root identity与
   `retry_same_boundary=false`。

Review17与后续四-hash授权前，以下12个paths必须全部不存在：

- `r17-targeted-tests.log`
- `r17-verify.log`
- `r17-build.log`
- `r17-migration-matrix.log`
- `impl-report-r17.md`
- `evidence/r17-clean-boundary.log`
- `evidence/r17-bundle-provenance.log`
- `evidence/r17-source-gates.log`
- `evidence/r17-hash-manifest.log`
- `evidence/r17-preview-bootstrap.log`
- `evidence/r17-preview-cold-start.log`
- `evidence/r17-preview-smoke.png`

`/private/tmp/agentloop-r17-state.*`与
`/private/tmp/agentloop-r17-bundle.*`在freeze/Review17阶段同样必须不存在。BEGIN
成功后driver才用`mktemp -d`建立新root，planned App固定为fresh bundle parent下的
`AgentLoop.app`。

BEGIN通过后，R17机械继承canonical Stage §28.2.2–§28.2.4、§28.4.4与A2 leaf
§10–§12冻结的POST_BUILD→PRE_SIGN→LAUNCH_READY、same-bundle direct exec、
matrix line-115唯一Stage hash临时delta/mandatory restoration、normal-root
isolation、fail-once、Review02与scoped acceptance合同。R17不修改schema/API/event/
package、15个产品/test bytes或两条App scripts。

## 9. Review17 gate

未参与R17六面修订、driver/probe/manifest/freeze生成的职责隔离reviewer唯一可写：

`/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/17-p1-plan-review.md`

Review17必须以当前真实bytes核对：

- 本freeze中的六面、driver、probe与manifest hashes；
- static manifest 115/115 strict PASS、无环排除与coverage；
- 13个status-capture blocks的S/P/C模式及clean Bash 3.2 probe；
- R16四anchors、110/110 manifest通过后的pre-BEGIN零写入、授权未消费与全部
  runtime/root absence；
- R15 immutable failure truth、empty logs、absent screenshot/App与preserved roots；
- driver pre-consumption zero-write、唯一消费点、active fail evidence与fresh names；
- zero product/test/App-script drift、matrix restoration、four-stage provenance；
- planner/reviewer/implementer/Review02/acceptance职责分离；
- canonical Stage §29、Plan §19、leaf §13仍精确为`无。`。

只有`APPROVED — 0 P0 / 0 P1`才允许请求后续新的用户四-hash授权。Review17前及其
通过但未获新授权时，全部执行继续禁止。

## 10. Open Questions

无。
