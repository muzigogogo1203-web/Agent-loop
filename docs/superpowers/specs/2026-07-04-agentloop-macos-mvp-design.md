# AgentLoop for macOS — MVP 设计

- 日期：2026-07-04
- 状态：已经用户两轮确认（架构方案 + 人性化修订），待 spec 评审
- 前身：Awesome Hermes（/Users/muzi/Projects/awesome-hermes，Electron + TS + Python）——本产品是其验证过的「群聊是房间、看板是事实源」路线的单运行时原生重写
- 工作名：AgentLoop（正式产品名待定）

## 1. 产品定位

一款 macOS 原生（Swift + SwiftUI）多 Agent 协作桌面工具：

用户自定义一群「伙伴」（Agent）→ 在「小队」里对一个「行动」（目标）下达指令 → 内置编排内核把目标拆成小目标 → 各伙伴独立运行 Agent Loop 认领执行 → 通过结构化交接包传递工作 → 交付物一等公民呈现给用户验收 → 收营时把经验沉淀为「营地笔记」，供整个营地后续行动复用。

三个用户确认的关键决策：

1. **LLM 接入**：API 直连（Anthropic + OpenAI 兼容），不依赖本地 CLI。
2. **伙伴能力**：基础工具集（工作目录内文件读写、网络抓取、行动板操作），无 shell。
3. **定位**：通用协作工具（写作、调研、规划、开发皆可），不预设开发场景。
4. **协调机制**：方案 A「看板即黑板」——确定性状态机路由，伙伴之间不自由聊天。

## 2. 命名体系（远征风）

界面文案全部使用中文命名；代码使用对应英文类型名。

| 概念 | 界面名 | 代码名 | 说明 |
|---|---|---|---|
| 频道 | 营地 | `Camp` | 最大集合，包含多个小队；经验沉淀发生在这一层 |
| 房间 | 小队 | `Squad` | 一群伙伴组成的群组，绑定可选工作目录 |
| 主题 | 行动 | `Mission` | 一次目标执行；同一小队同时只有一个活跃行动 |
| 子任务 | 小目标 | `Card` | 内核的调度单元；界面上不暴露列式看板术语 |
| Agent | 伙伴 | `Companion` | 用户定义：名字、颜色、职责、模型、工具白名单 |
| 营地管理员 | 向导 | `Companion(kind: guide)` | 每个营地创建时自动配备：营地对话、读营地内容、提案组队；不可指派小目标 |
| 经验沉淀 | 营地笔记 | `CampNote` | 收营复盘自动蒸馏 + 用户可编辑/置顶 |
| 个人记忆 | 伙伴记忆 | `CompanionNote` | 私聊沉淀的个人记忆，该伙伴工作与私聊时注入 |
| 单线程对话 | 私聊 / 营地对话 | `ChatThread` | 与伙伴的私聊（全局级）或与向导的营地对话（营地级） |
| 完结验收 | 收营 | closeout | 行动交付验收 + 笔记蒸馏 |
| 执行记录 | — | `Run` | 一张小目标的一次执行尝试 |
| 事件 | 动态 | `Event` | 追加式日志；一切 UI 是它的投影 |
| 产物 | 交付物 | `Artifact` | 耐久存储的文件产出 |

## 3. 目标与非目标

### MVP 目标

- 用户可创建伙伴（名字/颜色头像/职责 prompt/模型/工具子集）。
- 用户可创建营地 → 小队（邀请伙伴、绑定工作目录）→ 行动（下达目标）。
- 内核自动规划小目标并调度伙伴并发执行；全过程实时可见。
- 伙伴间通过结构化交接包传递工作，下游冷启动即可开工。
- 交付物落在用户可及的位置，验收界面一键 Finder reveal。
- 收营自动沉淀营地笔记；新行动的规划自动携带相关笔记。
- 用户可与任一伙伴单线程私聊；聊天内容沉淀为伙伴记忆，该伙伴此后工作时自动携带。
- 用户可在营地里直接与向导对话（无需创建小队）：查营地笔记与行动状态、由向导提案组建小队并开工（提案制，用户确认后才创建）。
- 活人感贯穿全程：每个状态变化有动效承接，等待有角色小动画陪伴，永不冷场。
- 崩溃/重启后行动可恢复继续。

