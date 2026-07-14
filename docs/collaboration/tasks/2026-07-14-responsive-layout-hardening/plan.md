# Coding 牧场窗口适配加固计划

日期：2026-07-14

## 授权与基线

- 用户已明确授权 Codex 安排本轮规划、实现和验收；
- 起始提交：`64f6327`；
- 工作树中已有用户目录 `.understand-anything/`，不得修改；
- 权威测试：`swift run RunTests`。

## 目标

让 Coding 牧场在 macOS 窗口从最小尺寸到大窗口/全屏之间连续缩放时保持可读、可操作：

- 不出现按钮或中文被压成逐字竖排；
- 不出现主内容被侧栏挤到不可用宽度；
- 不出现详情弹层超出内容区、主要操作被裁切；
- 辅助面板在空间不足时自动收起，空间恢复后可再次使用；
- 保持现有品牌、导航层级、数据和业务行为不变。

## 非目标

- 不重做视觉风格、信息架构或导航层级；
- 不修改 Core、数据库、Mission/Card 状态机或 Store 协议；
- 不增加依赖；
- 不改变最小窗口尺寸 640 × 680；
- 不处理 Preview 专用固定尺寸。

## 尺寸矩阵与预期行为

| 窗口范围 | 预期行为 |
|---|---|
| 640–899px 宽 | 自动使用详情优先模式，主侧栏收起；主内容占满窗口；复杂页头改为纵向分组/可换行；辅助笔记、动态面板保持收起。 |
| 900–1199px 宽 | 显示主侧栏；详情区仍采用紧凑页头；营地笔记、任务动态按各自现有阈值自动收起。 |
| ≥1200px 宽 | 显示主侧栏及用户主动开启的辅助面板；页头使用横向布局。 |
| 高度 680–759px | 主内容和弹层内部滚动，底部主要操作不被窗口裁切。 |
| 高度 ≥760px | 使用现有舒展布局。 |

主侧栏只在跨越紧凑断点时自动切换，避免用户在同一尺寸区间手动开关后被持续抢回状态。

## 实施任务

### 1. 统一布局策略

修改 `Sources/AgentLoopApp/Views/Theme.swift`：

- 增加集中式 `CampLayout` 断点与安全边距常量；
- 断点只描述 App 层布局，不进入 Core。

### 2. 窗口级导航降级

修改 `Sources/AgentLoopApp/Views/RootView.swift`：

- 读取整个窗口内容宽度；
- 跨越 900px 断点时在 `.all` 与 `.detailOnly` 间切换；
- 全局停营 banner 在紧凑宽度下将操作区移到下一行；
- 保留系统侧栏按钮和现有 selection 行为。

### 3. 营地主页面

修改 `Sources/AgentLoopApp/Views/CampHomeView.swift`：

- 页头在详情宽度不足时把标题与操作区分行，不允许按钮文字被压成竖排；
- 保留当前笔记本自动收起规则；
- 喂牛与待反刍 sheet 改为可伸缩的最小/理想/最大尺寸，不再要求固定宽高；
- 对话输入区在极窄详情宽度下允许主要输入与次要操作分行。

### 4. Coding 草原任务页

修改 `Sources/AgentLoopApp/Views/TaskRunView.swift`：

- 页头在紧凑详情宽度下按“标题/状态 → 牛与任务操作”分组；
- 状态、完成数、档位和花销允许自然换行；
- 预算告警与视图工具条在紧凑宽度下分行；
- 详情弹层按当前可用宽高计算尺寸。

修改 `Sources/AgentLoopApp/Views/Components/CardDetailInspector.swift`：

- 移除内部固定 620 × 640 尺寸，由调用方提供可用尺寸；
- 内容继续内部滚动，关闭操作始终可见。

### 5. 新版 Coding 牧场页面与表单

修改以下 App 层文件，统一紧凑页面和弹层的降级行为：

- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchHomeView.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/FeedComposerView.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/CowRosterView.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift`
- `Sources/AgentLoopApp/Views/DMChatView.swift`

仅处理固定宽度、横向表单和双栏卡片在窄宽度下的排列；不改变数据或交互流程。

## 验证

1. `swift build`；
2. `swift run RunTests`，完整输出保存为本目录 `verify.log`；
3. 使用隔离的临时 `AGENTLOOP_STATE_DIR` 与 `AGENTLOOP_UI_PREVIEW=1` 启动应用；
4. 逐一复核 640 × 680、900 × 700、1280 × 800 及最大化窗口下的：
   - 营地主页；
   - Coding 草原任务页；
   - 牛棚；
   - 设置；
   - 喂牛 sheet；
   - 待反刍 sheet；
   - 工作卡详情弹层；
5. 同时检查亮色与暗色不因布局修改产生裁切。

本仓库没有 App 层 UI 单测 target；本轮不新增无法运行的快照测试，以 App 构建、权威 Core 回归测试和可重复的真实窗口尺寸检查作为验收依据。

## 完成定义

- 尺寸矩阵中的页面均无文字竖排、控件重叠或主要操作裁切；
- 窄窗口自动释放侧栏占用，宽窗口恢复正常多栏；
- 固定详情弹层不会超出当前内容区；
- `swift build` 与 `swift run RunTests` 通过；
- 本目录包含 `verify.log` 与 `impl-report.md`。
