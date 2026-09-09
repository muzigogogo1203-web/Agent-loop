# Review07 → R8 只读可行性证据

> 日期：2026-07-26
>
> 状态：只读技术建议；不是 R8 授权，不修改或覆盖冻结 Stage/Plan

## 1. 输入与边界

只读审计使用下列冻结输入：

- Stage SHA-256：
  `683a876410689592e5ca7972e1e8206e6763f9baf2da4695ce47bc6b2ab8e40e`
- Plan SHA-256：
  `c7f6e26a10e622e47296a3eb2c2163ec989e26ed519b5d9db8d0ed1b51d25df3`
- Review07 SHA-256：
  `7266a4e38e12c20497c4cff4985020a97988372bf363a0e67353ccdc8e49a41a`

本审计没有编辑 `p1-stage-spec.md`、`p1-plan.md`、Review07、产品代码、
`Package.swift` 或脚本。它只为 R7-P1-1 与 R7-P1-2 收集实现可行性证据和推荐
的唯一关闭路径；在牧场主明确授权 R8 前，这些建议不具有规范效力。

## 2. R7-P1-1 推荐关闭路径

选择 **hoist 四个 surviving-table UPDATE guard 的 `DROP TRIGGER`**，不缩窄
ordinal 合同。

精确顺序应为：

1. 建立完整 table/index graph，完成 owning-table rebuild 和数据处理；
2. Swift resolver、copy/backfill、count/FK assertion phase barrier 成功；
3. 按固定顺序删除：
   - `event_no_update`
   - `verification_record_reject_update`
   - `acceptance_record_reject_update`
   - `external_operation_receipt_reject_update`
4. 四个 drop 之后不再执行 DML、resolver、backfill 或 assertion；
5. 然后才创建任何 v16 trigger，包括同表 guard 与跨表 trigger。

`durable_work_attempt_event_reject_update` 的旧 guard 必须继续在 owning-table
rebuild 前删除，不并入上述四项。四个 surviving-table 旧 guard 保留到所有
backfill/assertion 已完成；drop 不增加 `IF EXISTS`，避免把损坏 predecessor schema
静默当成成功。`event_no_delete` 和三个 v15 DELETE guards 始终保留。

验证合同应同时覆盖 literal fence 与真实 Swift migration trace：

- `barrier < four ordered drops < first CREATE TRIGGER`；
- 所有 table/index/alter/drop/rename（包括五个 `DROP TRIGGER`）的最大 ordinal
  小于任何 `CREATE TRIGGER` 的最小 ordinal；
- 每个 drop 边界、last-drop-to-first-create 以及 trigger installation 中途的失败
  都完整 rollback 到逐字一致的 v15 schema/data/16-trigger 快照；
- SQLite 3.51/3.52 的 literal 与同一真实 GRDB migrator lane 覆盖
  fresh/v11/v15 populated、replay、FK、integrity 和 snapshot rollback；
- 最终 through-v16/through-v17 trigger count 仍为 67/84。

只读虚拟 hoist 验证结果：

- SQLite 3.51 与 3.52 均得到 79 tables、208 indexes、84 triggers；
- `foreign_key_check` 为零行，`integrity_check=ok`；
- v15 后执行到四个 drop 再 rollback，两条 lane 都恢复 16 triggers 和四个旧
  UPDATE guards；
- rollback 前后 dump SHA-256 同为
  `3490f6e53cc9c45e1285d63b799a48cc9b58e8a5e84689394a69467f3b7d6e67`。

## 3. R7-P1-2 推荐关闭路径

选择 SQLite 原生 **`sqlite3_create_function_v2` + `xDestroy`**，由
`ActiveIngestionDeletionSQLPermit.swift` 唯一拥有 raw registration、C callbacks、
`Unmanaged` ownership、cell/context/exact-key registry 与生命周期 fault。

不选择：

- controlled `AppDatabase.close`：当前公开 raw `DatabasePool` 有大量调用面，
  wrapper 无法在不迁移调用面的情况下防止 direct `pool.close()`；若 close 因
  `SQLITE_BUSY` 失败，预先 invalidation 还会错误废弃仍然打开的连接；
- owner/deinit cleanup：GRDB `Database.functions` 在 successful
  `pool.close()` 后仍强持有 `DatabaseFunction` closure/cell，只能弱化现有合同并
  留下 stale live entry。

