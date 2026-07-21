# 像素牛走路动画：2 帧步行循环

Level 1-2。资产即将就位：`PixelCowStride<Color>.png` ×7（迈步姿态，与站姿同朝向、同比例）。行走时站姿⇄迈步按 ~6fps 交替，停下/非行走恢复站姿。

## 允许触碰的文件（仅此 2 个）

`CodingRanch/RanchArtView.swift`、`Components/CodingPastureTheaterView.swift`。

## 1. RanchArtView.swift

1. 新增 `static func strideSpriteImage(colorName: String) -> NSImage?` → `PixelCowStride<Cap>.png`（同缓存机制、同色名映射）。
2. `RanchCowSpriteView` 增加参数 `striding: Bool = false`：为 true 且 stride 资产存在时渲染 stride 图，否则渲染站姿（缺资产静默回退站姿，不崩）。阴影/翻转/interpolation(.none) 逻辑不变，既有调用点不受影响（默认 false）。

## 2. CodingPastureTheaterView.swift

1. 行走判定已存在（草点环线的走段）。走段内计算帧号：`let strideFrame = Int(t * 6.0 * speedJitter) % 2 == 1`，把 `striding: strideFrame` 传给 sprite；停段与非闲逛状态（asking/scratching/working/napping）一律 `striding: false`。
2. 走段的颠步 bob 幅度从 2.0 降到 1.2（腿部已有动画，位移减弱避免过跳）。
3. 其余（朝向、zIndex、名牌、横匾）不动。paused 时 TimelineView 停更即定格，无需额外分支。

## 验证

`swift build` + `swift run RunTests` 基线全绿（环境性失败照旧注明）；impl-report 简要映射。

## Open questions

（无）
