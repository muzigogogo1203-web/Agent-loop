# P0 Current-State Evidence Matrix

> 状态：**P0 Accepted — P1-A1a Entry Open**
>
> 采集日期：2026-07-25
>
> 实施分支：`codex/personal-ai-ranch-p0`
>
> 代码基线：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. 证据规则

证据强度：

- **强**：同一记录 HEAD 上的完整日志、只读数据库/进程事实、真实 UI 截图或直接源码契约；
- **中强**：真实外部调用或构建成功，但覆盖面有限或存在退化告警；
- **中**：代码存在性、旧产物或间接投影，只能证明部分 claim；
- **缺失**：没有本轮可重现证据，不得宣称成立。

所有事实按证据桶隔离；测试不能替代 UI，代码不能替代真实 Provider，旧 package 不能替代当前 HEAD。

## 2. 分支、构建与测试

| ID | Claim | 对象 / HEAD | 命令或文件锚点 | 耐久产物 | 结果 | 强度 | 缺口 / 下一门 |
|---|---|---|---|---|---|---|---|
| E-001 | P0 在独立分支执行 | `02334ec8` | `git branch --show-current`; `git rev-parse HEAD`; `git status --short --branch` | `evidence/preflight.txt` | `codex/personal-ai-ranch-p0`，基线 HEAD 可定位 | 强 | preflight 是 P0 采集时快照，不单独证明进入瞬间；入口归属另由本任务会话记录 |
| E-002 | Package 定义 Core、TestSuite、App、RunTests | `Package.swift` | `Package.swift:26-69` | 源码 | 四个 product/target 关系存在 | 强 | 不证明运行行为 |
| E-003 | 仓库权威测试入口是 `RunTests` | `Package.swift`; `Sources/RunTests/main.swift` | `swift run RunTests` | `verify.log` | 423 tests / 5 suites 全绿，约 11.4s | 强 | TestSuite 不依赖 App target，不覆盖 `AppStore`、`MissionScheduler` 和 SwiftUI |
| E-004 | App target 当前可编译 | `02334ec8` | `swift build --product AgentLoopApp` | `build.log` | debug 增量构建通过 | 中强 | 不是 clean/release/package/运行证据 |
| E-005 | 当前 HEAD 的分发脚本可生成 app/zip/dmg | 隔离 worktree `02334ec8` | `scripts/package-app.sh --version 1.1.0`; `codesign --verify --deep --strict`; `unzip -t`; `hdiutil verify` | `package.log`; `evidence/package-verify.log`; `evidence/package-snapshot.txt` | 首次因 GRDB clone 网络超时；复用本机已验证 checkout 后两次 release package 成功；最终复验保存了全部命令、原始输出和 exit code，签名/压缩包/镜像均通过 | 强（本机打包） | 未配置 Developer ID / notarization，未启动分发包；不能宣称正式可分发 |

## 3. 当前 App、UI 与数据状态

| ID | Claim | 对象 / HEAD | 命令或文件锚点 | 耐久产物 | 结果 | 强度 | 缺口 / 下一门 |
|---|---|---|---|---|---|---|---|
| E-010 | 当前真实 App 进程存在且使用 normal 数据根 | PID 10416 的时点快照 | `pgrep`; `lsof`; `AppStore.swift:339-352` | `evidence/runtime-snapshot.txt` | `.build/AgentLoop.app` 打开 `/Users/muzi/Library/Application Support/AgentLoop/agentloop.sqlite`、WAL、SHM 和锁 | 强 | PID/大小会漂移，任何后续操作必须重查 |
| E-011 | 当前 DB 完整但正在运行 | normal DB | read-only SQLite PRAGMA / query | `evidence/runtime-snapshot.txt` | WAL；integrity `ok`；dispatch mode `running`；WAL 非空 | 强 | 当前不满足安全 reset/snapshot 门 |
| E-012 | 真实主场可以打开 | 当前运行 App | macOS AX + screenshot | `evidence/current-live-home.jpg`; `evidence/live-ui-observation.md` | 我的营地、投喂入口、待处理、牛、任务和新手路径可见 | 强（活体） | 没有提交 Feed；截图不能单独把二进制严格绑定到 Git HEAD |
| E-013 | 真实任务工作台可以打开并显示失败/预算 | 当前运行 App | macOS AX + screenshot | `evidence/current-live-app.jpg`; `evidence/live-ui-observation.md` | 2/3 卡完成；2 件成果；预算 473.6k/400k；第三卡受阻 | 强（活体） | 不证明失败恢复或成果验收正确；不严格绑定 HEAD |
| E-014 | 真实像素 Coding 草原读取任务投影 | 当前运行 App | macOS AX + screenshot | `evidence/current-live-pasture.jpg`; `evidence/live-ui-observation.md` | 两头牛、营地知识、待命/复检、成果和真实工作卡可见 | 强（活体） | 单次截图不证明长期动画/状态无漂移；不严格绑定 HEAD |
| E-015 | 当前资源与 UI 代码包含像素牧场 | `Package.swift`; RanchArt | `Package.swift:49-53`; RanchArt 文件清单 | 源码 / 资源 | 资源存在并在真实 UI 渲染 | 强 | 完整可访问性和 Reduce Motion 未复验 |

