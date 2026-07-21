# 牧场 UI 升级实施报告

## 结果

已按 `plan.md` 完成草原漫步、牛棚与解锁、任务运行页三块 UI 升级。没有修改 Core、AppStore 契约、RootView 导航联动、MissionDraftConfirmationView、CampHomeView 或资源文件；没有提交。

## 改动文件

仅修改计划允许的六个实现文件：

1. `Sources/AgentLoopApp/Views/Theme.swift`
2. `Sources/AgentLoopApp/Views/Components/CodingPastureTheaterView.swift`
3. `Sources/AgentLoopApp/Views/CodingRanch/CowRosterView.swift`
4. `Sources/AgentLoopApp/Views/TaskRunView.swift`
5. `Sources/AgentLoopApp/Views/Components/CardRowView.swift`
6. `Sources/AgentLoopApp/Views/Components/FeedView.swift`

任务协议产物：本报告与 `verify.log`。

## 计划逐项映射

### A. Theme.swift 增量组件

- A1：新增 `RanchSectionHeader(icon:title:tint:count:)`，实现 26×26 tint 图标底、bold subheadline 标题和可选 `CampChip` 数量。
- A2：新增 `CampTag`，采用 caption2 medium、`Camp.ink`、`Camp.hay` 和胶囊内边距。
- A3：新增 `.campHoverLift()`；悬停缩放 1.012、阴影从 0.06/5/2 过渡到 0.12/9/4，Reduce Motion 下只改变阴影。
- A/共享布局：把 `FlowLayoutLite` 从 `TaskRunView.swift` 原样移到 `Theme.swift` 供牛棚和任务页共享；新增 `Camp.cardRadiusLarge = 16`。既有组件未改。

### B. 草原漫步动画

- B1：舞台 ZStack 外层加入 20 FPS `TimelineView`，直接使用既有 `paused = reduceMotion || controlActiveState != .key`。
- B2：新增 UInt64 FNV-1a helper，以 `companion.id` 确定性生成两组相位和 0.85...1.15 速度扰动。
- B3：按 `CompanionAnimState` 实现闲逛、半幅等待、原地点头和睡眠静止的 dx/dy/bob 纯时间函数；offset 放在 slot position 之后作用于整个 spot。
- B4：idle/thinking/celebrating 的朝向使用基础奇偶翻转 XOR 水平运动方向，并给 sprite 翻转加 0.35 秒 easeInOut；其他状态保持基础朝向。
- B5：paused 时 Timeline 停更；dense 横滚模式未加入漫步；未增加 Timer 或可变动画状态。

### C. 牛棚与解锁

- C1：页头改为 teal 真牛 sprite、bold title2 标题、`Camp.surface` 表面和 4pt pasture 渐变底边；副标题和自定义牛按钮保留。
- C2：已拥有与下一只可学习分区改用计划指定的 `RanchSectionHeader`，拥有区显示数量。
- C3：`CowRosterCard` 改成整卡 Button；64pt sprite 站在 pasture 椭圆上，缺图回退头像；role 使用 creek chip，specialties 使用 `FlowLayoutLite + CampTag`，recentMission 保留，右下角加入“档案”提示，圆角 16 并启用 hover lift。
- C4：`CowUnlockCard` 使用固定 amber 84pt sprite（契约无 colorName）；锁定态灰阶锁徽章、可领回态彩色 sparkles 徽章；信息层级、能力 tags、横向节点进度路径、moss 高亮描边和原 CTA 均按计划实现，布局改为单列。
- C5：载入、失败、action failure 横幅与解锁行为未改。

### D. 任务运行页

- D1：missionHeader 加入主导牛 56pt sprite 和 planning 思考气泡；标题升级为 bold title2；planning 状态 chip 使用 `Camp.skyWash`；状态与操作 chips 分行，操作行右对齐并保留 FlowLayout fallback；页头底部加入 pasture→hay 4pt 条，missionActions 逻辑不变。
- D2：系统 segmented Picker 改为自绘胶囊分段；轨道、选中白底浮起、ember 选中文字与 Coding 草原 moss leaf 均按计划实现；收哨、动态和提示逻辑不变。
- D3：`CardRowView` 左侧改为 34pt 状态圆徽章及指定 icon；头像优先 34pt 真牛、缺图回退；圆角 16、hover lift、既有选中/焦点描边均保留；running icon 在非 Reduce Motion 下 pulse。
- D4：`FeedView` 的牛头像优先 20pt sprite 并回退旧头像；牛/用户气泡分别改为 pasture/hay，系统消息与 pending 提问区逻辑不变。
- D5：成果标题改用指定 `RanchSectionHeader`；成果条目新增 pasture 0.5 opacity、圆角 8 的 hover 背景。

### 边界核对

- roster/card/feed 三处 sprite 缺失均有 `CompanionAvatarView` 回退。
- 动画完全由 Timeline 时间与 companion id 派生，Reduce Motion 或窗口非 key 时停止更新。
- 未改变任何 AppStore 调用、任务动作、pending answer、artifact reveal 或导航契约。

## 构建与测试

- `git diff --check`：通过。
- `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-ranch-ui-clang-cache SWIFTPM_CUSTOM_CACHE_PATH=/private/tmp/agentloop-ranch-ui-swiftpm-cache swift build --disable-sandbox --product AgentLoopApp`：通过，六个 UI 文件均实际编译，App 完成链接。
- 同环境 `swift build --disable-sandbox`：通过，`Build complete!`。
- 权威 `RunTests` 已运行，完整 stdout/stderr 写入 `verify.log`：
  - 并行模式完成构建并启动测试，但在受限环境的子进程用例阶段长时间无新输出，终止后追加串行复跑。
  - 串行 `swift run --disable-sandbox RunTests --no-parallel`：423 tests / 5 suites，419 通过、4 个已知沙箱基线问题，退出码 1。
  - 失败为 `keychainRoundTrip`（Keychain -50）、`workspaceBookmarkCaptureAndResolveRoundtrip`（security-scoped bookmark 不可用）、`haltDuringRunningCardLeavesReadyCardAndNoOpenRun` 与 `emergencyStopCancelsRunningBeforeWaitingForPlanner`（本仓库已记录的串行 runner 环境断言）。与上一轮牧场任务的 4 项受限沙箱基线一致，且均位于本任务未触及的 Core/测试路径。

## 与计划的偏离

实现范围与视觉规格无偏离。验证未达到正常环境全绿，原因是上述受限沙箱基线；未修改 Core 或测试来掩盖失败。裸 `swift build` 首次尝试还被默认用户缓存权限/缓存中的 SDK module 不匹配拦在 manifest 阶段，改用仓库既有的可写临时 Clang 缓存与 `--disable-sandbox` 后全目标构建通过。
