# 实现报告：像素风资产接入 + 数据驱动牛棚

## 改动文件

本任务的源码增量仅涉及计划允许的三个文件：

- `Sources/AgentLoopApp/Views/CodingRanch/RanchArtView.swift`
- `Sources/AgentLoopApp/Views/Components/CodingPastureTheaterView.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/CowRosterView.swift`

协作协议产物：

- `docs/collaboration/tasks/2026-07-20-pixel-ranch-app/verify.log`
- `docs/collaboration/tasks/2026-07-20-pixel-ranch-app/impl-report.md`

工作区在实现前已有牧场 UI 改动、旧资产删除和新像素资产；本任务保留了这些现有改动，没有回退或改写计划外文件。

## 计划逐项映射

### 1. RanchArtView.swift

- 场景资源切换为 `PixelBarn{Day|Night}.png` 和 `PixelPasture{Day|Night}.png`，`.base` 对应 `Pasture`。
- 场景、侧面牛 sprite 和睡姿牛 sprite 的 `Image` 均使用 `.interpolation(.none)`。
- `spriteImage(colorName:)` 映射到 `PixelCowSide<Color>.png`；新增 `sleepSpriteImage(colorName:)` 映射到 `PixelCowSleep<Color>.png`，两者复用现有 bundle 和 image cache。
- `RanchCowSpriteView` 更新为“`false` 原生朝左 / `true` 镜像朝右”语义，并将接地阴影宽度调整为 `height * 0.70`。
- 新增 `RanchBarnView`：日夜空棚底图、4 个集中定义的归一化槽位、前 4 只真实名册睡姿牛、超出 4 只的右下角放牧提示。空名册仅显示空棚，未知颜色会跳过对应槽位。

### 2. CodingPastureTheaterView.swift

- 舞台保留原有布局和渐变遮罩，`.base` 自动读取像素草场。
- 闲逛行进段改为 `dx > 0` 时 `flipped = true`、向左时 `false`；水平位移不足 1pt 时回溯上一个有明确方向的段。停留段继续使用刚结束的行进段朝向。
- `working` / `asking` / `scratching` / `napping` 统一 `flipped = true`，朝右面向内容。
- dense 卡片继续通过 `RanchCowSpriteView` 自动使用新资产。

### 3. CowRosterView.swift

- 底部横幅替换为 `RanchBarnView(cows: state.owned.map { ($0.id, $0.colorName) }, maxWidth: 560)`。
- “牧场的一天，从牛棚开始。”收尾文案与页头 teal sprite 保留。

## 资源 bundle 核验

`ls -1 .build/arm64-apple-macosx/debug/AgentLoop_AgentLoopApp.bundle/RanchArt`：

```text
PixelBarnDay.png
PixelBarnNight.png
PixelCowSideAmber.png
PixelCowSideBlue.png
PixelCowSideCoral.png
PixelCowSideGreen.png
PixelCowSidePink.png
PixelCowSidePurple.png
PixelCowSideTeal.png
PixelCowSleepAmber.png
PixelCowSleepBlue.png
PixelCowSleepCoral.png
PixelCowSleepGreen.png
PixelCowSleepPink.png
PixelCowSleepPurple.png
PixelCowSleepTeal.png
PixelPastureDay.png
PixelPastureNight.png
```

## 构建与测试

- `git diff --check`：通过。
- 裸 `swift build`：在 manifest 编译前被受限环境拦截，原因是默认 Clang module cache 不可写，并伴随当前 CLT compiler / SDK module build 版本不匹配报错。
- 使用仓库既有的受限环境跑法 `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-pixel-ranch-clang-cache SWIFTPM_CUSTOM_CACHE_PATH=/private/tmp/agentloop-pixel-ranch-swiftpm-cache swift build --disable-sandbox`：通过，全目标完成编译，`AgentLoopApp` 完成链接。
- 按要求执行裸 `swift run RunTests`，完整输出写入 `verify.log`；该命令同样在 manifest 编译前被默认 module cache 权限拦截。
- 随后在同一 `verify.log` 追加沙箱兼容的权威复跑：`CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-pixel-ranch-clang-cache SWIFTPM_CUSTOM_CACHE_PATH=/private/tmp/agentloop-pixel-ranch-swiftpm-cache swift run --disable-sandbox RunTests --no-parallel`。结果为 423 tests / 5 suites，419 通过、4 个已知受限沙箱基线问题：
  - `workspaceBookmarkCaptureAndResolveRoundtrip`：security-scoped bookmark 不可用。
  - `keychainRoundTrip`：Keychain `-50`。
  - `haltDuringRunningCardLeavesReadyCardAndNoOpenRun`：已记录的串行 runner 环境断言。
  - `emergencyStopCancelsRunningBeforeWaitingForPlanner`：已记录的串行 runner 环境断言。
- 上述 4 项与 `2026-07-19-ranch-ui-uplift` 的受限沙箱基线逐项一致，均位于本任务未触及的 Core / 测试路径；本轮没有新增失败。

## 与计划的偏离

实现内容无偏离。正常环境下的测试全绿未能在本受限沙箱内证明；实际结果为与前一牧场任务完全相同的 4 项环境基线失败，已如实记录，未修改 Core 或测试来掩盖问题。
