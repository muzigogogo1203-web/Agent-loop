# P1-A2 R15 Clean Re-verification Implementation Report

> 结论：**REJECTED_CONTAMINATED — BEGIN attestation false negative**
>
> 日期：2026-07-28
>
> Invocation：`r15-e20bac70-dead-4c21-8d42-541b0b8077b3`

## 1. Entry snapshot

- Branch：`codex/personal-ai-ranch-p0`
- HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
- R15 freeze：
  `e5ad3967f2e2b26a2bbf8b2ef7be405e8430cc30a82d51a7cb5f51926a99e3d7`
- Review15：
  `fbaa9612588c39cb5d99e95d9b68e00a234510e325abf5823c15f0b1eb8ecc05`
  且 verdict 为 `APPROVED — 0 P0 / 0 P1`
- 授权在新的用户 turn 中明确给出，并于
  `2026-07-28T18:00:01Z` 写入 BEGIN 后消费。

BEGIN 前只读 preflight 曾因 zsh 的特殊 `path` 参数被循环变量误用、覆盖 shell
`PATH` 而在执行 `git` 前返回非零。该次 preflight 没有创建任何 R15 artifact 或
fresh root，没有写 BEGIN，没有运行 test/build/matrix/source/bundle/preview，
因此没有消费授权。修正只读变量名后，preflight 证明：

- 12 个 R15 artifact paths 全部不存在；
- `AgentLoop` / `AgentLoopApp` process count 为 0；
- branch、HEAD、freeze、Review15匹配。

## 2. BEGIN and exact failure

BEGIN exclusive-created下列两个fresh、互不嵌套且为空的roots：

- state root：`/private/tmp/agentloop-r15-state.Zq6Jvm`
- bundle parent：`/private/tmp/agentloop-r15-bundle.2xROcy`

planned App
`/private/tmp/agentloop-r15-bundle.2xROcy/AgentLoop.app`
从未被创建。

BEGIN随后依次验证并记录了：

- 六个current canonical/control surfaces、R15 freeze、Review15、R14
  freeze/Review14；
- §2.5全部15个产品/test bytes；
- Package、runner、lock/resolver/result/materializer/EventKind、两条App scripts、
  matrix script、RanchArtView；
- 全部R13 implementation/incident artifacts；
- R12–R13B freezes以及Review12、12A、12B。

这些已执行项全部匹配冻结值。到 Review12C 时，attestation helper写出：

```text
review12c=db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109
review12c_expected=db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109
review12c_actual=db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109
```

尽管expected与actual逐字相同，helper仍执行了mismatch分支，并于
`2026-07-28T18:00:02Z`写：

```text
status=REJECTED_CONTAMINATED
reason=hash_mismatch:review12c
```

失败后的只读诊断重新计算两侧均为64字符、逐字相等；对同一review list的独立
comparison probe也全部返回equal。该false-negative在只读probe中未复现。

因此已确认的根因边界是：**R15 executor attestation logic产生了错误拒绝，而不是
Review12C或仓库bytes发生漂移**。更底层的触发机制仍缺乏足够证据；不得宣称已修复。
下一次计划若获授权，必须冻结一个带局部变量、比较前`%q`/length证据和明确
comparison result的attestation实现，并使用新的artifact names；不能复用本次
helper或本次boundary。

## 3. Fail-closed containment

按照leaf §11.4，本invocation永久保持`REJECTED_CONTAMINATED`，没有在同一boundary
重跑或继续后续门。containment独立证明：

- `AgentLoop` / `AgentLoopApp` process count：0；
- state root仍为空；
- bundle parent仍为空；
- planned App不存在；
- matrix script仍为entry SHA-256
  `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`；
- matrix Stage hash从未临时替换；
- 产品/test没有被修改；
- normal state root没有被读取、列举、stat、hash、SQLite-open、重置或写入；
- 两个fresh roots按失败证据要求保留，没有清理或复用。

## 4. Verification results

本轮在BEGIN失败后没有运行任何后续gate：

| Gate | Result |
|---|---|
| 41-name targeted tests | NOT RUN |
| authoritative `swift run RunTests` | NOT RUN |
| App debug build | NOT RUN |
| Core release build | NOT RUN |
| migration matrix | NOT RUN |
| source/privacy gates | NOT RUN |
| bundle assembly / Info.plist / codesign | NOT RUN |
| POST_BUILD / PRE_SIGN / LAUNCH_READY | NOT REACHED |
| bootstrap preview | NOT RUN |
| cold-start preview | NOT RUN |
| screenshot | NOT CREATED |
| END | NOT WRITTEN |

因此本报告不声称41 tests、完整RunTests、build、matrix、source gates、bundle
provenance、isolated preview或A2 completion通过，也不打开Review02、acceptance
或A3。

## 5. New artifacts and hashes

| Artifact | SHA-256 / state |
|---|---|
| `evidence/r15-clean-boundary.log` | `53eb91b840c5c8997fbc9da02d391f210f27b45d73b5e2431a6280a36110ab3b` |
| `evidence/r15-hash-manifest.log` | `1589d8d29cf3f8ca9e558c4ac6d4008bdd591194c7e975ecf2fd045e6a935399` |
| `r15-targeted-tests.log` | empty；`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `r15-verify.log` | empty；same empty-file hash |
| `r15-build.log` | empty；same empty-file hash |
| `r15-migration-matrix.log` | empty；same empty-file hash |
| `evidence/r15-bundle-provenance.log` | empty；same empty-file hash |
| `evidence/r15-source-gates.log` | empty；same empty-file hash |
| `evidence/r15-preview-bootstrap.log` | empty；same empty-file hash |
| `evidence/r15-preview-cold-start.log` | empty；same empty-file hash |
| `evidence/r15-preview-smoke.png` | not created |

本报告是本轮最后一个implementation artifact；其SHA-256在报告落盘后外部记录。

## 6. Historical truth and scope

- R13 whole invocation继续是`REJECTED_CONTAMINATED`；
- R13 installed-App normal-root incident与mutation `UNKNOWN`没有被本轮改变；
- Review01与Review14 verdict没有被推翻；
- Review15只批准R15 plan，不会把本次失败洗绿；
- 本轮没有commit、push、merge、release、外部或真实用户操作。

## 7. Deviations

- 没有获得或使用任何扩大范围的deviation authorization。
- BEGIN executor产生false-negative后严格停止；未以“expected与actual其实相等”为由
  绕过冻结的fail-once规则。

新的尝试必须先取得plan-level有界授权，冻结新artifact names与可观测
attestation逻辑，并重新接受职责隔离plan review。
