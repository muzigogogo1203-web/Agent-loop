# R9 SQLite diagnostics 修订与冻结证据

> 日期：2026-07-26
>
> 状态：R9 Candidate Frozen；Review09 Pending；Product Code Frozen

## 1. 授权与边界

牧场主明确授权 R9：仅按同一 SQLite `NULL/UNKNOWN` 根因，有界修订 Stage
§18.1 与 §18.6 的六处 durable-work diagnostics `CHECK`，同步 Plan/leaf-plan
测试门与哈希，重新冻结并执行职责隔离 Review09；通过前继续禁止 A1a acceptance、
A1b 和其他产品代码实施。

本文件只记录 planner revision/freeze 证据，**不是 Review09 结论**，不写
acceptance，也不授权产品、测试、Package、resolved或脚本改动。

## 2. 冻结哈希

| 文档 | R8/旧 SHA-256 | R9/新 SHA-256 |
|---|---|---|
| `p1-stage-spec.md` | `502393d1413c7ac21616afe0d2e5e847e22e8815d451113806ee94b702d88688` | `330dfd6de888e3cca14927cb9d82d5d4b1e1b7057b2814736fa923e2a2df0190` |
| `p1-plan.md` | `1b9ef563b265d6ac0138d083c352837771fc652831e111e92c32d3a36853a4ee` | `19e57761a9da3b11905ce72cb40e0e5c1a7bbcec1cb5f9462ef1cb1260da6ee3` |
| A1a `plan.md` | `f721386fb4767a4e6ef4afde1067bd400b5ea30d146d427899ba52d3a727e63c` | `4fc04f2c6c7a3dd67db71874f7d86807fa7882d566a64fe76c60cb3722593deb` |

`Package.resolved` 保持
`d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a`。

## 3. 六处唯一 SQL 修订

Stage 只在以下六个最终 diagnostics matrix 外增加
`CHECK (COALESCE((<existing matrix>), 0))`：

1. §18.1 `durable_work`；
2. §18.1 `durable_work_attempt`；
3. §18.1 `durable_work_attempt_event`；
4. §18.6 v16 rebuild `durable_work`；
5. §18.6 v16 rebuild `durable_work_attempt`；
6. §18.6 v16 rebuild `durable_work_attempt_event`。

六个 inner matrix 的状态、字段、分支与比较不变；没有新增或改写 schema、API、
状态机、权限、owner、allowed files、dependency、红线或执行顺序。

## 4. 测试门

Plan §3.1 与同步的 A1a leaf §4 固定：

- 7 个精确 NULL/UNKNOWN mechanism sentinel；
- v12 的19个、v16 的21个合法 branch control；
- work 56、attempt 40、v12 event 288、v16 event 384 的完整 normalized truth
  table及精确 legal/illegal/UNKNOWN 计数；
- SQLite 3.51/3.52 各自的 literal + real-GRDB lane；
- A1a 只执行 v12 gate，不越界实现 v16。

Plan §10 另固定 P1-E gate：旧 v12/v15 schema 的 parent/attempt/event 各预置至少
一条旧 matrix可接受的 UNKNOWN poison row，v16 migration必须 fail fast，并保持
canonical logical schema/data/trigger snapshot逐字一致以及 FK/integrity通过；
不得静默修复，也不得用物理数据库文件 bytes冒充逐字 snapshot。

## 5. 产品路径不变指纹

R9 前后下列产品、测试、Package与脚本 SHA-256 均相同：

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

R9 不声称上述既存 A1a 实现已通过；它们保持冻结，直到 Review09批准新规范。

## 6. 独立 Review 门

Review09 必须由未参与 R9 修订的 reviewer在上述新 hashes上完成。它必须确认六处
wrapper及 inner matrix不变、test gate/哈希一致、产品路径未触碰，并给出独立
P0/P1 verdict。零 P0/P1 前不得恢复 A1a 产品实施或 acceptance，也不得开始 A1b。
