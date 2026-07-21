# 像素世界整合实现报告

## 实现结果

已严格按 `plan.md` 完成五个允许文件内的实现，未提交代码。

### 1. campId 过滤修复

- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift`
  - `CowRosterHost.rosterState` 现在将 `campId == nil` 或空串的 regular 牛视为属于当前营地。
  - `kind == .regular` 条件保持不变。
- `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
  - `loadDashboard(campId:)` 使用相同的兼容过滤语义，保证首页 active cow 与牛棚名册一致。

### 2. 全景 Coding 草原

- `Sources/AgentLoopApp/Views/CodingRanch/RanchArtView.swift`
  - `RanchArtKind` 新增 `.panorama`，按明暗模式映射 `PixelPanoramaDay.png` / `PixelPanoramaNight.png`。
- `Sources/AgentLoopApp/Views/Components/CodingPastureTheaterView.swift`
  - 主舞台改为 `2.3333` 宽高比、`maxHeight: 520`，底图改用 `.panorama`，渐变遮罩强度减半。
  - 删除外置 `loopStageRail`；六个环节按计划锚点成为地图内木牌。激活木牌使用环节色与白字，并沿用遵守 paused 状态的 Timeline 弹跳；非激活木牌使用 `0.78` opacity 与 `0.92` scale；路标 zIndex 为 `5000`。
  - `activeStage` 计算逻辑未改动。
  - 牛群槽位改为计划指定的三只以内与四只以上两组常量；漫游半径改为 `0.06 * width`，原水平/垂直钳制 inset 保留。
  - `memoryTrough` 移至 `(0.87, 0.86)` 并保留 zIndex `10000`；空草原提示移至 `(0.5, 0.45)`。
  - dense 模式头图改用 `.panorama`，其余 dense 结构未改动。

### 3. 牛棚场景整合

- `Sources/AgentLoopApp/Views/CodingRanch/RanchArtView.swift`
  - `RanchBarnView` 新增可选 `lockedCow` 参数。
  - owned 少于四只且存在 locked cow 时，在最右侧空槽显示固定 amber 睡姿牛；不可解锁时灰度且 `opacity(0.5)`，可解锁时显示彩色牛和 16pt `sparkles` 徽章。
  - sprite 下方显示 `学习中` / `可以领回` 木牌；owned 已占满四个槽位或 sprite 缺失时不显示 locked cow，保留原缺失资源行为。
- `Sources/AgentLoopApp/Views/CodingRanch/CowRosterView.swift`
  - loaded 页面顺序调整为：页头 → 760pt 牛棚主场景 → 未解锁详情/CTA → owned 名册网格。
  - 牛棚传入首只 locked cow 与真实 `canUnlock` 状态。
  - 移除原底部牛棚位置和“牧场的一天，从牛棚开始。”收尾语。

## 文件范围

本任务修改的源文件仅为计划允许的五个：

1. `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift`
2. `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
3. `Sources/AgentLoopApp/Views/CodingRanch/RanchArtView.swift`
4. `Sources/AgentLoopApp/Views/Components/CodingPastureTheaterView.swift`
5. `Sources/AgentLoopApp/Views/CodingRanch/CowRosterView.swift`

另按协议生成 `verify.log` 与本报告。工作区中的像素资产、`CardRowView.swift`、`FeedView.swift`、`TaskRunView.swift`、`Theme.swift` 及其他任务目录改动均为本次开始前已有状态，本实现未触碰或回退它们。三个重叠的既有 UI 文件改动已原样保留并在其上完成计划增量。

## 构建与测试

- 五个源文件的 `git diff --check`：通过。
- 裸 `swift build`：在业务源码编译前失败；受限环境无法写默认 `/Users/muzi/.cache/clang/ModuleCache`，并报当前 CLT compiler 与 SDK module build 补丁版本不匹配。
- 沙箱兼容构建：
  - 命令：`CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-pixel-world-clang-cache SWIFTPM_CUSTOM_CACHE_PATH=/private/tmp/agentloop-pixel-world-swiftpm-cache swift build --disable-sandbox`
  - 结果：通过；五个相关源文件均完成编译，`AgentLoopApp` 完成链接。
- 按要求执行裸 `swift run RunTests`，其完整输出已写入 `verify.log`；该命令同样在 manifest 编译前被默认 module cache 权限拦截。
- 随后在同一 `verify.log` 追加沙箱兼容的权威复跑：
  - 命令：`CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-pixel-world-clang-cache SWIFTPM_CUSTOM_CACHE_PATH=/private/tmp/agentloop-pixel-world-swiftpm-cache swift run --disable-sandbox RunTests --no-parallel`
  - 结果：423 tests / 5 suites，419 通过、4 个受限环境问题：
    - `workspaceBookmarkCaptureAndResolveRoundtrip`：security-scoped bookmark 未能生成。
    - `keychainRoundTrip`：Keychain 返回 `-50`。
    - `haltDuringRunningCardLeavesReadyCardAndNoOpenRun`：card 状态断言未到 `.ready`。
    - `haltPersistenceFailureStillStopsAndCanRetryPersistence`：card 状态断言未到 `.ready`。
  - 四项均位于本任务未触及的 Core/测试路径；本任务涉及的 App 源码已由全目标构建验证。完整证据见 `verify.log`。

## 与计划的偏离

实现内容无偏离。正常环境下的测试全绿未能在当前受限沙箱内证明；实际环境结果已完整保留并如实列出，没有修改 Core、测试或增加兜底来隐藏失败。
