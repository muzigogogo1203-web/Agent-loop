# P0 实施 Plan — 总 Spec 与可执行基线

> 状态：**Completed — P0 Accepted；P1-A1a Accepted；Review10A Approved；P1-A1b Implementation Open**
>
> 本 plan 只允许文档、证据和生成日志变更。

## 1. 目标与非目标

目标、非目标、进入条件、完成门和红线以同目录 `spec.md` 为准。本文只定义执行顺序和文件范围。

## 2. 允许触及的文件

### 现有文件

- `docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`
- `AGENTS.md`
- `CLAUDE.md`
- `README.md`
- `docs/collaboration/claude-codex-protocol.md`
- 由历史索引明确列出的、直接冲突的历史产品方向 spec，仅允许增加 Superseded banner

### 新文件

- 本任务目录下的 `spec.md`
- 本任务目录下的 `plan.md`
- 本任务目录下的 `current-state-evidence.md`
- 本任务目录下的 `historical-document-index.md`
- 本任务目录下的 `test-data-reset-runbook.md`
- 本任务目录下的 `p1-stage-spec.md`
- 本任务目录下的 `p1-plan.md`
- 本任务目录下的 `verify.log`
- 本任务目录下的 `build.log`
- 本任务目录下的 `provider-cli-smoke.log`
- 本任务目录下的 `package.log`
- 本任务目录下的 `evidence/`
- 本任务目录下的 `reviews/`
- 本任务目录下的 `impl-report.md`
- 本任务目录下的 `acceptance.md`

除上述文件外不得修改。

## 3. 执行步骤

1. 记录进入时的 branch、HEAD、worktree 和工具版本。
2. 接受总 spec，并同步 SSOT、自治边界、Git 权限和非沙箱事实。
3. 只读核对代码、Package、脚本、entitlements、运行引擎与已知风险锚点。
4. 建立 evidence matrix、历史索引和 reset runbook。
5. 给直接冲突的历史产品方向 spec 增加最小 Superseded banner。
6. 在同一记录 HEAD 上运行 `swift run RunTests`，保存完整 `verify.log`。
7. 运行 `swift build --product AgentLoopApp`，保存完整 `build.log`。
8. 用现有 CLI 登录态做最小、无敏感输出的 Codex/Claude 真实调用 smoke，保存净化后的结果。
9. 优先对已经运行的 normal App 做只读进程、数据根和关键 UI smoke；只有 normal App 不可用时才启动隔离 preview。不得为了截图重启、提交任务或改变真实数据。
10. 运行打包链并保存结果；签名/公证只报告实际可证明的层级。
11. 让 Claude Code 根据 accepted master spec 和 P0 evidence 编写 P1 阶段 spec/plan；若按协议重试后仍不可用，记录失败，并使用已获授权、职责隔离、证据可追踪的替代规划者。
12. 让与规划者和实现者分离的独立 reviewer 检查 P1 是否决策完备、符合 P1 范围且 Open questions 为空；有 P0/P1 问题则修订并复审。
13. 写 P0 impl report 和逐项 acceptance，检查产品代码零修改。
14. 只有完成门全部通过后，回写总 spec 的 P0 状态并允许进入 P1。

## 4. 错误路径

- 测试或 build 失败：保存完整日志，定位根因；P0 不通过。
- App 无法启动或截图：保存 `.ips`、终端和进程证据；不得用 build 代替。
- CLI 未登录或真实调用失败：记录非敏感错误类别；不得伪造供给线可用。
- Claude Code 不可用：按协议重试一次并保存非敏感失败证据；若总 spec 与协议已授权替代路径，则改用职责隔离的规划者和 reviewer，并在 `reviews/00-claude-availability.md` 记录降级；没有可用替代者才写 `blocked.md`。
- 历史文档语义不清：只进入索引，不修改原文。
- 发现产品代码需要修改才能通过 P0：记录为 P1 风险，不在 P0 修复。

## 5. 验证命令

```bash
swift run RunTests
swift build --product AgentLoopApp
scripts/run-app.sh --preview
scripts/package-app.sh
```

CLI smoke 的精确命令只允许输出固定无敏感字符串，并在 evidence matrix 中记录；任何凭据、账号和回调参数不得落盘。

## 6. 当前停机点

Round 5 历史：`reviews/05-p1-plan-review.md` 对 Round 5 冻结输入给出
`CHANGES REQUIRED`（4 个 P0、1 个 P1），Review SHA-256 为
`28b4959fedab740c935238eb71537bb62a13474951149371b82c18e85a687f10`。
牧场主随后明确授权按照 `blocked.md` 开启一轮有界修订与职责隔离独立复审；该轮
授权已经执行完毕。

