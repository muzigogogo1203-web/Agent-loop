# 草原具象小牛 + 全部插画比例修复

Level 2。用户对已落地氛围资产的两条反馈：① 所有 RanchArt 插画随窗口宽度被裁切（越宽裁越狠）；② `CodingPastureTheaterView` 的白卡片浮层拼贴感重，要求草原上出现具象小牛。

## 目标

1. 全部 RanchArt 插画改为**锁定原始宽高比的 fit 渲染**，任何窗口尺寸都不裁切；草原舞台的小牛定位随之稳定对应图上地标。
2. 草原舞台用**透明底小牛 sprite**（已抠好，7 色，在 `Resources/RanchArt/RanchCow<Color>.png`）替代白卡片浮层；牛的身份/状态/点击行为仍完全由真实事件流驱动，逻辑不变。

## 非目标

- 不改 `TaskRunView` 对本视图的调用契约、不改任何 Core/数据层。
- 不动工作区里其他会话正在整合的文件（CliProcessBackend、BoardToolServer、AppStore、SettingsView 等）。只准触碰：`RanchArtView.swift`、`CodingPastureTheaterView.swift`、`CowRosterView.swift`、`CodingRanchHomeView.swift`（后两者当前无未提交改动，改前确认）。
- 不加动画（呼吸/走动留待后续）。

## 资产（已就位）

`Sources/AgentLoopApp/Resources/RanchArt/` 新增 7 张透明底 PNG：`RanchCowPurple/Teal/Coral/Pink/Blue/Green/Amber.png`（约 440-480×640）。已有 4 张场景 JPEG 不变。

## 改动设计（决策已定）

### 1. `RanchArtView.swift`

- 改造为两种布局：
  - `RanchArtView(kind:height:)`（现签名）**删除**，统一改为 `RanchArtView(kind:layout:)`，`enum RanchArtLayout { case fit(maxWidth: CGFloat?) }`——只保留 fit：`Image.resizable().scaledToFit()`，容器天然取图片宽高比，`maxWidth` 有值则 `.frame(maxWidth:)` 并由调用方外层居中。圆角 `clipShape` 保留。
  - 新增 `static func spriteImage(colorName: String) -> NSImage?`：把 `colorName.lowercased()` 映射到 `RanchCow<首字母大写>.png`（合法集合：purple/teal/coral/pink/blue/green/amber，先对照 `CompanionAvatarView` 的调色板 key 确认拼写一致），走同一 `resourceBundle` helper + 静态缓存；未知色/缺资源返回 nil。
  - 新增 `struct RanchCowSpriteView: View { let colorName: String; let height: CGFloat; let flipped: Bool }`：渲染 sprite（`scaledToFit`，`scaleEffect(x: flipped ? -1 : 1)`），底部加接地椭圆阴影（宽 ≈ height*0.55，高 ≈ height*0.10，black.opacity(0.16)，offset y ≈ height*0.46）。资源缺失渲染空。

### 2. `CodingPastureTheaterView.swift`

- **舞台比例锁定**：`pastureStage` 去掉固定高度表 `pastureStageHeight`，改为：外层 `.aspectRatio(1.5, contentMode: .fit)`（基座图 3:2）+ `.frame(maxHeight: 440)` + 水平居中；内部 `GeometryReader` 读实际尺寸做定位；基座图 `.resizable().scaledToFit()` 与容器完全重合。渐变遮罩/描边/圆角保留。
- **agentSpot（舞台模式）重做**：去掉白底大卡片。结构：`Button` label = `VStack(spacing: 3)`：
  1. `ZStack(alignment: .bottomTrailing)`：`RanchCowSpriteView(colorName: companion.color, height: compact ? 74 : 96, flipped: index % 2 == 1)`（index 由调用处传入）+ 现有状态徽章圆片（seatSymbols/seatAccent，22pt）。
  2. 一枚紧凑胶囊：`Text("\(companion.name) · \(label(for: state))")` caption2 semibold，前景 `seatAccent`，背景 `Camp.surfaceRaised.opacity(0.90)`，Capsule + 细描边 `accent.opacity(0.4)` + 轻阴影。
  - 工作卡标题从舞台上移除（保留在 `.help` tooltip 与点击行为里）；`disabled`/`help` 逻辑不变。
  - **回退**：`RanchArtView.spriteImage(colorName:)` 为 nil 时，整个 spot 走现有白卡片实现（保留原实现为 `legacyAgentSpot`）。
- **站位表更新**（归一化坐标基于完整 3:2 基座图，避开左上牛棚与右中池塘，落在草地上）：
  - 1 只：(0.60, 0.62)
  - 2 只：(0.38, 0.66)、(0.68, 0.52)
  - 3 只：(0.30, 0.64)、(0.56, 0.72)、(0.74, 0.50)
  - ≥4 只槽位：(0.24, 0.60)、(0.44, 0.74)、(0.64, 0.68)、(0.80, 0.52)、(0.52, 0.44)、(0.34, 0.46)、(0.16, 0.42)、(0.86, 0.70)
  - 边距钳制改为 horizontalInset 56 / verticalInset 60。
- **densePasture**：头图同样改 fit（`RanchArtView(kind: .base, layout: .fit(maxWidth: nil))` + `.frame(maxHeight: 200)` 居中）；横滚卡片里 `CompanionAvatarView` 换 `RanchCowSpriteView(height: 56)`（同样 nil 回退原头像）。
- `emptyPastureHint`、`memoryTrough`、`loopStageRail`、`activeStage`、状态文案与映射全部不变。

### 3. 调用方

- `CowRosterView`：`RanchArtView(kind: .barn, layout: .fit(maxWidth: 760))`，外层 `.frame(maxWidth: .infinity)` 居中。
- `CodingRanchHomeView` 空闲分支：`RanchArtView(kind: .base, layout: .fit(maxWidth: 640))`，同样居中。

## 边界与错误路径

- sprite 或场景图缺失：sprite 缺→legacy 卡片回退；场景图缺→现有静默不渲染路径不变。
- `companion.color` 大小写/未知值：lowercased 匹配失败→回退，不崩溃。

## 测试与验证

- `swift build` 通过；`swift run RunTests` 保持基线全绿（你的受限沙箱中 keychain/bookmark 类失败按环境产物记录即可）。
- impl-report 附：`ls` 证明 11 个资源文件都进了构建产物 bundle。

## 完成定义

构建+测试达标；四处调用点全部 fit 无裁切；舞台在 sprite 可用时渲染具象小牛 + 紧凑胶囊，缺资源时回退旧卡片。

## Open questions

（无）
