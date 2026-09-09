# P0 Gate Record — Accepted / P1-A1a Entry Open

> 状态：**P0 Accepted — no active P0 blocker**
>
> 日期：2026-07-26

## Round 5 阻断事实（历史）

牧场主授权的 Round 5 有界修订与职责隔离独立 Review 已执行完毕。冻结输入：

- `p1-stage-spec.md`：
  `1124c80ebaaadd6da427540dec19b89dabfc950405975146b2ac7cfa641c504d`
- `p1-plan.md`：
  `94828d327dff35e56c7d2c1eb2225b1d4ae02643fcaa613a8883cc5b224ceecd`

Round 5 结论为 `CHANGES REQUIRED`，包含 4 个 P0、1 个 P1；P1-A1a 未获
实施授权。完整证据位于 `reviews/05-p1-plan-review.md`，其 SHA-256 为
`28b4959fedab740c935238eb71537bb62a13474951149371b82c18e85a687f10`。
Reviewer 已确认 Stage/Plan 哈希在审查前后不变，且产品代码零 diff。

## Round 5 必须关闭的 finding（历史）

1. **R5-P0-1：pending terminal proposal 删除死锁。** 普通 Engine terminal
   commit 被 deletion fence 拒绝，而 deletion permit 没有专用、可恢复、覆盖全部
   proposal/artifact 形状的 closeout。
2. **R5-P0-2：legacy artifact 存在永久 blocker。** unresolved legacy artifact
   没有 typed 用户/adapter 裁决状态机；即使已证明文件位于全部 managed roots
   之外，当前 `evidenceKind` CHECK 也无法把它持久化为 workspace external。
3. **R5-P0-3：擦除 registry/schema 没有可实现的完整终态。**
   `artifact_storage_origin` 无 tombstone shape；已知遗漏包括
   `approval_grant_use.adapterOperationId`、
   `engine_execution.cancellationReason` 与
   `engine_terminal_proposal.invalidReason`。Card、Rumination、Engine 等 JSON
   tombstone 还与正常 typed decode 形状冲突，缺少逐列 sentinel 和
   redacted-row-first decode 规则。
4. **R5-P0-4：redaction guard 不是 one-shot。** legacy event 可重复 marker
   UPDATE；已经 redacted 的 provider row 还能单独改写 retained request hash 等
   审计字段。
5. **R5-P1-1：v16 migration 顺序不具 SQLite 可移植性。** provider trigger
   在 `camp_deletion_job` 建表前引用它；SQLite 3.51 接受，但 SQLite 3.52 在
   durable-work rename 时重验 schema 并失败。

补充只读审计没有增加 finding 类别或计数，只把上述 P0-2/P0-3 的关闭范围明确到
exact enum、字段和 JSON decode contract。

## Round 5 当时的权限与红线（历史）

Round 5 是牧场主明确授权的单轮有界修订/复审；它已经用尽。本 Review 不授权
下一轮静默修订，当前也没有新的牧场主授权。因此：

- 不修改 Round 5 冻结 Stage/Plan；
- 不实施 P1-A1a，不修改产品代码；
- 不创建 P0 acceptance，不把 P0 标记为 Accepted；
- 不 commit、push、merge、release、重置数据或进行外部操作；
- 只有牧场主明确授权新的有界修订与职责隔离独立 Review，才可重新打开规划编辑门。

## Round 5 当时需要牧场主决定（历史）

是否授权再增加一轮有界修订与职责隔离独立 Review，范围严格固定为一次性关闭本文件
列出的 R5-P0-1…P0-4、R5-P1-1 及其已归并的补充字段/shape，并在 Review 通过前
继续禁止全部产品代码实施。

## Round 5 后牧场主授权结果（已执行）

牧场主已明确授权按照本文件范围开启一轮有界修订与职责隔离独立复审，并要求在
通过前继续禁止产品代码实施。该授权：

- 只重新打开 P1 Stage/Plan 编辑门；
- 要求把 pending proposal deletion supersession、proposal blob cleanup/GC root、
  unknown artifact detach-only authority、artifact origin tombstone、逐列 privacy
  disposition、typed JSON redacted-first、user-request 删除终态、全行
  post-redaction lock 与 SQLite 3.52-safe migration order 一次性纳入；
- 要求重新冻结 Stage/Plan 哈希，并由未参与本轮修订的 reviewer 独立审查；
- 不授权产品代码、P1-A1a、P0 acceptance、commit、push、merge、release、数据
  重置或任何外部操作。