### 非目标（明确不做，v2+）

- 伙伴之间的自由讨论轮（分阶段混合协调，即原方案 C）。
- shell 工具、MCP 工具接入。
- 自定义看板列 / 工作流模板。
- 同一小队多行动并行。
- 本地 CLI Agent（claude/codex）适配。
- 营地笔记/伙伴记忆的向量检索（MVP 均为最近优先 + 手动置顶 + 关键词）。
- 同一伙伴或向导的多对话线程（MVP 各一个持续线程）。
- iCloud 同步、多设备。

## 4. 领域模型与持久化

### 4.1 实体

```text
Camp（营地）── 向导: Companion(kind: guide) 自动配备
  ├─ CampNote（营地笔记）
  ├─ ChatThread(kind: guide)（营地对话，单线程）
  └─ Squad（小队）── 成员: [Companion]（全局名册，邀请制）
      └─ Mission（行动）── 目标原文 + 精炼目标 + 状态 + 预算
          └─ Card（小目标）── 幂等键 mission:<id>:stage-N
              └─ Run（执行尝试）
Companion（伙伴，全局名册）
  ├─ CompanionNote（伙伴记忆）
  └─ ChatThread(kind: dm)（私聊，单线程）
Event（追加式，全局）
Artifact（属于 Card，耐久存储）
UserRequest（ask_user 门，属于 Card）
```

### 4.2 GRDB schema（SQLite WAL，单 DatabasePool）

| 表 | 关键列 |
|---|---|
| `companion` | id, name, color, role_prompt, model, tools_json, kind(regular/guide), camp_id?（guide 专属）, created_at |
| `camp` | id, name, created_at |
| `squad` | id, camp_id, name, member_ids_json, workspace_bookmark BLOB?, created_at |
| `mission` | id, squad_id, goal_raw, goal_refined, status, budget_tokens, spent_tokens, revision, created_at —— revision 为重规划计数，MVP 恒为 1（v2 动态重规划预留，前身 P5 的概念） |
| `card` | id, mission_id, idem_key UNIQUE, title, description, expected_output, assignee_id, status, blocked_reason_json?, depends_on_json, max_turns, token_budget, created_at |
| `run` | id, card_id, attempt, outcome?, turns, tokens_in, tokens_out, started_at, ended_at? |
| `event` | id, mission_id?, card_id?, run_id?, kind, payload_json, created_at —— 追加式，禁止 UPDATE/DELETE |
| `artifact` | id, card_id, path, kind, label, created_at |
| `camp_note` | id, camp_id, mission_id?, title, body_md, pinned, created_at, updated_at |
| `user_request` | id, card_id, kind(choice/confirm/text), prompt, options_json?, answer_json?, created_at, answered_at? |
| `chat_thread` | id, kind(dm/guide), companion_id, camp_id?, created_at |
| `chat_message` | id, thread_id, role(user/companion), content_json, distilled, created_at |
| `companion_note` | id, companion_id, source_thread_id?, title, body_md, pinned, created_at, updated_at |

- `event` 与投影表（card.status 等）在**同一写事务**内更新：既有审计日志，又有快查投影。
- UI 由 `ValueObservation` 直驱；崩溃恢复 = 纯重读。
- 交付物耐久存储：`~/Library/Application Support/AgentLoop/artifacts/<card_id>/`。

## 5. 协调内核（看板即黑板）

### 5.1 小目标状态机

```text
todo ──依赖全部完成──▶ ready ──被伙伴认领──▶ running ──complete_card 校验通过──▶ done
                                              │  ▲
                                     block_card│  │用户解除/重试
                                              ▼  │
                                            blocked ──▶ canceled
```

