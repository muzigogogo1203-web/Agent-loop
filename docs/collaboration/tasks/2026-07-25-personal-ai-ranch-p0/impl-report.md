# P0 Implementation Report — 总 Spec 与可执行基线

> 状态：**Completed — P0 Accepted; P1-A1a Entry Open**
>
> 日期：2026-07-25
>
> 分支：`codex/personal-ai-ranch-p0`
>
> 代码基线：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. 本阶段完成的工作

### SSOT 与协作边界

- 将长期总 spec 标记为 Accepted，并记录 P0 执行状态；
- 在 `AGENTS.md`、`CLAUDE.md`、`README.md` 和协作协议中建立长期总 spec 指针；
- 同步长期 Goal 的阶段内自治边界，同时保留“不 commit、不 push、不做破坏性或外部操作”的限制；
- 将仓库文档中的 App Sandbox 描述修正为当前真实的非沙箱构建事实。

### 历史治理与数据安全

- 建立 `historical-document-index.md`；
- 只给三份直接冲突的历史产品方向 spec 增加最小 Superseded banner；
- 保留历史 plan、report、acceptance、live-test 和验证日志原文；
- 建立 normal、preview 与自定义状态根的 `test-data-reset-runbook.md`；
- P0 没有停止真实 App、复制运行中数据库或执行任何 reset。

### 当前状态证据

- 建立 `current-state-evidence.md`，分离源码、测试、build、真实 App、Provider/CLI、package 与风险证据；
- 保存 branch、HEAD、工具版本和 worktree preflight；
- 保存 normal App 的进程、SQLite/WAL/lock、profile 只读快照；
- 保存主场、任务工作台与 Coding 草原的真实 UI 截图和观察记录；
- 保存 Codex 与 Claude CLI 的固定字符串真实 smoke；
- 保存当前 HEAD 的权威测试、App build 和隔离打包日志。

### P1 规划与 Review 门

- 已形成 P1 阶段 spec 与逐 slice 实施 plan，Open Questions 草案曾收敛为“无”；
- Claude Code 两次 403 后，按协议使用职责隔离的替代规划者和 reviewer；
- 三轮独立 Review 均未越权修改 P1 plan/spec 或产品代码；
- 第三轮冻结审查结论为 `CHANGES REQUIRED`：4 个 P0、7 个 P1，明确不授权 P1-A1a；
- 第三轮 Review 已保存为 `reviews/03-p1-plan-review.md`，SHA-256 为
  `e1c667db1c5b0f7cb056f7e426c45edbf6f02de370bfcd941f052d8b801d402d`；
- 协议三轮上限已到后，牧场主于 2026-07-25 确认“可逆归档＋用户确认的不可逆逻辑删除”，并明确授权增加一轮修订与职责隔离独立复审；
- 额外修订冻结后，Stage SHA-256 为
  `bfe8ac750ad028ab2508e6e5f6db21e0ad8b4a72cadcb0d9dd2686f8b3a35a67`，
  Plan SHA-256 为
  `5eb39c6c7170e76a99f83cd62fd0fffdb87e5d34d6218d7f7ba70c7c706e068b`；
- Round 4 独立 Review 判定 `CHANGES REQUIRED`：4 个 P0、4 个 P1，明确不授权
  P1-A1a；Review 保存为 `reviews/04-p1-plan-review.md`，SHA-256 为
  `ad30c15101659645729d9c0cc11d5803c5e0aa737abbd492c843b143fb9f8a1b`；
- Round 4 后，牧场主于 2026-07-25 再次明确授权一轮有界修订与职责隔离独立复审；范围固定为关闭 Round 4 的 4 个 P0、4 个 P1，并在重新冻结前消除已暴露的 P1-A1a 执行歧义；
- Round 5 有界修订后，Stage SHA-256 为
  `1124c80ebaaadd6da427540dec19b89dabfc950405975146b2ac7cfa641c504d`，
  Plan SHA-256 为
  `94828d327dff35e56c7d2c1eb2225b1d4ae02643fcaa613a8883cc5b224ceecd`；
- 主代理独立复算上述哈希，并把 8 个 SQL fences 叠加到当前真实 v11 schema
  结构执行：78 张表、`foreign_key_check` 零行、`integrity_check=ok`；另以
  populated archived running/queued/retry work fixture 复核 v16 收口与 lifecycle
  generation 绑定，并通过 Swift 6 fence typecheck；
- 上述结果只冻结 Round 5 Review 输入，不构成 Review 批准或 P1-A1a 实施授权；
- Round 5 职责隔离独立 Review 判定 `CHANGES REQUIRED`：4 个 P0、1 个 P1，
  明确不授权 P1-A1a；Review 保存为 `reviews/05-p1-plan-review.md`，SHA-256 为
  `28b4959fedab740c935238eb71537bb62a13474951149371b82c18e85a687f10`；
