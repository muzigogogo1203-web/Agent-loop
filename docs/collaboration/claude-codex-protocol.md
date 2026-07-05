# AgentLoop 开发范式：Claude 规划/审查 × Codex 实现

本文档是 AgentLoop 项目的**默认开发协议**。除非用户明确说"这次不用协作流程"，所有非琐碎实现工作都按此执行。

核心目标：

1. 节省 Claude token —— 所有可外包的工作（写代码、探索代码库、跑测试、读日志）都交给 Codex（GPT-5.5, xhigh）。
2. 保证质量 —— Claude 负责决策完备的规划与完备的 review，Codex 不做架构决策。
3. 稳定触发、不留死角 —— 每个环节都有明确的触发命令、产物文件、退出条件和兜底路径。

## 1. 角色分工

| 职责 | 负责方 |
|---|---|
| 需求澄清、风险分级、方案规划（spec/plan/tasks） | Claude |
| 代码实现、代码库探索、跑测试/构建、日志排查、机械性修改 | Codex |
| 代码 review、验收判定 | Claude |
| 按 review 结论修复 | Codex（resume 同一会话） |
| 高影响产品/架构决策 | 用户（Claude 负责把问题问出来） |

**外包原则**：凡是"读得多、写得多、但决策少"的活，一律给 Codex。Claude 只消费结论文件和增量 diff，不做全库扫描。

## 2. 任务分级

- **Level 0（琐碎）**：typo、注释、单行文案。Claude 直接改或一句话让 Codex 改，不走流程。
- **Level 1（局部）**：单文件/单组件修复。Claude 写一段简短任务说明 → Codex 实现 → Claude review diff。可跳过正式 plan 文件。
- **Level 2/3（跨模块/高风险）**：完整流程（§3）。涉及 GRDB schema、卡片状态机、交接包契约、并发模型、Keychain/沙箱的一律按 Level 3，plan 需用户确认后才触发实现。

## 3. 完整流程（Level 2/3）

每个任务建目录 `docs/collaboration/tasks/<yyyy-mm-dd>-<slug>/`（下称 `$TASK`）。

```text
1. Claude 澄清需求，必要时向用户提问（高影响决策不得自行发明）。
2. Claude 写 $TASK/plan.md（见 §4 决策完备标准），Level 3 需用户点头。
3. Claude 触发 Codex 实现（§5 命令）。
4. Codex 实现 + 自测，产出 $TASK/impl-report.md 与 $TASK/verify.log。
5. Claude review（§6 清单），结论写 $TASK/reviews/NN-claude-review.md。
6. 有 P0/P1 → codex exec resume 修复 → 回到 5。最多 3 轮，仍不过则升级给用户。
7. Claude 写 $TASK/acceptance.md：改了什么、验证了什么、残留风险。
```

## 4. plan.md 决策完备标准

Codex 不应需要发明任何重大决策。plan 必须包含：

- **目标与非目标**（防 scope creep）。
- **触及的文件/模块清单**与每处改动意图。
- **数据模型/契约变化**：GRDB 表、HandoffPayload、工具 schema 等逐字段写清。
- **边界与错误路径**：取消、超时、流中断、校验失败时的行为。
- **测试要求**：新增哪些测试、放在 `Sources/AgentLoopTestSuite/` 哪个文件。
- **验证命令**：本仓库权威跑法是 `swift run RunTests`（CLT-only 机器上 `swift test` 输出不可靠）；UI 可启动性用 `swift run AgentLoopApp` 构建通过为准。
- **明确的完成定义**。

plan 里留一节「Open questions」——若非空，先问用户，不触发实现。

## 5. 触发机制（稳定触发的硬性约定）

### 首轮实现

```bash
cd /Users/muzi/Agent-loop && codex exec --cd "$PWD" --sandbox workspace-write \
  --dangerously-bypass-hook-trust=false 2>&1 \
  "You are the IMPLEMENTER for AgentLoop. Read AGENTS.md first, then read <$TASK>/plan.md and implement it exactly. Rules: (1) Do not make architecture/product decisions not in the plan — if blocked, write the question to <$TASK>/blocked.md and STOP. (2) Follow existing Swift 6 / GRDB / actor patterns in the codebase. (3) Run 'swift run RunTests' and save full output to <$TASK>/verify.log. (4) Write <$TASK>/impl-report.md: what changed (file list), test results, anything deviating from plan. Do not commit."
```

- Claude 用 Bash `run_in_background` 挂起该命令，完成后回来收结果；不轮询。
- 超时预算：Level 1 ≤ 10 分钟，Level 2/3 ≤ 30 分钟；超时先看 impl-report/blocked.md 是否已产出，再决定 resume 还是重试。

### 修复轮

```bash
cd /Users/muzi/Agent-loop && codex exec resume --last \
  "Read <$TASK>/reviews/NN-claude-review.md. Fix all P0/P1 findings (P2 fix if cheap, otherwise note why not). Rerun 'swift run RunTests', append output to verify.log, update impl-report.md."
```

`resume --last` 复用 Codex 自己的实现上下文，双方都省 token。若 resume 失效（会话丢失），退化为首轮命令 + 附上 review 文件路径。

### 探索/杂活外包

不止实现可外包。现状调研、失败日志分析、机械重构等用只读或写沙箱的 `codex exec`，要求产出结论写到 `$TASK/notes/*.md`，Claude 只读结论。

### 死角兜底

- Codex 无输出/崩溃 → 重试一次；再失败则 Claude 接管实现并告知用户（协议降级，不静默卡死）。
- Codex 写了 blocked.md → Claude 回答或转问用户，答案追加进 plan.md，resume 继续。
- Codex 越权改了 plan 外的东西 → review 中标 P0，要求回滚该部分。
- 工作树有用户未提交改动 → 触发前 `git status` 快照，review 时核对 Codex 没动无关文件。

## 6. Claude review 完备清单

逐项过，结论按 P0（必须修）/P1（应修）/P2（建议）/P3（备忘）：

1. **符合 plan**：每个 task 都实现了？有 plan 外改动吗？
2. **正确性**：边界、错误路径、取消/超时行为、整数溢出、可选值强解包。
3. **并发**：Swift 6 严格并发下 actor 隔离正确、无跨 actor 数据竞争、AsyncStream 生命周期正确。
4. **数据层**：GRDB 迁移可重放、事务边界正确、不破坏既有数据。
5. **契约稳定**：HandoffPayload/工具 schema/JSON 编码（注意 sortedKeys——键序影响 prompt 缓存）。
6. **测试真实性**：verify.log 里测试确实跑了且全绿；新逻辑有对应测试而非只有 happy path。
7. **安全**：Keychain、沙箱书签、不泄露 API key 到日志。
8. **代码质量**：贴合既有风格，无多余抽象、无死代码、无残留调试输出。

review 方式：读 `git diff`（增量）+ impl-report + verify.log 关键行；只在 diff 引出疑问时定点读周边源码。

## 7. Git 纪律

- Codex 不 commit；commit 由 Claude 在验收通过后执行（或按用户指示）。
- 不 push、不 rebase、不动用户未提交的改动。
- Level 2/3 建议在 feature 分支上进行（沿用现有 feat/* 习惯）。

## 8. 历史雷点（review 必查项来源）

M1 评审抓过的真实 bug 类型，Codex 实现和 Claude review 都要对照：intValue 溢出崩溃、JSON 键序破坏 prompt 缓存、退避算术溢出、取消把卡片卡死在 running、complete_card 省略 artifacts 键烧自愈。
