# P1-A1a Blocked — SQLite `CHECK(NULL)` diagnostics fail-open

> 状态：**Resolved — A1a Accepted；A1b Entry Open**
>
> 日期：2026-07-26
>
> 当前代码基线：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. 阻塞事实

P1-A1a 已按冻结 Plan 建立 69/69 个命名测试并完成实现。权威命令
`swift run RunTests` 共运行 492 项，491 项通过，唯一失败为：

- `ddlRejectsEveryInvalidWorkAttemptEventErrorStatePair`

失败 SQL：

```sql
UPDATE durable_work_attempt
SET errorCode = 'unexpected'
WHERE workId = ? AND attempt = ?;
```

该行仍是开放 attempt：

```text
endedAt=NULL
outcome=NULL
errorCode='unexpected'
errorMessage=NULL
terminalWorkVersion=NULL
```

冻结 Stage §18.1 的最终 diagnostics `CHECK` 对这个非法组合求值为
`NULL/UNKNOWN`；SQLite 只在 `CHECK` 求值为 `0` 时拒绝，因此该写入被错误接受。
这不是 Store CAS 或测试夹具问题。

## 2. 全表与后续 rebuild 只读审计

职责隔离审计逐项检查了 §18.1 三表的 28 个 `CHECK`。其余 25 个没有发现
NULL fail-open；以下三条最终 state/diagnostics matrix 都存在同类路径：

1. `durable_work`
   - canceled work 可写入 `errorCode=NULL` 与 non-null reason。
2. `durable_work_attempt`
   - open attempt 可带任一 diagnostics；
   - closed canceled/interrupted attempt 可令必需 `errorCode=NULL`。
3. `durable_work_attempt_event`
   - canceled/interrupted event 可令必需 `errorCode=NULL`。

Stage §18.6 的 v16 durable-work rebuild 又逐字重建这三张表，并复制了相同三条
vulnerable matrix。若只改 §18.1，P1-E 的 v16 migration 会重新引入同一漏洞。

## 3. 最小根因修订

不改变 schema、状态机、列、索引、trigger 或任何合法行。只把上述三条最终
matrix 在两个 introducing/rebuild checkpoint 的共六处 literal wrapper：

- §18.1 三处；
- §18.6 v16 rebuild 三处；

由：

```sql
CHECK (<existing matrix>)
```

改为：

```sql
CHECK (COALESCE((<existing matrix>), 0))
```

这会把 `UNKNOWN` 明确映射为失败，同时保留原表达式对全部合法组合的判断。

同时扩展现有命名测试和 migration matrix 的 NULL regression，至少覆盖：

- work canceled required error code；
- attempt open diagnostics；
- attempt canceled/interrupted required error code；
- event canceled/interrupted required error code；
- SQLite 3.51 与 3.52 literal/real-GRDB lanes。

## 4. R9 授权、冻结输入与继续门

牧场主已明确授权 R9：只按同一 SQLite `NULL/UNKNOWN` 根因修订上述六处
diagnostics `CHECK`，同步 Plan/leaf test gate与哈希，重新冻结并执行职责隔离
Review09；通过前继续禁止 A1a acceptance、A1b 和其他产品代码实施。

R9 candidate 已冻结：

- Stage：
  `330dfd6de888e3cca14927cb9d82d5d4b1e1b7057b2814736fa923e2a2df0190`
- Plan：
  `19e57761a9da3b11905ce72cb40e0e5c1a7bbcec1cb5f9462ef1cb1260da6ee3`
- A1a leaf plan：
  `4fc04f2c6c7a3dd67db71874f7d86807fa7882d566a64fe76c60cb3722593deb`
- freeze evidence：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/evidence/r9-freeze-validation.md`

Review09 已由未参与修订的 reviewer 在上述 hashes 上判定
`APPROVED — 0 P0 / 0 P1`：

- report：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/09-p1-plan-review.md`
- report SHA-256：
  `392489e4f64c7a9ed9813e814654dcb746cce5a288ddae15a009d20f6884145e`

A1a 随后只恢复 v12 有界实施并完成双 SQLite gate、App build、492/492 当前全量
测试与隔离 preview。职责隔离 Review01 已判定
`APPROVED — 0 P0 / 0 P1 / 0 P2`，独立 acceptance owner 已判定
`ACCEPTED`。本阻塞保持关闭；当前只打开 A1b planning/entry gate，A1b 产品实施
仍须先完成 leaf Plan 与职责隔离 plan review。v16 poisoned predecessor rollback
gate仍归后续 P1-E，A1a 未跨 slice 提前实现。