- Reviewer 在 SQLite 3.51 上复验 8/8 SQL fences、populated v16 fixture、FK 与
  integrity，并以 SQLite 3.52 复现 v16 trigger 先引用未建表导致 rename 失败；
  Swift 6 fence通过，Stage/Plan 冻结哈希前后不变；
- 4 个 P0 分别是：pending terminal proposal 无 deletion-authorized closeout、
  unresolved legacy artifact 无完成裁决、artifact/隐私擦除 schema 无可实现终态、
  redaction exception 非 one-shot 且可改写 retained audit evidence；
- 1 个 P1 是 v16 trigger 创建顺序依赖 SQLite 3.51 的宽松行为；
- 主代理补充只读审计没有增加 finding 类别或计数，但确认 R5-P0-2/P0-3 还必须覆盖：
  verified-outside external evidence 枚举、`engine_terminal_proposal.invalidReason`
  deletion disposition，以及 Card/Rumination/Engine JSON tombstone 与 typed decode
  形状；
- Round 5 授权已经用尽。P0 完成门、P1-A1a 和全部产品代码实施继续关闭，等待
  牧场主决定是否授权下一轮有界修订与职责隔离独立复审。
- 牧场主随后明确授权按照 `blocked.md` 的精确范围开启一轮有界修订与职责隔离
  独立复审；只重新打开 P1 Stage/Plan 编辑门，产品代码、P0 acceptance 与
  P1-A1a 继续冻结。
- 该有界修订形成 Round 6 冻结输入：Stage SHA-256 为
  `301dcb485b607e99f28be73fbabfa69a560e8d639bf3b0d1dea67d3a1b4aff2c`，
  Plan SHA-256 为
  `8b2c5dd90f5e6c1a2e05a0804238dd4c0e660d898544ec55ace4a7c1011ac754`；
- Round 6 职责隔离独立 Review 判定 `CHANGES REQUIRED`：1 个 P0、1 个 P1；
  Review 保存为 `reviews/06-p1-plan-review.md`，SHA-256 为
  `9c688836e1a3d62999740e3f6bec5ca477846ed9f6c9491247de2316c0ab1d68`；
- R6-P0-1：9 个规范性 append-only 表所需的 guard 可执行图缺 11 个 trigger；
  当前 through-v16/through-v17 数为 56/73，合同完整图应为 67/84；
- R6-P1-1：现有 ordinary Ingestion delete API、UI 文案与 adapter 物理删除路径
  会被 v16 unconditional DELETE guards 确定性拒绝，Stage/Plan 尚未决定移除、
  延期或 typed tombstone 替代语义；
- Review06 确认 Review05 的 proposal、legacy artifact、enumerated erasure shape
  与 SQLite 3.52 order 缺陷已经在 plan level 关闭；Review05 的不可变 audit
  evidence 要求仍由 R6-P0-1 接续阻断；
- Round 6 授权已经执行完毕。P0 acceptance、P1-A1a、全部产品代码实施和下一轮
  Stage/Plan 编辑均关闭，等待牧场主再次明确授权新的有界修订与职责隔离独立
  Review。
- 2026-07-26，牧场主明确回复：“授权 R7，并同意上述 Ingestion 删除语义。”
  R7 只重新打开 P1 Stage/Plan 有界修订门与冻结后的职责隔离 Review07；产品代码、
  P1-A1a 与 P0 acceptance 继续冻结；
- 已同意的 ordinary Ingestion 语义为：`resultOnly` 在严格 active、
  non-materialized、无 link/candidate/非终态 work/provider 的前提下删除 result，
  CAS ingestion 回 `queued` 并保留 source/raw；`sourceAndResult` 只在无 link、
  无任何 persisted candidate、无非终态 work/provider 且可选 result 未
  materialized 时事务删除 result/ingestion；`everythingIncludingProjection`
  永久 typed reject，任何投影均不删除；
- 该语义复用 v14 append-only command receipt/domain event 与 sealed V1 command
  做 replay/conflict、revalidation、CAS/count rollback；v16 继续永久保护
  candidate/link，仅把 result/ingestion 改为 exact event-bound conditional
  DELETE guards，不新增表、列、schema version 或 trigger 总数；
- R7 有界修订已经完成并冻结：Stage SHA-256 为
  `683a876410689592e5ca7972e1e8206e6763f9baf2da4695ce47bc6b2ab8e40e`，
  Plan SHA-256 为
  `c7f6e26a10e622e47296a3eb2c2163ec989e26ed519b5d9db8d0ed1b51d25df3`；