推荐的唯一 ownership/lifecycle 合同：

1. `AppDatabase` 在创建 pool 前构造并强持有 instance registry；
2. `Configuration.prepareDatabase` 是
   `registry.installConnectionUDF(on:)` 的唯一产品调用者；
3. install 为每个真实 connection 建立
   `(raw pointer identity, random connection nonce)` exact key、cell 和弱 registry
   entry；
4. SQLite 通过 `pApp` 强持有一个 context；registry 只弱持 cell；
5. UDF 用 `nArg=-1`、`SQLITE_UTF8`，不使用 `DatabaseFunction`、不标
   deterministic，也不能标 `SQLITE_DIRECTONLY`，因为规范 trigger 必须调用它；
6. `xFunc` 只读取 `sqlite3_user_data`，执行 exact 53/63 arity、type、nullability、
   step、generation 与 permit 校验；错误稳定 fail closed，不查询/reenter DB，
   不记录正文；
7. `xDestroy` 以 `takeRetainedValue` exact once，先使 cell/generation 失效，再按
   exact key 清 registry；identity mismatch 设置 instance sticky lifecycle fault，
   后续 setup/mutation/resolution 全部 typed fail closed；
8. registration failure 时 SQLite 也调用 `xDestroy`，error branch 不得再次手工
   release；
9. “connection close”精确定义为 SQLite connection object 的真实销毁：
   `sqlite3_close` 返回 `SQLITE_BUSY` 时连接没有关闭，因此不清理；`close_v2`
   zombie 在最后一个 statement/blob/backup 释放时才销毁并清理。

这条路径不需要 AppDatabase close wrapper，不会被公开 `pool.close()` 绕过，也不
新增 migration、table、column 或 trigger。`Package.swift` 的 R8 文件范围应明确：
只允许给 `AgentLoopCore` 增加同一已解析 GRDB package 的直接
`GRDBSQLite` product dependency；不新增 package，`Package.resolved` 不变化。

只读 Swift 6 / GRDB 7.11.1 探针结果：

- strict concurrency + warnings-as-errors callback/typecheck 通过；
- real pool 建立 writer+reader 共 2 个 context，保持 pool/AppDatabase 存活并直接
  `pool.close()` 后 `destroyed=2`、`alive=0`；
- 256-byte function name registration 返回 21，`xDestroy` exact once，后续 close
  不 double-destroy；
- `sqlite3_close` 在 outstanding statement 下返回 `SQLITE_BUSY` 时不 destroy，
  finalize 后 successful close 才 destroy；
- `close_v2` zombie 在 statement finalize 前保留 context，finalize 后 destroy；
- 256 轮 reopen 中发生 254 次 pointer reuse，每次旧 context 都先销毁，新连接使用
  新 nonce。

SQLite 官方合同明确说明 `xDestroy` 会在函数被删除/覆盖、连接关闭以及
`sqlite3_create_function_v2` 注册失败时调用：

- <https://www.sqlite.org/c3ref/create_function.html>
- <https://www.sqlite.org/c3ref/close.html>

## 4. R8 最小允许范围与完成门建议

若牧场主授权 R8，修订范围只应包括：

- Stage/Plan 对上述唯一 trigger 顺序的同步编码；
- Stage/Plan 将 GRDB `DatabaseFunction` registration 改为 raw
  `sqlite3_create_function_v2`/`xDestroy` ownership 合同；
- 对应 owner、允许文件、direct dependency、source sentinels、lifecycle/ordinal/
  rollback tests；
- Review07 两个 finding 的 closure matrix；
- 哈希重新冻结与职责隔离 Review08。

R8 仍不得修改产品代码、创建 P0 `acceptance.md`、实施 P1-A1a、commit、push、
merge、release、reset 数据或执行外部操作。只有 Review08 给出零 P0/P1，才可进入
P0 最终 acceptance audit。

## 5. 结束完整性

- Stage/Plan/Review07 哈希与 §1 完全一致；
- `Sources`、`Package.swift`、`scripts` tracked/untracked diff 均为零；
- `git diff --check` 通过；
- 本证据不把探针描述为真实 Store/UDF 正例；该正例仍是 P1-E 实现门。
