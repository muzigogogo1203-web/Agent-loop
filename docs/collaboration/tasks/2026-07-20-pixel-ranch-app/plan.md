# 像素风资产接入 + 数据驱动牛棚

Level 2。用户拍板：App 内牧场视觉从黏土 3D 全面转**高品质像素风**。直接动因：黏土牛棚图烤死 4 只牛与名册真实数据（可能为 0）冲突。核心新能力：**牛棚横幅数据驱动**——空棚底图 + 按真实名册摆睡姿像素牛。

## 资产（已就位于 `Sources/AgentLoopApp/Resources/RanchArt/`，旧黏土资产已移除）

- 场景：`PixelPastureDay/Night.png`（3:2 悬浮牧场岛，空）、`PixelBarnDay/Night.png`（16:9 牛棚内景，四个空干草隔间）
- 牛 sprite（透明底）：`PixelCowSide<Color>.png` ×7（侧面站姿，**原生朝左**）、`PixelCowSleep<Color>.png` ×7（睡姿带 Zzz），Color ∈ Purple/Teal/Coral/Pink/Blue/Green/Amber

## 允许触碰的文件（仅此 3 个）

`RanchArtView.swift`、`Components/CodingPastureTheaterView.swift`、`CodingRanch/CowRosterView.swift`。
（CardRowView/FeedView/TaskRunView 经由 `RanchCowSpriteView`/`spriteImage` 自动获得新资产，不要动它们。）

## 1. RanchArtView.swift

1. 场景资源名替换：`Ranch{Barn|Base}{Day|Night}` + 扩展名 jpg → `Pixel{Barn|Pasture}{Day|Night}` + png（`RanchArtKind.base` 对应 Pasture）。
2. **全部像素渲染加 `.interpolation(.none)`**（场景 Image 与 sprite Image 都要，保像素锐利）。
3. `spriteImage(colorName:)` 映射改为 `PixelCowSide<Cap>.png`；新增 `sleepSpriteImage(colorName:)` → `PixelCowSleep<Cap>.png`（同缓存机制）。
4. `RanchCowSpriteView` 语义更新：像素侧站 sprite **原生朝左**；`flipped: false` = 朝左原样，`flipped: true` = 镜像朝右。接地阴影保留（椭圆参数可微调至 width*0.7）。
5. **新增 `RanchBarnView`**：`(cows: [(id: String, colorName: String)], maxWidth: CGFloat?)`。
   - 底图：barn 场景（日/夜随 colorScheme），`scaledToFit` + `.interpolation(.none)` + 圆角 14 裁切，`maxWidth` 约束居中。
   - `.overlay { GeometryReader { proxy in ... } }` 内按隔间槽位摆睡姿牛：槽位归一化中心 `x ∈ [0.13, 0.385, 0.64, 0.895]`、`y = 0.74`；每只 `Image(nsImage: sleepSpriteImage(colorName:))`，宽 = `proxy.size.width * 0.17`（高按 sprite 比例自适应），`.interpolation(.none)`。
   - 摆 `min(cows.count, 4)` 只（取数组前 4），**0 只 = 纯空棚**；`cows.count > 4` 时右下角 `CampChip(text: "+\(count-4) 只在外放牧", color: Camp.amber)`，padding 10。
   - sleep sprite 缺失（未知色）该槽跳过不崩。整体 `.accessibilityHidden(true)`。

## 2. CodingPastureTheaterView.swift

1. 舞台底图自动换像素（kind .base 已指向 Pixel Pasture），无需改布局；确认渐变遮罩仍协调（保留）。
2. **朝向语义适配**（像素牛原生朝左，旧黏土牛语义相反）：
   - 行进段：`dx_direction > 0`（向右走）→ `flipped = true`；向左走 → `false`；|方向x|<1pt 沿用上一段。停留段保持刚走完那段的朝向。
   - 非闲逛状态（working/asking/scratching/napping）：统一 `flipped = true`（朝右，面向内容），废除奇偶基础翻转的残留使用。
3. dense 模式卡片里的 sprite 同样自动换新资产，不需改。

## 3. CowRosterView.swift

底部横幅 `RanchArtView(kind: .barn, layout: .fit(maxWidth: 560))` 替换为 `RanchBarnView(cows: state.owned.map { ($0.id, $0.colorName) }, maxWidth: 560)`，收尾语句保留。页头 teal sprite（现在会变成像素青牛）保留。

## 边界

- 任何 sprite/场景缺失走既有静默/回退路径，不崩。
- 槽位坐标常量集中定义（数组），便于后续微调。

## 验证

`swift build` 通过；`swift run RunTests` 基线全绿（沙箱环境性失败照旧注明）；impl-report 逐项映射并附资源 bundle 内容 ls。

## Open questions

（无）