Round 6 冻结输入为：

- Stage：
  `301dcb485b607e99f28be73fbabfa69a560e8d639bf3b0d1dea67d3a1b4aff2c`
- Plan：
  `8b2c5dd90f5e6c1a2e05a0804238dd4c0e660d898544ec55ace4a7c1011ac754`

`reviews/06-p1-plan-review.md` 的 SHA-256 为
`9c688836e1a3d62999740e3f6bec5ca477846ed9f6c9491247de2316c0ab1d68`，
结论为 `CHANGES REQUIRED`（1 个 P0、1 个 P1）：

- append-only guard 可执行图缺 11 个 trigger，当前 v16/v17 为 56/73，合同完整图
  应为 67/84；
- ordinary Ingestion delete API/UI/adapter 与 v16 unconditional guards 冲突，
  缺少实施者可直接执行的产品语义决定。

Review06 后，步骤 13–14、P0 acceptance、P1-A1a、全部产品代码实施以及 P1
Stage/Plan 编辑门均关闭。

2026-07-26，牧场主明确回复：“授权 R7，并同意上述 Ingestion 删除语义。”R7 只
重新打开 P1 Stage/Plan 有界修订与冻结后的职责隔离 Review07：

- 关闭 R6-P0-1：补齐 append-only guards，并把 through-v16/through-v17 精确
  trigger 数更新为 67/84；
- 按已同意语义关闭 R6-P1-1：`resultOnly` 在严格 active/non-materialized/
  no-link/no-candidate/no-active-work 前提下删除 result 并 CAS 回 `queued`，
  保留 source/raw；`sourceAndResult` 在无 link、无任何 persisted candidate、
  无非终态 work/provider 且可选 result 未 materialized 时，事务删除可选 result
  与 ingestion；`everythingIncludingProjection` 永久返回
  `projectionDeletionUnsupported`，不删除任何投影；
- 所有 archived/deleting/deleted/redacted ordinary delete 均拒绝；不新增
  schema 对象或版本，复用 v14 `domain_command_receipt`/`domain_event` 与 sealed
  V1 command 做精确 replay/conflict、revalidation、CAS/count rollback，事件不含
  原文；
- v16 对 candidate/link 保持 unconditional DELETE guards，仅把
  result/ingestion guards 替换为 exact event-bound conditional guards，完整
  trigger 总数不因该替换增加。

R7 有界修订已经完成并冻结：

- Stage：
  `683a876410689592e5ca7972e1e8206e6763f9baf2da4695ce47bc6b2ab8e40e`
- Plan：
  `c7f6e26a10e622e47296a3eb2c2163ec989e26ed519b5d9db8d0ed1b51d25df3`

冻结前职责分离语义审计和结构审计均为 0 P0、0 P1。8 个 SQL fences 在 SQLite
3.51/3.52 上均得到 79 tables、208 indexes、84 triggers、FK 0 与 integrity
`ok`；UDF arity 为 53/63；Stage/Plan Markdown markers 为 42/12、平衡且
trailing whitespace 为 0；Swift 6 / GRDB 7
`writeWithoutTransaction`/autocommit prototype typecheck 通过；产品路径 tracked
与 untracked diff 均为 0，`git diff --check` 通过。真实 Store/UDF 正例只能在
P1-E 实现后运行，当前没有宣称通过。

职责隔离独立 Review07 已完成。`reviews/07-p1-plan-review.md` 的 SHA-256 为
`7266a4e38e12c20497c4cff4985020a97988372bf363a0e67353ccdc8e49a41a`，
结论为 `CHANGES REQUIRED`（0 个 P0、2 个 P1）：

- v16 literal SQL fence 在首个 `CREATE TRIGGER` 后仍有四个
  `DROP TRIGGER`，与 Stage/Plan 要求所有 table/index/drop/rename statement 位于
  trigger-install phase 之前的 literal ordinal gate 冲突；
- GRDB 7.11.1 会在 connection close 后继续强持有注册的
  `DatabaseFunction`，公开 API 没有 per-connection close hook，因此无法按冻结合同
  立即失效 UDF cell 并清除 weak registry entry。

冻结前语义/结构审计的 0 P0、0 P1 不替代职责隔离 Review07；真实 Store/UDF 正例
仍未运行并继续保留为 P1-E 实现门。Reviewer 确认 Stage/Plan 冻结哈希前后不变，
产品代码零差异。