## 4. 安全、权限与状态目录

| ID | Claim | 对象 / HEAD | 命令或文件锚点 | 耐久产物 | 结果 | 强度 | 缺口 / 下一门 |
|---|---|---|---|---|---|---|---|
| E-020 | 当前 App 不是 App Sandbox | build/package 配置 | `scripts/agentloop.entitlements:5-7`; `scripts/package-app.sh:110-118`; `codesign -d --entitlements` | `evidence/runtime-snapshot.txt` | entitlement 明确 false；当前 ad-hoc app 没有 sandbox entitlement | 强 | 后续目标安全模型仍需 P1/P4 决策 |
| E-021 | normal/preview/custom 状态根可精确解释 | 当前源码 | `AppStore.swift:339-352`; `run-app.sh:88-99` | `test-data-reset-runbook.md` | normal 与 preview 路径及 env 优先级已记录 | 强 | preview flag 本身不隔离，必须检查 env/lsof |
| E-022 | 数据 reset 已有安全 runbook | 当前机器与源码 | StateDirectoryLock、WAL、bootstrap、prefs/Keychain 调查 | `test-data-reset-runbook.md` | 定义收哨、退出、checkpoint、integrity、快照、move 与回退 | 强 | P0 明确不执行；实际执行需要新精确授权 |

## 5. Provider、Runtime Profile 与 CLI

| ID | Claim | 对象 / HEAD | 命令或文件锚点 | 耐久产物 | 结果 | 强度 | 缺口 / 下一门 |
|---|---|---|---|---|---|---|---|
| E-030 | 数据模型支持 API、OAuth、Codex CLI、Claude CLI profiles | 当前源码 | `Sources/AgentLoopCore/Database/Records.swift:136-160` | 源码 | 五类 profile 枚举存在 | 强（实现） | 不等于当前可用 |
| E-031 | OAuth/CLI/API 目录策略已实现 | 当前源码 | `Sources/AgentLoopCore/Provider/ModelCatalogService.swift:35-96` | 源码 / tests | OAuth/CLI 内建只读，API 可刷新 | 强（实现） | 本轮未验证线上 catalog refresh |
| E-032 | 当前 normal DB 只有 OAuth/API profiles | normal DB | read-only count query | `evidence/provider-profile-snapshot.txt` | `chatgpt_oauth=1`（默认），`openai_api=1`；3 头牛 inherit | 强 | 不读取 Keychain，不能证明凭据有效 |
| E-033 | 当前牧场没有 CLI profile | normal DB | 同一 read-only query | `evidence/provider-profile-snapshot.txt` | 没有 `cli_codex` / `cli_claude` 行 | 强 | CLI adapter 尚未接入当前真实牧场路径 |
| E-034 | CLI backend 与 ranchboard bridge 已实现 | 当前源码 | `Sources/AgentLoopCore/Loop/CliProcessBackend.swift:18-173,248-460` | 源码 / tests | 权限映射、CLI 启动、MCP bridge 与终态要求存在 | 强（实现） | 没有本轮 App 内真实 CLI card |
| E-035 | Codex CLI 当前能完成真实请求 | Codex 0.144.5 | `evidence/cli-smoke-commands.txt` 中的固定字符串、read-only、ephemeral 命令 | `provider-cli-smoke.log`; `evidence/cli-smoke-commands.txt` | 最终输出 `P0_CODEX_CLI_OK` | 中强 | WebSocket 5 次断开后回退 HTTPS；有 model cache/plugin/state 告警；不证明牧场 backend |
| E-036 | Claude CLI 已安装但当前请求不可用 | Claude 2.1.81 | `evidence/cli-smoke-commands.txt` 中显式 Sonnet 和默认模型两次固定字符串命令 | `provider-cli-smoke.log`; `evidence/cli-smoke-commands.txt` | 两次 403 `Request not allowed` | 强 | 不得宣称双 CLI 可用；默认 Claude planner/reviewer 当前是单点故障 |
| E-037 | App 内真实 Provider 本轮成功 | 当前 normal App | — | — | 未证明 | 缺失 | 当前 UI 历史显示网关中断；P1 前只能记录缺口，不能宣称成功 |

