# M4 知识与对话层 — 实现计划 v2（Level 3，用户已授权直接执行）

> **v2 修订（2026-07-05，执行会话）**：① 用户明确本里程碑**全部代码由 Claude 亲自实现**（Core/数据/服务/UI 均不外包 Codex），实现顺序与测试要求沿用；② gateway-resilience（`../2026-07-05-gateway-resilience/plan.md`，因 Codex 在无源码的 main 工作树运行而 blocked）并入本任务为第 0 步；③ 现状核对清单已跑完，修正见「核对结果」；④ 补 D9（向导对话手动沉淀为营地笔记，spec §10.2 原文要求，v1 遗漏）。分支 `feat/m4` 基于 tag `m3`（gateway 未合入，基线 138 测试绿已验证）。UI 先出设计稿再落地（用户要求）。

来源：spec §16-M4（`docs/superpowers/specs/2026-07-04-agentloop-macos-mvp-design.md` §8/§9/§10/§6.2-5,6/§15-6）。
验收（spec 原文）：**私聊沉淀的记忆出现在该伙伴下一次工作上下文；向导对话一键组队开工；跨行动经验复用可演示**。

## 现状基础（截至 feat/m3 @ tag m3，勿重建）+ 核对结果

- ~~表全部已建~~ **核对纠正：`companion_note` 表不存在**（v1 迁移只建了 `camp_note`）——需新增迁移 `v3` 建 `companion_note`（含 companionId 索引）。`camp_note`/`chat_thread`（kind dm/guide）/`chat_message`（含 `distilled`）确认已建。
- `chat_message.contentJson` 现状 = `{"text":"..."}`（`ChatMessageRecord.text` 解码 `[String:String]` 失败时整串回退）——D5 提案块与之共存，需新增类型化访问器 `ChatMessageRecord.proposal`（解析 `type=="squad_proposal"`），guide 历史发给 LLM 时提案块渲染为占位文本，UI 侧检测渲染卡片。
- 向导实体自 M1 存在（`Companion(kind: .guide, campId:)`，默认营地自动配备，不在 `regularCompanions()` 名册）；`guide.toolsJson=="[]"` 确认无消费方（CardRunner 用固定 `ToolDef.agentTools`，ChatService 无工具）。
- `ChatService`：DM 单线程流式、无工具、maxTokens 4096；流模式 = AsyncThrowingStream + 内部 Task + onTermination cancel，完整回复且未取消才落库。GuideChatService 对齐此模式。
- `ContextPacket`：已有 upstreamHandoffs（M2）与 answeredRequests（M3）注入段；§6.2 的第 5/6 项（营地笔记/伙伴记忆）是本期新增。
- `Orchestrator.closeout`：delivering→accepted + 事件，无蒸馏。**核对补充：`startMission(goal:companionIds:workspacePath:plannerModel:)` 无预算参数，`createMissionShell` 固定 `KernelDefaults.missionBudget`**——两者加可选 `budgetTokens: Int = KernelDefaults.missionBudget` 以承接 propose_squad.budget。
- 工具 `ToolDef.agentTools` = **8 件**（gateway 未合入；本任务第 0 步实现 append 后签名不变、件数不变，M4-4 加 search_camp_notes 后 = 9 件）。
- provider 工厂 `makeProvider(model)`（Orchestrator 构造参数，@Sendable 闭包）；AppStore 有 `defaultModel`（设置页暂未暴露选择器，不影响 D1）。**D1 落地方式：`closeout(missionId:distillModel:)` 由 AppStore 调用时传 `defaultModel`，Orchestrator 用既有 makeProvider 工厂构造 Distiller**；蒸馏任务注册进独立 `distillTasks` 注册表，`waitUntilIdle`/`shutdown` 均纳入。
- `MockProvider` 只记录 histories/toolChoices——**加 `recordedSystems`**（DM 记忆注入与向导 system 的测试需要）。
- UI：营地无首页（RootView `Destination` 无 camp 入口）；DM 窗口无沉淀按钮无记忆列表；`NavigationSplitView` 两栏（侧栏+detail），营地首页作为新 detail 场景。

## 第 0 步：gateway-resilience（并入，原计划全文见 `../2026-07-05-gateway-resilience/plan.md`）

