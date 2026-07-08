# M8 实现计划 v1 — 驿路（MCP 客户端，stdio-only）(Level 3，待用户过目)

> 基于 feat/m6 + V2 设计 §5-M8。前置：M7 验收通过（审批分级、PATH 捕获、进程注册表是本里程碑的直接依赖）。
> **Level 3 项：迁移 v6（mcp_server + camp_mcp_enable 两表）**。V2 最大深水区，范围保险见文末。
> 附注：本计划为主循环自写自查（子代理评审因额度触顶未跑，可补）；M7 机制以其计划 D1/D5/D6 为契约引用。

验收（V2 设计 §5-M8 活体验收）：**接入 2 个真实 MCP server，伙伴一次行动内调 GitHub MCP 归纳 issue 列表、调 Playwright MCP 给网页截图；MCP 工具经白名单+审批生效；kill 掉 server 进程，卡片 block、行动不死、重启 server 后重试卡片成功；向导与既有 10 工具全量回归。**

## 现状盘点（已逐条核实）

- **注入点现成**：CardRunner 装配处（M6-D4/D8）——capabilityHandlers 字典 + `toolAccess.allows` 过滤 + 提示词工具区从 `handlers.keys` 派生，三处同源。MCP 工具走同一装配口，构造上自动同步。
- **schema 透传兼容**：`ToolDef.inputSchema` 是 `JSONValue`——MCP tools/list 返回的 JSON Schema 原样透传给 provider，无需建模。
- **白名单语义现成**：ToolAccess v2 显式列表（M6-D5b）明确「外部/MCP 工具必须显式勾选，不被空名单继承」——本里程碑正是该语义的首个消费者。
- **审批默认现成**：M7-D1 已定「MCP 工具默认 write 级」→ 标准档不弹窗、谨慎档过审，用户可在工具管理里升 dangerous。
- **子进程基建现成**（M7）：LoginShellEnvironment（npx/uvx 需要完整 PATH）+ ShellProcessRegistry（收哨/退出清理）。
- **AppStore 双流式对称结构**：chatStreamID/guideStreamID + 两个 DeltaCoalescer + 对称的 stop 逻辑（AppStore.swift ~98-130 区）——第二刀合并目标。
- 官方 SDK `modelcontextprotocol/swift-sdk`：提供 Client + StdioTransport，Swift 6 并发标注；**成熟度未实测**，首任务做探针（见 D1）。

## 决策（D1–D8，待用户过目）