E-037 是被明确定位的产品能力缺口，不是 P0 要求“Provider 必须成功”的 claim。P0 的完成要求是让真实供给线现状与失败边界可复核；若把 E-037 写成成功，或没有记录它，才构成 P0 阻断。App 内供给线端到端成功属于后续金路径完成门。

## 6. 当前产品表面与缺口

| ID | Claim | 代码锚点 | 证据 | 结论 | 强度 / 缺口 |
|---|---|---|---|---|---|
| E-040 | 主窗口与 Sidebar 已存在 | `AgentLoopApp.swift:5-18`; `RootView.swift:48-109,147-257` | 活体 screenshots | Coding 牧场、营地、任务、回营、牛群、设置可见 | 强 |
| E-041 | 营地首页已有统一文字投喂入口 | `CodingRanchHomeView.swift:23-178`; `FeedComposerView.swift:35-267` | `current-live-home.jpg` | 文字输入与来源/意图 UI 存在 | 强；未提交 |
| E-042 | URL/文件没有真实统一摄取 | `CodingRanchStoreAdapter.swift:310-342` | 源码 | URL 仍主要是元数据，提交固定为 `.text` | 强；P2 缺口 |
| E-043 | 当前 onboarding 不是目标闭环 | `CodingRanchOnboardingView.swift:9-50` | 源码 / 主场 screenshot | 现有两步说明和 0/4 新手卡不等于教练→真实成果→用户验收 | 强；P2 缺口 |
| E-044 | 世界含真实投影和 ambient 行为 | `CodingPastureTheaterView.swift:4-13,607-680` | `current-live-pasture.jpg` | 真实任务状态已进入世界 | 中强；长期状态真实性仍需时序测试 |

## 7. 历史文档治理

| ID | Claim | 对象 / HEAD | 命令或文件锚点 | 耐久产物 | 结果 | 强度 | 缺口 / 下一门 |
|---|---|---|---|---|---|---|---|
| E-050 | 历史方向与证据权威已经分级 | P0 文档集 | 三份历史方向 spec 的 Superseded banner；历史 plan/report/live-test 保持原文 | `historical-document-index.md` | 只有产品方向被取代；历史实施与验证记录仍按原基线保留 | 强 | 旧证据不能替代当前阶段复验；v1.0 live-test 未完成 |

## 8. P1 根因风险基线