1. `write_file` 增可选 `append: boolean`（缺省 false 覆盖，文件不存在时 append=新建）；`FileTools.write` 与 `FileToolHandler` 透传；`ContextPacket` 工作契约末尾追加分块写文件条款（「约超过 3000 字分多次 write_file，首次不带 append，之后 append: true 续写，每段 ≤3000 字」，确定性文案无时间戳）。
2. `AnthropicProvider`：`consumeStream` 抛 `malformedStream` 且有剩余尝试时，下一次尝试改用 stream=false 普通 JSON 请求（body 仅 stream 字段不同）；新增 `consumeNonStreaming`：完整 message JSON → content blocks（复用 `ContentBlock.init(from:)`）→ 先合并 yield 全部 text 为一次 `.textDelta` 再 yield `.turn`；解析失败按 `.malformedStream` 抛。非流式仅作断流兜底，首选永远流式。`requestBody` 增 `stream: Bool = true` 参数。
3. `KernelDefaults.transportRetryDelays: [Duration] = [2s,5s,10s,20s]`；`Orchestrator` 构造 `CardRunner` 时传入（Planner 维持 [2s,4s]）。
4. 测试 5 组照原计划（appendModeAppends / write_file schema 断言 / contractMentionsChunkedWrites / fallsBackToNonStreamingAfterMalformedStream / nonStreamingParsesToolUse）。

## 目标

1. **营地笔记**：收营自动蒸馏（LLM 一次调用，失败确定性回退）；新行动规划与卡片执行自动携带（置顶全部 + 最近 3 摘要）；`search_camp_notes` 工具供伙伴与向导按需检索；营地首页可浏览/编辑/置顶/删除。
2. **伙伴记忆**：私聊沉淀（手动按钮 + 切走线程时对未蒸馏增量自动蒸馏，`distilled` 水位）；该伙伴执行卡片与私聊时注入（置顶全部 + 最近 3 摘要，严格按伙伴隔离）；DM 侧栏可浏览/编辑/置顶/删除。
3. **向导**：营地首页常驻对话（带工具的聊天循环）：`search_camp_notes` + `camp_status()`（只读全景）+ `propose_squad(...)`（提案制组队——类型化提案块入库、确认卡片渲染、**用户确认才建队开工**、按提案 id 幂等）。

## 非目标

- 向量检索（关键词 LIKE + 最近优先 + 置顶，spec 明确）；私聊闲置定时自动蒸馏（仅手动 + 切走触发，闲置阈值列 spec 开放问题，推迟并申报）；多对话线程；DM 带工具（spec：MVP 私聊无工具）；伙伴工具白名单勾选 UI（`companion.tools_json` 继续不消费，普通伙伴统一 agentTools+search_camp_notes，申报偏差）；营地多于一个（沿用默认营地）；M5 项（恢复/预算/打包）。

## 关键决策（D1–D8，待用户过目）