本文件继续保留为 Round 5 finding 与本轮授权边界的耐久证据；执行状态由 P0
`spec.md`、`plan.md`、`impl-report.md` 和总 spec 继续追踪。

## Round 6 当前阻断事实

上述授权轮次已经完成。Round 6 冻结输入为：

- `p1-stage-spec.md`：
  `301dcb485b607e99f28be73fbabfa69a560e8d639bf3b0d1dea67d3a1b4aff2c`
- `p1-plan.md`：
  `8b2c5dd90f5e6c1a2e05a0804238dd4c0e660d898544ec55ace4a7c1011ac754`

职责隔离独立 Review06 位于 `reviews/06-p1-plan-review.md`，SHA-256 为
`9c688836e1a3d62999740e3f6bec5ca477846ed9f6c9491247de2316c0ab1d68`。
Reviewer 确认冻结输入前后哈希不变、产品代码零 diff，并给出
`CHANGES REQUIRED`：1 个 P0、1 个 P1。零 P0/P1 完成门未满足。

## Round 6 必须精确关闭的 finding

### R6-P0-1：append-only guard 可执行图缺 11 个 trigger

Stage 的规范合同要求 9 个 append-only 表均具有 UPDATE/DELETE guard；对允许
finalizing 首次 redaction 的表，只能替换 UPDATE guard，DELETE guard 必须保留。
当前可执行图 through-v16/through-v17 只有 56/73 个 trigger，而合同完整图应为
67/84。必须在同一有界修订中：

1. 在各表的 introducing migration 安装标准 UPDATE/DELETE abort guards；
2. v16 安装 durable attempt-event redaction exception 前，显式替换其标准 UPDATE
   guard 并保留 DELETE guard；Verification、Acceptance、external receipt 同理；
3. 补齐 `domain_command_receipt`、`domain_event`、
   `verification_invalidation`、`memory_dependency` 的 UPDATE/DELETE guards，
   以及 Verification、Acceptance、external receipt 缺失的 DELETE guards；
4. 把 Stage/Plan 的 v16/v17 精确 trigger 数同步更新为 67/84；
5. 在每个 introducing-slice migration gate 和 SQLite 3.51/3.52 两条 lane 中，
   对 9 个表插入合法行并证明普通 UPDATE/DELETE 均 abort；对 5 个允许删除擦除的
   表，另证明 finalizing 首次 UPDATE 成功，而 wrong-phase、second/no-op、
   extra-column UPDATE 和 DELETE 均 abort；
6. 证明被拒绝的 `domain_event` DELETE 不会留下或制造 dangling
   `camp_event_scope`。

### R6-P1-1：ordinary Ingestion delete 与 v16 guards 冲突

当前三个 `IngestionDeletionScope`、public protocol、UI 文案和 adapter 会物理删除
`rumination_result`、`action_candidate` 与 `ingestion_item`；v16 对这些表安装
unconditional DELETE guards，且只有 Camp deletion finalizing redaction exception。
必须在 v16 之前或同一 slice 做出唯一、可实施的决定：

1. 精确定义三个 `IngestionDeletionScope` 的 post-v16 语义；
2. 指定准确 slice 与全部 owner：contracts、adapter/controller、live host、UI
   wording、records/store 和 tests；
3. 若保留删除，定义 active-Camp typed user-deletion authority、terminal
   state/tombstone、provenance、精确字段、race、idempotency 与 one-shot guards，
   且不得削弱 Camp-deletion evidence；
4. 若移除或延期，在 v16 前移除/禁用 protocol 与 UI promise，并定义替代 UX；
5. 为三个 scope、materialized/source-link blockers、retry/replay 和 post-v16 UI
   行为增加 migration/runtime tests。

## Round 6 Review 后权限与红线（历史）

Round 6 的有界修订与职责隔离独立 Review 授权已经执行完毕；Review06 不授权静默
开启下一轮。因此：

- 不修改 Round 6 冻结 Stage/Plan；
- 不实施 P1-A1a，不修改产品代码；
- 不创建 P0 acceptance，不把 P0 标记为 Accepted；
- 不 commit、push、merge、release、重置数据或进行外部操作；
- 只有牧场主再次明确授权新的有界 Stage/Plan 修订与职责隔离独立 Review，才可
  重新打开规划编辑门；
- 新冻结稿取得零 P0/P1 verdict 前，P0 acceptance 与全部 P1 实施持续关闭。

