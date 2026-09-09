# P0 Acceptance — 总 Spec 与可执行基线

> 结论：**ACCEPTED**
>
> 日期：2026-07-26
>
> 分支：`codex/personal-ai-ranch-p0`
>
> 代码基线：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> 下一入口：P1-A1a 文档准备与实施门已打开；P1-A1a 仍必须按冻结 Plan 独立实现、
> 验证、Review 和验收，不能跨到 A1b。

## 1. 验收范围

P0 只建立长期产品 SSOT、当前实现证据、历史治理、数据安全 runbook、P1 冻结
Stage/Plan 和独立 Review。P0 没有修改产品代码、运行行为、migration、Package
依赖或脚本，也没有执行数据重置、commit、push、merge、release 或外部操作。

## 2. P0 Spec §6 完成门

| # | 完成门 | 结论 | 验收证据 |
|---:|---|---|---|
| 1 | 长期总 spec 状态为 Accepted | PASS | `docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md` 为 `Accepted 1.0`；牧场主接受记录已写入；根任务 `get_goal` 在最终审计时返回长期 Goal `active` |
| 2 | P0 决策全部解决或合法延期 | PASS | `spec.md` §4 五项决策均有结论；只有最终品牌名按总 spec §29 合法延期，且不触发命名迁移 |
| 3 | SSOT、Goal、Git 权限和 sandbox 事实一致 | PASS | `AGENTS.md`、`CLAUDE.md`、`README.md`、`docs/collaboration/claude-codex-protocol.md` 均指向总 spec；长期 Goal 不扩大 Git/破坏性/外部权限；Developer ID entitlement 明确关闭 App Sandbox，当前 ad-hoc 包无 entitlement plist |
| 4 | Evidence matrix 覆盖要求的事实桶 | PASS | `current-state-evidence.md` 覆盖 branch/HEAD、代码、测试、build、package、真实 App/UI、Provider/CLI、权限、历史和 R-01～R-09 根因风险 |
| 5 | 权威测试与 App build 全绿并保存完整日志 | PASS | `verify.log` 保存 `swift run RunTests` 的 423 tests / 5 suites 全绿输出；`build.log` 保存 `swift build --product AgentLoopApp` 成功输出；二者对象为未发生产品差异的 `02334ec8…` |
| 6 | 真实 App 启动与关键页面证据已保存 | PASS | `evidence/runtime-snapshot.txt`、`evidence/live-ui-observation.md` 与三张 `current-live-*.jpg` 覆盖 normal App、我的营地、任务工作台和 Coding 草原 |
| 7 | Provider/CLI 能力与缺口没有被夸大 | PASS | `provider-cli-smoke.log` 和 evidence matrix 记录 Codex 裸 CLI 成功但发生 WebSocket→HTTPS 降级；Claude 两次 403；normal DB 无 CLI profile；App 内真实 Provider 成功明确为未证明 |
| 8 | 历史索引和 Superseded 标记完成 | PASS | `historical-document-index.md` 建立权威分级；三份直接冲突的历史产品方向 spec 只增加最小 Superseded banner，历史实施与验证证据原文保留 |
| 9 | Reset runbook 完成且没有执行重置 | PASS | `test-data-reset-runbook.md` 固定 normal/preview/custom 路径、进程/WAL/锁、快照和回退门；P0 只读证据仍显示原 normal DB、WAL 和锁处于运行状态，没有执行 reset |
| 10 | P1 Stage、Plan、独立 Review 完成且 Open Questions 为空 | PASS | Stage SHA-256 `502393d1413c7ac21616afe0d2e5e847e22e8815d451113806ee94b702d88688`；Plan SHA-256 `1b9ef563b265d6ac0138d083c352837771fc652831e111e92c32d3a36853a4ee`；两份 Open Questions 均精确为“无。”；`reviews/08-p1-plan-review.md` 为 `APPROVED — 0 P0 / 0 P1` |
| 11 | 产品代码仍未修改 | PASS | 最终审计对 `Package.swift`、`Package.resolved`、`Sources`、`scripts` 的 tracked、untracked、staged 查询均无输出；P1 Stage/Plan 冻结哈希未漂移 |
| 12 | Impl report 与 acceptance 逐项引用证据 | PASS | `impl-report.md` 已同步 Review08、最终产品零差异和诚实边界；本文逐项引用全部完成门；`evidence/p0-final-acceptance-audit.md` 保存最终完整性结果 |

## 3. Review 与冻结完整性

职责隔离 Review08 报告：

- 文件：`reviews/08-p1-plan-review.md`
- SHA-256：
  `d4e22ccf8b38b33e013969414d14b17ab32bfb94c549fc9df8c349d44a158755`
- 结论：`APPROVED — 0 P0 findings and 0 P1 findings`

R8 冻结验证证据 SHA-256：

`2bedd27c7ce9bfca5ce568ab08544b7502533a5593e8095bb20a8f752b59b5e7`

Review08 只批准 P1 冻结合同足够完备并打开 P0 最终验收；它没有宣称真实
`IngestionDeletionStore`、raw UDF、v16 Swift migration 或普通 Ingestion 删除
正例已经实现或运行。这些仍属于 P1 的实现门。

## 4. 诚实边界

以下缺口不属于 P0 的成功声明，继续进入后续阶段门：

- App 内真实 Provider 成功未证明；Claude CLI 当前不可用；normal 牧场没有 CLI
  profile；
- 423 项 Core TestSuite 不覆盖 `AppStore`、`MissionScheduler`、SwiftUI 或真实
  外部供给线；
- 分发包只有 ad-hoc 签名，未公证、未启动验证、未做跨机 Gatekeeper 验证；
- 真实 UI 截图不把运行二进制严格绑定到 Git HEAD；
- 当前 normal DB 仍在运行且 WAL 非空，不能宣称可安全 reset；
- `current-state-evidence.md` 的 R-01～R-09 仍是 P1 必须逐项关闭的根因风险；
- P1-A1a 只建立 Durable Work DDL + Store；即使 A1a 通过，也不能宣称 planning
  根因已经修复。

## 5. 阶段裁决

P0 的十二项完成门全部通过，因此 P0 于 2026-07-26 标记为 **Accepted**。

允许的下一步仅为冻结 `p1-plan.md` 定义的 P1-A1a：

1. 建立固定 P1/A1a 任务目录和职责分离的 slice plan；
2. 只修改 A1a 精确允许文件；
3. 保存权威测试、App build 和 SQLite migration matrix 证据；
4. 完成职责隔离独立 Review 与 slice acceptance；
5. A1a 通过前不得进入 A1b，也不得执行任何仍未授权的 Git、数据或外部操作。