| # | 决策 | 理由 |
|---|---|---|
| D1 | 蒸馏（收营/记忆）用 `makeProvider(设置 defaultModel)` 的**单轮无工具调用**，输出以「强制 JSON 提示 + 宽松解析」获取（不加 tool_choice 协议面）；收营蒸馏失败回退 = 交接包 outcome+summary 逐卡拼接为笔记正文；记忆蒸馏失败静默留水位下次再试（均 spec 原文） | 蒸馏是旁路增强，绝不阻塞主流程 |
| D2 | 注入预算确定性截断：置顶笔记/记忆全文单条 ≤800 字（超出截断加省略号）；「最近 3」每条摘要 ≤150 字；渲染顺序 置顶(createdAt ASC)→最近(DESC)，无时间戳 | prompt 缓存纪律与上下文成本可控 |
| D3 | `search_camp_notes(query)`：title/body LIKE 匹配，置顶优先 + createdAt DESC，top 5，返回「标题 + 前 200 字」；空结果返回明确文案 | spec 关键词+最近优先 |
| D4 | 向导聊天循环 = 新 `GuideChatService`：多轮工具循环（上限 6 轮工具往返，超限强制文本收尾），流式渲染，无终结契约（聊天非卡片）；向导工具固定三件，普通伙伴卡片执行新增 search_camp_notes（共 9 件） | 复用 AgentLoop 会背上终结/预算契约，聊天场景不适配 |
| D5 | `propose_squad` 提案块 = `chat_message.content_json` 类型化结构 `{type:"squad_proposal", proposalId, name, memberIds, goal, budget, status: pending/confirmed/dismissed, missionId?}`；确认动作事务内校验 status==pending → `orchestrator.startMission` → 更新块 status/missionId（chat_message 允许 UPDATE，仅 event 表 append-only）；重复确认幂等拒绝 | spec §10.2 逐条（重启可确认、id 幂等、永不静默建队） |
| D6 | `camp_status()` 返回确定性 JSON 文本：各 mission（title/status/卡片完成比）+ 最近 5 个交付物（label+卡题）；只读查询组装，不走 LLM | spec 只读全景 |
| D7 | 记忆自动蒸馏触发点 = AppStore 离开 DM 线程（切换 Destination）时检查未蒸馏增量 ≥4 条则后台蒸馏；手动按钮无条件蒸馏当前全部未蒸馏增量 | 「切走」是 spec 点名的触发；4 条阈值防琐碎单句成本 |
| D8 | UI 信息架构：侧栏新增「营地」区（营地首页入口置于「新行动」下方）；营地首页 = 左笔记本（列表+编辑+置顶+删除）右向导对话（复用 Feed 气泡风格 + 提案确认卡片）；DM 窗口右侧加记忆抽屉（浏览/编辑/置顶/删除，与笔记同交互组件 `NoteListPane` 复用） | spec §11 营地首页一等界面；组件复用降本 |
| D9 | **向导对话手动沉淀**（v2 新增）：营地首页向导对话工具栏「沉淀笔记」按钮 → `Distiller.distillGuideChat`（与 distillMemory 同构：未蒸馏增量 → `(title, bodyMd)?`，skip 约定相同）→ `saveCampNote(missionId: nil)` + `markDistilled` + 事件 `camp_note_created {source:"guide_chat"}`；失败静默留水位。向导线程**无切走自动蒸馏**（spec 只点名手动） | spec §10.2「营地对话可手动沉淀为营地笔记」，v1 遗漏 |
| D10 | **提案确认并发语义**（v2 细化）：确认 = 事务内 CAS（读块 → 校验 status==pending → 置 confirmed）→ 事务外 `startMission(..., budgetTokens:)` → 二次 update 写 missionId；startMission 失败则补偿回滚 status→pending 并浮出错误。二次确认在 CAS 处抛 `StaleProposalError` → UI 提示「提案已处理」。先 CAS 后建队，宁可回滚不重复建队 | D5 幂等的无竞态落地 |

## 契约（逐字段）

### 迁移 v3（v2 新增——核对发现 companion_note 缺失）

```swift
m.registerMigration("v3") { db in
    try db.create(table: "companion_note") { t in
        t.primaryKey("id", .text)
        t.column("companionId", .text).notNull().references("companion").indexed()
        t.column("sourceThreadId", .text).references("chat_thread")
        t.column("title", .text).notNull()
        t.column("bodyMd", .text).notNull()
        t.column("pinned", .boolean).notNull().defaults(to: false)
        t.column("createdAt", .datetime).notNull()
        t.column("updatedAt", .datetime).notNull()
    }
}
```

### 记录类型（`Records.swift` 新增；camp_note 表已存在）

```swift
CampNoteRecord { id, campId, missionId?, title, bodyMd, pinned: Bool, createdAt, updatedAt }
CompanionNoteRecord { id, companionId, sourceThreadId?, title, bodyMd, pinned: Bool, createdAt, updatedAt }
// ChatMessageRecord 新增类型化访问器（v2）：
// var proposal: SquadProposalBlock?  — contentJson.type=="squad_proposal" 时解析
// SquadProposalBlock: Codable { proposalId, name, memberIds: [String], goal, budget: Int?, status: pending/confirmed/dismissed, missionId: String? }
```

### AppDatabase 新 API

```swift
// 笔记/记忆 CRUD（update 仅 title/bodyMd/pinned/updatedAt；delete 硬删）
campNotes(campId:) / saveCampNote / deleteCampNote
companionNotes(companionId:) / saveCompanionNote / deleteCompanionNote
searchCampNotes(campId:query:limit:5)          // D3 语义
pinnedAndRecentCampNotes(campId:recent:3)      // D2 注入源
pinnedAndRecentCompanionNotes(companionId:recent:3)
undistilledMessages(threadId:) -> [ChatMessageRecord]   // distilled == false
markDistilled(messageIds:)                      // 事务置位
findOrCreateGuideThread(campId:)                // 对齐既有 findOrCreateDMThread
updateChatMessageContent(id:contentJson:)       // D5 提案块状态更新
```

### 蒸馏服务（新 `Sources/AgentLoopCore/Knowledge/Distiller.swift`）

