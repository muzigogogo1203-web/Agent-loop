# P1-A1a Acceptance — Durable Work DDL + Store

> 状态：**ACCEPTED**
>
> 日期：2026-07-26
>
> Acceptance owner：职责隔离的独立验收者
>
> 验收对象：`codex/personal-ai-ranch-p0`，
> `HEAD=02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. 独立性与判定边界

本 acceptance owner 未参与 P1-A1a 的 Stage、总 Plan、leaf Plan、R9 修订、产品
实现、测试实现、runner、保存日志、impl report、Review09 或 Review01 的编写；
此前只执行过 R9 前的只读范围审计。本轮唯一 repository 写入是本文，没有修改实现、
冻结输入、控制索引、`blocked.md`、日志、Review 或 preview evidence。

本验收只接受：

- `AgentLoopCanonicalJSON.v1`；
- `v12-p1-durable-work` migration；
- Durable Work ledger/store；
- 本 slice 的 69 个命名测试、双 SQLite migration matrix、App build 与隔离
  preview 完成门。

本验收不表示 production planning 已接线，不关闭 R-01，不接受或提前实现 A1b，
也不接受 §18.6/v16 或 P1-E。

## 2. 冻结输入与职责隔离 Review

验收前后独立复算：

| 输入 | SHA-256 | 结论 |
|---|---|---|
| frozen P1 Stage | `330dfd6de888e3cca14927cb9d82d5d4b1e1b7057b2814736fa923e2a2df0190` | 匹配 R9 freeze |
| frozen P1 Plan | `19e57761a9da3b11905ce72cb40e0e5c1a7bbcec1cb5f9462ef1cb1260da6ee3` | 匹配 R9 freeze |
| frozen A1a leaf Plan | `4fc04f2c6c7a3dd67db71874f7d86807fa7882d566a64fe76c60cb3722593deb` | 匹配 R9 freeze |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` | 与 HEAD / Review09 基线一致 |
| Review09 | `392489e4f64c7a9ed9813e814654dcb746cce5a288ddae15a009d20f6884145e` | `APPROVED — 0 P0 / 0 P1` |
| final Review01 | `7bb7a856ba050111f96c85c4f0e186af8959a695990e3878e57b58ac1943e3bd` | `APPROVED — 0 P0 / 0 P1 / 0 P2` |

Stage §28 与 Plan §18 的 Open Questions 都精确为“无。”。Review09 只批准 R9
规范闭包；Review01 独立审查了当前实现、证据与范围。两者职责与本 acceptance
owner 分离。

## 3. 完成门

| # | 完成门 | 当前证据 | 判定 |
|---:|---|---|---|
| 1 | 精确十文件范围 | 当前 `Package.swift`、`Sources`、`scripts` 的 tracked/untracked/staged 差异集合，精确等于 leaf Plan §3.1 的十个允许路径；`Package.resolved` 未改 | PASS |
| 2 | 无跨 slice 接线 | 没有 v16 migration、provider-dispatch、A1b supervisor/resolver、`schedule_fire` schema，亦无 App、Planner、Orchestrator、Rumination 产品接线；`Package.swift` 只增加 test-only runner target | PASS |
| 3 | v12 DDL 与 R9 根因闭包 | 真实 migrator 只追加 `v12-p1-durable-work`；§18.1 三个 diagnostics matrix 使用冻结的 `COALESCE(...,0)`；三表、五索引和 append-only trigger pair 成立 | PASS |
| 4 | CanonicalJSON 与 Store 合同 | Review01 对 strict UTF-8/private byte AST、canonical/hash、Failure Codable、Camp/replay、CAS、attempt/event、rollback、时间/lease/backoff、diagnostics 与 claimability 逐项判定通过 | PASS |
| 5 | 69 个命名测试 | frozen 名称与当前源码 exact match、无缺失或重名：Database 3、CanonicalJSON 10、DurableWork 56 | PASS |
| 6 | 当前权威测试 | 保存的 `verify.log` 最终当前态为 492/492；本 acceptance owner 再次独立运行 `swift run RunTests`，492 tests / 5 suites 全绿，exit 0 | PASS |
| 7 | App build | `build.log` 保存成功输出；本 acceptance owner 再次运行 `swift build --product AgentLoopApp`，exit 0 | PASS |
| 8 | 双 SQLite migration matrix | 保存日志及本 owner 再次完整运行均通过 SQLite 3.51.0 与 3.52.0；每条 lane 覆盖 real GRDB fresh/v7/v8/v9/v10/v11 与 Stage literal | PASS |
| 9 | 384-row catalog 与健康/回滚门 | 每个 real/literal scope 均执行 work 56=`18/38`、attempt 40=`10/30`、event 288=`17/271`，7 sentinel=`0/7`、19 controls=`19/0`；replay、FK、integrity、DDL、append-only、real/literal rollback、catalog 前后 row/FK/integrity health equality 全通过 | PASS |
| 10 | 隔离 preview | `AGENTLOOP_STATE_DIR=/private/tmp/agentloop-a1a-preview.2Wc0jy`；进程、环境、全部打开状态文件和 clean exit 已保存；截图为真实 1190×732 PNG，显示预期 no-model degraded state，未用 UI 冒充产品接线 | PASS |
| 11 | 文档、阻塞与 hygiene | `blocked.md` 已标记 R9 blocker resolved、当前门为 acceptance；`impl-report.md`、`verify.log`、`build.log`、截图与最终 hashes 一致；`git diff --check` 通过 | PASS |
| 12 | 独立 Review 无未决 finding | final Review01 为 0 P0 / 0 P1 / 0 P2；没有未知失败或未关闭的 A1a finding | PASS |

`verify.log` 中两次早期高并发 `IdlePatternProvider` exhaustion 失败被完整保留，各自
隔离复跑通过，随后两次完整 492/492 通过；本 acceptance owner 当前独立全量复跑
也为 492/492。因此这些历史波动不构成当前未决红测，也没有被删除或伪装。

## 4. Acceptance verdict

**P1-A1a ACCEPTED。**

当前证据足以证明 CanonicalJSON v1、durable-work v12 DDL、ledger/store 与本 slice
全部完成门在当前 worktree 成立。A1a acceptance 只打开冻结顺序中的
`P1-A1b — Durable Planning Supervisor + Integration` 进入门；它不自行实施 A1b，
且 A1b 仍须独立 plan、范围、验证、Review 与 acceptance。

权限没有扩大：仍不授权 commit、push、merge、release、数据重置、付款、公开沟通、
外部操作或真实用户操作。§18.6/v16 仍由后续 P1-E 负责；production planning 和
R-01 仍保持未完成。
