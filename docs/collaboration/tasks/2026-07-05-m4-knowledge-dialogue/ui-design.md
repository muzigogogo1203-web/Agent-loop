# M4 UI 设计稿 — 营地首页 / 提案卡片 / DM 记忆抽屉

沿用 `Theme.swift` 营地感体系（羊皮纸画布、篝火橙主色、圆角 14/10、rounded 字体、暗色=篝火夜景）。
本稿对照 spec §11「营地首页：营地笔记本 + 向导常驻对话；组队提案渲染为结构化确认卡片」与 §11.1-11.3 活人感原则。

## 1. 信息架构

```
侧栏                          detail
┌──────────────┐  ┌─────────────────────────────────┐
│ [新行动]      │  │ Destination.camp → CampHomeView │
│ ⛺ 营地       │◀─┤ 左：营地笔记本 NoteListPane      │
│ 进行中的行动… │  │ 右：向导对话 GuideChatColumn     │
│ 往期行动…     │  └─────────────────────────────────┘
│ 伙伴…        │
│ 设置          │
└──────────────┘
```

- 侧栏「营地」入口置于「新行动」按钮下方、行动列表上方——营地是家，行动是出门。图标 `tent.fill`，选中态 ember。
- `Destination` 新增 `.camp`；App 首启仍落在 newMission（不改变现有习惯），营地一键可达。

## 2. 营地首页 CampHomeView

两栏（HStack）：**左 = 营地笔记本（固定 340pt）**，**右 = 向导对话（flex 主体）**。
宽度自适应沿用 m3.3 规则：窗口 < 860pt 时笔记本自动收起，工具栏保留切换按钮（`book.closed` ⇄ `sidebar.leading`），用户偏好与自动收起互不覆盖。

### 2.1 顶部横幅（跨两栏）

- 左：`⛺ 我的营地`（title3 semibold）+ 副标语（caption，inkSecondary）：「行动的经验和向导都在这儿」。
- 右：向导头像（CompanionAvatarView，amber，状态由对话流驱动：idle 呼吸 / thinking 冒泡 / working 敲打）。

### 2.2 营地笔记本 NoteListPane（复用组件，camp/companion 两种数据源）

```
┌ 营地笔记 ──────── [N 条] ┐
│ 🔍 搜索笔记…             │
│ ── 置顶 ──               │
│ 📌 北岭探索复盘  [收营]   │   ← 标题 + 来源 chip
│    先看等高线，雨天路滑…  │   ← 正文前 2 行，inkSecondary
│ ── 全部 ──               │
│    营地决策：桥优先       │
│    …                    │
│ 空态：⛺「还没有笔记——    │
│  收营后自动沉淀，或让向导记」│
└─────────────────────────┘
```

- 搜索框：本地即时过滤（title/body contains），无网络。
- 行：标题（callout medium）、正文摘要 2 行、置顶行首 `pin.fill`（ember）；来源 chip：`missionId != nil` → 「收营」（moss）；否则「手记」（stone）。
- 交互：点击 → 编辑 sheet（标题 TextField + 正文 TextEditor(等宽不必) + 置顶 Toggle + 删除（role destructive，二次确认）+ 保存）；右键菜单：置顶/取消置顶、删除。
- 列表变更动画：插入 `.opacity + .move(top)`，reduceMotion 时无动画。

### 2.3 向导对话 GuideChatColumn

- 气泡复用 DM `ChatBubble` 风格：向导在左（amber 头像 + surface 气泡），用户在右（ember 0.14 气泡）。
- **工具活动行**（活人感·无死等）：toolActivity 事件期间在流式气泡上方显示一行小字 + TypingIndicator：
  - `search_camp_notes` → 「向导翻了翻笔记本…」
  - `camp_status` → 「向导看了看营地各处…」
  - `propose_squad` → 「向导在拟组队提案…」
- 输入区：TextField + 发送按钮（与 DM 一致）+ 工具栏「沉淀笔记」按钮（`sparkles`；D9）。
- 沉淀反馈：按钮转菊花 → 底部 toast「已沉淀 1 条营地笔记」/「这段对话暂时没什么可记的」，2.5s 自动消失。

