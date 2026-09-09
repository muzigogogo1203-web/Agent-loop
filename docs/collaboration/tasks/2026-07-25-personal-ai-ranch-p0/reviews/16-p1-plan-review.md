# P1-A2 R16 Static-Attestation Plan Review

> Verdict：**APPROVED — 0 P0 / 0 P1**
>
> 日期：2026-07-28
>
> Review 对象：R16 final frozen planning bytes、reviewed BEGIN driver 与 static
> entry manifest

## 1. Scope and independence

本 reviewer 未参与 R16 六面修订、`r16-begin.sh`、`r16-entry.sha256` 或
`plan-freeze-r16.md` 的生成。本次只读审查当前真实 bytes；唯一写入是本 Review16
文件。先前对 driver 的预审不作为、也不替代本 Review16。

本次没有运行 R16 external caller、driver/BEGIN、targeted/full test、build、
migration matrix、source gate、bundle assembly/sign 或 preview；没有访问 normal
state root，没有修改产品/test/App/matrix scripts、R15 evidence、任何 App、Review02
或 acceptance。

允许的静态检查结果：

- `/bin/bash --noprofile --norc -n evidence/r16-begin.sh`：PASS；
- `/usr/bin/shasum -a 256 --strict -c evidence/r16-entry.sha256`：110/110 PASS；
- `git diff --check`：PASS；
- R16 runtime artifacts 与本 Review 在审查开始时均不存在。

## 2. Exact identities reviewed

| Artifact | Current SHA-256 | Result |
|---|---|---|
| canonical Stage | `053b66cb2328b25c81cb471509b90450e364583a48b41c4dabfd5eaa38874165` | exact |
| canonical total Plan | `1cbe04c36e13a45119120c817dde1f40548c97191651daf4d2f751a66619dcd6` | exact |
| A2 leaf Plan | `0bbc6ee512ce03f75be6ce5745ec2e866e70ecbfa011398e32d29984a88b7731` | exact |
| A2 blocked/history | `efc67d9335e330744f6d75d3e4b856408b7e4f0c104f166639866501b7bfce1b` | exact |
| P1 Stage control | `e7af89af798e51adbfd59fa757536e58fc9b2f382fc2f92a8c1a2cf7bb134ff0` | exact |
| P1 Plan control | `7d0975a5c7a4a1c90cb3b146fd7e26c6080e72e21419dbe936bd5ceaa4ee7948` | exact |
| `evidence/r16-begin.sh` | `ffa61fa7c8c281cdb8dfb853b38aafce9536ddcc276e18d64c082de8887b55b0` | exact |
| `evidence/r16-entry.sha256` | `0c2f5dc59e5f0e193214d1c8532a91818a339abdfb3150177c680fe61f8a0b1e` | exact |
| `evidence/plan-freeze-r16.md` | `c10ae51ad78b414aab18c3785b79aac49feb73c47ac5fdcb896ca874ae319867` | exact |

六个 canonical/control surfaces 的 current gate 同义且没有 current stale
opening：

`R15 BEGIN REJECTED_CONTAMINATED；R16 Static-Attestation Candidate Frozen；Review16 Pending；A2 Clean Re-verification Frozen`

历史上曾打开的 R12/R13 gates 均被明确标为 historical/non-current。canonical
Stage §29、total Plan §19、A2 leaf §13 均仍精确为：

`无。`

## 3. R15 immutable rejected boundary

以下 predecessor/current bytes 与 R16 freeze 精确一致：

| Artifact | Current SHA-256 / state |
|---|---|
| `evidence/plan-freeze-r15.md` | `e5ad3967f2e2b26a2bbf8b2ef7be405e8430cc30a82d51a7cb5f51926a99e3d7` |
| `reviews/15-p1-plan-review.md` | `fbaa9612588c39cb5d99e95d9b68e00a234510e325abf5823c15f0b1eb8ecc05`；仅批准 R15 plan |
| `evidence/r15-clean-boundary.log` | `53eb91b840c5c8997fbc9da02d391f210f27b45d73b5e2431a6280a36110ab3b`；永久 `REJECTED_CONTAMINATED` |
| `evidence/r15-hash-manifest.log` | `1589d8d29cf3f8ca9e558c4ac6d4008bdd591194c7e975ecf2fd045e6a935399` |
| `impl-report-r15.md` | `e6b0226b3440da997f7e08571d8e5e5229d66069ea5ad6485ee146c249dbe72e` |
| eight reserved gate logs | 各 0 bytes；`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r15-preview-smoke.png` | absent |
| `/private/tmp/agentloop-r15-state.Zq6Jvm` | directory、non-symlink、empty |
| `/private/tmp/agentloop-r15-bundle.2xROcy` | directory、non-symlink、empty；planned App absent |

failure evidence 诚实保留了 Review12C expected/actual 相同而 helper
false-negative、micro-trigger 未复现、八个后续 gate 未运行、matrix literal 未替换、
产品/test/App scripts 零 delta、planned App/screenshot 缺失及两 root 保留为空。
Review15 没有被错误解释为对失败 execution 的追溯批准，R15 也没有被洗绿。

## 4. Static manifest and acyclic trust chain

`r16-entry.sha256` 当前为 110 行，全部使用 lowercase 64-hex、two spaces 和
`/Users/muzi/Agent-loop/...` absolute path；path 集合按 bytewise 顺序排列且唯一。
110/110 strict check 全绿，分类覆盖与 freeze 一致：

- six current surfaces：6；
- reviewed driver：1；
- A1b review/acceptance anchors：2；
- frozen A2 product/test files：15；
- full-file sentinels、Package、runner、two App scripts、matrix script 与
  RanchArtView：14；