| Risk ID | Claim | 精确锚点 | 当前证据 | P1 硬门 |
|---|---|---|---|---|
| R-01 | 普通 Planner 失败可能留下 `.planning` | `AppDatabase.swift:600-632`; `Orchestrator.swift:209-269` | 先建 shell；catch 只记错误 | durable planning job、失败终态、启动收编、回归测试 |
| R-02 | Rumination 可能永久停在 `.ruminating` | `RuminationService.swift:45-88`; `CodingRanchStoreAdapter.swift:96-138,310-342` | 后台 Task 未耐久持有；失败路径可被 `try?` 吞掉 | durable job、lease/adoption、错误可见、回归测试 |
| R-03 | Candidate→Mission 与 source link 非原子 | `CodingRanchStoreAdapter.swift:239-270`; `MissionDraftFactory.swift:45-139` | App 先 startMission 再 link，未使用已有原子 convert | 单事务/幂等命令测试 |
| R-04 | Schedule 在真正启动前 claim | `MissionScheduler.swift:220-256`; `ScheduleStore.swift:338-363` | 启动失败后 `lastFiredAt` 已写 | claim/intention/commit/release 状态机 |
| R-05 | App 层大量 `try?` 会把故障伪装为空 | `AppStore.swift`; `McpStore.swift` | AppStore 约 85 处、Orchestrator 约 15 处、McpStore 约 5 处，需逐项分类 | 禁止静默成功；错误投影和 trace ID |
| R-06 | MCP/知识加载会静默降级 | `Orchestrator.swift:1355-1383` | 注释和实现允许失败变空 | fail-visible 或明确批准的 degraded mode |
| R-07 | `AppStore.swift` 过度集中 | `AppStore.swift`（约 2583 行） | composition、Provider、调度、聊天、适配、UI 投影混合 | 只按 P1 contract 消费者分层，不做无目标大重构 |
| R-08 | 成果查看、知识回写、牛成长含占位/推断 | `CodingRanchStoreAdapter.swift:275-294,484-539`; `NewcomerUnlockPolicy.swift:61-112` | viewed 由 artifact 非空推断，部分字段空，成长依赖事件存在 | Outcome/Verification/Acceptance/Memory 明确状态机 |
| R-09 | 接受 UI 可能早于 durable closeout | `CodingRanchLiveHosts.swift:374-415`; `AppStore.swift:1527-1539` | UI 先导航，再等待持久关闭 | 验收事务/失败 UI/回归测试 |

## 9. 可以宣称 / 不能宣称

### 可以宣称

- `02334ec8` 上 423 项 TestSuite 测试全绿；
- App target 当前能完成 debug build；
- 真实 normal App、主场、工作台和像素草原当前可见；
- 当前 DB integrity 为 `ok`，但仍在运行且 WAL 非空；
- OAuth/API/CLI 的数据模型、适配器与 UI 配置代码存在；
- Codex 裸 CLI 当前可响应，但有传输降级；
- P1 根因风险均有直接代码锚点。

### 不能宣称

- 当前产物已经 Developer ID 签名、公证或通过跨机 Gatekeeper；
- App 内 ChatGPT OAuth/OpenAI API 当前请求成功；
- Claude CLI 当前可用；
- Codex/Claude CLI 已接入当前真实牧场 profile；
- URL/文件已被真正摄取；
- 成果查看、独立验证、用户验收、知识晋升和成长形成真实闭环；
- 绿色 TestSuite 覆盖 AppStore、MissionScheduler、SwiftUI 或真实外部供给线；
- 当前 running DB 可以安全 reset 或作为恢复快照。

## 10. P1 规划门证据

