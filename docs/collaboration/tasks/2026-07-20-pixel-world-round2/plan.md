# 像素世界第二轮：进度横匾 + 场景即界面的牛棚

Level 2。用户反馈：① 草原路标与场景结合不佳且干扰牛群——选定方案：六环节收进一块清晰的「进度横匾」，当前环节跳动；② 牛棚仍有冗余、信息分散——重构为「场景即界面」。设计决策权已授予 Claude，本 plan 即最终设计。

## 允许触碰的文件（仅此 3 个）

`CodingRanch/RanchArtView.swift`、`Components/CodingPastureTheaterView.swift`、`CodingRanch/CowRosterView.swift`。

## 1. 草原：牧场进度横匾（CodingPastureTheaterView）

1. **移除**上一轮的 6 个沿路小木牌 overlay（路标锚点数组、木牌视图整段删除）。
2. 新增**进度横匾**（单一 overlay，地图内顶部居中）：
   - 位置：水平居中，距舞台顶 12pt；宽度 `min(stageW * 0.72, 640)`。zIndex 6000。
   - 容器：RoundedRectangle(cornerRadius: 10)，亮色填 `Camp.hay.opacity(0.92)`、暗色填 `Camp.surfaceRaised.opacity(0.90)`，描边 `Camp.line`，阴影 black 0.10/6/2。内边距水平 10 垂直 6。
   - 内容：HStack(spacing: 2) 六段。每段：`HStack(spacing:3){ Image(stage.icon) + Text(stage.title) }` caption2；段间插 `chevron.right` caption2、`Camp.inkSecondary.opacity(0.5)`（最后一段前用 `arrow.uturn.forward` 呼应循环）。
   - 非激活段：`Camp.inkSecondary`。激活段：包在 RoundedRectangle(cornerRadius: 7) `stage.color` 底、白字 caption2.bold、水平 7 垂直 3 内边距，并迁移现有 TimelineView 弹跳 lift（sin 双周期 ±2.5pt，遵守 paused）。
   - 窄适配：`ViewThatFits(in: .horizontal)` 两版——完整版如上；紧凑版非激活段只显图标、激活段仍显「图标+标题」。
   - `activeStage` 逻辑不变。
3. **牛群槽位下压避开横匾**（横匾占顶部 ~0.05-0.20 高度带）：把所有 y < 0.30 的槽位改为 y ≥ 0.32：`(0.40,0.28)→(0.40,0.34)`、`(0.56,0.24)→(0.56,0.32)`；其余不变。
4. 其余（漫游、遮罩、memoryTrough、dense）不动。

## 2. 牛棚：场景即界面（RanchArtView.RanchBarnView + CowRosterView）

### RanchBarnView 升级

签名改为：`RanchBarnView(cows: [(id: String, name: String, colorName: String)], lockedCow: (name: String, canUnlock: Bool)?, maxWidth: CGFloat?, onSelectCow: ((String) -> Void)? = nil)`。

1. 每个有牛的隔间：睡姿 sprite 下方挂**名字木牌**（`Text(name)` caption2.bold、`Camp.hay` 底、圆角 6、`Camp.ink`、水平 8 垂直 3 内边距、细描边 `Camp.line`），木牌位于隔间底部 y≈0.92 处对应槽位 x。
2. 整个隔间区域（sprite+木牌）包 `Button` → `onSelectCow?(id)`；`onHover` 时 sprite `scaleEffect(1.04)`（reduceMotion 时只换阴影）；`.help("查看 \(name) 的档案")`。onSelectCow 为 nil 时不可点（保持普通展示）。
3. 锁定槽（最右空槽）逻辑保留：灰剪影/彩色+sparkles、「学习中/可以领回」木牌——木牌样式与名字木牌统一。锁定槽不可点。
4. cows.count > 4 的「+N 只在外放牧」chip 保留。

### CowRosterView 重排（根治冗余）

新结构（ScrollView 内，从上到下）：

1. 页头（不变，含「创建自定义牛…」按钮）。
2. **牛棚场景**：`RanchBarnView(cows: owned 映射(id,name,colorName), lockedCow: 同前, maxWidth: 800, onSelectCow: onOpenCow)`——页面唯一主视觉。
3. **解锁进度行**（仅 `state.locked` 非空时）：一条 campCard 行。
   - 折叠态（默认，canUnlock=false）：`HStack{ Image("lock.fill") Camp.stone + Text("\(cow.name) · 学习中 \(done)/\(total)")（done=progress.steps 中 completed 数）callout.semibold + Spacer + chevron }`，点击整行展开/收起（@State 控制，withAnimation）。
   - 展开态内容（复用上一轮已实现的组件）：爪印进度路径 + 「它能帮你」CampTag 行 + learningGoal caption。
   - `canUnlock=true` 时：强制展开、行首图标换 `sparkles`（Camp.moss）、标题「\(cow.name) · 可以领回」、行尾放现有「领回营地」主按钮（保留 actionState 逻辑与失败面板）。
4. **迷你名册行**：`FlowLayoutLite` 排布，每只 owned 牛一枚胶囊按钮：`HStack(spacing:6){ RanchCowSpriteView(colorName:, height: 22, flipped: true) + Text(name) callout.weight(.semibold) Camp.ink + CampChip(text: role, color: Camp.creek) }`，`Camp.surface` 底 Capsule、描边 `Camp.line`、`.campHoverLift()`，点击 → onOpenCow(id)。
5. **删除** `CowRosterCard` 的使用与 LazyVGrid 网格、删除该 struct（预览如引用则同步更新）；specialties/recentMission 不再在本页展示（档案页已有）。
6. `CowSummaryViewState` 等契约不改；`unlock()`、AccessibilityNotification 逻辑保留。

## 边界与验证

- sprite 缺失回退不变；onSelectCow 空安全。
- `swift build` + `swift run RunTests` 基线全绿（环境性失败照旧注明）；impl-report 逐项映射。

## Open questions

（无）
