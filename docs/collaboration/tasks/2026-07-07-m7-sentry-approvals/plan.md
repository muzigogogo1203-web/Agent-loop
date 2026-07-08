# M7 实现计划 v1 — 哨卡（授权分级 + kill switch + shell + 成本面板）(Level 3，待用户过目)

> 基于 feat/m6 + V2 设计 §5-M7。前置：M6 用户正式测试通过、打 m6 tag。
> 分工沿用：全部代码 Claude 亲自实现；UI 先设计后落地，截图循环自验。
> **Level 3 项：迁移 v5（mission.autonomy 列）**。
> 附注：本计划为主循环自写自查（子代理评审编队因会话额度触顶未跑成，额度恢复后可补评审轮）。
> **跨计划迁移序协调（M7-M10 共同约定）**：v5=M7 / v6=M8 / v7=M9 / v8=M10，详见各计划。

验收（V2 设计 §5-M7 活体验收）：**真实小任务「clone 一个仓库并跑通测试」由伙伴用 shell 完成；`rm -rf` 类命令在标准档触发审批、弹窗可见完整命令；放手档在预算内不弹窗；行动中途 kill switch 一键止损，事件日志完整、无孤儿卡、无残留子进程；成本面板分账含规划轮。验收专项盯审批疲劳：分级矩阵若退化成「全部弹窗」或「全部放行」即返工。**

## 现状盘点（已逐条核实）

- **ask_user 门链路完整可复用**：`BoardTools.swift:117` askUser → `:160 suspendCardForUserRequest`（卡片 blocked(needsHumanInput) + user_request 行，同事务）；`user_request` 表有自由文本 `kind` 列（无枚举约束，**加新 kind 零迁移**）；UI `AskUserPromptView`（卡片行内联渲染）；答复后卡片回 ready 冷启动重跑，`answeredRequests(cardId)`（AppDatabase.swift:773）注入 ContextPacket。
- `Orchestrator.shutdown()` 存在（取消 tick/planning/running/distill 四类任务）但至今无人调用；`AppDelegate` 已存在（AgentLoopApp.swift，NSApplicationDelegateAdaptor）——退出钩子接线点现成。
- 429 处理只在请求层：`AnthropicProvider.swift:133` 429/5xx 按 retry-after 或指数退避（maxRetries=3），重试耗尽抛 ProviderError；**无全局派发协调**。
- 成本数据已齐：`run` 表 tokensIn/tokensOut + `card.assigneeId` 可推按卡/按伙伴分账；规划轮在 `planning_tokens` 事件（M6.5，payload 含三段用量）；行动总额在 `mission.spentTokens`。
- 工具风险属性无处安放 → ToolDef 是纯静态定义（M6 后单一分发、白名单在 CardRunner 收口）——分级属性加在 ToolDef 旁最顺。
- 文本截断工具 `WebFetchTool.truncateUTF8` 是 package static——shell 输出截断可复用（顺手抽到 `Support/TextTruncation.swift`）。

## 决策（D1–D9，待用户过目）