### 2.4 组队提案卡片 ProposalCardView（嵌在消息流中）

```
┌───────────────────────────────┐  pending: amber 边框 1.5pt
│ 🏕 组队提案 · 先遣队           │  title: callout semibold
│ 目标：探索北岭并画出等高线图    │  body, 可多行
│ 👤👤 甲、乙        [预算 66k]  │  头像叠排 + 名字 + 预算 chip
│ ┌───────────┐ ┌──────┐        │
│ │ 就这么办 🔥│ │ 先不 │        │  主按钮 ember / 次按钮 stone
│ └───────────┘ └──────┘        │
└───────────────────────────────┘
confirmed → 边框转 moss，按钮区变为「✓ 已开工 · 去看看 →」（跳转该行动）
dismissed → 整卡 60% 透明度，footer「已搁置」
```

- 出现动画：spring scale 0.96→1 + opacity（reduceMotion 静态）。
- 确认中：主按钮内嵌 ProgressView，双击保护（confirming set）。
- 确认失败（StaleProposalError）：toast「这个提案已经处理过了」。
- 成员头像取自名册；已被删除的成员显示占位问号头像并禁用确认按钮（防幽灵成员）。

## 3. DM 私聊：沉淀按钮 + 记忆抽屉

- toolbar：`[沉淀记忆 ✨] [记忆 📖] [编辑伙伴]`。
  - 沉淀记忆：手动触发（minMessages=1），转菊花 → toast「已记住这段对话」/「暂时没什么要记的」。
  - 记忆抽屉：右侧 330pt 滑出（`.move(edge:.trailing)`），NoteListPane 复用（companion 数据源，来源 chip：「私聊」）。宽度 < 820pt 时禁用抽屉按钮（help 提示加宽窗口）。
- **切走自动蒸馏**（D7）：RootView selection 离开 chat(id) 时触发 `store.autoDistillOnLeave(companionId)`（阈值 ≥4 条未蒸馏），后台静默，完成后若产出记忆则 toast 一次。

## 4. AppStore 新增状态

```swift
// 营地
var campId: String?              // 默认营地，init 时解析
var campNotes: [CampNoteRecord]
var guideMessages: [(id, role, text, proposal?)]  // 从 chat_message 读取
var guideStreaming: Bool
var guideToolActivity: String?   // 人话化工具名
var confirmingProposals: Set<String>
// 记忆
var memoryNotes: [CompanionNoteRecord]（当前 DM 伙伴）
var memoryDrawerVisible: Bool
var distillingMemory / distillingGuideChat: Bool
// 反馈
var knowledgeToast: String?      // 统一 toast 通道
```

- `.campNoteCreated` 内核事件 → `reloadCampKnowledge()`（收营蒸馏完成时若正看营地首页，笔记实时浮现）。
- 向导流复用 `DeltaCoalescer`（30-50ms 合批，多流不掉帧）。

## 5. 动效与可达性清单（spec §11.2）

| 场景 | 动效 | reduceMotion 替代 |
|---|---|---|
| 笔记插入/删除 | opacity+move snappy | 直接刷新 |
| 提案卡片出现 | spring 缩放+淡入 | 静态显示 |
| 提案确认成功 | 边框色 amber→moss + 按钮区淡切 | 直接切换 |
| 向导思考/工具 | TypingIndicator + avatar thinking/working | 静态文字行保留 |
| toast | 底部浮出淡入淡出 | 淡入淡出保留（非运动） |
| 记忆抽屉 | move(trailing) | 直接显隐 |

失焦暂停、TimelineView ≤10fps 沿用 CompanionAvatarView 既有实现。

## 6. 微文案（人话，向导有口吻）

- 向导空对话开场占位：「我是这营地的向导。想了解营地情况、翻往期笔记，或者组队出发，都可以找我。」
- 提案确认按钮「就这么办」/ 驳回「先不」；确认后 feed 口吻「向导把小队拉好了，已经出发。」
- 沉淀 toast 见上文；营地笔记空态见 2.2。