- 状态转移是一个穷举 `switch` 的纯函数；非法转移编译期不可表达。
- 补充转移（与 §13/§14 对齐）：`running → ready`（崩溃恢复把中断的卡片放回就绪）与 `running → canceled`（预算耗尽提前收营时终态化在途卡片）；`blocked` 解除后回 `ready` 经调度器重新派发，而非直接回 `running`。
- **MVP 无卡级人工验收**：`complete_card` 的交接包校验（§7）同步执行——校验失败作为 tool_result 错误返回、卡片保持 `running` 让伙伴修正；校验通过即 `done`，下游依赖立即解锁。人工验收只发生在行动层（收营）。这保证「零人工到收营」的活体冒烟硬门（§15-5）与下游冷启动（§16-M2）成立。
- `blocked` 必须携带类型化原因（关联值，非可空列）：`needsHumanInput(UserRequest)` / `budgetExhausted` / `toolFailure(String)` / `refusal` / `noTerminator`。
- Mission 状态：`planning → executing → delivering → accepted / failed`，由小目标状态纯函数推导 rollup。`delivering` = 全部小目标终态且至少一个 done，等用户收营。
- **MVP 验收是单向的**：收营即 `accepted`；不满意的部分通过在小队里下达新行动解决，无卡级退回重做路径（v2 议题）。`failed` 仅两个触发：用户主动放弃行动，或预算耗尽后用户选择终止而非加注。

### 5.2 不可违背的不变量（继承自前身的实战教训）

1. **单规划者**：一个行动一个执行图一个规划者。规划是对 `card.idem_key` 的 upsert；发现已有执行图的规划调用必须 no-op 并记审计事件。
2. **产物先耐久、完成后落库**：`complete_card` 先把声明的产物拷贝（copy 而非 move，含路径包含检查）到耐久存储并改写路径，然后才持久化完成事件。前身曾因临时目录 GC 吃掉交付物烧光下游预算。
3. **一卡一主**：每张小目标同一时刻只有一个伙伴执行；每个伙伴同时只执行一张。
4. **工具是唯一终结方式**：Run 只能以 `complete_card` 或 `block_card` 结束；聊天里说「做完了」不算数。
5. **终止条件由内核检查**，不依赖伙伴自觉：`maxTurns 且 token 预算` 硬顶，预算剩 10%（下限 3 轮）注入强制收尾指令。

### 5.3 调度（level-triggered reconcile）

- 触发 = 事件 + 周期 tick（兜底漏事件）；reconcile 幂等。
- 计算就绪集：`todo` 且 `depends_on` 全部 `done` → `ready`。
- 按负责伙伴空闲度启动 Agent Loop（`actor Orchestrator` 的 TaskGroup 子任务）。
- LLM 只出现在三个决策点：规划提案、歧义受阻分类、（v2）评审判定；全部有确定性回退，且**永不信任模型报的 id**（一律以内核生成的 id 为准）。
- 原生化红利：伙伴是进程内 Swift task，前身的 pid 僵死检测/心跳租约/孤儿清剿整套复杂度替换为「任务取消 + 每轮超时（默认 120s/轮）」。

## 6. Agent Loop（每小目标一个隔离循环）

### 6.1 循环

```swift
var history = [contextPacket]                    // 不传全量聊天史
while run.turns < card.maxTurns {
    let resp = try await provider.streamTurn(history, tools)   // SSE 流式
    history.append(resp.assistantContentVerbatim)               // 原样追加，含 thinking 块
    switch resp.stopReason {
    case .toolUse:
        let results = await execute(resp.toolCalls)             // 只读工具可并发
        history.append(.user(toolResults: results))             // 全部结果放同一条消息
    case .endTurn where !didTerminate:
        history.append(.user(reminderCompleteOrBlock))          // 提醒一次
        if remindedBefore { return .blocked(.noTerminator) }
    case .refusal:   return .blocked(.refusal)
    default:         break loop
    }
}
```

- 未知 content block 类型以 `.unknown(rawJSON)` 原样透传回传——thinking/compaction 块不回传会静默丢状态，这是 Codable 建模的硬约束。
- 工具错误不抛出循环：返回 `is_error` tool_result 让模型自愈；同一工具连续 3 次失败 → `blocked(.toolFailure)`。
- `pause_turn`：原样追加 assistant 内容后继续，封顶 5 次。