## Round 6 Review 后需要牧场主决定（历史）

是否再次授权一轮有界 Stage/Plan 修订与职责隔离独立 Review，范围严格固定为一次性
关闭 R6-P0-1 与 R6-P1-1 的上述 exact closure，并在 Review 通过前继续禁止全部产品
代码实施。

## R7 牧场主授权结果

2026-07-26，牧场主明确回复：“授权 R7，并同意上述 Ingestion 删除语义。”

该授权只重新打开：

- 按 R6-P0-1 与下述已决 R6-P1-1 语义修订 P1 Stage/Plan；
- 修订完成后的哈希冻结与职责隔离独立 Review07。

该授权本身当时不表示 R7 修订、验证或 Review07 已完成，也不授权产品代码、
P1-A1a、P0 acceptance、commit、push、merge、release、data reset 或任何外部
操作。当前 R7 修订、冻结前验证与 Review07 均已完成；Review07 的非通过 verdict
见下文。

### 已同意的 ordinary Ingestion 删除语义

1. `resultOnly`
   - 只允许 active、未归档、未 materialized 的 `needsReview`，或仍带旧 result
     的 `failed`；
   - `terminalReason`/`redactedAt` 为空，且无 `knowledge_source_link`、任何
     persisted `action_candidate`、非终态 rumination work/provider；
   - 物理删除 result，并以 CAS 将 ingestion 更新为 `queued`、
     `errorText = NULL`、`version + 1`；source/raw 保留，可重新反刍。
2. `sourceAndResult`
   - 只允许 active 的 `queued|failed|needsReview|discarded`，且
     `terminalReason`/`redactedAt` 为空；
   - 必须无 `knowledge_source_link`、无任何 persisted `action_candidate`、无
     非终态 work/provider；可选 result 必须未 materialized；
   - 单事务先删除可选 result，再按精确 count 删除 ingestion；永不删除
     candidate 或 link。
3. `everythingIncludingProjection`
   - 永久 typed reject `projectionDeletionUnsupported`；
   - 不删除 CampNote、Mission、candidate、link 或任何其他投影。

archived、`deletionRequested`、`deleting`、`deletedTombstone` 或 redacted 的
ordinary delete 一律拒绝。

### Guard、receipt 与 replay 方向

- 不新增表、列或 schema version；
- 复用 v14 append-only `domain_command_receipt` 与 `domain_event`；
- 使用 sealed `ActiveIngestionDeletionCommandV1`，在串行事务中执行精确
  replay/conflict、revalidation、CAS 与 row-count rollback；事件不得含原文；
- v16 对 candidate/link 保持永久 unconditional DELETE guards；
- result/ingestion 改为 exact event-bound conditional DELETE guards；这是替换，
  不增加完整 trigger 总数。

## R7 冻结结果

R7 有界修订已经完成并冻结：

- `p1-stage-spec.md`：
  `683a876410689592e5ca7972e1e8206e6763f9baf2da4695ce47bc6b2ab8e40e`
- `p1-plan.md`：
  `c7f6e26a10e622e47296a3eb2c2163ec989e26ed519b5d9db8d0ed1b51d25df3`

冻结前职责分离语义审计与结构审计均为 0 P0、0 P1。8 个 SQL fences 在 SQLite
3.51/3.52 上均得到 79 tables、208 indexes、84 triggers、FK 0 与 integrity
`ok`；UDF arity 为 53/63；Stage/Plan Markdown markers 为 42/12、平衡且
trailing whitespace 为 0；Swift 6 / GRDB 7
`writeWithoutTransaction`/autocommit prototype typecheck 通过。产品路径
`Sources`、`Package.swift`、`scripts` 的 tracked/untracked diff 均为 0，
`git diff --check` 通过。

真实 Store/UDF 正例尚未运行，因为实现尚不存在；它是 P1-E 的强制实现门。上述
冻结前结果不构成 Review07 批准。

## R7 冻结时权限与红线（历史）

- Stage/Plan 编辑与重新冻结门当时已关闭；剩余授权只允许职责隔离 Review07；
- P0 acceptance、P1-A1a 和全部产品代码实施继续关闭；
- commit、push、merge、release、data reset 与外部操作继续关闭；
- 不得把冻结前审计描述为 Review07 已通过或真实 Store/UDF 正例已运行；
- 只有上述冻结稿获得零 P0/P1 的职责隔离 Review07 verdict，才可继续 P0
  acceptance。