| # | 决策 | 理由 |
|---|---|---|
| D1 | **依赖探针先行**（半天上限）：Package.swift 引官方 swift-sdk（pin 精确版本），写一个 spike 测试跑通 initialize + tools/list + tools/call 对 filesystem server。**失败即切自写 MiniMCP**：stdio JSON-RPC 客户端只需三个方法（initialize/tools/list/tools/call），协议面极小，Codable 直写 | 深水区先探底；自写兜底把外部依赖风险封顶在半天 |
| D2 | **数据模型（迁移 v6）**：`mcp_server`（id, name, command, argsJson, envJson, experimental, createdAt）全局表 + `camp_mcp_enable`（campId, serverId 复合主键）营地级启用关联表 | 设计明示「全局注册 + 营地级启用」；关联表让频道隔离与 M5-0 一致 |
| D3 | **生命周期 `McpServerManager` actor**：按需启动（该营地行动首次派发时 spawn 已启用 servers）；每 server 一个连接，tools/list 结果缓存（server 重启失效）；**失败语义**：启动失败/进程死亡 → server 标记 down + 依赖它的在途卡 block(toolFailure)、**绝不自动重试**，设置页「重启」按钮手动复活；进程登记 ShellProcessRegistry（收哨/退出统一清理）；env = LoginShellEnvironment + server 自定义 envJson 叠加 | 设计明示的保守失败语义；挂死比失败更可怕 |
| D4 | **工具注入与命名**：工具名 `mcp__<server>__<tool>`（双下划线，满足 Anthropic `^[a-zA-Z0-9_-]{1,128}$` 约束；server/tool 名先做字符白名单清洗）；dispatch 时 Orchestrator 按卡所在营地取启用 servers → manager 取工具清单 → CardRunner 以 ClosureToolHandler 注入 capabilityHandlers（调 manager.call，30s 超时）；ToolAccess 显式列表过滤照旧；结果只取文本内容（image/resource 内容替换为「[图片/资源，V2 暂不支持]」占位）并过 `ExternalContent.wrap(source: "MCP·<server>")` | 三处同源装配口不新开旁路；文本-only 是设计定的刀法 |
| D5 | **凭据**：server 的敏感 env（如 GitHub PAT）不进 envJson 明文——`mcp_server` 行可声明 `secretEnvKeys`（argsJson 同级），实际值存 Keychain（account `mcp-<serverId>-<key>`），启动时合成注入。设置页对声明的 secret key 给 SecureField | envJson 落 SQLite 明文放 PAT = 违背「key 永不进 SQLite」纪律 |
| D6 | **精选 server 清单**（内置模板一键添加，非 experimental）：filesystem（`npx -y @modelcontextprotocol/server-filesystem <工作目录>`）、GitHub（`npx -y @modelcontextprotocol/server-github`，PAT 走 D5）、Playwright（`npx -y @playwright/mcp@latest`）。「自定义 server」入口标注 experimental + 风险提示。首次添加任一 server 时检查 node 可用性（which npx via LoginShellEnvironment），缺失给安装指引 | 开箱即用三件覆盖文件/代码/浏览器三大场景 |
| D7 | **UI**：设置页「MCP 驿站」区（模板卡片一键添加/自定义/重启/删除/experimental 签）；营地首页「启用的驿站」开关列表；伙伴编辑器工具区**按 server 分组**展示 `mcp__` 前缀工具勾选（显式授权，默认全不勾）；卡片受阻详情里 server down 时给「去设置页重启」引导 | 显式授权 UI 是 D5b 语义的兑现 |
| D8 | **AppStore 绞杀第二刀**：`McpStore`（server CRUD/启用/状态）拆出；**StreamSession 合并（DM/向导两套对称流式状态收一）列为可砍项**——做不完顺延 M9，砍单申报 | 设计原文「做不完不强求」 |

新增 EventKind：`mcpServerDown`（server 死亡时挂在受影响 mission 上，UI 可渲染）。

## 触及面

- Core：`Mcp/`（新目录：McpServerManager、MiniMCP 或 SDK 适配层、ToolBridge）、`Loop/CardRunner.swift`（外部工具注入）、`Kernel/Orchestrator.swift`（dispatch 时取营地工具清单透传）、`Database/`（迁移 v6 + 两表 CRUD + EventKind +1）、`Support/KeychainStore`（多 secret account 已支持，零改动）。
- App：SettingsView「MCP 驿站」区、营地首页启用开关、CompanionEditorView 分组勾选、`McpStore` 拆分、受阻详情引导。
- 测试：+16±（FakeTransport 驱动 manager：初始化/清单缓存/调用/超时/进程死亡→down；注入后三处同源断言；显式白名单不含 mcp 工具→不注入；审批 write 级默认联动（M7 Gate 复用测试）；命名清洗；v6 迁移）。

## 实现顺序

D1 探针 → D2 迁移与 CRUD → D3 manager（Fake 驱动全绿）→ D4 注入打通（filesystem server 端到端）→ D5 凭据 → D6/D7 清单与 UI → D8 拆分。**范围保险（设计明示）**：超重先砍 experimental 自定义入口保精选清单；再超砍到单 server（Playwright）保端到端；StreamSession 合并随时可弃。

## Open questions（待用户拍板）

1. **D4 工具名前缀** `mcp__<server>__<tool>`——OK？
2. **D5 凭据方案**：secret env 进 Keychain（account 按 server 分）而非 envJson 明文——OK？
3. **D6 node 依赖**：三个精选 server 都要 npx（本机需 Node）；缺失时给指引而不代装——OK？
4. M7 若有延期，M8 是否允许在**只有白名单、没有审批门**的状态下先行接 filesystem（只读工具先行）？推荐不允许（守「先笼子后野兽」），除非你要抢进度。
