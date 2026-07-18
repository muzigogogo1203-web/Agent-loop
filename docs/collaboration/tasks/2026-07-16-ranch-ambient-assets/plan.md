# 牧场氛围资产进 App（首批静态插画）

Level 2。设计依据：`docs/superpowers/specs/2026-07-15-coding-ranch-visual-design.md` §5「氛围资产先行」。

## 目标

把 4 张黏土风静态插画接入 App 两个位置，并建立主题感知的资产加载底座：

1. 牛棚名册页（`CowRosterView`）顶部横幅：亮色主题显示白天牛棚，暗色主题显示夜晚牛棚。
2. 牧场主页（`CodingRanchHomeView`）「Coding 草原」区的空闲分支：显示空基座插画（亮=日/暗=夜）。

## 非目标（防 scope creep）

- 不改 `CampfireTheaterView`/`CompanionAvatarView` 的自绘体系。
- 不引入动画/视频/Rive 资产，不加设置项，不碰数据层与任何 Core 逻辑。
- 不做图片缓存策略以外的性能工程（一个进程级静态缓存即可）。

## 资产（已就位，勿重新生成）

`Sources/AgentLoopApp/Resources/RanchArt/` 下 4 个 JPEG（约 2000px 宽，已存在于工作区）：
`RanchBarnDay.jpg`、`RanchBarnNight.jpg`、`RanchBaseDay.jpg`、`RanchBaseNight.jpg`。

## 触及文件与改动意图

1. **Package.swift**：`AgentLoopApp` target 增加 `resources: [.copy("Resources/RanchArt")]`。用 `.copy` 保留子目录结构；SwiftPM 会为该 target 生成 `Bundle.module`。
2. **新文件 `Sources/AgentLoopApp/Views/CodingRanch/RanchArtView.swift`**：
   - `enum RanchArtKind { case barn, base }`。
   - `struct RanchArtView: View`：`@Environment(\.colorScheme)` 决定 Day/Night 变体；资源名 = `"Ranch" + (barn ? "Barn" : "Base") + (dark ? "Night" : "Day")`。
   - 加载：`Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "RanchArt")` → `NSImage(contentsOf:)`；用一个 `@MainActor` 的静态 `[String: NSImage]` 缓存避免重复解码（App 层 UI 代码全部 MainActor，遵循现有模式即可）。
   - 渲染：`Image(nsImage:).resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: height).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))`，`height` 由调用方传入。
   - 装饰性图片：`.accessibilityHidden(true)`。
   - **资源缺失时返回 `EmptyView` 等价物（不崩溃、不占位）**——用 `if let` 包住整个渲染。
3. **`CowRosterView.swift`**：ScrollView 内容 `VStack`（现第 55 行）首位插入 `RanchArtView(kind: .barn, height: 150)`。随内容滚动，不改变现有 header/列表结构。
4. **`CodingRanchHomeView.swift`**：`missionSection` 的空闲分支（现约 249 行「基础牛现在空闲…」文案处）在文案上方插入 `RanchArtView(kind: .base, height: 170)`。仅空闲分支显示；有进行中行动时不显示。

## 数据模型/契约变化

无。纯 App 层视图 + 打包资源。

## 边界与错误路径

- 资源文件缺失/解码失败：静默不渲染（`if let`），页面其余部分正常。
- 亮暗切换：`colorScheme` 环境值驱动，SwiftUI 自动重渲染，无需通知机制。
- 缓存只增不减（4 张小图，进程级，可接受）。

## 测试要求

- 现有测试全绿即可；本改动为纯视图+资源，不强制新增单测（`AgentLoopTestSuite` 不依赖 App target，无法断言 `Bundle.module` 资源）。
- 若实现中发现 `Bundle.module` 在 `AgentLoopApp` target 不可用（无 resources 声明历史），以编译错误为准修正 Package.swift 写法。

## 验证命令

1. `swift build 2>&1 | tail -5`——全 target 构建通过（含资源打包）。
2. `swift run RunTests`——现有套件全绿（当前基线 409/409），完整输出存 `verify.log`。

## 完成定义

构建通过 + RunTests 全绿 + 上述两个视图的代码路径按亮/暗主题选择 Day/Night 资产 + 资源缺失路径不崩溃。impl-report.md 列出改动文件与偏离项。

## Open questions

（无）
