# M8「驿路」实现报告（2026-07-08，全部代码 Claude 亲自实现）

基线 1e13630（feat/m8 自 feat/m7 分出）→ 收尾 HEAD。**288 测试全绿**（M7 收尾 264 + 新增 24，另有 2 个 env 门控活体探针默认跳过）；App 目标编译通过；UI 截图循环亮暗双色自验通过，且**在真实 playwright MCP server 上完整走通 停摆→手动重启→在营·23 工具 的生命周期**。

## D1 探针结论（计划要求申报）

官方 `modelcontextprotocol/swift-sdk`（0.12.1）**resolve 与编译成功**，但判定不采用：

1. 它的 `StdioTransport` 只接现成文件描述符——**子进程的拉起/env 合成/收哨/死亡检测仍需全套自建**，SDK 只省下 JSON-RPC 封帧；
2. 拖进 swift-nio/atomics/collections/system/log/eventsource 六个传递依赖（项目现在只有 GRDB），为三个方法的协议面不值；
3. 0.x API 漂移风险 + 它自带 `Value` JSON 类型与我们 `JSONValue` 的双向转换税。

→ 按计划兜底路线自写 **MiniMCP**（initialize / tools/list 带翻页 / tools/call，换行分帧 JSON-RPC 2.0，对端主动请求一律 -32601，容忍 stdout 日志噪声行）。**两个活体探针钉住协议正确性**：`AGENTLOOP_MCP_SPIKE=1`（filesystem server 三方法全链路）、`AGENTLOOP_MCP_MANAGER_SPIKE=1`（Manager 全路径拉起真实 playwright，23 工具组装成名）。

## 交付对照（plan v1 D1–D8 全部落地）

| 决策 | 落点 | 提交 |
|---|---|---|
| D1 MiniMCP | `Mcp/MiniMcpClient.swift`（actor，pending 按 id 配对、超时看门狗、死亡回调区分主动关闭）+ `Mcp/McpTransport.swift`（协议 + StdioProcessTransport：/usr/bin/env 解析命令、F_SETNOSIGPIPE、stderr 尾部 4KB 捕获、PID 进 ShellProcessRegistry） | m8.0-4 |
| D2 迁移 v6 | `mcp_server`（name 唯一且**建后不可改**——它是工具名组成部分）+ `camp_mcp_enable` 复合主键关联表；CRUD 在 `Database/McpDatabase.swift`（删除级联清启用关联） | m8.0-4 |
| D3 Manager | `Mcp/McpServerManager.swift` actor：按需启动、单飞防重、tools/list 缓存、**down 绝不自动重试**（设置页重启是唯一复活路径）、代际计数使旧死亡回调失效、env 合成 登录shell < envJson < Keychain | m8.0-4 |
| D4 注入 | 工具名 `mcp__<server>__<tool>`（字符白名单清洗、server 段 `__` 压缩、128 上限、撞名先到先得）；`ExternalTool` 走 CardRunner **同一装配口**——白名单过滤、审批门（write 级）、提示词工具区三处同源不开旁路；结果过 `ExternalContent.wrap("MCP·<server>")`，image/resource 替换占位；调用路径不反解析名字（装配时捕获原始坐标） | m8.0-4 |
| D5 凭据 | `secretEnvKeysJson` 只存 key 名，值在 Keychain（account `mcp-<serverId>-<key>`）；Manager 经 `secretProvider` 闭包解析（M6-D7 惯例，Core 不直连 Keychain）；设置页按声明的 key 给 SecureField；删除驿站连带清凭据 | m8.0-4 / m8.5-7 |
| D6 精选清单 | filesystem（添加时弹目录选择）/ github（PAT 走 D5）/ playwright 三件模板一键添加；自定义入口挂 experimental 签 + 信任警示；npx 缺失时给 nodejs.org 指引不代装 | m8.5-7 |
| D7 UI | 设置页「MCP 驿站」区（状态签 未启动/启动中/在营·N 工具/停摆+人话线索、重启/删除、凭据行、2s 轮询）；营地首页驿站启用勾选（N/M 计数）；伙伴编辑器按 server 分组显式勾选（原始名+描述、「连接列出工具」、**已勾但列不出的名字保留可取消**）；受阻详情驿站停摆引导行；feed 新增 mcp_server_down 节拍 | m8.5-7 |
| D8 拆分 | `McpStore` 独立 store（server CRUD/状态/启用/凭据/node 检查），AppStore 只持引用——绞杀第二刀落地 | m8.5-7 |

新增 EventKind：`mcp_server_down`（测试钉裸字符串）。新增 KernelDefaults：mcpInitTimeout=60s、mcpCallTimeout=30s。

## 与计划的偏差（申报）

1. **StreamSession 合并（D8 可砍项）→ 顺延 M9**。计划原文「做不完不强求」；M9 计划 D7 已预留「若 M8 顺延则在此一并完成」。
2. **握手超时 15s→60s（真机实测改）**：npx 冷启动要现场下包，15s 必超时（活体验证：playwright 首启 34s+）。超时文案改为可行动（「稍等再点重启」+「代理变量加进驿站 env」）。
3. **mcp_server_down 事件按失败调用逐次记录，未做去重**——卡片通常失败一次即 block，事件量可控；接受轻微冗余换实现简单。
4. **GUI 环境已知限制**：`zsh -l -c env` 取不到交互式 shell（.zshrc）里的代理变量，GUI 下 npx 下载显著慢于终端。出路已内建：驿站 envJson 可配代理变量；报错文案已指路。
5. **一次未复现的套件抖动**：某次全量跑 288 测试报 1 issue，未捕获到具体测试名，连续 3 次复跑全绿。备案观察（新测试多用 25ms 轮询等待，并行负载下可能偶发），后续里程碑盯梢。

## 验证

- `swift run RunTests`：288/288 绿 ×3（MiniMCP 握手/翻页/占位/isError/rpc 错误/超时/死亡挂起失败+回调/主动关闭不回调/-32601/噪声行；命名清洗组合解析；CRUD+启用隔离幂等+级联；Manager 启动缓存/启动失败 down 不重试/重启复活/进程死亡 down/env 合成优先级/撞名确定性；注入显式白名单语义（存量 "[]" 不继承 mcp、v2 显式注入、板工具永在）；桥接 ExternalContent 包裹 + down 事件）。
- 活体：`AGENTLOOP_MCP_SPIKE=1`（真 filesystem server 读回文件内容）、`AGENTLOOP_MCP_MANAGER_SPIKE=1`（真 playwright server 23 工具）均绿。
- UI 截图循环（fixture 库 + 预览模式，亮暗双色）：设置页驿站区全态（含 old-map 停摆的 stderr 人话线索 `env: definitely-not-a-command: No such file or directory`）、营地首页启用勾选、编辑器分组勾选（github 未连接给按钮/playwright 列 23 工具默认全不勾）、真机重启后「在营 · 23 工具」绿签。

## 遗留

- 用户活体验收：`docs/superpowers/2026-07-08-m8-live-test.md`（GitHub PAT 场景需你自己的 token）→ 通过打 `m8` tag。
- 前置提醒：收官门（M4/M5）与 M6/M7 正式测试仍在队列；tag 顺序 m4→m5→m6→m7→m8。
- 已知限制（申报）：MCP 工具结果文本-only（图片/资源占位，V2 刀法）；server 改名不支持（删除重加）；GUI 代理环境见偏差 4。