- 冻结前职责分离语义审计与结构审计均为 0 P0、0 P1；8 个 SQL fences 在
  SQLite 3.51/3.52 上均得到 79 tables、208 indexes、84 triggers、FK 0 与
  integrity `ok`；UDF arity 为 53/63；
- Stage/Plan Markdown markers 为 42/12、平衡且 trailing whitespace 为 0；
  Swift 6 / GRDB 7 `writeWithoutTransaction`/autocommit prototype typecheck
  通过；产品路径 tracked/untracked diff 均为 0，`git diff --check` 通过；
- 真实 Store/UDF 正例尚未运行，因为对应产品实现不存在；该项保留为 P1-E 强制
  实现门。冻结前审计不构成职责隔离 Review 批准；
- Review07 保存为 `reviews/07-p1-plan-review.md`，SHA-256 为
  `7266a4e38e12c20497c4cff4985020a97988372bf363a0e67353ccdc8e49a41a`，
  判定 `CHANGES REQUIRED`：0 个 P0、2 个 P1；
- R7-P1-1 是 v16 literal fence 中四个 late `DROP TRIGGER` 与规范性 trigger
  ordinal gate 的冲突；R7-P1-2 是 GRDB 7.11.1 公开 API 无法实现
  connection-close 时 UDF cell 立即失效与 weak-registry cleanup；
- Reviewer 确认 Stage/Plan 冻结哈希前后不变、Review07 只写入自身 review 文件且
  产品代码保持零差异。R7 授权随 Review07 用尽，P0 acceptance、P1-A1a 与产品代码
  实施继续冻结。
- 牧场主随后明确授权 R8，只允许按 E-071 的两个已验证路径修订 Stage/Plan、
  重新冻结并执行 Review08；P0 acceptance、P1-A1a与产品代码继续冻结；
- R8 将四个 surviving-table UPDATE guard drops固定到 v16 barrier后、首个
  `CREATE TRIGGER`前，并以 Permit文件唯一拥有的 raw
  `sqlite3_create_function_v2 + xDestroy`冻结 connection lifecycle；
- R8 最终冻结输入为 Stage
  `502393d1413c7ac21616afe0d2e5e847e22e8815d451113806ee94b702d88688`、Plan
  `1b9ef563b265d6ac0138d083c352837771fc652831e111e92c32d3a36853a4ee`；
- SQL/ordinal、Swift/GRDB lifecycle与跨文档语义/范围三路预审均为
  0 P0、0 P1，证据保存在 `evidence/r8-freeze-validation.md`；这不是 Review08，
  真实 Store/UDF正例和真实 v16 Swift migration仍未运行；
- R8 Stage/Plan编辑门已关闭，剩余授权只允许职责隔离 Review08。
- Review08 在冻结哈希不变、产品路径零差异的前提下给出
  `APPROVED — 0 P0 / 0 P1`；报告 SHA-256 为
  `d4e22ccf8b38b33e013969414d14b17ab32bfb94c549fc9df8c349d44a158755`；
- 两路职责隔离 P0 最终只读审计均未发现实质 blocker 或新增 P1 finding；
- 已创建 `acceptance.md`，并把 master、P0 spec/plan、blocked、evidence matrix
  和本文同步收口；最终完整性证据保存于
  `evidence/p0-final-acceptance-audit.md`；
- P1 Stage/Plan 冻结字节没有改变，P0 产品路径最终仍为零差异。

## 2. 验证结果