### 6.2 上下文包（冷启动开工的关键）

规划时和调度时组装，注入 system + 首条 user 消息：

1. 伙伴职责 prompt（用户定义）
2. 小目标：标题 + 描述 + **预期产出**（必填）
3. 上游小目标的交接包摘要 + 产物耐久路径
4. 工作目录根路径 + 可用工具说明
5. 相关营地笔记（见 §9）
6. 伙伴记忆：置顶全部 + 最近 3 张摘要（见 §10.1）
7. 交接包格式要求 + 「必须以 complete_card/block_card 收尾」契约

### 6.3 Provider 协议

```swift
protocol LLMProvider {
    func streamTurn(_ history: [Message], tools: [ToolDef]) -> AsyncThrowingStream<AgentEvent, Error>
}
```

- `AnthropicProvider`：SwiftAnthropic 2.2.x。content blocks / stop_reason / tool_use.input 已解析对象。
- `OpenAICompatProvider`：MacPaw/OpenAI 0.5.x。tool_calls / finish_reason / arguments 为 JSON 字符串（防御性解析，可能畸形）。
- 内部统一为同一套 `ToolCall {id, name, argumentsData}` / `StopReason` 类型。
- **Prompt 缓存是一等设计**（Loop 每轮重发全史，10 倍输入成本杠杆）：冻结系统前缀、确定性工具排序、`cache_control: ephemeral` 标记最后一个稳定块、前缀内禁止时间戳/UUID；以 `usage.cache_read_input_tokens` 验证。
- 上下文接近上限（usage 达窗口 ~75%）：客户端摘要压缩旧轮次，复用完全相同的 system/tools 前缀保缓存。

## 7. 交接机制（SPEC 式交接包）

`complete_card` 的必填参数，版本化 Codable 结构，写入时校验：

```swift
struct HandoffPayload: Codable {   // v1
    let outcome: String            // 结果一句话
    let summary: String            // 人话摘要（双读者：用户和下游伙伴）
    let artifacts: [ArtifactDecl]  // {relativePath, kind, label}；≥1 个，或
    let noArtifactReason: String?  //   显式说明为何无产物（二选一强制）
    let verification: [Verification] // {method, passed, note} 怎么验证的
    let next: String?              // 建议下一步
    let risks: [String]            // 风险与未尽事项
}
```

- 校验失败 → 拒绝完成，把校验错误作为 tool_result 返给伙伴修正。
- 产物在小目标详情和交付面板中是可点击一等行（Finder reveal），不埋在文字里。
- 下游伙伴的上下文包引用的是**耐久路径**（§5.2 不变量 2 保证其存在）。

## 8. 工具集（MVP）

| 类别 | 工具 | 边界 |
|---|---|---|
| 行动板 | `complete_card(handoff)` | 唯一正常完成方式；触发产物耐久化 |
| | `block_card(reason, detail)` | 类型化受阻 |
| | `add_progress_note(text)` | 一句话进展 → 小目标行的实时snippet + 动态流 |
| | `ask_user(kind, prompt, options?)` | 类型化提问（choice/confirm/text）；卡片挂起等答复，UI 显式 CTA |
| 文件 | `list_dir` `read_file` `write_file` | 严格限定小队工作目录内：安全作用域书签 + 规范化路径包含检查；无工作目录的小队写入交付暂存区 `~/Library/Application Support/AgentLoop/staging/<card_id>/`（`complete_card` 时按 §5.2-2 拷入耐久存储，收营后暂存区可清理） |
| 网络 | `web_fetch(url)` | URL → 正文 markdown；只读 |
| 笔记 | `search_camp_notes(query)` | 关键词 + 最近优先，返回笔记摘要 |
| 向导专属 | `camp_status()` | 只读营地全景：小队/行动/小目标状态/最近交付物 |
| | `propose_squad(name, member_ids, goal, budget?)` | 提案制组队：产出确认卡片，用户确认后内核才创建小队与行动（§10.2）；budget 缺省取设置默认值（§13） |

