# M4 实现报告（Claude 全量实现，2026-07-05）

计划：`plan.md` v2（含现状核对修订与 D9/D10 增补）。分支 `feat/m4` 基于 tag `m3`。
分工变更：用户明确本里程碑全部代码由 Claude 亲自实现（不外包 Codex）；UI 先出设计稿（`ui-design.md` + `ui-mockup.html`）再落地。

## 提交清单

| 提交 | 内容 |
|---|---|
| 48efe2a | 第 0 步 gateway-resilience：write_file append 分块、非流式兜底、传输重试 [2,5,10,20]s |
| cd03632 | m4.1 知识库数据层：迁移 v3(companion_note)、笔记/记忆 CRUD、LIKE 检索、注入源、水位、向导线程、提案块 CAS |
| （含上） | m4.2 Distiller：收营/记忆/向导沉淀 + 确定性回退 + closeout 异步旁路挂点 |
| （含上） | m4.3 注入：ContextPacket/Planner/DM system 三处 + Orchestrator 接线 + NoteSnippet(D2 截断) |
| （含上) | m4.4 向导层：工具三件、GuideChatService(≤6 轮)、confirmSquadProposal(D10)、MemoryDistillService(D7/D9)、budgetTokens 参数 |
| 4ff94d3 | m4.5 UI：营地首页(笔记本+向导对话+提案卡片三态)、DM 记忆抽屉与沉淀按钮、campToast、宽度自适应 |

## 验证

- 权威跑法 `swift run RunTests`：**197/197 绿**（基线 138 + 新增 59），沙箱跑法 `CLANG_MODULE_CACHE_PATH=… swift run --disable-sandbox RunTests`；真机复跑见 verify.log。
- 金路径升级（plan「测试要求」）：跨行动经验复用（A 收营→B 规划与卡片上下文含 A 笔记）、私聊蒸馏→记忆→下一卡上下文，均离线闭环通过。
- UI 截图循环自验（亮/暗色）：营地首页双栏、提案 pending/confirmed 两态、记忆抽屉、DM 气泡，对照 `ui-design.md` 通过。

## 与 plan 的偏离（申报）

1. **plan 核对修订已入 v2**：companion_note 表缺失→迁移 v3；startMission 无预算参数→新增 budgetTokens；MockProvider 增 recordedSystems。
2. **宽度自适应阈值**：设计稿写「窗口 <860」，实现为 **detail 区宽度 <780**（GeometryReader 量的是 detail 不含侧栏；860 会在默认 1060 窗口下误收笔记本）。DM 抽屉沿用 m3 的 820。
3. **camp_status 上限**：missions 取最近 20 条（plan D6 未定上限，防营地状态 JSON 无界膨胀）。
4. **向导对话模型**：使用设置 defaultModel（而非 guide.model）——与蒸馏模型一致，向导实体 model 字段暂不消费（同 companion.tools_json 的既有处理，spec 未定此项）。
5. **预览模式硬化**（实现中发现）：`provider()`/`autoDistillOnLeave` 在 AGENTloop_UI_PREVIEW=1 时不读钥匙串（避免系统授权弹窗）；新增 `AGENTLOOP_STATE_DIR` 开发用状态目录覆盖（预览不污染真实库）。
6. **向导可编辑入口**：营地首页向导头像右键「编辑向导…」（spec §10.2「可改名与自定义人设」的最小落地）。

## 实现期发现的环境事实（记录备查）

- 本机（macOS 26.3）从 CLI 直接运行 `.build/debug/AgentLoopApp` 裸二进制时**所有文字不渲染**（窗口只有色块；辅助功能树完整）。打成 `.app` bundle + ad-hoc codesign 后正常。UI 预览/截图脚本因此改用 bundle 方式（`/private/tmp/agentloop-m4-preview/AgentLoopPreview.app` 模式）。用户日常 `swift run AgentLoopApp` 若复现此问题，同法处理。

## 评审

五路对抗评审（并发/数据层/契约申报/LLM 卫生/UI）另附 `reviews/`；确认项修复后复跑全量。