当时没有新的产品决策 blocker；唯一停机门是等待授权范围内的 Review07 verdict。
Review07 已经给出非零 P1，因此上述条件已经触发。

## Review07 阻断事实

职责隔离独立 Review07 位于 `reviews/07-p1-plan-review.md`，SHA-256 为
`7266a4e38e12c20497c4cff4985020a97988372bf363a0e67353ccdc8e49a41a`。
Reviewer 独立复算确认冻结输入前后哈希不变：

- `p1-stage-spec.md`：
  `683a876410689592e5ca7972e1e8206e6763f9baf2da4695ce47bc6b2ab8e40e`
- `p1-plan.md`：
  `c7f6e26a10e622e47296a3eb2c2163ec989e26ed519b5d9db8d0ed1b51d25df3`

Review07 给出 `CHANGES REQUIRED`：0 个 P0、2 个 P1。产品代码保持零差异，
Review07 只写入自身 review 文件。冻结前语义/结构审计的 0 P0、0 P1 不替代该独立
Review verdict。

## Review07 必须精确关闭的 finding

### R7-P1-1：v16 literal fence 与规范性 trigger ordinal gate 冲突

Stage/Plan 要求同一 fence 内先完成 table/index graph、copy/backfill/assertion、
drop/rename 和 phase barrier，之后才允许 `CREATE TRIGGER`；literal v16 fence 却在
首个 `CREATE TRIGGER` 后仍包含四个 `DROP TRIGGER`。双 SQLite lane 能完整执行且
得到 79 tables、208 indexes、84 triggers、FK 0、integrity `ok`，但结构成功不能
替代 literal ordinal 合同。下一轮必须在 Stage/Plan 中选择并编码唯一规则：

1. 把四个 `DROP TRIGGER` 全部移到 barrier/首个 `CREATE TRIGGER` 之前；或
2. 明确把 ordinal gate 限定为 table/index graph statement，并把
   `DROP TRIGGER`/`CREATE TRIGGER` replacement pair 定义为 final trigger-install
   phase。

同时必须更新 literal ordinal test 描述、重新冻结并独立复审，不能把选择留给
实施者。

### R7-P1-2：GRDB 公开 API 无法实现 connection-close registry cleanup

冻结合同同时要求 `Configuration.prepareDatabase` 为每个真实 connection 创建唯一
cell、GRDB `DatabaseFunction` closure 强持有该 cell、registry 只保留 weak exact-key
entry，并在 connection close 时立即失效 cell、清除 weak entry。GRDB 7.11.1 的
`Database` 会在 close 后继续强持有已注册 functions，而
`onConnectionWillClose` seam 是 internal，当前授权的公开 API 无法同时满足这些
要求。下一轮必须选择并编码一个确切、可支持的生命周期设计，至少明确 owner、允许
文件、直接 `pool.close()` 的绕过防护和验证测试；不得让实施者自行发明 AppDatabase
close seam、deinit-time 弱化语义、raw SQLite `xDestroy` 注册或 GRDB patch。

## Review07 后当前权限与红线

- R7 授权随 Review07 用尽；当前没有 Stage/Plan 修订或重新冻结授权；
- 不创建 P0 `acceptance.md`，不把 P0 标记为 Accepted；
- 不实施 P1-A1a，不修改任何产品代码；
- 不 commit、push、merge、release、重置数据或进行外部操作；
- 真实 Store/UDF 正例尚未运行，因为实现不存在；它继续是 P1-E 强制实现门；
- 只有新的冻结稿经职责隔离独立 Review 得出零 P0/P1，才可进入 P0 最终
  acceptance audit。

## R8 只读可行性消歧

在不修改冻结 Stage/Plan、Review07 或产品代码的前提下，已对两个 finding 完成
只读实现可行性审计。完整证据位于
`evidence/review07-r8-readonly-feasibility.md`；该证据是未授权、非规范性的
技术建议，不会自行打开 R8 编辑门。

推荐的唯一最小修订路径为：

1. R7-P1-1：保留旧 guards 覆盖全部 migration 数据处理；Swift
   backfill/assertion barrier 成功后，按固定顺序 hoist 四个 surviving-table
   UPDATE guard drops，并在此后不再执行 DML，随后才创建任何 v16 trigger。不缩窄
   ordinal 合同，不使用 `IF EXISTS`；