- 每个伙伴可勾选工具子集（`companion.tools_json` 白名单）。
- 向导的工具集固定（`search_camp_notes` + 向导专属两项），不参与勾选；普通伙伴不可用向导专属工具；私聊不带工具（MVP）。
- `web_search` 视 MVP 进度可选（需外部搜索 API key），不在承诺范围。
- 只读工具（read_file/list_dir/web_fetch/search_camp_notes）标记 parallel-safe，可并发执行。

## 9. 经验沉淀（营地笔记）

1. **收营复盘**：行动验收通过时，内核用一次 LLM 调用把行动全程（目标、各交接包、验证结果、受阻记录）蒸馏成一张营地笔记（做了什么/什么做法有效/关键产物在哪/踩了什么坑），存入 `camp_note`。蒸馏失败不阻塞收营（确定性回退：用交接包摘要拼接）。
2. **开工带经验**：同营地内新行动规划时，上下文包自动附带：置顶笔记全部 + 最近 N 张（默认 3）笔记摘要。
3. **主动翻阅**：伙伴通过 `search_camp_notes` 工具按需检索。
4. **可浏览可编辑**：笔记本是营地首页的一等界面；用户可编辑、置顶、删除。

## 10. 对话与记忆（伙伴私聊 + 营地向导）

### 10.1 伙伴私聊与伙伴记忆

- 名册中每个伙伴支持单线程私聊（每伙伴一个持续线程）。私聊是纯对话循环：伙伴职责 prompt + 伙伴记忆（置顶 + 最近）+ 对话历史；MVP 私聊不带工具。
- **沉淀**：两个触发——用户点「沉淀记忆」（对当前会话立即蒸馏）；或会话闲置/切走后对未沉淀增量自动蒸馏（`chat_message.distilled` 标记水位）。蒸馏产物是伙伴记忆（标题 + 正文 + 来源线程）；蒸馏失败静默、下次触发重试，不阻塞任何流程。
- **注入**：该伙伴执行小目标或私聊时，上下文携带其置顶记忆全部 + 最近 3 张摘要（§6.2）。记忆严格按伙伴隔离，只注入本伙伴的运行。
- 记忆可浏览/编辑/置顶/删除（与营地笔记同一套交互）。
- 长线程上下文管理与 Agent Loop 相同（§6.3 客户端摘要压缩）。

### 10.2 营地向导（内置管理员）

- 每个营地创建时自动配备一位**向导**（`Companion(kind: guide, campId:)`）：默认名「向导」，用户可改名与自定义人设 prompt；不出现在全局名册，不可被指派小目标。
- **营地对话**：营地首页的常驻单线程对话，无需创建小队即可使用。能力 = 读 + 提案：
  - 读知识：`search_camp_notes` 检索营地笔记；
  - 读状态：`camp_status()` 只读营地全景（小队、行动、小目标状态、最近交付物）；
  - **提案组队**：`propose_squad(name, member_ids, goal, budget?)` 产出结构化组队提案（小队名 + 从全局名册选的成员 + 行动目标 + 预算建议），在对话中渲染为确认卡片；**用户确认后内核才创建小队与行动**，向导永不静默建队（前身 P8 教训：领航员提案制）。未确认的提案是 `chat_message.content_json` 里的类型化结构块（非自由文本），重启后仍可确认；确认动作以提案 id 幂等，杜绝重复建队。
- 向导对话的上下文构成：人设 prompt + 对话历史 + 工具定义——知识与状态**按需拉取**（工具调用），不自动注入营地笔记。
- 营地对话可手动「沉淀」为营地笔记（入 `camp_note`，与收营蒸馏同表同交互）。

## 11. UI 设计（SwiftUI，macOS 14+）

三栏 `NavigationSplitView`，shoebox 应用：

