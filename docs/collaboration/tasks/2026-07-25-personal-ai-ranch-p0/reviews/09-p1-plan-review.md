# P1 Stage / Plan Independent Review — Review09

> 日期：2026-07-26
>
> Reviewer：职责隔离的独立 Review09 reviewer
>
> 审查对象：获授权 R9 的 SQLite durable-work diagnostics
> `NULL/UNKNOWN` 有界修订、同步测试门与重新冻结

## 1. 独立性与写入边界

Reviewer 未参与 R9 Stage、Plan、leaf-plan、控制索引、`blocked.md` 或 freeze
evidence 的编写与修订，也没有修改或评审既存 A1a 产品实现。本次审查唯一写入的
repository 文件是本报告；所有 SQL probe 都在 SQLite `:memory:` 数据库中执行，
没有修改 normal、preview 或其他持久数据库。

审查开始时：

- branch：`codex/personal-ai-ranch-p0`
- HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
- worktree 已包含 R9 前就存在的 P0/P1 文档与 A1a 实现差异；这些既存差异不是
  Review09 的写入，也不被本报告判定为实现通过。

## 2. Verdict

**APPROVED — 0 P0 findings and 0 P1 findings.**

Review09 只批准 R9 规范闭包足以恢复 **P1-A1a v12** 的有界实现与验证工作。
它不批准 A1a acceptance，不批准 A1b、P1-E 或其他产品代码实施，也不授权 commit、
push、merge、release、数据重置、付款、公开沟通、外部操作或真实用户操作。

既存 A1a 实现、测试、migration runner 和脚本的正确性不属于本次规范 Review 的
成功声明；它们仍须按新冻结合同完成 v12 修正、双 SQLite 验证、独立实现 Review
与 acceptance。

## 3. 冻结输入与交叉引用

Review 前后独立复算的冻结输入为：

| 输入 | SHA-256 |
|---|---|
| `p1-stage-spec.md` | `330dfd6de888e3cca14927cb9d82d5d4b1e1b7057b2814736fa923e2a2df0190` |
| `p1-plan.md` | `19e57761a9da3b11905ce72cb40e0e5c1a7bbcec1cb5f9462ef1cb1260da6ee3` |
| A1a leaf `plan.md` | `4fc04f2c6c7a3dd67db71874f7d86807fa7882d566a64fe76c60cb3722593deb` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |

以下当前控制文件均引用同一组三个 R9 hashes：

- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md`
- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md`
- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1a-durable-work-store/plan.md`
- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1a-durable-work-store/blocked.md`
- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/evidence/r9-freeze-validation.md`

P0 acceptance、Review08、R8 evidence 和 P0 历史 blocked/status 文档中的旧 hashes
均明确描述 R8/P0 当时的历史冻结输入，不是当前 R9 执行控制引用，因此没有构成
hash 冲突。

Stage §28 与 Plan §18 的 Open Questions 都精确为：

```text
无。
```

## 4. R9 Stage 修订的精确边界

当前 Stage 相对 R8 旧 Stage 的逆变换只做下列操作：

1. 顶部状态从 R9 candidate 恢复为旧的
   `Proposed for independent review`；
2. 在六个目标位置分别移除外层 `COALESCE(..., 0)`，保留 inner matrix；
3. 删除新增的 Stage §27.1 R9 resolution section。

该逆变换生成的 SHA-256 精确为：

`502393d1413c7ac21616afe0d2e5e847e22e8815d451113806ee94b702d88688`

即已独立恢复 Review08 的旧冻结 Stage hash。由此证明 R9 没有改写第七处 SQL、
schema、API、state、permission、owner、allowed files、dependency、redline 或
execution order。

六个目标 wrapper 的当前 Stage 行与 inner matrix byte hash 为：

| Stage checkpoint / table | 当前行 | inner bytes | inner SHA-256 |
|---|---:|---:|---|
| §18.1 `durable_work` | 2586 | 529 | `a52ebc85a8054ca5e7c642adcfb51606ad9568e632ac22d664d45e66fda52d3c` |
| §18.1 `durable_work_attempt` | 2642 | 414 | `7b1d28321570003f758ab114e557b1fed542ba439029cbee365a178c5757af51` |
| §18.1 `durable_work_attempt_event` | 2684 | 672 | `1efbb92c2fed09d77e1747a580c3e3f5c19fcbdf23c3a7051325c527c6d63d48` |
| §18.6 `durable_work_v16` | 3873 | 499 | `4ba3161543fb6390013c389a65b435f87823d0a17926557f7c2bc9857df1bb01` |
| §18.6 `durable_work_attempt` | 3953 | 398 | `51558d7b34452c10e90a43f153c11b4d04d7247de6c50a0517d5f3de9d4da1fe` |
| §18.6 `durable_work_attempt_event` | 4094 | 732 | `5fd04625c353a19ddabf1e987965e9e34648f361ffd6f91e6f4b4cbb4a90fc79` |

每个 inner byte sequence 在恢复出的旧 Stage 中都精确出现一次，证明状态分支、字段、
比较、换行与缩进都没有被 wrapper 修订改变。

在 R9 定义的 durable-work diagnostics scope 内，Stage 的 SQL fences 只有上述六个
实际 `CHECK (COALESCE((...`；说明文字中的示例不计作 SQL。§18.1 三张表共有
28 个 `CHECK`，除三个目标 matrix 外的 25 个要么只比较 `NOT NULL` 列，要么通过
`IS NULL` / `IS NOT NULL` 把 nullable 分支变为二值判断。§18.6 三张目标表共有
31 个 `CHECK`，除三个目标 matrix 外的 28 个也满足相同条件；新增的
provider-dispatch 与 redaction constraints 使用 non-null discriminator 和
`IS NULL` / `IS NOT NULL`。因此本次 durable-work diagnostics 根因范围内没有
第七个同类 `NULL/UNKNOWN` fail-open。

## 5. SQLite 3.51 / 3.52 独立语义验证

实际 lane 与 source id：

| Lane | `sqlite_version()` | `sqlite_source_id()` |
|---|---|---|
| system | `3.51.0` | `2025-06-12 13:14:41 f0ca7bba1c5e232e5d279fad6338121ab55af0c8c68c84cdfb18ba5114dcaapl` |
| Homebrew | `3.52.0` | `2026-03-06 16:01:44 557aeb43869d3585137b17690cb3b64f7de6921774daae9e56403c3717dceab6` |

两条 lane 都独立证明：

- `CREATE TABLE t(x CHECK(NULL)); INSERT ...` 成功并留下 1 行；
- `CHECK(COALESCE(NULL, 0))` 的同一 INSERT 以 CHECK constraint failure 拒绝。

六个 inner matrix 从当前 Stage SQL fences 直接提取。每一行的完整 normalized
domain 都同时与独立的 intended-validity oracle 比较：

| Matrix | Domain | 旧 true | 旧 false | 旧 UNKNOWN | wrapper legal | wrapper illegal | wrapper NULL | oracle mismatch |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| v12 work | 56 | 18 | 37 | 1 | 18 | 38 | 0 | 0 |
| v12 attempt | 40 | 10 | 21 | 9 | 10 | 30 | 0 | 0 |
| v12 event | 288 | 17 | 269 | 2 | 17 | 271 | 0 | 0 |
| v16 work | 56 | 18 | 37 | 1 | 18 | 38 | 0 | 0 |
| v16 attempt | 40 | 10 | 21 | 9 | 10 | 30 | 0 | 0 |
| v16 event | 384 | 19 | 363 | 2 | 19 | 365 | 0 | 0 |

SQLite 3.51.0 与 3.52.0 对上表每个数字都完全一致。wrapper 后没有一个
`NULL`，也没有一个与独立 oracle 不一致的 row。

此外，两条 lane 都使用带实际 `CHECK(COALESCE(...,0))` 的临时表执行 INSERT：

| Gate | SQLite 3.51.0 | SQLite 3.52.0 |
|---|---:|---:|
| v12 七个 NULL/UNKNOWN sentinels | 7/7 constraint rejection | 7/7 constraint rejection |
| v16 七个 NULL/UNKNOWN sentinels | 7/7 constraint rejection | 7/7 constraint rejection |
| v12 legal branch controls | 19/19 inserted | 19/19 inserted |
| v16 legal branch controls | 21/21 inserted | 21/21 inserted |

这同时证明 wrapper 关闭了全部固定 mechanism sentinels，并没有把任何冻结的合法
branch 误判为非法。

## 6. Plan、leaf 与 slice ownership

总 Plan 的逆变换只恢复旧顶部状态，并删除 R9 新增的：

- §3.1 diagnostics sentinel/control/truth-table gate；
- §10 A1a/E dual-lane 与 poisoned-predecessor rollback bullets；
- §17.1 R9 resolution section。

逆变换生成的 SHA-256 精确为旧 Plan：

`1b9ef563b265d6ac0138d083c352837771fc652831e111e92c32d3a36853a4ee`

A1a leaf-plan 的逆变换只恢复旧状态与旧 upstream hashes、移除 R9 pause 文本并移除
同步的 §3.1 R9 gate，生成的 SHA-256 精确为：

`f721386fb4767a4e6ef4afde1067bd400b5ea30d146d427899ba52d3a727e63c`

当前总 Plan 从 `### 3.1 P1-A1a` 到 `### 3.2 P1-A1b` 前的完整 byte sequence，
与 leaf §4 从同名 `### 3.1` 到 leaf §5 前的 byte sequence 完全相同：

```text
total Plan §3.1 bytes = 22152
leaf Plan §4 copied §3.1 bytes = 22152
byte equality = true
```

范围与 gate 核对结果：

- A1a 只实现和运行 §18.1 的 v12 introducing checkpoint；
- A1a 固定执行 7 sentinels、19 legal controls 与 56/40/288 normalized rows；
- P1-E 才执行 §18.6 v16 rebuild、21 legal controls 与 384-row event table；
- P1-E 才在旧 v12 与 v15 分别预置 parent work、attempt、event poison rows；
- v16 遇 poison 必须 fail fast，并保持 canonical logical
  schema/data/trigger snapshot、foreign-key check 与 integrity check；
- 合同明确禁止静默修复 poison row，禁止把不稳定的物理 database bytes 冒充
  logical snapshot；
- A1a 与 P1-E 都要求 SQLite 3.51/3.52 的 literal 与同一真实 GRDB migrator
  lane；
- §17.1 没有新增 schema、API、dependency 或 allowed file；
- A1a 不得提前实现或执行 v16，P1-E 也没有被提前打开；
- 原 P1-A1a → A1b → A2 → A3 → A4 → B → C → D → E → F1 → F2 顺序、
  owner separation、redlines 与 completion gates 没有改变。

## 7. R9 期间产品路径未变

R9 planner 首次修改文档前保存的原始 shell fingerprints，与 Review09 当前独立复算
完全一致：

| 路径 | SHA-256 |
|---|---|
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/AgentLoopCore/Database/AppDatabase.swift` | `aa063159902ec27832a91dad5c70b4d6881517847c2a8d46a9134733f356aca0` |
| `Sources/AgentLoopCore/Database/DurableWorkStore.swift` | `68098d8e4f977a3591826772a737f2e67a2070f1eebf5fa8d18b8172b192f07b` |
| `Sources/AgentLoopCore/JSON/CanonicalJSON.swift` | `7b14b628b14e8f10854116d029bbb7af480a3f9f2c7f5562ad8daae764113b79` |
| `Sources/AgentLoopCore/Work/DurableWork.swift` | `694e922ef582ea1551dfcb78ec7544a191967dda980a4f2b82852fa62b20bbb2` |
| `Sources/AgentLoopTestSuite/DatabaseTests.swift` | `bb35ad60d06e418afe62f261493535a57545a7fb37dda2db049a763150ea6c56` |
| `Sources/AgentLoopTestSuite/CanonicalJSONTests.swift` | `433184d3ed3f270a424d748240252fc4c2c7928480e96a31370589465ee1dfe7` |
| `Sources/AgentLoopTestSuite/DurableWorkTests.swift` | `702daec92083e9f0ace5714e154cfe58a4a18b30ccc5aaf8d8a12d38f955a2bf` |
| `Sources/P1MigrationMatrixRunner/main.swift` | `e86dbb80b17e29c10117e22c3c9fa11e4508a46253de55376294575a3259c7d7` |
| `scripts/verify-p1-migrations-sqlite-matrix.sh` | `fc332708f3be12a2f77191c8b1fce704ec2e443d588f173a4d6bad899d962c0f` |

因此 R9 文档修订期间没有产品、测试、Package、resolved 或 script drift。上述路径
存在的 worktree 差异属于 R9 前已暂停的 A1a 实现，不是 Review09 对实现正确性的
批准。

## 8. Repository hygiene 与继续门

`git diff --check` 在报告写入前通过。报告写入后再次复算三份 candidate hashes、
`Package.resolved` 与全部产品 fingerprints，结果均未漂移；最终
`git diff --check` 也通过。

Review09 通过后允许的下一步只有：

1. 恢复 A1a 对 v12 三个 diagnostics wrappers 的实现；
2. 在既有允许测试/runner/script 范围内实现新冻结的 v12 sentinels、controls、
   normalized truth table 与双 SQLite gates；
3. 运行并保存 A1a 的完整 authoritative test、App build 与 matrix 证据；
4. 再由与 implementer 职责隔离的 reviewer 审查实现。

A1a acceptance 在实现 Review 零 P0/P1 前仍关闭；A1b、P1-E 与其他产品代码继续
关闭。

## 9. Findings

| Severity | Count |
|---|---:|
| P0 | 0 |
| P1 | 0 |

