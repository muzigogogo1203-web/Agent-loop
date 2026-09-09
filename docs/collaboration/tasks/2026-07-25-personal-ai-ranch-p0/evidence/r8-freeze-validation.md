# R8 Stage / Plan 冻结与预审证据

> 日期：2026-07-26
>
> 状态：R8 Candidate Frozen；Review08 Pending；Product Code Frozen

## 1. 授权与边界

牧场主明确授权：

> 授权 R8：仅按 E-071 的两个已验证路径有界修订 Stage/Plan，重新冻结后执行职责
> 隔离 Review08；通过前继续禁止 P0 acceptance、P1-A1a 和产品代码实施。

本轮只允许：

1. 按 E-071 hoist v16 四个 surviving-table UPDATE guard drops；
2. 按 E-071 将 GRDB `DatabaseFunction` ownership替换为 raw
   `sqlite3_create_function_v2 + xDestroy`；
3. 同步上述两条路径所必需的 owner、direct dependency、source sentinel、
   ordinal/lifecycle/rollback tests和 Review07 closure matrix；
4. 冻结新哈希并执行职责隔离 Review08。

本轮没有授权产品代码、P0 `acceptance.md`、P1-A1a、commit、push、merge、
release、data reset或外部操作。

## 2. 冻结输入

- `p1-stage-spec.md`
  - SHA-256：
    `502393d1413c7ac21616afe0d2e5e847e22e8815d451113806ee94b702d88688`
- `p1-plan.md`
  - SHA-256：
    `1b9ef563b265d6ac0138d083c352837771fc652831e111e92c32d3a36853a4ee`

冻结后 Stage/Plan 编辑门关闭。冻结前核验不是 Review08；只有职责隔离 Review08
可以给出本轮独立 Review verdict。

## 3. R7-P1-1 关闭证据

v16 literal fence 固定为：

1. owning-table rebuild前原位删除
   `durable_work_attempt_event_reject_update`；
2. 完成完整 graph、copy/backfill/resolver/count/FK assertion barrier；
3. 按固定顺序、无 `IF EXISTS` 删除：
   - `event_no_update`
   - `verification_record_reject_update`
   - `acceptance_record_reject_update`
   - `external_operation_receipt_reject_update`
4. 四项之后零 DML、resolver、copy/backfill或 assertion；
5. 最后才创建任何 v16 trigger。

最终预审复核：

- 8 个 SQL fences字节稳定；
- v16 exact 5 个 `DROP TRIGGER`、57 个 `CREATE TRIGGER`；
- first create ordinal 793，last drop ordinal 787；
- first create之后结构/drop statement为0；
- `DROP TRIGGER IF EXISTS` 为0；
- SQLite 3.51/3.52 trigger checkpoints均为
  `2/4/4/4/8/16/67/84`；
- 两条 lane最终均为79 tables、208 indexes、84 triggers；
- `foreign_key_check` 为0，`integrity_check=ok`，GC fence通过；
- populated-v15 的62个 drop/trigger failure boundaries在两条 lane均逐字回滚；
- populated snapshot SHA-256前后均为
  `7ede7a401a060abc388f93d727791f9cfe95c7744d219c27286606daca518bbb`；
- 五个 predecessor guard逐项缺失时两条 lane均 fail fast，不以
  `IF EXISTS` 吞错。

SQL/ordinal预审 verdict：**0 P0 / 0 P1**。

## 4. R7-P1-2 关闭证据

冻结合同固定：

- `ActiveIngestionDeletionSQLPermit.swift` 是唯一 raw
  `GRDBSQLite`/SQLite/callback/`Unmanaged` owner；
- `AppDatabase` 的 `Configuration.prepareDatabase` 是唯一
  release/product install caller；
- 唯一 test-only例外是同一 Permit文件内 `#if DEBUG` 封闭 scenario runner的内部
  自有 fixture；
- install严格执行 private-boundary preflight/provisional publish → unlock →
  唯一 raw registration call → relock/reconcile；
- duplicate pointer install在 C call前 sticky typed fail，零 purge/replacement；
- `xFunc`/`xDestroy` 为 file-private noncapturing top-level callbacks；
- SQLite唯一持有 retained `pApp`；`xDestroy.takeRetainedValue` exact once，error
  branch零 manual release；
- registration failure、later `prepareDatabase` setup throw、direct pool close、
  `SQLITE_BUSY`、`close_v2` zombie与 pointer reuse均按 SQLite真实销毁语义收敛；
- Store不 import `GRDBSQLite`，raw autocommit检查只在 Permit-owned封闭 API内。

DEBUG probe只有两个入口：

- exact lifecycle enum：
  `registrationFailure|laterPrepareDatabaseSetupThrow|directPoolClose|
  duplicatePointerInstall|busyCloseThenRetry|closeV2ZombieFinalRelease|
  boundedPointerReuse`；
- exact mismatch enum：
  `missing|wrongKey|wrongCell|replaced|duplicateCleanup`。

runner只创建内部自有隔离 fixture，复用同一 private raw call，bounded reuse最多
256次；只返回 immutable counters/flags/booleans。它不接受或返回
Database/AppDatabase/path/pointer/key/nonce/cell/context/permit/closure，也不暴露
lookup/install/consume能力。mismatch runner内部强持 typed fixture，只二次调用
remove helper而不二次调用 C destructor，并在内部验证 sticky fault之后 setup、
mutation lookup与resolution lookup全部 typed reject。

Swift 6 strict-concurrency / GRDB 7.11.1预审探针：

```text
later setup throw: alive=0 destroy=1
direct pool close: alive=0 destroy=2
registration failure: xDestroy=1 contextDeinit=1
SQLITE_BUSY then retry: xDestroy=1 contextDeinit=1
close_v2 zombie final release: xDestroy=1 contextDeinit=1
pointer reuse: 126
lifecycle: 128/128
```

resolved GRDB revision保持：
`b83108d10f42680d78f23fe4d4d80fc88dab3212`。

Swift/lifecycle预审 verdict：**0 P0 / 0 P1**。

## 5. 语义、结构与范围

职责分离语义/范围预审 verdict：**0 P0 / 0 P1**。

- Stage/Plan只采用 E-071 的两条路径，没有第三条 lifecycle或 ordinal架构；
- 旧 `DatabaseFunction` 仅剩禁止性或 finding 名称，不存在正向注册合同；
- 不存在 Store raw autocommit、第二次 C destructor、AppDatabase close wrapper、
  GRDB patch、raw unregister/overwrite或 deinit-time cleanup替代路径；
- Stage/Plan `Open Questions` 均精确为“无。”；
- Stage Markdown fence markers为42，Plan为12，均成对；
- trailing whitespace为0，均有 EOF newline；
- UDF literal arity保持 `deleteIngestion=53`、`deleteResult=63`。

## 6. 产品范围与诚实边界

冻结时执行：

```bash
git diff --name-only -- Package.swift Package.resolved Sources scripts
git ls-files --others --exclude-standard -- Package.swift Package.resolved Sources scripts
git diff --check
```

产品路径 tracked/untracked均无输出，diff check通过。

本证据不宣称真实 `IngestionDeletionStore`、UDF正例、真实 v16 Swift migration或
P1-E产品测试已经运行；实现尚不存在，这些仍是 P1-E强制实现门。本证据也不替代
Review08，不创建 P0 acceptance，不打开 P1-A1a或产品代码实施门。