- **侧栏**：营地（含营地笔记与向导对话入口）→ 小队 → 行动 的层级导航；伙伴名册（点击伙伴打开私聊）；设置。首次启动自动创建默认营地，不强迫理解层级。
- **中央（行动视图，人性化）**：
  - 顶部：行动目标（精炼一句话）+ 在场伙伴头像 + 状态摘要（「进行中 · 3/5 个小目标完成」）+ 预算指示。
  - 主体：小目标清单——每行显示：状态图标（✓/转圈/举手/虚线待启动）、标题、负责伙伴、实时一句话（来自 `add_progress_note`）。**不暴露列式看板与状态机术语**。
  - 等待用户决策的小目标浮到显眼位置：琥珀高亮 + 内联选项按钮/「去回答」。
  - 底部：交付物条（已交付文件 + Finder reveal）。
- **小目标详情面板**（点击滑出）：完整状态、执行时间线（工具调用人话化）、交接包、Run 历史、产物列表。列式状态视图作为详情面板内的开发者视角保留。
- **右栏（小队动态）**：类型化事件渲染成伙伴发言气泡（认领/进展/提问/受阻/完成）+ 用户输入框（下达新行动、回答提问、验收）。
- **伙伴私聊窗口**：流式对话 + 「沉淀记忆」按钮 + 该伙伴的记忆列表（浏览/编辑/置顶/删除）。
- **营地首页**：营地笔记本 + 向导常驻对话；组队提案渲染为结构化确认卡片（成员/目标/预算 + 确认按钮）。
- **伙伴编辑器**：名字、颜色头像、职责 prompt、模型选择、工具勾选。
- **设置**：API 端点（默认官方，可自定义为任何 Anthropic Messages API 兼容网关/本地代理，UserDefaults 持久化）、API key（Keychain）、默认模型（含自定义模型 id）、默认预算。
- 流式性能：token 增量 30–50ms 合批后再更新 `@Observable` store，多伙伴同时流式不掉帧。

### 11.1 设计语言：活人感

- 基调「营地感」：温暖色调、圆润几何、插画感角色；暗色模式做成篝火夜景氛围（暖光点缀）而非纯灰黑。方向性约束，具体视觉稿实现期产出。
- 伙伴与向导是「角色」不是列表项：头像有呼吸感 idle 微动画，状态变化时有表情/姿态切换。
- 微文案原则：系统术语人话化，状态文案带角色口吻（向导：「我把小队拉好了，出发？」；已有例：「等你拿主意」「收营」）。

### 11.2 动效体系

- **每个状态变化有承接**：页面/面板切换用 `matchedGeometryEffect` 连续转场；列表项有插入/移除动画；小目标状态翻转（就绪→进行中→完成）有卡片翻面/勾选动画。
- **无死等**：任何等待状态都有活动指示——LLM 流式间隙的打字气泡、规划中的向导摊地图动画、工具执行中的微动效。
- **角色状态动画由真实状态驱动**：动画状态机消费合并事件流——卡片状态（§14 显式枚举）+ 轮内 AgentEvent（流式中/工具执行中，§6.3）+ 伙伴指派情况（无在执行卡 = 空闲）——而非仅读卡片状态。动画态集：idle 呼吸/眨眼、思考（冒泡，流式中）、干活（敲打，工具执行中）、提问（举手）、受阻（挠头）、完成（小欢呼）、空闲（打盹）。动画演的是真实状态，不是装饰性假动画。
- **实现**：SwiftUI 原生（`PhaseAnimator` / `KeyframeAnimator` / `TimelineView`，macOS 14 齐备）；角色 MVP 用代码绘制的参数化简笔形象（换色即换伙伴，零外部资产依赖），预留 Rive/Lottie 资产升级路径。
- **克制与可达性**：尊重系统「减弱动态效果」（`accessibilityReduceMotion` → 静态替代，随每个动效里程碑同步落地，M1/M3 即有基础版，非全部推迟到 M5）；动效永不阻塞交互；ambient 动画用 `TimelineView` 低帧率（≤10fps）且窗口失焦时暂停，不与流式渲染争主线程（与上文合批策略协同）。

### 11.3 等待小剧场