| 验证 | 结果 | 耐久证据 | 边界 |
|---|---|---|---|
| `swift run RunTests` | PASS：423 tests / 5 suites | `verify.log` | 不覆盖 AppStore、MissionScheduler、SwiftUI 或真实 Provider |
| `swift build --product AgentLoopApp` | PASS | `build.log` | debug 增量 build |
| normal App 活体只读 smoke | PASS：主场、任务工作台、Coding 草原可见 | `evidence/current-live-*.jpg`; `evidence/live-ui-observation.md` | 未提交输入、未重启、未改变真实数据；截图不严格绑定 HEAD，且只作私有测试证据 |
| Codex CLI 固定字符串调用 | PASS | `provider-cli-smoke.log` | WebSocket 失败后回退 HTTPS；不证明 App 内 CLI backend |
| Claude CLI 固定字符串调用 | FAIL：两次 403 | `provider-cli-smoke.log`; `reviews/00-claude-availability.md` | 明确记录为能力缺口 |
| `scripts/package-app.sh --version 1.1.0` | PASS（使用本机已验证 checkout 的隔离复验） | `package.log`; `evidence/package-verify.log`; `evidence/package-snapshot.txt` | 首次网络 clone 超时；产物只有 ad-hoc 签名，未公证、未启动 |
| package integrity | PASS：codesign、ZIP、DMG，完整原始 transcript 和 exit code 已保存 | `evidence/package-verify.log`; `evidence/package-snapshot.txt` | 不证明正式分发或跨机 Gatekeeper |
| 敏感信息扫描 | PASS：文本证据未发现 credential-shaped value、email、带 query 的 callback URL 或具体 session/account value | `evidence/privacy-scan.txt` | 三张 JPEG 是私有 UI 证据，未做 OCR 扫描，不公开 |
| R7 冻结前规划验证 | PASS：语义/结构审计 0 P0/0 P1；双 SQLite 8 fences 为 79 tables/208 indexes/84 triggers、FK 0、integrity ok；UDF 53/63；Markdown/Swift 6/GRDB 7 checks 通过 | `p1-stage-spec.md`; `p1-plan.md`; `current-state-evidence.md` E-068 | 只验证冻结 blueprint；不替代 Review07，真实 Store/UDF 正例未运行 |
| Review07 职责隔离审查 | CHANGES REQUIRED：0 P0 / 2 P1 | `reviews/07-p1-plan-review.md`; `current-state-evidence.md` E-070 | literal trigger ordinal 合同与 GRDB connection-close cleanup 合同未决；R7 授权用尽 |
| R8 冻结前规划验证 | PASS：SQL/ordinal、Swift/GRDB lifecycle、语义/范围均0 P0/0 P1；双 SQLite保持67/84与79/208/84；62个v16 failure boundaries逐字回滚；lifecycle覆盖registration failure、later setup throw、direct close、BUSY、zombie、reuse | `evidence/r8-freeze-validation.md`; `current-state-evidence.md` E-073 | 只验证冻结 blueprint；不替代Review08，真实Store/UDF正例未运行 |
| Review08 职责隔离审查 | APPROVED：0 P0 / 0 P1；冻结哈希不变、产品路径零差异 | `reviews/08-p1-plan-review.md`; `current-state-evidence.md` E-075 | 只批准冻结合同并打开 P0 final audit；不证明未实现的 Store/UDF 正例 |
| P0 最终完成门审计 | PASS：两路只读审计无实质 blocker；十二项完成门已逐项验收 | `acceptance.md`; `evidence/p0-final-acceptance-audit.md`; E-076～E-077 | 只验收 P0；A1a 仍需独立实施、验证、Review 和 acceptance |

## 3. 与原 plan 的偏差

1. **真实 App 证据优先于 preview。** 进入 P0 时已有 normal App 正在运行并持有真实状态锁，因此只读检查该进程和关键页面，没有为截图重启 App 或另外启动 preview。这样既满足真实 App 证据要求，也避免改变真实数据。
2. **package 在隔离 worktree 执行。** `package-app.sh` 会替换 `dist/`；为保留用户现有产物，使用记录 HEAD 的临时 detached worktree。首次 GRDB 网络 clone 超时后，复用主工作区已验证的 SwiftPM checkout 完成打包；验证完成后删除临时 worktree。
3. **Claude Code 降级。** Claude CLI 按协议重试一次后仍返回 403。没有跳过规划或让实现者自批，而是按 accepted master spec 和协议记录故障，并使用职责隔离的替代规划者与 reviewer。
4. **测试数据未重置。** 用户允许未来重置测试数据，但 P0 仅建立安全 runbook；当前 DB 仍在运行且 WAL 非空，不满足安全 reset 前置门。
5. **Review08 不替代实现验证。** Review08 已批准冻结合同并关闭 P0 的规划门，
   但真实 Store/UDF 正例、真实 Swift migration 和 P1 产品路径尚未实现或运行；
   这些仍由对应 P1 slice 的测试与 Review 负责。

## 4. 产品代码范围

P0 没有修改 `Sources/`、`Package.swift`、`Package.resolved`、脚本、migration 或
运行行为。最终 acceptance 已对这些产品路径执行 tracked、untracked 与 staged
差异检查，均无输出。

## 5. P0 收口与下一门

P0 已完成，没有遗留的 P0 blocker。

下一门是 P1-A1a：

- 先建立固定 A1a task 目录与职责分离的 slice plan；
- 只实施冻结 `p1-plan.md` §3.1 的精确允许文件与合同；
- 保存完整 `swift run RunTests`、App build 和 SQLite matrix 证据；
- 完成独立 Review/acceptance 前不得进入 A1b；
- 真实 Store/UDF 正例继续属于 P1-E，当前不得提前宣称通过。
