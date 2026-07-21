# 像素世界第二轮实施报告

## 改动文件

仅修改计划允许的三个实现文件：

1. `Sources/AgentLoopApp/Views/Components/CodingPastureTheaterView.swift`
   - 删除六块沿路小木牌及其锚点。
   - 在地图顶部 12pt、水平居中位置加入单一进度横匾，宽度为 `min(stageW * 0.72, 640)`，包含完整/紧凑两套 `ViewThatFits` 内容。
   - 保留 `activeStage` 判定并迁移原有 TimelineView 弹跳；暂停或 Reduce Motion 时不弹跳。
   - 将两个顶部牛群槽位从 `0.28/0.24` 下压至 `0.34/0.32`；漫游、dense、遮罩与 memory trough 逻辑未改。
2. `Sources/AgentLoopApp/Views/CodingRanch/RanchArtView.swift`
   - `RanchBarnView` 的牛数据增加 `name`，新增可选 `onSelectCow` 回调。
   - 每个有牛隔间加入统一名字木牌；有回调时整个 sprite + 木牌区域可点击并提供档案 help。
   - hover 时 sprite 放大至 `1.04`；Reduce Motion 下不缩放，仅更新阴影。
   - 保留最右锁定槽的灰阶/彩色、sparkles、学习中/可以领回木牌及 `+N 只在外放牧` chip；锁定槽不可点击。
3. `Sources/AgentLoopApp/Views/CodingRanch/CowRosterView.swift`
   - 保留页头，将牛棚场景升级为唯一主视觉并接通 `onOpenCow`。
   - 将解锁区重排为默认折叠的 campCard 进度行；可领回时强制展开并保留原有 action state、领回操作、失败面板和无障碍公告。
   - 展开内容复用爪印进度路径、能力 CampTag 与 learning goal。
   - 将 LazyVGrid/CowRosterCard 替换为 FlowLayoutLite 迷你名册胶囊；删除 `CowRosterCard`，本页不再展示 specialties/recentMission。

按协议另生成 `verify.log` 与本报告。任务开始前工作区已存在的像素资产、其他 Swift 文件和其他任务目录改动均未触碰或回退。

## 构建与测试

- 三个实现文件的 `git diff --check`：通过。
- 裸 `swift build`：在业务源码编译前失败；受限环境不能写默认 `/Users/muzi/.cache/clang/ModuleCache`，并伴随当前 CLT compiler / SDK module build 补丁版本不匹配。
- 沙箱兼容构建：
  - 命令：`CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-pixel-world-round2-clang-cache SWIFTPM_CUSTOM_CACHE_PATH=/private/tmp/agentloop-pixel-world-round2-swiftpm-cache swift build --disable-sandbox`
  - 结果：通过；三个目标文件均实际编译，`AgentLoopApp` 完成链接。最终增量复跑同样通过（`Build complete!`）。
- 按要求执行裸 `swift run RunTests`，完整输出写入 `verify.log`；该命令同样在 manifest 编译前被默认 module cache 权限拦截。
- 随后在同一 `verify.log` 追加两次沙箱兼容的权威串行复跑：
  - 命令：`CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-pixel-world-round2-clang-cache SWIFTPM_CUSTOM_CACHE_PATH=/private/tmp/agentloop-pixel-world-round2-swiftpm-cache swift run --disable-sandbox RunTests --no-parallel`
  - 首轮：423 tests / 5 suites，419 通过、4 个问题。
  - 最终轮：423 tests / 5 suites，418 通过、5 个问题。
  - 两轮问题的并集均为当前受限沙箱已记录的基线类型：
    - `workspaceBookmarkCaptureAndResolveRoundtrip`：security-scoped bookmark 未能生成。
    - `keychainRoundTrip`：Keychain 返回 `-50`。
    - `haltDuringRunningCardLeavesReadyCardAndNoOpenRun`：串行 runner 下 card 状态未到 `.ready`。
    - `emergencyStopCancelsRunningBeforeWaitingForPlanner`：串行 runner 下 card 状态未到 `.ready`；仅最终轮出现。
    - `haltPersistenceFailureStillStopsAndCanRetryPersistence`：串行 runner 下 card 状态未到 `.ready`。
  - 上述失败均位于本任务未触及的 Core/测试路径；相同 bookmark、Keychain 与 halt 串行断言已在相邻牧场任务中记录。本任务没有修改 Core、测试或增加兜底来隐藏失败。完整证据见 `verify.log`。

## 与计划的偏离

实现内容无偏离。正常环境下的全绿结果无法在当前受限沙箱内证明；环境门槛与实际测试结果已如实记录。