- 长等待（规划中、多伙伴执行中）时，行动页展示「篝火小剧场」：篝火旁的伙伴们各自演当前真实状态——干活的敲打、等依赖的打盹、提问的举手、向导摊地图规划。数据来自同一事件流，**是真实状态的可视化**，好看且可读（一眼看出谁在忙谁被卡）。
- 呈现方式：行动视图顶部提供「清单 ⇄ 小剧场」切换（同数据两种渲染）；有伙伴在执行且用户 30s 无交互时轻提示可切换，不自动打断。
- 向导的角色实体与形象自营地创建即存在（M1 默认营地即有向导可渲染），M4 才启用的只是其对话与工具能力——小剧场里向导的规划动画不依赖 M4。
- 三个必须覆盖的等待场景：① 流式生成间隙（打字指示）② 规划中（向导摊地图）③ 行动执行中（篝火小剧场）。

## 12. 技术栈

| 层 | 选型 | 理由 |
|---|---|---|
| UI | SwiftUI，macOS 14+，Swift 6 语言模式 | @Observable 落在 14；选 GRDB 后无需求 15 的理由 |
| LLM | SwiftAnthropic 2.2.x + MacPaw/OpenAI 0.5.x（pin 精确版本） | 均活跃维护，覆盖流式 + tool use；官方 Anthropic Swift SDK 尚不存在 |
| 持久化 | GRDB 7.11.x（SQLite WAL） | 后台并发写入 + 追加式日志场景明确优于 SwiftData |
| 并发 | actor + TaskGroup + AsyncStream + swift-async-algorithms 1.1.x | N 个并发 loop 事件流 merge 进单 @MainActor store |
| 动效 | SwiftUI `PhaseAnimator` / `KeyframeAnimator` / `TimelineView` / `matchedGeometryEffect`；角色 MVP 代码绘制 | macOS 14 原生齐备，零资产依赖起步；Rive/Lottie 为升级路径 |
| 安全 | App 沙箱 + user-selected 读写 entitlement + 安全作用域书签；Keychain（SecItem） | 书签随 squad 存储，过期自动重铸；key 永不进 UserDefaults/SQLite |

## 13. 预算与安全

- 预算三层：per-turn `max_tokens`、per-card `maxTurns + token 预算`（`card.token_budget` 列，规划者在行动总额内分配，缺省取设置里的默认值）、per-mission 总额。行动总额耗尽时暂停并给用户三选：**加注**（继续）、**提前收营**（未完成小目标转 `canceled` 使其终态化，进入 `delivering` 验收已有成果）、**终止**（行动 `failed`）。与 §5.1 的 `delivering` 定义（全部小目标终态）一致。
- 预算剩 10%（下限 3 轮）注入强制收尾指令：立即 complete 或 block。
- 文件写入仅限工作目录（含 symlink 规范化检查）；无 shell；网络只读。
- `ask_user` 是类型化持久门（`user_request` 表），不靠 regex 扫聊天。
- 对话线程（私聊/营地对话）不设 token 硬顶——用户实时在场即是控制——但用量计入统计展示。

## 14. 错误处理与恢复

| 故障 | 处理 |
|---|---|
| API 429/5xx/529 | 指数退避重试，尊重 retry-after |
| API 401/403 | 行动暂停 + 引导到设置配 key |
| refusal | `blocked(.refusal)`，不重试 |
| 工具错误 | `is_error` tool_result 自愈；同工具连续 3 次 → blocked |
| 上下文超限 | 客户端摘要压缩（保缓存前缀） |
| 每轮超时（120s） | 取消本轮，按工具错误路径重试一次，再超 → blocked |
| App 崩溃/退出 | 事件已落库；重启 reconcile 把 running 卡片直接转回 `ready` 并重建上下文包（`interrupted` 记在 Run 的 outcome 上，不是卡片状态——卡片状态机保持 §5.1 的穷举集合） |
| 收营蒸馏失败 | 确定性回退：交接包摘要拼接为笔记 |

每个静默状态都是显式枚举，UI 可渲染：排队中/执行中/等待用户/受阻(分类)/中断待恢复。

## 15. 测试策略