| ID | Claim | 对象 | 证据 | 结果 | 强度 | 下一门 |
|---|---|---|---|---|---|---|
| E-060 | Round 5 冻结输入未经 reviewer 修改 | `p1-stage-spec.md`; `p1-plan.md` | 独立复算 SHA-256；`reviews/05-p1-plan-review.md` | Stage `1124c80e…504d`、Plan `94828d32…eecd` 前后一致 | 强 | 冻结输入继续保持不变 |
| E-061 | Round 5 独立 Review 未通过 | `reviews/05-p1-plan-review.md` | Review SHA-256 `28b4959f…7f10`；DDL counterexamples；SQLite 3.51/3.52 matrix | `CHANGES REQUIRED`：4 P0、1 P1；A1a/P0 acceptance/产品代码门关闭 | 强 | 新一轮修订/复审需要牧场主明确授权 |
| E-062 | Round 5 期间产品代码为零 diff | `Sources`; `Package.swift`; `scripts` | `git diff --name-only -- Sources Package.swift scripts` | 无输出 | 强 | P0 acceptance 前持续复验 |
| E-063 | 牧场主已重新授权有界修订与职责隔离独立复审 | P0 `blocked.md` 的精确关闭范围 | 当前任务用户授权记录；总 spec/P0 状态同步 | 只重新打开 Stage/Plan 编辑门；产品代码、A1a、acceptance 继续关闭 | 强 | 重新冻结并取得零 P0/P1 verdict |
| E-064 | Round 6 冻结输入未经 reviewer 修改 | `p1-stage-spec.md`; `p1-plan.md` | 独立复算 SHA-256；`reviews/06-p1-plan-review.md` | Stage `301dcb48…ff2c`、Plan `8b2c5dd9…c754` 前后一致 | 强 | 保留为当前 Review06 冻结输入 |
| E-065 | Round 6 独立 Review 未通过 | `reviews/06-p1-plan-review.md` | Review SHA-256 `9c688836…1d68`；双 SQLite migration/guard counterexamples；current-code implementability audit | `CHANGES REQUIRED`：1 P0、1 P1；append-only 图缺 11 guards（56/73 应为 67/84），ordinary Ingestion delete 与 v16 guards 冲突 | 强 | P0 acceptance、A1a 与 Stage/Plan 编辑门关闭；下一轮需牧场主明确授权 |
| E-066 | Round 6 结束时产品代码为零 diff | `Sources`; `Package.swift`; `scripts` | `git diff --name-only -- Sources Package.swift scripts`；`git ls-files --others --exclude-standard -- Sources Package.swift scripts` | tracked 与 untracked 均无输出 | 强 | P0 acceptance 前持续复验 |
| E-067 | 牧场主授权 R7 并确认 ordinary Ingestion 删除语义 | P0 `blocked.md` 与当前用户授权记录 | 2026-07-26 原话：“授权 R7，并同意上述 Ingestion 删除语义。” | 只重新打开 Stage/Plan 有界修订与职责隔离 Review07；`resultOnly` 为严格前置条件下删除 result 并回退 queued、保留 source/raw，`sourceAndResult` 为无 link/candidate/活跃 work 且未 materialized 时事务删除 result/ingestion，`everythingIncludingProjection` 永久 typed reject；复用 v14 receipt/event，v16 保留 candidate/link guards 并以 event-bound guards 约束 result/ingestion | 强 | Review07 已完成且非零 P1；该授权已经用尽，产品代码、A1a、P0 acceptance 与所有外部/破坏性操作继续关闭 |
| E-068 | R7 Stage/Plan 已冻结，冻结前职责分离审计未发现 P0/P1 | `p1-stage-spec.md`; `p1-plan.md` | SHA-256 复算；语义与结构审计；8 个 SQL fences；SQLite 3.51/3.52；Markdown、Swift 6 与 GRDB 7 prototype checks | Stage `683a876410689592e5ca7972e1e8206e6763f9baf2da4695ce47bc6b2ab8e40e`、Plan `c7f6e26a10e622e47296a3eb2c2163ec989e26ed519b5d9db8d0ed1b51d25df3`；语义 0 P0/0 P1、结构 0 P0/0 P1；两条 SQLite lane 均为 79 tables/208 indexes/84 triggers、FK 0、integrity ok；UDF arity 53/63；Markdown markers 42/12 平衡且 trailing 0；`writeWithoutTransaction`/autocommit prototype typecheck 通过 | 强 | 冻结前 0/0 不替代 E-070 的独立 Review07；真实 Store/UDF 正例未运行，必须在 P1-E 实现门执行 |
| E-069 | R7 冻结时产品代码仍为零 diff | `Sources`; `Package.swift`; `scripts` | `git diff --name-only -- Sources Package.swift scripts`；`git ls-files --others --exclude-standard -- Sources Package.swift scripts`；`git diff --check` | 产品路径 tracked/untracked 均无输出；diff check 通过 | 强 | Review07 再次确认产品代码零差异；P0 acceptance 前持续复验 |
| E-070 | Review07 独立审查未通过，R7 授权用尽 | `reviews/07-p1-plan-review.md`; R7 冻结 Stage/Plan | Review SHA-256 `7266a4e38e12c20497c4cff4985020a97988372bf363a0e67353ccdc8e49a41a`；冻结哈希前后复算；literal SQL ordinal audit；GRDB 7.11.1 source/typecheck/runtime lifecycle probe；产品路径 diff | `CHANGES REQUIRED`：0 P0、2 P1。R7-P1-1 为 v16 四个 late `DROP TRIGGER` 与规范性 literal trigger ordinal gate 冲突；R7-P1-2 为 GRDB public API 无法在 connection close 时立即失效 UDF cell 并清 weak registry entry。Stage `683a8764…40e`、Plan `c7f6e26…5df3` 前后不变；产品代码零差异 | 强 | R7 授权已经用尽；P0 acceptance、A1a、产品代码与 Stage/Plan 编辑门关闭。R8 有界修订与 Review08 必须先取得牧场主明确授权 |
| E-071 | Review07 两个 P1 已完成只读 R8 可行性消歧 | `evidence/review07-r8-readonly-feasibility.md` | 双 SQLite 虚拟 hoist/rollback；Swift 6 strict + GRDB 7.11.1 raw UDF lifecycle probes；SQLite 官方 `xDestroy`/close 合同；冻结哈希与产品零差异复验 | 推荐唯一关闭路径：barrier 成功后、首个 CREATE 前 hoist 四个 surviving-table UPDATE guard drops；以 raw `sqlite3_create_function_v2` + `xDestroy` 替代 GRDB `DatabaseFunction` ownership，精确覆盖 successful close、BUSY、close_v2 zombie、registration failure 与 pointer reuse | 强 | 只读技术建议，不构成 R8 授权或规范变更；Stage/Plan/产品代码仍关闭，真实 Store/UDF 正例仍未运行 |
| E-072 | 牧场主明确授权 R8 | 当前任务用户原话；`blocked.md` | “授权 R8：仅按 E-071 的两个已验证路径有界修订 Stage/Plan，重新冻结后执行职责隔离 Review08；通过前继续禁止 P0 acceptance、P1-A1a 和产品代码实施。” | 只重新打开 E-071 两路径的 Stage/Plan 修订、重新冻结和 Review08；未授权产品代码、acceptance、Git写操作、release、data reset或外部操作 | 强 | R8修订已冻结；剩余授权仅用于 Review08 |
| E-073 | R8 Stage/Plan 已重新冻结，三路预审为0 P0/0 P1 | `p1-stage-spec.md`; `p1-plan.md`; `evidence/r8-freeze-validation.md` | SHA-256复算；双 SQLite SQL/ordinal/62-boundary rollback；Swift 6 strict + GRDB 7.11.1 lifecycle probes；跨文档语义/范围审计；Markdown/Open Questions检查 | Stage `502393d1413c7ac21616afe0d2e5e847e22e8815d451113806ee94b702d88688`；Plan `1b9ef563b265d6ac0138d083c352837771fc652831e111e92c32d3a36853a4ee`。R7-P1-1/R7-P1-2预审均关闭；SQLite 3.51/3.52保持67/84和79/208/84；lifecycle探针覆盖registration failure、later setup throw、direct close、BUSY、zombie、reuse；语义/范围0/0 | 强 | 冻结前0/0不替代Review08；真实Store/UDF正例和真实v16 Swift migration仍是P1-E实现门 |
| E-074 | R8 冻结时产品代码仍为零 diff | `Package.swift`; `Package.resolved`; `Sources`; `scripts` | tracked/untracked path检查；`git diff --check` | 产品路径tracked/untracked均无输出；diff check通过 | 强 | Review08须再次独立复验；P0 acceptance前持续保持 |
| E-075 | Review08 独立审查通过 | `reviews/08-p1-plan-review.md`; R8 冻结 Stage/Plan | Review SHA-256 `d4e22ccf8b38b33e013969414d14b17ab32bfb94c549fc9df8c349d44a158755`；双 SQLite 124 个 failure boundary、10 个缺失前驱、GRDB 7.11.1/Swift 6 lifecycle probe、产品路径差异与冻结哈希复算 | `APPROVED — 0 P0 / 0 P1`；Stage/Plan 哈希不变；产品路径零差异；真实 Store/UDF 正例明确未实现、未运行 | 强 | 只打开 P0 final acceptance audit，不直接授权 A1a |
| E-076 | P0 最终完成门经两路职责隔离只读审计 | P0 spec §6；当前根任务 Goal；全部 P0 证据 | `evidence/p0-final-acceptance-audit.md`；branch/HEAD、四份 SHA、Open Questions、日志、UI、历史、runbook、权限和产品 tracked/untracked/staged 差异复核 | 无实质 P0 blocker、无新增 P1 finding；根任务 Goal active；最终文本隐私复扫只有规范字段假阳性，净结果为零 | 强 | 终态文书必须与状态回写同批完成 |
| E-077 | P0 Accepted，P1-A1a 进入门打开 | `acceptance.md`; master spec；P0 spec/plan/impl report | 十二项完成门矩阵；最终 post-write 完整性检查 | P0 Accepted；A1a 只能按冻结 `p1-plan.md` §3.1 实施并独立 Review/验收；Stage/Plan 字节不变，产品代码在 P0 仍为零差异 | 强 | A1a 通过前不得进入 A1b；Git、数据与外部权限未扩大 |
