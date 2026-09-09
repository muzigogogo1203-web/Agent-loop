# P1-A2 R16 Static-Attestation Plan Freeze

> 状态：R16 Static-Attestation Candidate Frozen；Review16 Pending；全部执行继续禁止
>
> 日期：2026-07-28
>
> 分支：`codex/personal-ai-ranch-p0`
>
> HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. 授权范围与停止线

牧场主授权R16只关闭R15 BEGIN executor-attestation false negative：

- 同步三份canonical、A2 blocked与两个P1 control surfaces；
- 新增reviewed `r16-begin.sh`、static `r16-entry.sha256`与本freeze；
- 重新冻结后只执行职责隔离Review16。

本授权不允许运行R16 driver/BEGIN、targeted/full test、build、migration matrix、
source gate、bundle assembly/sign或preview，不允许修改产品/test/App/matrix
scripts，不允许创建Review02/acceptance、进入A3、commit、push、merge、release、
normal-data、外部或真实用户操作。Review16通过本身也不执行；必须等待后续新的用户
turn逐字给出四个terminal hashes并另行授权。

## 2. R16 final planning identities

### 2.1 Six canonical/control surfaces

| Surface | Absolute path | SHA-256 |
|---|---|---|
| canonical Stage | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | `053b66cb2328b25c81cb471509b90450e364583a48b41c4dabfd5eaa38874165` |
| canonical total Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | `1cbe04c36e13a45119120c817dde1f40548c97191651daf4d2f751a66619dcd6` |
| A2 leaf Plan | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | `0bbc6ee512ce03f75be6ce5745ec2e866e70ecbfa011398e32d29984a88b7731` |
| A2 blocked/history | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/blocked.md` | `efc67d9335e330744f6d75d3e4b856408b7e4f0c104f166639866501b7bfce1b` |
| P1 Stage control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md` | `e7af89af798e51adbfd59fa757536e58fc9b2f382fc2f92a8c1a2cf7bb134ff0` |
| P1 Plan control | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md` | `7d0975a5c7a4a1c90cb3b146fd7e26c6080e72e21419dbe936bd5ceaa4ee7948` |

六面current状态同义：

`R15 BEGIN REJECTED_CONTAMINATED；R16 Static-Attestation Candidate Frozen；Review16 Pending；A2 Clean Re-verification Frozen`

### 2.2 Reviewed driver and static manifest

| Artifact | Absolute path | SHA-256 / invariant |
|---|---|---|
| reviewed BEGIN driver | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r16-begin.sh` | `ffa61fa7c8c281cdb8dfb853b38aafce9536ddcc276e18d64c082de8887b55b0`；Bash 3.2 `-n` PASS；independent driver audit `APPROVED — 0 P0 / 0 P1 / 0 P2` |
| static entry manifest | `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r16-entry.sha256` | `0c2f5dc59e5f0e193214d1c8532a91818a339abdfb3150177c680fe61f8a0b1e`；110 entries；`shasum --strict -c` PASS |

`r16-entry.sha256`使用`<lowercase 64-hex><two spaces><absolute path>`，按absolute
path bytewise sorted unique。110项覆盖：

| Class | Count |
|---|---:|
| six current surfaces | 6 |
| reviewed R16 driver | 1 |
| A1b review/acceptance entry anchors | 2 |
| A2 product/test frozen files | 15 |
| full-file sentinels/Package/runner/App/matrix scripts/RanchArtView | 14 |
| RanchArt exact regular files | 27 |
| R13 implementation/incident/Review01 evidence | 14 |
| original through R15 plan freezes | 11 |
| Review12 through Review15 plan reviews | 9 |
| R15 execution/failure artifacts | 11 |
| **Total** | **110** |

manifest明确不包含自身、本freeze、Review16或任何runtime `r16-*` artifact。六个
surfaces与driver也不嵌入manifest、本freeze或Review16的后生成hash。

## 3. Acyclic trust chain

唯一信任链为：

```text
immutable inputs + final six surfaces + reviewed r16-begin.sh
  → static r16-entry.sha256
  → plan-freeze-r16.md
  → reviews/16-p1-plan-review.md
  → later user authorization carrying four terminal hashes
```

- 本freeze记录surfaces/driver/manifest hashes，但不记录自身hash或尚未生成的
  Review16 hash；
- Review16只绑定本freeze及其predecessors，不记录自身hash；
- 完整`freeze + Review16 + driver + manifest`四元组只能由Review16后的新用户
  authorization提供；
- 不允许upstream自填、推导或回写self/downstream hash。

## 4. Immutable R15 rejected boundary

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
被该invocation访问。R16不得覆盖、追加、补齐、删除、清理、重命名或复用上述任何
文件、absence或root。

已确认的根因边界仅为：R15 helper在Review12C expected/actual均为
`db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109`
时false-negative；更底层micro-trigger未复现。R16通过static manifest与standard
`shasum --strict -c`整体替换该风险类，不宣称small fix修复未知机制。

## 5. Exact zero-write external caller

Review16通过且后续新用户提供四个final hashes后，只可用下列clean caller。argument
顺序固定为`freeze, Review16, driver, manifest`：