1. **MockProvider 脚本回放**：预设 tool_use 序列 → Agent Loop 纯逻辑单测（终止、提醒、自愈、预算收尾线）。
2. **状态机穷举**：全部转移合法性单测。
3. **内核不变量测试**：双规划 no-op、产物先耐久后完成、一卡一主。
4. **金路径集成**：假 LLM 端到端跑完一个两卡行动（含交接包传递 + ask_user 门）。
5. **活体冒烟仪式**（前身最贵教训——离线全绿抓不住打包/双规划者类回归）：每个里程碑用真实 API key 跑一个真需求零人工到收营，产物落在用户可及位置才算过。
6. **对话与记忆**：私聊蒸馏 → 伙伴记忆生成 → 该伙伴下一次卡片上下文注入的闭环单测（Mock 驱动）；向导组队提案确认门测试（未确认不得创建小队）。

## 16. 里程碑

实施计划按里程碑逐个制定（每个里程碑一份计划），不做单一大平铺计划。

| 里程碑 | 内容 | 验收 |
|---|---|---|
| M1 | 单伙伴单卡完整 loop：流式 UI、文件/网络工具、Keychain 设置；伙伴私聊（纯对话，暂不沉淀）；动效骨架（页面转场、流式打字指示、伙伴 idle/思考两态） | 真实 API 完成一个单卡任务，产物可 Finder reveal；与伙伴流畅私聊；等待全程有活动指示 |
| M2 | 内核：规划者、状态机、多卡串行依赖、交接包 | 两卡依赖行动端到端，下游冷启动开工 |
| M3 | 多伙伴并发、小队动态流、ask_user 门、交付面板、行动视图人性化完整版；角色状态动画全集 + 篝火小剧场 | 3 伙伴并发行动，中途问答 + 验收；小剧场准确反映各伙伴真实状态 |
| M4 | 知识与对话层：营地笔记（收营蒸馏 + 开工携带 + 检索）、伙伴记忆（沉淀 + 注入）、向导（营地对话 + camp_status + 组队提案） | 私聊沉淀的记忆出现在该伙伴下一次工作上下文；向导对话一键组队开工；跨行动经验复用可演示 |
| M5 | 崩溃恢复、预算收尾线、沙箱书签打磨、Reduce Motion 与动效性能打磨、打包分发 | 杀进程重启行动续跑；Reduce Motion 开启时全部动效有静态替代；产出可分发的 .app |

## 17. 继承自前身的教训对照表

| 前身踩坑 | 本设计的结构性规避 |
|---|---|
| TS/Python 双运行时契约漂移 → 双规划者事故 | 单 Swift 运行时 + 幂等键 upsert（§5.2-1） |
| scratch GC 吞产物，下游烧预算恢复日志 | 产物先耐久后完成（§5.2-2） |
| 僵死 worker 持卡 31 分钟（pid-alive ≠ liveness） | 进程内 task + 每轮超时，无进程模型（§5.3） |
| 预算耗尽前没交接，成果丢失 | 10% 收尾线注入（§13） |
| 「做完了」口头汇报与板上状态不一致 | 工具是唯一终结方式（§5.2-4） |
| 交付物埋在内部路径用户摸不到 | 交付面板 + Finder reveal + 位置即验收标准（§7/§11） |
| 静默状态不可见（「领航员受阻」之谜） | 全部显式枚举可渲染（§14） |
| 离线测试全绿掩盖打包/活体回归 | 活体冒烟仪式为里程碑硬门（§15-5） |

## 18. 开放问题

1. 正式产品名（工作名 AgentLoop；仓库 /Users/muzi/Agent-loop）。
2. `web_search` 的搜索后端选型（若 MVP 内做）。
3. 营地笔记/伙伴记忆蒸馏的 prompt 模板细节（实现期定稿）。
4. 私聊自动沉淀的闲置阈值取值（实现期定稿，M4）。
5. 角色动画的美术方向与资产管线（MVP 代码绘制简笔角色起步；是否引入 Rive/Lottie 与美术资产来源，M3 前定）。
