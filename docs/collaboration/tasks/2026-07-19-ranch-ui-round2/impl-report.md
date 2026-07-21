# 牧场 UI 第二轮实现报告

## 改动文件

本轮只修改计划允许的三个源码文件：

- `Sources/AgentLoopApp/Views/TaskRunView.swift`
- `Sources/AgentLoopApp/Views/Components/CodingPastureTheaterView.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/CowRosterView.swift`

另按任务要求生成验证产物 `verify.log` 和本报告。工作树中 `CardRowView.swift`、`FeedView.swift`、`Theme.swift` 及 `2026-07-19-ranch-ui-uplift/` 的改动在本轮开始前已经存在，本轮未触碰。

## 计划逐项映射

### A. 草原可滚动

- `theaterMode` 分支改为纵向 `ScrollView`，内部以 `VStack(spacing: 14)` 包含 `CodingPastureTheaterView` 和 `artifactsView`。
- 内层栈保持 `maxWidth: .infinity`，舞台继续水平居中并跟随可用窗口宽度。
- 工作卡分支仍由 `cardList` 自身滚动，`artifactsView` 保持在其外部。

### B. 路径行进系统

- 用基于现有 `fnv1a` 的确定性四草点椭圆环线替换 Lissajous 漂移；角度、半径、停留和相位均由种子位段生成，草点沿用水平 56 / 垂直 60 inset 钳制。
- 每段按 `9pt/s * speedJitter` 计算步行时长，段后停留 `4...10s`；周期位置由 `t + phaseOffset` 的余数纯函数计算。
- 走段使用 smoothstep 插值；停段固定在下一草点。
- 朝向由当前行进段的水平分量决定，近垂直段沿用上一段方向；停留保持刚完成段朝向；翻转动画为 0.3 秒。
- 走段使用只向上弹的 `-2 * abs(sin(t * 7 * speedJitter))` 步态。
- `idle / thinking / celebrating` 行进；`asking / scratching` 在 slot 轻微横晃；`working` 在 slot 点头；`napping` 完全静止。
- 每只牛按路径上的实际 y 坐标设置 `zIndex`，料槽固定为 `10_000`；名牌随牛整体移动。
- `TimelineView`、paused 契约、空草原提示和 dense 模式未改。

### C. 牛棚布局重排

- loaded 内容顺序改为：解锁区（若有）→ 解锁失败面板（若有）→ 已在营地名册 → 底部牛棚收尾；页头仍位于滚动内容之前。
- 解锁失败面板仍紧跟解锁区。
- 底部新增居中 caption `牧场的一天，从牛棚开始。`，牛棚图改为 `.fit(maxWidth: 560)` 并居中。
- 卡片、进度路径和错误面板样式未改。

## 构建与验证

- `git diff --check`：通过。
- 裸 `swift build`：在项目编译前失败；受限环境不能写 `~/.cache/clang/ModuleCache`，同时输出当前 CLT 编译器/SDK 模块版本不匹配的连带错误。
- 使用仓库既有沙箱跑法：
  - `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-ranch-ui-round2-clang-cache SWIFTPM_CUSTOM_CACHE_PATH=/private/tmp/agentloop-ranch-ui-round2-swiftpm-cache swift build --disable-sandbox`
  - 结果：通过；最终 `Build complete! (4.50s)`，三个 UI 文件均实际编译，`AgentLoopApp` 完成链接。
- 按要求执行裸 `swift run RunTests` 并将完整输出写入 `verify.log`；该命令同样在项目编译前被模块缓存权限阻断。
- 使用仓库既有沙箱跑法执行完整测试：
  - 并行运行成功编译测试目标，但在测试启动后不再前进，保留日志后中止。
  - 串行运行命令：`CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-ranch-ui-round2-clang-cache SWIFTPM_CUSTOM_CACHE_PATH=/private/tmp/agentloop-ranch-ui-round2-swiftpm-cache swift run --disable-sandbox RunTests --no-parallel`。
  - 最终运行完成 423 项 / 5 suites，418 项通过、5 项失败，退出码 1：
    1. `workspaceBookmarkCaptureAndResolveRoundtrip`：受限环境未生成 security-scoped bookmark。
    2. `haltDuringRunningCardLeavesReadyCardAndNoOpenRun`：未触及的 halt/cancellation 时序断言失败。
    3. `emergencyStopCancelsRunningBeforeWaitingForPlanner`：未触及的 halt/cancellation 时序断言失败。
    4. `haltPersistenceFailureStillStopsAndCanRetryPersistence`：同一实现下前一轮通过、最终轮失败，属于受限环境中的时序波动。
    5. `keychainRoundTrip`：受限环境返回 `KeychainError(status: -50)`。

完整原始输出见 `verify.log`。其中 bookmark、前两项 halt/cancellation 和 Keychain 与仓库上一轮 Ranch UI 任务记录的四项受限环境失败一致；本轮未修改相关 Core 或测试文件。由于这些环境性失败，计划要求的“基线全绿”未在当前沙箱内达成。

## 偏离计划

- 实现内容无偏离。
- 验证结果未达到全绿；未通过修改 Core/测试或吞掉错误来掩盖受限环境失败。
- 未提交代码。
