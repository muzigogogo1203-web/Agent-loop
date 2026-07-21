# 像素世界整合：campId 过滤修复 + 全景草原 + 牛棚场景整合

Level 2。用户反馈：① 牛棚空着但本地明明有两只牛（bug）；② 像素化后界面不该再「地图装小框、UI 在外面摆摊」——环节路标要长进草原地图里，可学习的牛要住进牛棚场景里。

## Bug 根因（已用生产库确认）

用户的两只 regular 牛（阿桂、1）`campId` 为空（早期流程创建），而两处过滤都是 `$0.campId == campId`，全被滤掉。修法：**空 campId 视为归属当前营地**（当前单营地语义）。

## 允许触碰的文件（仅此 5 个）

`CodingRanchLiveHosts.swift`、`CodingRanchStoreAdapter.swift`、`CodingRanch/RanchArtView.swift`、`Components/CodingPastureTheaterView.swift`、`CodingRanch/CowRosterView.swift`。

## 1. campId 过滤修复（两处，改法一致）

- `CodingRanchLiveHosts.swift` rosterState（约 L190）与 `CodingRanchStoreAdapter.swift`（约 L17）：
  `$0.campId == campId` → `($0.campId == campId || ($0.campId ?? "").isEmpty)`（按 campId 实际类型适配 nil/空串两种）。`kind == .regular` 条件不变。

## 2. 全景草原（CodingPastureTheaterView 结构性改造）

新资产已就位：`PixelPanoramaDay/Night.png`（21:9 全景地图：左上牛棚、右上池塘、右下干草+饲料槽、一条小路从左下蜿蜒到右缘）。

1. `RanchArtView.RanchArtKind` 加 `.panorama`（映射 PixelPanorama{Day,Night}.png）。
2. 舞台改全景：AspectFitStageLayout 比例改 `2.3333`、maxHeight 520；底图 kind 用 `.panorama`。渐变遮罩强度减半（全景自带层次）。
3. **loopStageRail 整段移除**，六环节变成地图路标 overlay：
   - 路标锚点常量数组（沿地图小路，集中定义便于微调）：`[(0.10,0.80),(0.28,0.74),(0.46,0.71),(0.63,0.68),(0.79,0.66),(0.93,0.63)]`。
   - 每个路标 = 小木牌视图：VStack(spacing:0){ 牌面 RoundedRectangle(cornerRadius:6) 填 `Camp.hay`、内容 HStack{stage.icon caption2 + stage.title caption2.bold}、`Camp.ink` 前景、描边 `Camp.line`；牌面下 3×8pt 木桩矩形 }。非激活：opacity 0.78、scale 0.92。激活：牌面填 `stage.color`、白字、scale 1.0，加现有 TimelineView 弹跳 lift（迁移原 stageMarker 的 sin 弹跳，遵守 paused）。zIndex 5000。
   - `activeStage` 计算逻辑原样保留。
4. **牛群漫游槽位改到全景大草地**（常量数组）：
   - ≤3 只：`[(0.45,0.42),(0.62,0.50),(0.32,0.52)]`
   - ≥4 只：`[(0.30,0.44),(0.46,0.54),(0.60,0.40),(0.72,0.50),(0.40,0.28),(0.56,0.24),(0.22,0.56),(0.84,0.40)]`
   - 漫游半径升到 `0.06*W`；钳制 inset 维持；槽位已避开牛棚区与池塘。
5. `memoryTrough` 移到地图右下饲料槽旁 `(0.87, 0.86)`（样式不变，zIndex 10000 保留）。
6. `emptyPastureHint` 移到 `(0.5, 0.45)`。dense 模式头图同样换 `.panorama`，其余不变。

## 3. 牛棚场景整合（RanchArtView.RanchBarnView + CowRosterView）

1. `RanchBarnView` 增加可选参数 `lockedCow: (name: String, canUnlock: Bool)?`：
   - 有值且 owned 占用的槽位 < 4 时，取**最右侧空槽**放一只睡姿 sprite（固定用 "amber" 色）：未可解锁 `.grayscale(1).opacity(0.5)`；可解锁则彩色并在 sprite 右上叠 16pt `sparkles` 徽章（`Camp.moss` 圆底白图标）。
   - 该槽 sprite 下方挂小木牌：`Text(canUnlock ? "可以领回" : "学习中")` caption2.bold、`Camp.hay` 底、圆角 6、`Camp.ink` 前景。
2. `CowRosterView` 结构重排：页头 → **牛棚场景**（`RanchBarnView(cows:..., lockedCow: state.locked.first.map { ($0.name, state.newcomerProgress.canUnlock) }, maxWidth: 760)`，页面主视觉）→ 解锁详情卡（仅未解锁时，进度路径+CTA 原样保留）→ 名册网格。移除原底部收尾语和原横幅位置。

## 边界与验证

- sprite/场景缺失回退路径不变；lockedCow 槽位不足时静默不显示。
- `swift build` + `swift run RunTests` 基线全绿（环境性失败照旧注明）；impl-report 逐项映射。
- 修复后预期：用户库中牛棚显示 2 只睡姿牛（阿桂、1）+ 最右槽一只灰剪影学习牛。

## Open questions

（无）

## Blocked 解答（Claude，resume 用）

分支已由 Claude 在沙箱外创建：当前即 `feat/pixel-ranch`（未提交的像素资产改动随分支携带）。你无需也不要执行任何 git 分支/提交操作，直接在当前工作区实现本 plan 即可。
