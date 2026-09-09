# P0 阶段 Spec — 总 Spec 与可执行基线

> 状态：**Accepted — P1-A1a Entry Open**
>
> 日期：2026-07-25
>
> 实施分支：`codex/personal-ai-ranch-p0`
>
> 进入基线：`main@02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> 上位权威：`docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`

## 1. 阶段目标

P0 把已经接受的长期方向转成可执行、可审计、不会误跨阶段的工程基线：

1. 长期总 spec 成为仓库产品方向的 SSOT；
2. 当前代码、测试、构建、真实 App、Provider/CLI、安全边界和已知风险具有可重现证据；
3. 历史产品文档的权威关系明确；
4. P0 开放决策已解决或按总 spec §29 合法延期；
5. P1 有决策完备的阶段 spec、实施 plan 和独立 Review；
6. P0 完成门通过前不修改产品代码。

## 2. 进入条件

| 条件 | 当前证据 | 状态 |
|---|---|---|
| 牧场主接受长期总 spec | 2026-07-25 用户授权按照 spec 自主执行 | 已满足 |
| Codex 长期实施 Goal 已激活 | 当前 Codex Goal objective | 已满足 |
| 当前基线可定位 | `main@02334ec8d21533be81d93d39191bc7d9b9c24f7f` | 已满足 |
| 大规模演进在独立分支 | `codex/personal-ai-ranch-p0` | 已满足 |
| 工作树已有变更归属明确 | 进入时只有总 spec 为本任务新增文件 | 已满足 |

## 3. 范围

### 3.1 必须交付

- 将长期总 spec 标记为 Accepted，并记录 P0 状态；
- 在 `AGENTS.md`、`CLAUDE.md`、`README.md` 和协作协议中建立 SSOT 指针；
- 修正当前 App sandbox/权限事实；
- 建立 `current-state-evidence.md`，所有 claim 都有命令、文件锚点或耐久证据；
- 保存权威测试、App build、真实启动、Provider/CLI 和必要的打包证据；
- 建立 `historical-document-index.md` 和最小 Superseded 标记；
- 建立测试数据安全重置 runbook，但不执行重置；
- 形成 P1 阶段 spec、plan，以及由 Claude Code 或协议允许的职责隔离替代角色产出的独立 plan/review 记录；
- 形成 P0 `impl-report.md`、`acceptance.md` 和完整日志。

### 3.2 非目标

- 不修改 `Sources/`、`Tests` 或产品运行行为；
- 不新增 GRDB migration；
- 不重置真实或 preview 数据；
- 不变更 bundle id、target、状态目录或最终品牌名；
- 不实现 P1 的可靠性修复和领域契约；
- 不邀请真实用户、不发布、不付款、不操作外部生产系统。

## 4. P0 决策

| 开放项 | P0 决定 | 是否影响完成门 |
|---|---|---|
| 产品母体最终品牌名 | 最终品牌名延期；当前产品母体在文档中称“个人 AI 牧场”，当前 App 显示名继续使用“Coding 牧场”，兼容名继续使用 AgentLoop。P0 不做命名迁移 | 否 |
| 历史 spec 标记 | 建立单一历史索引；只给直接冲突的产品方向 spec 添加短 Superseded banner，历史 plan/report/live-test 原文不改 | 是 |
| 测试数据库重置 | P0 明确不重置。先记录正常/preview/自定义状态目录、进程、SQLite sidecar、快照和回退步骤；真正执行仍需精确目标和单独破坏性授权 | 是 |
| Goal 授权同步 | `AGENTS.md` 与协作协议记录阶段内自治和强制暂停边界；不扩大 Git、破坏性或外部操作权限 | 是 |
| Evidence matrix 格式 | 使用 Markdown 表：Evidence ID、claim、对象/HEAD、命令或文件锚点、耐久产物、结果、证据强度、缺口/下一门 | 是 |

## 5. 禁止跨越的红线

1. P0 没有通过完成门前，不得修改产品代码或进入 P1 实施。
2. 未保存完整日志时，不得把终端摘要写成“可复现证据”。
3. Test/build 不能替代真实 App；Preview 不能替代真实后端；CLI 版本不能替代真实调用。
4. 不得把用户凭据、OAuth 回调、账号标识、Keychain 内容或 API key 写入日志。
5. 不得执行数据重置、删除、commit、push、merge、release 或真实用户操作。
6. P1 plan 的 Open questions 非空、未通过独立 Review，或超出总 spec 时，不得开始实现。
7. 任何红测、未知失败、事实冲突或 P0 完成门所需的证据缺口都会阻止 P0 完成；如实登记的阶段外能力缺口不等于把该能力伪装成 P0 成功。

## 6. 完成门

P0 只有在下列条件全部成立时才能标记 Accepted：

- 长期总 spec 状态为 Accepted；
- P0 决策表全部解决或合法延期；
- SSOT、Goal 授权、Git 权限和真实 sandbox 事实在关键文档中一致；
- evidence matrix 覆盖代码、测试、build、真实 App、Provider/CLI、权限、历史和已知风险；
- 权威测试与 App build 在记录的 HEAD 上全绿，完整日志已保存；
- 真实 App 启动与关键页面证据已保存；
- Provider/CLI 供给线的能力与缺口没有被夸大；
- 历史索引和 Superseded 标记完成；
- 测试数据 reset runbook 完成，但没有执行重置；
- P1 阶段 spec、plan 与独立 Review 完成，Open questions 为空；
- 产品代码仍未修改；
- P0 impl report 与 acceptance 逐项引用以上证据。

## 7. 当前阻断门

### Round 5 历史

Round 5 职责隔离独立 Review 结论为 `CHANGES REQUIRED`（4 个 P0、1 个 P1）。
Review 位于 `reviews/05-p1-plan-review.md`，SHA-256 为
`28b4959fedab740c935238eb71537bb62a13474951149371b82c18e85a687f10`。

该轮冻结输入为：

- Stage SHA-256：
  `1124c80ebaaadd6da427540dec19b89dabfc950405975146b2ac7cfa641c504d`
- Plan SHA-256：
  `94828d327dff35e56c7d2c1eb2225b1d4ae02643fcaa613a8883cc5b224ceecd`

牧场主已明确授权按照 `blocked.md` 的范围开启一轮有界修订与职责隔离独立复审。
该授权轮次已经执行完毕并形成 Round 6 冻结输入与 Review06。

### Round 6 Review 结果

Round 6 冻结输入：

- Stage SHA-256：
  `301dcb485b607e99f28be73fbabfa69a560e8d639bf3b0d1dea67d3a1b4aff2c`
- Plan SHA-256：
  `8b2c5dd90f5e6c1a2e05a0804238dd4c0e660d898544ec55ace4a7c1011ac754`

职责隔离独立 Review06 位于 `reviews/06-p1-plan-review.md`，SHA-256 为
`9c688836e1a3d62999740e3f6bec5ca477846ed9f6c9491247de2316c0ab1d68`。
结论为 `CHANGES REQUIRED`（1 个 P0、1 个 P1）：

- P0：9 个规范性 append-only 表所需的 guard 可执行图缺 11 个 trigger；当前
  v16/v17 trigger 数为 56/73，满足合同的完整图应为 67/84；
- P1：普通用户的 Ingestion 删除 API、UI 与 adapter 仍执行物理删除，与 v16
  unconditional DELETE guards 冲突，且 Stage/Plan 尚未决定替代语义。

Review06 结束时继续保持以下 gate：

- 不创建 P0 `acceptance.md`，不把 P0 标记为 Accepted；
- 不实施 P1-A1a，不修改任何产品代码；
- 不 commit、push、merge、release、重置数据或进行外部操作；
- 当时不再授权修改 P1 Stage/Plan；下一轮有界修订与职责隔离独立 Review 必须由
  牧场主再次明确授权；
- 只有新冻结稿的职责隔离独立 Review 得出零 P0/P1，才可继续 P0 acceptance。

### R7 冻结输入与当前 gate

2026-07-26，牧场主明确回复：“授权 R7，并同意上述 Ingestion 删除语义。”该授权
只重新打开 P1 Stage/Plan 的有界修订门，以及冻结后的职责隔离独立 Review07；不
授权产品代码实施。

牧场主同意的 ordinary Ingestion 删除语义固定为：

- `resultOnly`：只允许 active、未归档、未 materialized 的 `needsReview`，或仍有旧
  result 的 `failed`；要求删除判别字段为空，且无 source link、candidate、非终态
  rumination work/provider。物理删除 result 后，以 CAS 把 ingestion 退回
  `queued`、清空 `errorText`、`version + 1`，保留 source/raw 以便重跑；
- `sourceAndResult`：只允许 active 的
  `queued|failed|needsReview|discarded`，删除判别字段为空，且无 source link、
  任何 persisted candidate、非终态 work/provider；可选 result 必须未
  materialized。事务内先删除可选 result，再按精确 count 删除 ingestion；永不删除
  candidate 或 link；
- `everythingIncludingProjection`：永久 typed reject
  `projectionDeletionUnsupported`，不删除 CampNote、Mission、candidate、link 或
  其他投影。archived、`deletionRequested`、`deleting`、
  `deletedTombstone` 或 redacted 的普通删除一律拒绝。

实现合同不得新增表、列或 schema version；复用 v14 append-only
`domain_command_receipt` 与 `domain_event`，以 sealed
`ActiveIngestionDeletionCommandV1`、串行事务、精确 replay/conflict、
revalidation/CAS/count rollback 保证幂等与竞态安全，事件不得含原文。v16 对
candidate/link 保持永久 DELETE guard；result/ingestion 改为精确 event-bound
conditional DELETE guard，替换现有 guard，不增加完整 trigger 总数。

R7 有界修订已经形成冻结候选：

- Stage SHA-256：
  `683a876410689592e5ca7972e1e8206e6763f9baf2da4695ce47bc6b2ab8e40e`
- Plan SHA-256：
  `c7f6e26a10e622e47296a3eb2c2163ec989e26ed519b5d9db8d0ed1b51d25df3`

冻结前职责分离语义审计与结构审计均为 0 P0、0 P1。只读验证覆盖 8 个 SQL
fences；SQLite 3.51/3.52 均得到 79 tables、208 indexes、84 triggers、
`foreign_key_check` 零行与 `integrity_check=ok`；两个 deletion UDF 的规范调用
arity 分别为 53/63；Stage/Plan Markdown fence markers 分别为 42/12 且平衡、
trailing whitespace 为 0；Swift 6 / GRDB 7
`writeWithoutTransaction`/autocommit prototype typecheck 通过；产品路径
`Sources`、`Package.swift`、`scripts` 的 tracked/untracked diff 均为 0，
`git diff --check` 通过。真实 Store/UDF 正例尚未运行，因为实现尚不存在；它仍是
P1-E 的强制实现门，不得把 blueprint 验证描述成运行时通过。

### Review07 结果与当前 gate

职责隔离独立 Review07 位于 `reviews/07-p1-plan-review.md`，SHA-256 为
`7266a4e38e12c20497c4cff4985020a97988372bf363a0e67353ccdc8e49a41a`。
Reviewer 复算确认 Stage/Plan 冻结哈希前后不变，产品代码保持零差异，并给出
`CHANGES REQUIRED`（0 个 P0、2 个 P1）：

- R7-P1-1：v16 literal SQL fence 与规范性 trigger ordinal gate 冲突。Stage/Plan
  要求同一 fence 的最后一个 table/index/drop/rename statement 与 barrier 之后才能
  `CREATE TRIGGER`，但 literal fence 在首个 `CREATE TRIGGER` 后仍有四个
  `DROP TRIGGER`。双 SQLite 结构执行通过，不能替代 literal ordinal 合同；
- R7-P1-2：冻结合同要求 connection close 立即失效 UDF cell 并清除 weak registry
  entry，但 GRDB 7.11.1 的 `Database` 会继续强持有已注册
  `DatabaseFunction`，公开 API 又没有 per-connection close hook。当前授权 API
  无法实现该生命周期合同，必须先决定唯一 owner、绕过防护与测试。

冻结前职责分离语义/结构审计的 0 P0、0 P1 不替代上述独立 Review07。真实
Store/UDF 正例仍未运行，因为实现尚不存在；它继续是 P1-E 强制实现门，不得描述成
运行时通过。

因此零 P0/P1 完成门未满足，R7 授权已经用尽。Stage/Plan 编辑、P0 acceptance、
P1-A1a、产品代码、commit、push、merge、release、data reset 和外部操作全部继续
关闭。再次修改 Stage/Plan 并执行 Review08，必须先取得牧场主新的 R8 明确授权。

### R8 授权、冻结输入与当前 gate

2026-07-26，牧场主明确授权：

> 授权 R8：仅按 E-071 的两个已验证路径有界修订 Stage/Plan，重新冻结后执行职责
> 隔离 Review08；通过前继续禁止 P0 acceptance、P1-A1a 和产品代码实施。

R8 只编码 E-071 已验证的两条关闭路径：

- v16 在 barrier成功后、首个 `CREATE TRIGGER` 前按固定顺序 hoist四个
  surviving-table UPDATE guard drops，之后零DML/resolver/assertion；
- 以 Permit文件唯一拥有的 raw `sqlite3_create_function_v2 + xDestroy` 替代
  `DatabaseFunction` ownership，并冻结 provisional install/reconcile、SQLite真实
  销毁语义与不泄漏能力的封闭 DEBUG lifecycle runner。

R8 Stage/Plan 已重新冻结：

- Stage SHA-256：
  `502393d1413c7ac21616afe0d2e5e847e22e8815d451113806ee94b702d88688`
- Plan SHA-256：
  `1b9ef563b265d6ac0138d083c352837771fc652831e111e92c32d3a36853a4ee`

冻结前 SQL/ordinal、Swift/GRDB lifecycle与跨文档语义/范围三路只读核验均为
0 P0、0 P1；完整证据位于 `evidence/r8-freeze-validation.md`。这些结果不替代
Review08，也不表示真实 Store/UDF正例已运行。

R8 冻结当时 Stage/Plan 编辑门关闭，剩余授权只允许职责隔离独立 Review08。Review08
给出零 P0/P1 前，P0 acceptance、P1-A1a、产品代码、commit、push、merge、release、
data reset与外部操作继续关闭；若 Review08 发现任何 P0/P1，本轮不得自行修订冻结
输入。

### Review08 结果与 P0 最终验收

职责隔离独立 Review08 位于 `reviews/08-p1-plan-review.md`，SHA-256 为
`d4e22ccf8b38b33e013969414d14b17ab32bfb94c549fc9df8c349d44a158755`。
Reviewer 独立复算确认：

- Stage SHA-256 保持
  `502393d1413c7ac21616afe0d2e5e847e22e8815d451113806ee94b702d88688`；
- Plan SHA-256 保持
  `1b9ef563b265d6ac0138d083c352837771fc652831e111e92c32d3a36853a4ee`；
- verdict 为 `APPROVED — 0 P0 / 0 P1`；
- 产品路径 tracked/untracked 差异为零；
- 真实 Store/UDF 正例仍未实现或运行，Review08 没有把 blueprint 可行性描述为
  产品运行成功。

Review08 只打开 P0 最终验收审计。随后两路职责隔离只读审计与主代理复核均确认
§6 的实质完成门已满足；`acceptance.md` 已逐项引用十二项完成门，最终产品路径
仍为零差异。因此 P0 于 2026-07-26 标记为 **Accepted**。

P1-A1a 进入门现已打开，但只允许冻结 `p1-plan.md` §3.1 的 Durable Work DDL +
Store slice。A1a 必须独立实现、验证、Review、验收；通过前不得进入 A1b。commit、
push、merge、release、data reset 和外部操作仍未授权。