2. R7-P1-2：由 `ActiveIngestionDeletionSQLPermit.swift` 唯一使用 raw
   `sqlite3_create_function_v2` + `xDestroy` 管理 connection context/cell/exact-key
   lifecycle，替代 GRDB `DatabaseFunction` 的强持有路径；successful direct
   `pool.close()`、registration failure、`SQLITE_BUSY`、`close_v2` zombie 和
   pointer reuse 均已有只读探针证据；
3. R8 只同步 owner、允许文件、`GRDBSQLite` direct product dependency、source
   sentinels、ordinal/lifecycle/rollback tests 与 Review07 closure matrix；不新增
   migration/schema/trigger，也不修改产品代码。

这两项仍需牧场主明确授权后才能写入 Stage/Plan，并且必须重新冻结、执行职责隔离
Review08。只读探针不是实际 Store/UDF 正例；后者继续保留为 P1-E 实现门。

## Review07 后需要牧场主决定

是否授权 R8：只针对 R7-P1-1 与 R7-P1-2，按上述已验证的唯一最小路径开启一轮有界
Stage/Plan 修订，重新冻结后执行职责隔离独立 Review08；Review08 通过前继续禁止
P0 acceptance、P1-A1a 与全部产品代码实施。

## R8 牧场主授权结果

2026-07-26，牧场主明确回复：

> 授权 R8：仅按 E-071 的两个已验证路径有界修订 Stage/Plan，重新冻结后执行职责
> 隔离 Review08；通过前继续禁止 P0 acceptance、P1-A1a 和产品代码实施。

该授权没有扩大产品、Git、破坏性或外部操作权限，只重新打开：

- E-071 两条路径内的 Stage/Plan 有界修订；
- 修订完成后的哈希冻结；
- 冻结后的职责隔离独立 Review08。

## R8 冻结结果

R8 有界修订和冻结前核验已经完成：

- `p1-stage-spec.md`：
  `502393d1413c7ac21616afe0d2e5e847e22e8815d451113806ee94b702d88688`
- `p1-plan.md`：
  `1b9ef563b265d6ac0138d083c352837771fc652831e111e92c32d3a36853a4ee`

冻结前 SQL/ordinal、Swift/GRDB lifecycle与跨文档语义/范围预审均为
0 P0、0 P1。完整耐久证据位于 `evidence/r8-freeze-validation.md`。预审不是
Review08；真实 Store/UDF正例和真实 v16 Swift migration仍未实现或运行。

## R8 冻结后权限与红线

- Stage/Plan编辑门关闭；R8剩余授权只允许职责隔离 Review08；
- 不创建 P0 `acceptance.md`，不把 P0标记为 Accepted；
- 不实施 P1-A1a，不修改任何产品代码；
- 不 commit、push、merge、release、重置数据或进行外部操作；
- 不把冻结前0/0描述为 Review08通过；
- Review08只有在冻结哈希前后不变且 verdict为0 P0/0 P1时，才可打开 P0最终
  acceptance audit；
- Review08若发现任何P0/P1，R8授权随该Review用尽；不得在本轮修改冻结输入，必须
  记录 finding并重新取得牧场主授权。

R8 冻结当时没有需要牧场主补充的产品决定；当时唯一进行中的 gate 是职责隔离
Review08。

## Review08 结果

职责隔离 Review08 已完成：

- Stage SHA-256：
  `502393d1413c7ac21616afe0d2e5e847e22e8815d451113806ee94b702d88688`
- Plan SHA-256：
  `1b9ef563b265d6ac0138d083c352837771fc652831e111e92c32d3a36853a4ee`
- Review08 SHA-256：
  `d4e22ccf8b38b33e013969414d14b17ab32bfb94c549fc9df8c349d44a158755`
- Verdict：`APPROVED — 0 P0 / 0 P1`

冻结哈希前后不变，产品路径保持零差异。Review08 没有声称真实 Store/UDF 正例或
P1 产品代码已经运行；它只打开 P0 final acceptance audit。

## P0 最终 gate 结果

两路职责隔离只读审计与主代理最终复核均未发现实质 P0 blocker。P0 spec §6
十二项完成门已由 `acceptance.md` 逐项引用并通过，最终完整性证据位于
`evidence/p0-final-acceptance-audit.md`。

因此：

- P0 已 Accepted；
- P1-A1a 进入门已打开；
- A1a 只能按冻结 `p1-plan.md` §3.1 执行，独立验收前不得进入 A1b；
- 当前没有需要牧场主补充的产品决定；
- commit、push、merge、release、data reset 与外部操作继续未授权。