```swift
struct Distiller {
    // 收营：输入 mission(goal/refined) + 各 done 卡 (title, handoff outcome/summary/risks)
    // 输出 CampNote(title ≤30 字, bodyMd 含四节：做了什么/什么做法有效/关键产物在哪/踩了什么坑)
    func distillCloseout(...) async -> (title: String, bodyMd: String)   // 失败→回退拼接，不抛错
    // 记忆：输入伙伴名/职责 + 未蒸馏消息增量
    // 输出 nil（增量无值得记的内容，模型可判）或 (title, bodyMd)
    func distillMemory(...) async throws -> (title: String, bodyMd: String)?
}
```

Prompt 模板写死在该文件（中文、固定文案、要求仅输出 JSON `{"title":…,"body":…}`；解析容错：剥 markdown 代码围栏后 JSONDecoder，失败再取首行为题其余为体）。`distillMemory` 模型判「无内容」的约定：输出 `{"skip":true}`。

### 工具（`ToolDef.swift`）

```text
search_camp_notes: { query: string 必填 }                          // agentTools 与向导共有
camp_status: {}                                                    // 向导专属
propose_squad: { name: string, memberIds: string[] 1..6, goal: string, budget?: integer }  // 向导专属
```

`agentTools` → 9 件（+search_camp_notes）；新 `guideTools = [search_camp_notes, camp_status, propose_squad]`。propose_squad 校验：memberIds 均存在且 kind==regular、去重、goal 非空；违规 → `.error` 自愈。

### 注入（`ContextPacket` + `Planner`）

- ContextPacket 新参数 `campNotes: [NoteSnippet]`、`companionNotes: [NoteSnippet]`（`NoteSnippet {title, body}`，按 D2 已截断），渲染为「# 营地笔记（往期经验）」与「# 你的记忆」两段，位置在上游交接之前；空则整段省略。
- Planner 用户消息追加「# 营地笔记」段（同源 D2）。
- DM 聊天 system 追加记忆段（置顶全部 + 最近 3，D2 截断）。
- Orchestrator 派发与 startMission 时从 db 读取并传入（campId 经 squad→camp 查询）。

### 收营蒸馏挂点（`Orchestrator.closeout`）

closeout 事务成功后**异步旁路** spawn 蒸馏任务（注册进 planningTasks 同款注册表以便 shutdown/waitUntilIdle 追踪）：Distiller.distillCloseout → `saveCampNote(missionId 关联)` → 事件 `camp_note_created {noteId, source: "closeout" | "fallback"}` → emit missionChanged。蒸馏任务失败也走回退——**任何路径都产出一张笔记**。

### 向导聊天（新 `Sources/AgentLoopCore/Chat/GuideChatService.swift`）

- 输入：campId、向导 companion、用户消息；历史 = guide 线程全量（含提案块渲染为文本占位）。
- 循环：streamTurn(工具=guideTools)→ tool_use 则执行并续轮（≤6 轮）→ endTurn 输出文本收尾；`propose_squad` 执行 = 建 pending 提案块消息（D5）并将「提案已生成，等待用户确认」作为 tool_result 返给模型。
- 事件流对 UI：textDelta / toolActivity(name) / proposalCreated(messageId) / finished。
- 确认动作在 AppStore：`confirmSquadProposal(messageId)` → 校验 pending → startMission(memberIds, goal, budget ?? KernelDefaults.missionBudget, workspacePath: nil) → 更新块 → 跳转该 mission；驳回 = status dismissed。

### 事件新增 kind

`camp_note_created`、`companion_note_created {noteId, companionId}`、`squad_proposal_confirmed {proposalId, missionId}`（营地对话动作也留审计）。

## UI（Claude 亲自实现，营地感体系沿用 `Theme.swift`）

1. 侧栏「营地」入口 + `Destination.camp`；营地首页两栏：`NoteListPane`（新组件：搜索框 + 置顶分组列表 + 行内编辑 sheet + 置顶/删除上下文菜单）+ 向导对话列（Feed 气泡风格、提案确认卡片：成员头像组/目标/预算 + 「就这么办」主按钮 + 「先不」次按钮；confirmed 后卡片变为已开工态并可跳转行动）。
2. DM 窗口：工具栏「沉淀记忆」按钮（蒸馏中转菊花，完成后 toast 式提示）+ 右侧记忆抽屉（`NoteListPane` 复用，330pt，可开关，遵循 m3.3 的宽度自适应规则）。
3. 详情/文案全部人话化；reduceMotion 与失焦暂停沿用既有约定。
4. 完成后 Claude 截图循环自验（AGENTLOOP_UI_PREVIEW=1 预览模式），并对照 spec §11 营地首页描述。

## 测试要求（v2：Claude 实现，预计 +30±，含第 0 步 5 组与 D9/D10 补充；文件名照列）

