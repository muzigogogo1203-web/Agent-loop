# 牧场 UI 升级：草原漫步动画 + 牛棚重设计 + 任务运行页重设计

Level 2。用户反馈三块：① 草原的牛不会动，要自主动起来；② 「我的营地」创建计划之后的任务运行页整块 UI 不好；③ 「牛棚与解锁」太丑。设计语言：**简洁、有设计感、偏卡通、亲切**（黏土牧场语言）。

## 非目标

- 不改任何 AppStore 字段/方法调用契约、不改 RootView 导航联动（`onChange(of: currentMissionId/navigateToMissionId)`）、不碰 Core。
- 不改 MissionDraftConfirmationView、CampHomeView（后续轮次）。
- 不引入新资源文件（现有 RanchArt JPEG/PNG 够用）。
- 动画不引入可变状态/Timer——全部由 `TimelineView` 的时间纯函数驱动（seek-safe），尊重现有 `paused = reduceMotion || controlActiveState != .key` 约定。

## 允许触碰的文件（仅此 6 个）

`Theme.swift`（仅增量添加，不改既有组件）、`CodingPastureTheaterView.swift`、`CowRosterView.swift`、`TaskRunView.swift`（missionView 子树）、`Components/CardRowView.swift`、`Components/FeedView.swift`。

## A. Theme.swift 增量组件（三块共用，全部新增不改旧）

1. `RanchSectionHeader`：`(icon: String, title: String, tint: Color, count: Int? = nil)` — 图标放 26×26 tint.opacity(0.15) 圆角方块（radius 8）内、tint 前景；标题 `.subheadline.weight(.bold)`、`Camp.ink`；可选 count 用现有 `CampChip`。替代纯灰字 `CampSectionTitle` 用于这三个页面（别的页面不动）。
2. `CampTag`：小标签胶囊 — `.caption2.weight(.medium)`、`Camp.ink` 前景、`Camp.hay` 底、水平 8 垂直 3、Capsule。用于 specialties/capabilities。
3. `.campHoverLift()` ViewModifier：`onHover` 驱动 `scaleEffect(hover ? 1.012 : 1)` + shadow(black.opacity 0.06→0.12, radius 5→9, y 2→4)，`.animation(.easeOut(duration:0.18))`；`accessibilityReduceMotion` 时只变阴影不缩放。

## B. 草原漫步动画（CodingPastureTheaterView）

舞台模式的每只牛在自己站位附近自主活动，**状态决定动法**（保持「真实状态可视化」原则）：

1. 整个 stage 的 ZStack 外包一层 `TimelineView(.animation(minimumInterval: 1/20, paused: paused))`（`paused` 用现有定义）；`t = timeline.date.timeIntervalSinceReferenceDate`。
2. 每只牛从 `companion.id` 播种确定性参数（写一个 `fnv1a` 哈希 helper 返回 UInt64，取位段生成）：`phase1, phase2 ∈ [0, 2π)`、`speedJitter ∈ [0.85, 1.15]`。
3. 按 `CompanionAnimState` 计算站位偏移 `(dx, dy)`（在 `.position(slot)` 之后再 `.offset(dx, dy+bob)` 整个 spot）：
   - `idle / thinking / celebrating`（闲逛）：`dx = W*0.045*sin(t*0.11*j+p1)`，`dy = H*0.030*sin(t*0.07*j+p2)`；走路颠步 `bob = 1.6*abs(cos(t*0.11*j+p1))*sin(t*2.3)`。
   - `asking`（原地等人）：幅度减半、无 bob。
   - `working`（干活）：`dx = 0`，`dy = 1.4*sin(t*1.7+p1)`（原地小幅点头）。
   - `napping`：全零（睡觉不动）。
   - `scratching`：同 asking。
   （W/H 为 stage 实际尺寸。）
4. 朝向跟随移动：闲逛状态 `flipped = 基础奇偶翻转 XOR (cos(t*0.11*j+p1) < 0)`；对 flip 加 `.animation(.easeInOut(duration:0.35), value: flipped)` 平滑转身。非闲逛状态维持基础奇偶翻转。
5. `paused` 为 true 时 TimelineView 停更，全部定格——不需要额外分支。dense 横滚模式不加漫步（列表不适合）。

## C. 牛棚与解锁（CowRosterView）

1. **页头**：图标换成 `RanchCowSpriteView(colorName: "teal", height: 40, flipped: false)`（有真牛比 SF Symbol 亲切；青色区别于卡片）；标题「牛棚」`.title2.weight(.bold)`；副标题不变。头部背景改 `Camp.surface` 底 + 底边 `Camp.pasture` 4pt 渐变条（轻草地暗示）。
2. **分区标题**：`RanchSectionHeader(icon: "pawprint.fill", title: "已经在营地的牛", tint: Camp.moss, count: state.owned.count)`；解锁区 `RanchSectionHeader(icon: "sparkles", title: "下一只可以学习的牛", tint: Camp.amber)`。
3. **CowRosterCard 重做**：
   - 头像区：`RanchCowSpriteView(colorName: cow.colorName, height: 64)` 站在一个 `Camp.pasture` 椭圆（宽 56 高 14）上；sprite 缺失回退现有 `CompanionAvatarView`。
   - 名字 `.headline.weight(.bold)`；role 从灰字改为 `CampChip(text: cow.role, color: Camp.creek)`。
   - specialties：`FlowLayoutLite`（TaskRunView 已有，挪到 Theme.swift 作共享——允许这一处移动代码，TaskRunView 引用同步改）+ `CampTag` 逐个渲染，替代「·」拼接。
   - recentMission 保留 Label 样式。
   - 整卡 `Button`（点击即打开档案），移除「查看牛的档案」文字按钮，右下角放 `Image(systemName:"arrow.right.circle.fill")` + 「档案」caption 的轻指示；`.campHoverLift()`；卡片圆角用 16（新常量 `Camp.cardRadiusLarge = 16` 加进 Theme）。