```bash
/usr/bin/env -i \
  LC_ALL=C LANG=C PATH=/usr/bin:/bin:/usr/sbin:/sbin TMPDIR=/private/tmp \
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
  /bin/bash --noprofile --norc -c '
set -Eeuo pipefail
set -f
IFS=$'"'"' \t\n'"'"'

readonly r16_root=/Users/muzi/Agent-loop
readonly r16_task="$r16_root/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination"
readonly r16_freeze="$r16_task/evidence/plan-freeze-r16.md"
readonly r16_review="$r16_root/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/16-p1-plan-review.md"
readonly r16_driver="$r16_task/evidence/r16-begin.sh"
readonly r16_manifest="$r16_task/evidence/r16-entry.sha256"

r16_anchor_fail() {
  /usr/bin/printf \
    "R16_ANCHOR_REJECTED code=%s reason=%s authorization_consumed=false\n" \
    "$1" "$2" >&2
  exit "$1"
}

[[ "$#" -eq 4 ]] || r16_anchor_fail 64 invalid_argument_count
for r16_hash in "$@"; do
  [[ "${#r16_hash}" -eq 64 ]] || r16_anchor_fail 64 malformed_terminal_hash
  case "$r16_hash" in *[!0-9a-f]*) r16_anchor_fail 64 malformed_terminal_hash ;; esac
done
for r16_path in "$r16_freeze" "$r16_review" "$r16_driver" "$r16_manifest"; do
  [[ -f "$r16_path" && ! -L "$r16_path" ]] ||
    r16_anchor_fail 65 invalid_terminal_artifact_type
done

if ! /usr/bin/printf "%s  %s\n%s  %s\n%s  %s\n%s  %s\n" \
  "$1" "$r16_freeze" \
  "$2" "$r16_review" \
  "$3" "$r16_driver" \
  "$4" "$r16_manifest" |
  /usr/bin/shasum -a 256 --strict -c -; then
  r16_anchor_fail 65 terminal_anchor_failure
fi
if ! /usr/bin/shasum -a 256 --strict -c "$r16_manifest"; then
  r16_anchor_fail 66 static_manifest_failure
fi

exec /bin/bash --noprofile --norc "$r16_driver" "$1" "$2" "$3" "$4" ||
  r16_anchor_fail 74 driver_exec_failure
' r16-anchor \
  '<R16_FREEZE_SHA>' '<REVIEW16_SHA>' '<R16_DRIVER_SHA>' '<R16_MANIFEST_SHA>'
```

caller不重定向、不创建temp/artifact/root，不运行driver以外的任何gate。anchor或
static-manifest任一失败只写console、`authorization_consumed=false`、不进入driver。

## 6. Reviewed driver contract

`r16-begin.sh`只建立BEGIN boundary，不运行测试、构建、matrix、source、bundle、
sign或preview：

1. pre-BEGIN验证exact clean env、四anchors、110-entry static manifest、absolute/
   sorted/unique/regular/non-symlink shape、branch/HEAD、全部R16 runtime paths
   absent、AgentLoop/AgentLoopApp进程为0、R15 screenshot/planned App absent及两个
   R15 roots存在且为空；失败零写入、不消费授权；
2. 只在pre-BEGIN全绿后exclusive-create`evidence/r16-clean-boundary.log`并立即写
   current invocation ID与`authorization_consumed=true`；该点是唯一消费点；
3. consumption后exclusive-create九个text logs，创建两个fresh、absolute、
   non-symlink、empty、distinct、non-nested且不复用R15的state/bundle roots；
4. activation后再次检查四anchors、manifest shape与全部110 hashes，将raw
   `OK`/`FAILED`、producer/shasum return codes、exact count与worktree status写入
   `evidence/r16-hash-manifest.log`；
5. 结构门证明RanchArt exact 27 regular-file path set、零nonregular/symlink node，
   并记录frozen Info.plist
   `5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58`
   与RanchArt derived manifest
   `4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab`；
6. 只有上述全绿才写`begin_attestation_complete=true`与`status=BEGIN_ATTESTED`；
   consumption后任一error/signal/indeterminate probe永久写
   `REJECTED_CONTAMINATED`、phase、真实command/rc、root identity与
   `retry_same_boundary=false`。

## 7. Fresh R16 runtime artifacts

Review16和后续四-hash授权前，以下paths必须全部不存在：

- `r16-targeted-tests.log`
- `r16-verify.log`
- `r16-build.log`
- `r16-migration-matrix.log`
- `impl-report-r16.md`
- `evidence/r16-clean-boundary.log`
- `evidence/r16-bundle-provenance.log`
- `evidence/r16-source-gates.log`
- `evidence/r16-hash-manifest.log`
- `evidence/r16-preview-bootstrap.log`
- `evidence/r16-preview-cold-start.log`
- `evidence/r16-preview-smoke.png`

BEGIN通过后，R16机械继承canonical Stage §28.2.2–§28.2.4与§28.3.4、A2 leaf
§10–§12冻结的POST_BUILD→PRE_SIGN→LAUNCH_READY、same-bundle direct exec、
matrix line-115唯一Stage hash临时delta/mandatory restoration、normal-root
isolation、fail-once、Review02与scoped acceptance合同。R16不修改schema/API/event/
package、15个产品/test bytes或两条App scripts。

## 8. Review16 gate

未参与R16修订、driver/manifest/freeze生成的职责隔离reviewer唯一可写：

`/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/16-p1-plan-review.md`

Review16必须以当前真实bytes核对：

- 本freeze中的六面、driver、manifest hashes；
- static manifest 110/110 strict PASS、无环排除与coverage；
- R15 immutable failure truth、empty logs、absent screenshot/App与preserved roots；
- driver pre-consumption zero-write、唯一消费点、active fail evidence与fresh names；
- zero product/test/App-script drift、matrix restoration、four-stage provenance；
- planner/reviewer/implementer/Review02/acceptance职责分离；
- canonical Stage §29、Plan §19、leaf §13仍精确为`无。`。

只有`APPROVED — 0 P0 / 0 P1`才允许请求后续新的用户四-hash授权。Review16前及其
通过但未获新授权时，全部执行继续禁止。

## 9. Open Questions

无。