R7 授权已经用尽。步骤 13–14、P0 acceptance、P1-A1a、Stage/Plan 编辑、产品代码、
commit、push、merge、release、data reset 与外部操作继续关闭。只有牧场主明确授权
R8，才可围绕上述两个 P1 修订 Stage/Plan、重新冻结并执行职责隔离 Review08。

牧场主随后明确授权 R8，范围严格固定为 E-071 的两个已验证路径。R8 已完成有界
修订与三路冻结前只读核验，并冻结为：

- Stage：
  `502393d1413c7ac21616afe0d2e5e847e22e8815d451113806ee94b702d88688`
- Plan：
  `1b9ef563b265d6ac0138d083c352837771fc652831e111e92c32d3a36853a4ee`

SQL/ordinal、Swift/GRDB lifecycle与语义/范围预审均为0 P0、0 P1；耐久证据为
`evidence/r8-freeze-validation.md`。这不是 Review08，真实 Store/UDF正例仍未运行。

R8 冻结当时的执行点为步骤12的职责隔离独立 Review08。Stage/Plan编辑门关闭；Review08
通过前继续关闭步骤13–14、P0 acceptance、P1-A1a、产品代码、commit、push、merge、
release、data reset与外部操作。Review08若发现 P0/P1，R8授权即用尽，不得在本轮
直接修改冻结输入。

Review08 已在冻结哈希不变、产品路径零差异的前提下给出
`APPROVED — 0 P0 / 0 P1`；报告 SHA-256 为
`d4e22ccf8b38b33e013969414d14b17ab32bfb94c549fc9df8c349d44a158755`。
两路只读 P0 最终审计均未发现实质 blocker。步骤13–14现已完成：

- `impl-report.md` 与 `acceptance.md` 已逐项引用完成门；
- master spec、P0 spec/plan、blocked 和 evidence matrix 已同步终态；
- P1 Stage/Plan 冻结字节与 Review08 哈希保持不变；
- 产品路径 tracked/untracked/staged 差异仍为零；
- 最终完整性证据位于 `evidence/p0-final-acceptance-audit.md`。

P0 与 P1-A1a 已 Accepted。P1-A1b 只读 planning/entry 审计在
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1b-durable-planning/blocked.md`
记录的七项冻结契约缺口，已由牧场主明确授权的 R10 有界修订形成 candidate
closure。首轮 R10 冻结输入为：

- Stage：
  `36420de83e30043665c72d8ad8f0cf6ed98e930df296327c9f2d19bc9a72e62e`
- P1 总 Plan：
  `e89f7e972f665a49f1bd07bd4921ad86e6ce595429344718639ef0688f8b32af`
- A1b leaf Plan：
  `bb5aa2cd5e7eb7e0cfcbd472b63382d4e5d0a0afd6d4e195737772e82f8c35be`

冻结与产品/test 零变更指纹证据位于
`evidence/r10-freeze-validation.md`。职责隔离 Review10 在上述 hashes 上判定
`CHANGES REQUIRED — 0 P0 / 2 P1`；不可变报告
`reviews/10-p1-plan-review.md` 的 SHA-256 为
`acac1f5b09359f27a095acb12804a58daf6ac3d1250dc5fb7309699cd21851c1`。

两个 finding 分别属于既有 R10-6 generic planning capability 与 R10-1 App
入口可执行验证根因，已在同一 R10 授权内有界关闭并冻结为 Candidate 2：

- Stage：
  `d05452fd0a877fb03e94ff0e1a75a0efa3b095c93c14ff856c79da04619db3a6`
- P1 总 Plan：
  `b14c145c433a03606c925d5f027d7a3a25d458b07a2a5bb447a29424cce58a61`
- A1b leaf Plan：
  `cf1b603c2147a2cb2619a5230ff3b71a41b2968f78e0c3e28480da09460feb0e`

重新冻结、双路预审归零与产品/test/Package 零漂移证据位于
`evidence/r10a-freeze-validation.md`。职责隔离 Review10A 已在 Candidate 2 精确
hashes 上给出 `APPROVED — 0 P0 / 0 P1`；报告
`reviews/10a-p1-plan-review.md` 的 SHA-256 为
`a268725470996d04db109b4caeb378fdfa64b66abd85b6f7ac55ecb420956bfe`。
A1b implementation gate 已打开，implementer 只能按 frozen leaf §3/§11 实施。
A1b acceptance 前不得进入 A2。Git、数据重置、release 和外部操作权限没有扩大。