| # | 决策 | 理由 |
|---|---|---|
| D1 | **工具风险三级**：`ToolRisk` 枚举（readOnly/write/dangerous），`ToolDef.risk(name:)` 单点映射。板工具四件 + 只读五件（list/read/web_fetch/web_search/search_camp_notes）= readOnly **且豁免审批**（complete_card 含产物落盘但它是内核终结契约，被审批卡死=违背 spec §5.2-4）；write_file = write；shell = dangerous；**MCP 工具默认 write（M8 引用此默认）** | 分级集中定义；终结契约不可被门挡 |
| D2 | **自主档位**（远征风：谨慎 careful / 标准 standard / 放手 free）：**迁移 v5 加 `mission.autonomy TEXT NOT NULL DEFAULT 'standard'`**；新行动表单选择（缺省取设置页全局默认，UserDefaults）；行动执行中**可改**（行动头部控件），变更记 `EventKind.autonomyChanged` 事件。放行矩阵：谨慎=write 即审；标准=dangerous 才审；放手=预算内全放行 | 档位属于行动事实，进 DB 不进 UserDefaults；中途可改是治审批疲劳的阀门 |
| D3 | **审批门 = user_request 复用**：新 `kind: "approval"`（零迁移）；`options_json` 存 `{tool, inputJson 全文, inputHash}`；审批弹卡复用 AskUserPromptView 通道但**必须渲染动作实体**（shell 命令全文/写入路径+内容摘要，等宽字体）；answer = approve/deny。挂起语义原样复用 suspendCardForUserRequest（blocked(needsHumanInput)），不引入新终结方式 | 设计 §5-M7 明示复用；持久门崩溃恢复语义自动继承 |
| D4 | **授权令牌语义**：批准后卡片冷启动重跑，模型会再次调用同一工具——`ApprovalGate`（包裹 ToolExecutor 的 handler 装饰层，在 CardRunner 装配处套上）放行判据 = 本卡已有 approved 的 `(tool, inputHash)` 记录（SHA256(tool + 规范化 JSON)）；**同参数放行一次性、参数变了重新审批**；deny → 该调用返回 is_error tool_result（「用户拒绝了此操作：<理由>」）让模型改道，不挂卡 | 一次性+参数绑定防「批一次等于全放」；deny 不挂卡避免死循环 |
| D5 | **kill switch「紧急收哨」**：`Orchestrator.emergencyStop()`——取消全部在途 run（卡片走既有 card_interrupted → ready）+ 取消 planning + 置 `halted` 标志（reconcile 不派发）+ `EventKind.campHalted`；`resume()` 清标志并 reconcile，记 campResumed。UI：行动页工具栏红色「收哨」按钮 + Cmd+.；halted 状态全局横幅提示可恢复。**App 退出接线**：AppDelegate.applicationWillTerminate → shutdown + ShellProcessRegistry 清理（一并消掉「shutdown 无人调用」债） | 复用孤儿卡领养语义，重启/恢复零新机制 |
| D6 | **ShellTool（dangerous）**：`/bin/zsh -c <command>`，cwd 锁定小队工作目录（无目录→error 拒绝）；超时 120s（KernelDefaults.shellTimeout）；stdout+stderr 合并按字节截断 20KB（复用 truncateUTF8，抽 Support/TextTruncation）；退出码非零→结果标注但不算工具错误（模型自判）。**进程管理**：`ShellProcessRegistry` actor 登记活跃 Process，行动取消/收哨/App 退出时 terminate() 全部；**限制申报：只终止直接子进程**（孙进程逃逸靠超时兜底；进程组 killpg 需要 setpgid 注入，V2 不做 C shim）。**PATH 捕获**：启动后异步 `zsh -l -c env` 一次性解析缓存（`LoginShellEnvironment`），注入 shell 与 M8 MCP 子进程 | GUI app 极简 PATH 是桌面 MCP 宿主经典坑，M7 立机制 M8 复用 |
| D7 | **成本面板**：卡片详情弹层加「花销」节（本卡各 run 的 tokens）；行动头部预算指示扩展为可点开的分账浮层（按伙伴/按卡/规划轮三组，数据 = runs join cards + planning_tokens 事件聚合）；营地首页加营地累计（missions.spentTokens 求和）。口径文案「本地估算（按 API 回报用量累计）」 | 数据全部现成，纯投影 UI |
| D8 | **全局限流兜底**：CardRunner 捕获 `ProviderError.http(429)`（重试耗尽后冒泡）→ 发 KernelEvent → Orchestrator 置 15s `cooldownUntil`，reconcile 期间不派发新卡（在途不动），记 `EventKind.rateLimitCooldown`。申报：provider 内部退避已覆盖多数场景，此为多伙伴并发下的派发层兜底 | 轻实现；不改 ProviderEvent 协议面 |
| D9 | **AppStore 绞杀第一刀**：`ApprovalStore`（待审列表/答复动作/自主档位读写/收哨状态）拆出；本域 try? 吞错改 toast 浮出 | 设计明示的第一刀 |

新增 EventKind：`approvalRequested`/`approvalDecided`/`autonomyChanged`/`campHalted`/`campResumed`/`rateLimitCooldown`（测试断言照例钉裸字符串）。

## 触及面

- Core：`Tools/`（ToolRisk + ShellTool 新建 + ApprovalGate 装饰层）、`Support/`（LoginShellEnvironment、ShellProcessRegistry、TextTruncation 抽取）、`Loop/CardRunner.swift`（Gate 套装 + 429 冒泡）、`Kernel/Orchestrator.swift`（emergencyStop/resume/cooldown + autonomy 透传）、`Database/`（迁移 v5、user_request approval kind 的读写扩展、EventKind +6）。
- App：新行动表单（档位选择）、行动头部（档位控件 + 收哨按钮 + 分账浮层）、AskUserPromptView（approval 渲染分支：等宽命令全文）、SettingsView（全局默认档位）、`ApprovalStore` 拆分、AppDelegate 退出接线。
- 测试：+18±（矩阵×档位放行/挂起、inputHash 一次性授权、deny 改道、emergencyStop 后无孤儿卡+重启续跑、shell 超时/截断/无目录拒绝/退出清理、429 冷却不派发、autonomy 迁移与事件、成本聚合正确性）。

## 实现顺序

D1 分级 + D2 档位（v5 迁移）→ D3/D4 审批门与令牌 → D6 shell（第一个 dangerous 消费者，验证整条门链）→ D5 收哨与退出接线 → D8 限流 → D7 成本面板 → D9 拆分收尾。每步 RunTests 全绿 + App 目标 swift build。

## Open questions（待用户拍板）

1. **D2 档位中途可改**（记事件）vs 锁定到收营——推荐可改，OK？
2. **D4 授权粒度**：同卡同工具**同参数**一次性放行（参数变了重审）——还是同卡同工具后续全放行？推荐前者。
3. **D5 收哨入口**：行动页工具栏按钮 + Cmd+.（不做菜单栏全局项，M10 常驻模式时再加）——OK？
4. **D6 子进程限制**：只 terminate 直接子进程、孙进程靠超时兜底（不做 C shim/进程组）——接受？