- （v2 增）`GuideChatTests`：提案确认 CAS——confirmed 后二次确认抛 StaleProposalError；startMission 失败补偿回滚 pending。
- （v2 增）`DistillerTests`：distillGuideChat skip 约定与 camp_note 落库(source: guide_chat)。

- `DistillerTests`：JSON 正常解析 / 带围栏解析 / 畸形回退（closeout 拼接回退产出非空笔记；memory 返回 nil on skip）/ prompt 无时间戳。
- `KnowledgeStoreTests`（DatabaseTests 扩展亦可）：笔记/记忆 CRUD、置顶排序、search LIKE 语义、undistilled 水位与 markDistilled、updateChatMessageContent。
- `ContextPacketTests` 增：注入两段渲染确定性、D2 截断（801 字→800+省略号）、空省略。
- `PlannerTests` 增：用户消息含营地笔记段。
- `GuideChatTests`：工具循环（MockProvider 脚本：camp_status → 文本收尾）；propose_squad 建 pending 块；6 轮上限强制收尾；提案确认幂等（二次确认拒绝）；memberIds 校验自愈。
- `OrchestratorTests` 增：closeout 后（Mock 蒸馏失败路径）仍产出回退笔记 + 事件；waitUntilIdle 等待蒸馏任务。
- 金路径升级：行动 A 收营 → 笔记生成 → 行动 B 的规划消息与卡片上下文均含 A 笔记摘要（跨行动复用离线版，验收 ③）；私聊蒸馏 → 记忆 → 该伙伴下一卡上下文含记忆（验收 ①，spec §15-6 闭环）。
- 既有 138+（含 gateway-resilience 新增）零回归。

## 用户正式测试脚本（交付时产出 `docs/superpowers/2026-07-06-m4-live-test.md`）

1. 跑一个小行动到收营 → 营地首页出现蒸馏笔记，可编辑/置顶。
2. 新行动（相关主题）→ 观察规划质量/卡片产出引用了笔记经验（或详情面板上下文可证）。
3. 与某伙伴私聊几轮有信息量的对话 → 点「沉淀记忆」→ 记忆抽屉出现条目 → 给该伙伴派卡 → 其产出/详情可见记忆生效。
4. 切走线程自动蒸馏：私聊 ≥4 条后切去设置再回来 → 增量已沉淀。
5. 向导对话：问营地状态（camp_status）→ 搜笔记 → 让它组队 → 确认卡片 → 「就这么办」→ 直达新行动执行；重复点确认验证幂等。
6. Reduce Motion 下新 UI 全静态替代。

## 完成定义

1. Codex 层测试全绿零回归（真机权威）；plan 外零改动。
2. Claude UI 完成并截图自验；营地首页/记忆抽屉/提案卡片可用。
3. 三条 spec 验收在正式测试脚本中全部可走通。
4. impl-report/verify.log/reviews 齐全；用户正式测试通过后打 `m4` tag。

## 实现顺序（v2：全部 Claude 实现）

0. gateway-resilience 三改动 + 5 组测试（独立可验证，先落地先验证）。
1. 迁移 v3 + 记录类型 + AppDatabase 知识 API + 测试。
2. Distiller + closeout 挂点 + 测试。
3. 注入（ContextPacket/Planner/DM system）+ 测试。
4. 工具三件 + GuideChatService + 提案块 + 确认动作 API + 测试 + 金路径升级。
5. UI：先设计稿（布局/交互/视觉，沿用 Camp 主题）→ 营地首页 + NoteListPane + 提案卡片 + DM 记忆抽屉 + 沉淀按钮（截图循环自验）。
6. live-test 脚本 + 真机全量复跑 + 多路对抗 review + 修复轮。

## 现状核对清单（v2：已跑完，结论并入上文「核对结果」）

- [x] 基线 = tag m3 @ de4baa5，gateway 未合入（其任务 blocked，原因为 Codex 跑错工作树）；分支 feat/m4 已建，基线 138 测试绿。
- [x] `chat_message.content_json` = `{"text":...}`；提案块共存方案见「核对结果」第 2 条。
- [x] `ChatService` 流式/取消模式已核对，GuideChatService 对齐。
- [x] `agentTools` = 8 件。
- [x] guide `toolsJson=="[]"` 不被消费。
- [x] 新发现出入已修订：companion_note 表缺失（迁移 v3）、startMission 无预算参数、MockProvider 无 system 记录。

## Open questions

（无。用户已授权直接执行；D9/D10 为执行会话按 spec 与代码现状增补。）
