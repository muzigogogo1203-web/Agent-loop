# P0 Hardening Round 1 — Implementation Report

日期：2026-07-10  
分支：`codex/p0-hardening-round1`  
状态：实现与验证完成，未提交

## 结果摘要

本轮完成四组根因修复，并补齐由全量验证暴露出的两处测试同步问题：

1. 伙伴工具白名单损坏时 fail-closed：仅保留行动板工具，不启动/装配 MCP，并写入可检索诊断。
2. 单实例与 SQLite 竞争治理：5 秒 busy timeout、开发/分发包单实例声明、状态目录进程锁、预览状态隔离，以及脚本全模式冷启动检查。
3. 记忆沉淀原子化：水位 CAS、note 与 event 在同一事务提交；失败或并发输家完整回滚。
4. Orchestrator 警告与可观测性：移除编译器确认的冗余 `await`；提案自愈和诊断持久化失败不再静默。

没有变更数据库 schema、依赖、产品 UI 或发布版本。

## 变更文件

### 生产代码

- `Sources/AgentLoopCore/Tools/ToolAccess.swift`
  - 坏 JSON、错误 v2 形状和未知版本返回零能力工具且标记 `parseFailed`。
  - v2 编码失败改为 fail-fast，不再危险回退为 legacy `[]`。
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
  - 解析失败时记录诊断并跳过 MCP 装配。
  - 提案自愈失败记录 OSLog、持久化诊断并发送内核事件。
  - 移除 touched paths 中的冗余 `await`。
- `Sources/AgentLoopCore/Database/AppDatabase.swift`
  - WAL 保持不变，增加 5 秒 busy timeout。
  - kernel-error event 持久化失败改为 OSLog error，不再 `try?` 吞错。
- `Sources/AgentLoopCore/Support/StateDirectoryLock.swift`
  - 新增基于 `.agentloop.lock` 的非阻塞 `flock`，使用 `O_CLOEXEC`，错误包含锁路径和 errno。
- `Sources/AgentLoopApp/AppStore.swift`
  - 数据库初始化前获取并在 AppStore 生命周期内持有状态目录锁。
- `Sources/AgentLoopCore/Database/KnowledgeStore.swift`
  - 新增 DM/Guide 原子沉淀入口，以及水位 compare-and-set。
- `Sources/AgentLoopCore/Knowledge/MemoryDistillService.swift`
  - produced-note 路径改用原子事务；stale winner 抑制重复 note；失败写 OSLog。
- `scripts/run-app.sh`
  - 删除 `open -n`；所有脚本启动均要求冷启动；`--preview` 默认使用隔离状态目录；生成的 plist 禁止多实例；构建前后各检查一次现有进程。
- `scripts/package-app.sh`
  - 分发 plist 禁止多实例。

### 回归测试

- `Sources/AgentLoopTestSuite/ToolAccessTests.swift`
- `Sources/AgentLoopTestSuite/CardRunnerTests.swift`
- `Sources/AgentLoopTestSuite/McpTests.swift`
- `Sources/AgentLoopTestSuite/DatabaseTests.swift`
- `Sources/AgentLoopTestSuite/SupportTests.swift`
- `Sources/AgentLoopTestSuite/MemoryDistillTests.swift`
- `Sources/AgentLoopTestSuite/OrchestratorTests.swift`
- `Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift`
- `Sources/AgentLoopTestSuite/AgentLoopTests.swift`

新增覆盖包括：坏配置 board-only、MCP 零启动、诊断事件、WAL/busy timeout、独立 file-description 锁竞争与释放、note/event 注入失败回滚、CAS 重复抑制、模型工作期间新消息边界、提案自愈错误持久化与推送。

## 验证结果

- 权威套件：`swift run RunTests`，**305/305 通过**；完整 stdout/stderr 见 `verify.log`。
- 独立 QA 在最终快照上连续运行 3 次权威套件，均为 **305/305 通过**。
- `swift build --product AgentLoopApp`：通过。
- `swift build --product AgentLoopApp -Xswiftc -warnings-as-errors`：通过。
- 独立 QA 的全新 scratch warnings-as-errors 构建：通过。
- `zsh -n scripts/run-app.sh scripts/package-app.sh`：通过。
- 两份脚本生成的 Info.plist 经 `plutil -lint`：通过。
- `git diff --check`：通过。
- 有活跃 AgentLoop 时，plain / preview / custom-state 三种脚本调用均在构建前以 rc=1 拒绝；未知参数 rc=2。
- 未启动第二个 App，避免干扰 `/private/tmp/agentloop-m8` 的活跃实例。

补充：主控尝试再做一次新的 scratch 构建时，停在 GRDB 的 SQLiteLib 子模块网络拉取；该冗余运行被中止。代码验证不依赖该结果，因为当前工作区 warnings-as-errors 构建及独立 QA 的 fresh-scratch 构建均已通过。

## 验证期间发现并修复的问题

- `rateLimitTriggersGlobalCooldownThenRecovers` 曾在全量并发中先观察到 card blocked、后写 cooldown event。测试改为等待 `Orchestrator.waitUntilIdle()` 后再读事件，未增加重试或弱化断言。
- `slowActiveStreamDoesNotIdleTimeout` 曾因单事件间隔相对 timeout 的调度余量不足而偶发假超时。测试保留“总流时长大于 timeout”的证明，同时把单事件间隔调整为远小于 timeout；生产超时逻辑未改。

## 计划调整与偏差

- 初始范围在实现前经静态审查补入跨 bundle/raw-binary 的状态目录锁；否则仅靠 bundle 单实例键无法保护同一数据库。
- 全量验证暴露的两处既有测试同步问题已显式加入 `plan.md` 后修复。
- 新增 Orchestrator/MCP、模型中途新消息、提案自愈失败三条集成回归，以满足 completion definition 的端到端证据要求。
- 除上述已写回计划的收口项外，无未计划的架构、数据模型或依赖决策。

## 残余风险 / 下一轮候选

- P3：`run-app.sh` 最后一次 `pgrep` 与 `open` 之间仍存在极小 TOCTOU 窗口；若同 bundle 进程恰在此间启动，LaunchServices 仍可能复用旧进程并忽略本次环境。当前双检查已缩小窗口。根治方案是独立 preview bundle ID，或由 App 持久化并可验证运行模式 marker；不在本轮范围。
- 更大的 P0/P1 审计项（durable halt、planning-attempt recovery、run/card outcome 原子化、预算预留、MCP 进程组/沙箱等）继续留在下一轮，不在本次实现中静默扩展。

## Git

- 已创建并使用分支 `codex/p0-hardening-round1`。
- 未 stage、未 commit、未 push。
