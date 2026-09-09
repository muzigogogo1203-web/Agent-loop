# 产品接手基线审计

日期：2026-09-05。状态：**本轮接手与基线审计完成，独立复核通过（0 P0 / 0 P1 / 0 P2）；可信版本基线尚未验收。**

独立复核：`reviews/01-baseline-review.md`。这是接手文档与审计证据的通过，不是当前软件已通过全部工程门。下一轮先处理执行稳定性和严格构建，再进入完整用户流程的实施。

## 接手结论

已获用户确认：由 Codex 负责产品方向、普通可逆取舍、设计实施与交付，重要改动进行职责隔离复核。长期个人 AI 牧场愿景不变，优先收口可日常使用的桌面 Coding 工作闭环。决策边界与三个里程碑见 `spec.md`。

本轮没有修改 Swift、数据库、测试、依赖或打包脚本；只更新六个文档入口、补正历史验证记录并取证。未执行 commit、push、merge、release、公开通信、支付、真实 Provider 调用、用户数据删除或 App 启动。

## 当前版本身份

- 权威目录：`/Users/muzi/Agent-loop`。
- 开始分支：`codex/personal-ai-ranch-p0`；接手分支：`codex/product-takeover-baseline-20260905`。
- HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`。HEAD 只是历史基底，不代表包含所有当前改动。
- 开始时已有 97 个 tracked 文件改动（+70051 / -6309）及大量 untracked 实现/证据，均保留。其他 worktree 未修改。
- `source-before.sha256`：303 个当前存在的源码、测试、package、scripts 与 `.agents` 文件的清单。清单 SHA-256：`6d91b9e4eb0bee2917b395b5780f10ad565a6e4271cce9367606e4a2b256aaee`。不含文档或生成物，不把已删除的 tracked 路径当成存在文件；删除状态保留在 `baseline.txt`。
- 初始磁盘可用约 18 GiB，严格构建后约 16 GiB；没有同时运行其他 Swift runner 或 App。不把这些观察当作排除系统负载的完整证据。

## 新验证结果

| 验证 | 本轮事实 | 证据 |
| --- | --- | --- |
| 默认全量 | `swift run RunTests`，1086 tests / 31 suites，47.542 秒，6 issues，exit 1 | `verify.log` |
| 六项定向复核 | 六个精确 filter 各运行一次，均带 `--no-parallel`，六次 exit 0 | `focused-reruns.log` |
| 严格 App 构建 | `swift build --product AgentLoopApp -Xswiftc -warnings-as-errors`，exit 1，13 处唯一诊断位置 | `build.log` |
| 新包与预览启动 | 构建门失败后跳过；旧包仅只读识别，不冒充新构建 | `launch-status.md` |
| 源码保全与格式 | 303 文件前后清单完全一致；`git diff --check` exit 0 | `source-after.sha256`、`final-checks.log` |
| 真实 Provider/CLI、用户流程验收 | 未执行；不由合成 fixture 测试代替 | 本报告权限边界 |

默认全量与 Sept 1 的失败集合、错误类别完全一致：

| Test | 默认全量观察（用例计时） | 定向复核（每次 run summary 计时） |
| --- | --- | --- |
| `p1f1_075CLIHelpCapabilityMismatchIsUnsupported` | `processGroupSurvived`，11.243 秒 | pass，36.870 秒 |
| `boardServerStopWaitsForBlockedHandlerThenCloses` | `socketSetupFailed("Connection refused")` | pass，2.206 秒 |
| `boardServerStopWakesBlockedAcceptLoopAndReleasesListener` | `receiveTimedOut` | pass，0.245 秒 |
| `shellTimeoutTerminatesProcess` | elapsed 7.477318958 秒，要求 < 5 秒 | pass，0.787 秒 |
| `cliProcessBackendCancellationEscalatesAfterGrace` | `processCleanupFailed("process did not exit within kill grace")` | pass，1.024 秒 |
| `cliProcessBackendCancellationReturnsCheckedEvidence` | 同上 | pass，0.709 秒 |

定向通过支持继续调查组合运行条件，不证明根因已确定或修复。`processGroupSurvived` 同时用于多个清理阶段，不能从错误名称断言子进程泄漏；两个 Board 失败均发生在 stop 前的连接/hello 阶段。独立根因调查见 `diagnostic-notes.md`。

严格构建诊断来自：

- `Orchestrator.swift`：1 处无需 async 的 await、8 处已弃用的数组 `String(cString:)`、1 处未修改的 var。
- `BoardServerBridgeMain.swift`、`CliEngineAdapter.swift`：各 1 处同类 String 数组重载弃用。
- `PlanningProviderResolver.swift`：1 处不需要的 try。

这些是 warnings-as-errors 模式下的错误。不能写成“普通 App 构建也已失败”：本轮没有另跑普通 App 构建，也没有通过关闭严格告警来宣布构建门通过。

## 文档修订范围

1. `AGENTS.md`：产品/工程负责人授权、独立复核、范围与证据纪律。
2. `CLAUDE.md`：可选参与者指南，与当前负责制保持一致。
3. `README.md`：移除当前仍在 P0 的误导，区分已有 feed 主流程与目标工作闭环。
4. `docs/collaboration/claude-codex-protocol.md`：显式当前覆盖；历史协议保留，不把其中固定模型/角色命令当作当前要求。
5. `docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`：当前状态/治理说明，历史正文和哈希保留，产品不变量不变。
6. Sept 1 deletion `impl-report.md`：增加带日期勘误，原始日志不变。

每个文件的原文快照在 `pre-change/`。本轮审查针对这六处增量和新审计产物，不能据此声称已独立复核全部历史 dirty 实现。

## 历史报告勘误

Sept 1 默认测试实际为六项失败/六个 issue，只复核了其中五项。遗漏的是 `p1f1_075CLIHelpCapabilityMismatchIsUnsupported` / `processGroupSurvived`。本轮补齐一次独立复核，但不会改写 Sept 1 的历史运行结果。

原始日志 SHA-256：

- Sept 1 `verify.log`：`ae8a1b8fcadd177b27de8b035c07f26c5251eddeb492f75d8c9db6e2fea70ff5`。
- Sept 1 `serial-reruns.log`：`0e7fb5dbf425de9eed14511f497f7b0b0de6108a49a2d722a770373304c51f45`。

## 下一步与完成边界

第一优先级是一次有明确结束标准的执行稳定性修复：对默认组合运行采集一次进程栈/队列阶段时序，验证共享后台队列阻塞或执行器饥饿的假设；同时把清理的 signal、reap、EOF、server stop 错误分开定位。证据明确后才修改共享生命周期/调度根因，不采用增大 timeout、整套串行化或重试刷绿。

严格告警清理作为独立可复核小任务处理，涉及路径字符串解码时保持 NUL 截断、UTF-8 与路径校验语义，不能机械替换破坏权限边界。随后复跑默认全量、严格构建和隔离启动，再规划默认目标入口到共同理解/成果契约的首个完整界面切片。

本轮仍未关闭 P1-F1 的完整 source/compatibility 门与全量历史实现独立 Review；未声明 P1-F1、P1 或 P2 Accepted。不会把基线审计完成当作可交付产品验收完成。

## 工作方式取舍

- 沿用当前 dirty 目录并切新分支，避免遗漏历史实现；代价是依靠原文快照和哈希证明本轮范围，而不是 clean worktree 隔离。
- 只让一个 Swift runner 运行，文档编辑与读源码调查并行；代价是如有外部负载仍需另行排查，不能假定环境完全空闲。
- 保留报告、日志和本轮工作记录，不自动 commit 或清理其他任务的文件；代价是本地会留下审计资料。

内部 scratch 工具曾因两个 `plan.md` 同名向旧 SDD 工作目录写入 `/Users/muzi/Agent-loop/.superpowers/sdd/plan/task-1-brief.md`，随后一次不匹配的生成尝试把它变成空文件。`scratch-path-check.log` 的文件出生时间确认该文件于本轮 22:03:48 创建；旧 ledger 仍是 Aug 29 的修改时间，没有覆盖历史 ledger。已把这个本轮误生成的空文件移至废纸篓（可恢复），并改用唯一命名的本轮 plan/workspace。本轮必要证据全部保存于本任务目录。