- RanchArt exact regular files：27；
- R13 implementation/incident/Review01 evidence：14；
- original through R15 freezes：11；
- Review12 through Review15 reports：9；
- R15 execution/failure artifacts：11。

manifest 不包含自身、R16 freeze、Review16 或任何 runtime `r16-*` artifact。
六个 surfaces 与 driver 也没有预填 manifest/freeze/Review16 的 downstream/self
hash。信任链因此无环：

`immutable inputs + driver → manifest → freeze → Review16 → later user authorization`

## 5. Driver and external caller

对 driver 的静态控制流审查结论：

1. Bash 3.2 syntax PASS；使用 `set -Eeuo pipefail`、`set -f`、固定 `IFS` 与
   `umask 077`，关键路径使用 absolute command/path，未复用 R15 zsh helper、
   dynamic expected map 或 silent fallback。
2. pre-consumption 只读顺序为 terminal anchors → manifest shape →
   110-entry strict manifest → branch/HEAD → 12 个 runtime paths absent →
   process absence → R15 preserved roots/App/screenshot；该路径不创建 artifact 或
   fresh root。
3. 唯一 authorization consumption point 是 noclobber exclusive-create
   `evidence/r16-clean-boundary.log` 并在同一初始化写入
   `invocation_id`、`authorization_consumed=true` 与 `status=BEGIN_STARTED`。
4. consumption 后才 exclusive-create 九个全新 text logs，再用不同
   `mktemp -d` templates 创建 absolute state/bundle roots；driver 验证其
   non-symlink、empty、realpath identity、distinct、non-nested、非 R15 root，
   planned App absent。
5. activation 后重新 strict-check 四 anchors 与全部 110 entries；anchor pipeline
   保存 producer/shasum `PIPESTATUS`，manifest 保存 raw `OK`/`FAILED`、return code
   与 exact count，worktree status 也写入独立 hash log。
6. RanchArt 结构门冻结 exact 27-name set，独立拒绝 nonregular/symlink node，并记录
   frozen Info.plist 与 RanchArt manifest identities。只有全部结构/hash gate
   通过才写 `begin_attestation_complete=true` 与 `status=BEGIN_ATTESTED`。
7. activation 后 explicit error、unexpected command failure、signal 或
   indeterminate probe 均进入 active fail evidence，记录 phase、reason、
   shell-quoted failed command、真实 exit code、root identity、
   `status=REJECTED_CONTAMINATED` 与 `retry_same_boundary=false`。
8. driver 本身只建立 BEGIN boundary，不运行 test/build/matrix/source/bundle/sign/
   preview；12 个 runtime artifact names 均为全新 R16 names。

freeze 中的 external caller 顺序与 driver position arguments 同为
`freeze, Review16, driver, manifest`。caller 先在 `env -i` 与
`/bin/bash --noprofile --norc` 中对四行 in-memory/stdin anchor manifest 执行
strict check，再 strict-check static manifest，最后才 `exec` driver；任一前置失败
只写 console、标明 `authorization_consumed=false`，不创建 artifact/root。

## 6. Drift, provenance, restoration and ownership

- 110/110 manifest check证明 leaf §2.5 的 15 个产品/test bytes与 frozen
  sentinels保持不变；`scripts/run-app.sh`、`scripts/package-app.sh` 当前 hashes
  分别为
  `5b34e5e98a0e91b4087e20525c3aba81e7955475865d2af70e6ae65736e7997b`、
  `7891aef62cfe26caef766572b5258f0fe206b7ccd8b6f039700834276e6a1705`。
- matrix script 当前 hash 为
  `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`，
  line 115 当前且唯一 `expected_stage_hash` 为 predecessor
  `a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f`。
  冻结合同只在 Review16、后续四-hash授权、external checks 与 BEGIN 全绿后允许
  matrix 前机械替换该单值，并要求成功或失败后立即恢复 entry value/hash；恢复不
  重新打开失败门。
- BEGIN 后机械继承
  `POST_BUILD → PRE_SIGN → LAUNCH_READY`、single ad-hoc sign、same-bundle
  direct exec、bootstrap/cold-start zero-overlap 与 END zero-drift 证明。R13
  installed-App incident、mutation unknown、Review01 和 R15 false negative 必须
  在 Review02/acceptance 中继续披露。
- planner、Review16 reviewer、implementer、Review02 implementation reviewer 与
  acceptance owner 的写入职责互斥；Review16 不写 implementation/runtime evidence，
  implementer 不写 Review/acceptance，Review02 通过前 acceptance 不打开。

## 7. Findings

### P0

无。

### P1

无。

### P2

无。

## 8. Verdict and authorization boundary

**APPROVED — 0 P0 / 0 P1**

本 verdict 只批准 R16 frozen plan/static-attestation boundary，不批准或执行 R16
caller/BEGIN，也不授权 test、build、matrix、source gate、bundle/sign、preview、
产品/test/App-script修改、Review02、acceptance 或 A3。

后续仍必须由 Review16 完成后的**新用户 turn**逐字提供四个 final SHA-256，并按
`freeze, Review16, driver, manifest` 顺序另行授权：

1. R16 freeze：
   `c10ae51ad78b414aab18c3785b79aac49feb73c47ac5fdcb896ca874ae319867`；
2. Review16：本文件落盘后的 final SHA-256；本文件不自填自身 hash；
3. R16 driver：
   `ffa61fa7c8c281cdb8dfb853b38aafce9536ddcc276e18d64c082de8887b55b0`；
4. R16 manifest：
   `0c2f5dc59e5f0e193214d1c8532a91818a339abdfb3150177c680fe61f8a0b1e`。

在该新用户授权到达前，全部执行继续禁止。