4. **CowUnlockCard 重做（「领养卡」）**：
   - 左侧：未解锁 = `RanchCowSpriteView(colorName: cow.colorName ?? "amber", height: 84)` 加 `.grayscale(1).opacity(0.55)` 剪影 + 右下角 22pt 锁徽章（`lock.fill`，`Camp.stone` 圆底白描边）；`canUnlock` = 彩色 sprite + `sparkles` 徽章（`Camp.moss`）。若 `LockedCowViewState` 无 colorName 字段就固定用 "amber"。
   - 右侧上：名字 bold + 现有「学习中/可以领回」chip；role callout；learningGoal caption。
   - **解锁条件改横向进度路径**：`HStack` 中每个 step 一个节点——22pt 圆（完成 = `Camp.moss` 实心 + 白 `pawprint.fill`；未完成 = `Camp.stone.opacity(0.25)` 圆 + `Camp.stone` 序号数字），节点间 2pt 连接线（完成段 moss / 未完成段 line），节点下方 step.title caption2 居中（`fixedSize` 防截断，整体可 `ScrollView(.horizontal)` 兜底窄窗）。替代现有 checkmark 列表。
   - capabilities：`RanchSectionHeader(icon:"hand.thumbsup.fill", title:"它能帮你", tint: Camp.creek)` + `CampTag` 流式排列，替代 checkmark.seal 列表。
   - `canUnlock` 时：卡片描边 `Camp.moss`（用现有 highlighted 机制换色或本卡自绘）+ 底部 CTA 行保留（文案与按钮不变）。
   - 两列 `ViewThatFits` 结构可移除，改单列纵排（能力 tags → 进度路径 → CTA）。
5. 载入/失败/横幅结构不动。

## D. 任务运行页（TaskRunView.missionView 子树 + CardRowView + FeedView）

原则：信息不减、层级重排、抽象图标换真素材、灰底灰字提亮。

1. **missionHeader 英雄化**：
   - 左侧加当前主导牛 sprite：取 `presentCompanions` 第一只的 colorName（取不到则 "purple"），`RanchCowSpriteView(height: 56)`；`missionPhase == .planning` 时 sprite 上方叠一个思考气泡（`Camp.surfaceRaised` 圆角气泡内放现有 `TypingIndicatorView`）。
   - 标题行：missionTitle `.title2.weight(.bold)`；statusChip 里 planning 文案「基础牛正在规划路线…」保留但底色改 `Camp.skyWash`。
   - chips 分两行分组：状态类（statusChip + 完成数）一行，操作类（autonomyMenu + spendChip）一行右对齐；`FlowLayoutLite` 保留兜底。
   - 页头卡片底部加 4pt `Camp.pasture`→`Camp.hay` 渐变细条（与牛棚页头呼应）。
   - missionActions 按钮组不动（逻辑保留）。
2. **viewToggle**：分段控件改自绘胶囊分段（`Camp.surfaceRaised` 轨道 + 选中段 `Camp.surface` 白底浮起 + `Camp.ember` 前景；「Coding 草原」段选中时图标 `leaf.fill` 变 `Camp.moss`）。收哨/动态按钮样式不动。
3. **CardRowView**：
   - 左侧 4pt 竖条改为 34pt 状态圆徽章：状态色 opacity 0.15 圆底 + 状态 icon（done=checkmark / running=hammer.fill / blocked=hand.raised.fill / ready·todo=circle.dashed / canceled=xmark，色用 `CampStatusStyle.cardColor`）。
   - 头像换 `RanchCowSpriteView(colorName:, height: 34)`（缺失回退 CompanionAvatarView）。
   - 圆角 16、`.campHoverLift()`（保留现有选中/焦点描边逻辑，仅换视觉参数）。
   - running 卡：徽章 icon 加 `symbolEffect(.pulse)`（macOS 14 可用；respetc reduceMotion 时不加）。
4. **FeedView 气泡**：牛的气泡加 20pt sprite 小头像（缺失回退现有头像）；牛气泡底色 `Camp.pasture`、用户气泡底色 `Camp.hay`（暗色模式对应动态色已定义）、系统消息保持灰；圆角语言不变。底部 pending 提问区与按钮逻辑不动。
5. **artifactsView**：标题换 `RanchSectionHeader(icon:"shippingbox.fill", title:"回营成果", tint: Camp.amber)`；条目行加 hover 背景（`Camp.pasture.opacity(0.5)` 圆角 8）。

## 边界与验证

- sprite 缺失回退路径三处（roster/card/feed）都必须存在，不许崩。
- 动画：reduceMotion 或窗口失焦时完全定格（现有 paused 契约）；CPU 无新增常驻计时器。
- `swift build` 通过；`swift run RunTests` 保持基线全绿（受限沙箱环境失败照旧注明）。
- impl-report 列出每处视觉改动与对应 plan 条目号。

## 完成定义

三块页面按上述规格落地、逻辑契约零变化、测试全绿。

## Open questions

（无）
