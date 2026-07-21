# UI 优化轮实现报告

## 改动文件

- `Sources/AgentLoopApp/Views/Theme.swift`
- `Sources/AgentLoopApp/Views/TaskRunView.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/MissionDraftConfirmationView.swift`
- `Sources/AgentLoopApp/Views/Components/CardDetailInspector.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/CowRosterView.swift`
- `Sources/AgentLoopApp/Views/Components/CodingPastureTheaterView.swift`
- `Sources/AgentLoopApp/Views/SettingsView.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/ReturnSummaryView.swift`
- `Sources/AgentLoopApp/Views/TrophyCenterView.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/FeedComposerView.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchCommonViews.swift`
- `Sources/AgentLoopApp/Views/ScheduleManagerView.swift`
- `Sources/AgentLoopApp/Views/CampHomeView.swift`
- `docs/collaboration/tasks/2026-07-20-ui-polish-round/verify.log`
- `docs/collaboration/tasks/2026-07-20-ui-polish-round/impl-report.md`

未修改 Core、AppStore 或测试逻辑；未提交。

## 逐项映射

### A. 设计语言统一

- **A1**：Settings、新任务表单、任务草稿确认、待反刍、营地笔记和回营成果标题统一为 `title2.weight(.bold)`。
- **A2**：ReturnSummary 的成果/验证/知识、MissionDraftConfirmation 的四张主卡、Rumination 结果卡、Settings 的一级分区、CampHome 的驿站/往期任务均改为 `RanchSectionHeader`；卡内次级 `API Key` 小标题保留 `CampSectionTitle`。
- **A3**：需求分区改 creek；任务草稿知识条目图标和牛棚角色 chip 改 stone；牛专长改为 hay 底的 `CampTag`。
- **A4**：规划状态改标准 `CampChip`；新增动态 `Camp.lavender` 并用于 handoff；FeedComposer、Rumination 外层内容与 MissionDraftConfirmation gutter 统一为 20。

### B. 交互安全

- **B1**：两个开工主按钮改为 `Command-Return`，旁边增加 `⌘↩ 开始` 提示，多行输入不再被裸回车提交。
- **B2**：CardDetailInspector 通过 Binding 暴露退回意见脏状态；背景、Esc 和关闭按钮统一走关闭请求，首次提示 `意见还没提交，再点一次关闭`，两秒内第二次才关闭；提交成功先清理草稿状态后关闭。
- **B3**：两个 Camp 按钮样式读取 `isEnabled`，禁用态统一 0.45 且无阴影；本轮授权文件中的手动禁用透明度均已移除。
- **B4**：收哨和小队动态间距改为 20；收哨增加指定警告文案的 destructive `confirmationDialog`，恢复不增加确认。
- **B5**：验收清单改为本地 `AcceptanceItem: Identifiable` 状态，编辑/删除按稳定 UUID，提交前映射回 `[String]`。
- **B6**：开工禁用时在按钮上方显示 `startBlockReason` 或按目标、工作目录、验收条件生成的缺失提示。
- **B7**：解锁条件展开行改为整行 Button，chevron 随状态旋转，并提供动态展开/收起 accessibility label。

### C. 显示严谨

- **C1**：新增 `CampFormat.tokens(_:)`，千位以上保留一位小数；TaskRun 三处改用 helper，CardDetailInspector 完整 token 数改用系统千位分组。
- **C2**：草原名牌限制最大宽度 132，单行尾部截断并通过 help 提供全名与状态。
- **C3**：日程时间戳改用本地化 `Date.FormatStyle` 的 numeric date + shortened time。
- **C4**：花销签增加尾部 chevron、帮助文本和 hover 加深描边，数值同时接入统一格式化。

### D. 反馈完整

- **D1**：领回成功后显示 `🐮 <牛名> 领回营地了` toast，并用 0.5 秒 spring 动画提交成功后的名册/场景刷新状态。
- **D2**：CampCopy 改为“工作卡详情”；源码范围 grep 已无“小目标面板”残留（任务 plan 自身仍保留该验收字样）。

## 验证

- `git diff --check`：通过。
- 裸 `swift build`：在项目源码编译前被受限环境阻断；默认 Clang module cache 不可写，并伴随当前 CLT compiler / SDK patch 版本不匹配。
- 沙箱兼容构建：`CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-ui-polish-clang-cache SWIFTPM_CUSTOM_CACHE_PATH=/private/tmp/agentloop-ui-polish-swiftpm-cache swift build --disable-sandbox` 通过，`Build complete!`，所有本轮 UI 文件实际编译并完成 App 链接。
- 按要求执行了裸 `swift run RunTests`，完整失败输出与后续兼容复跑都保存在 `verify.log`。裸命令同样在 manifest 编译前被默认 module cache 权限阻断。
- 沙箱兼容权威复跑：同一缓存环境下 `swift run --disable-sandbox RunTests --no-parallel` 共 423 tests / 5 suites，419 通过、4 个已知受限串行沙箱基线失败，退出码 1：
  - `workspaceBookmarkCaptureAndResolveRoundtrip`（security-scoped bookmark 不可用）
  - `keychainRoundTrip`（Keychain status -50）
  - `haltDuringRunningCardLeavesReadyCardAndNoOpenRun`
  - `emergencyStopCancelsRunningBeforeWaitingForPlanner`
- 上述四项与上一轮牧场 UI 任务记录的受限沙箱基线一致，均位于本轮未触及的 Core/测试路径。

## 范围约束与偏离

- B3 要求“全仓调用处清理”，但允许文件清单未包含 `CompanionEditorView.swift`、`DMChatView.swift`、`RootView.swift`、`CodingRanchHomeView.swift`；这四个文件仍各有一处手动禁用透明度。本轮遵守“只触碰允许文件”的更严格约束，没有越权修改。授权文件内已全部清理。
- 除受限环境验证结果和上述允许文件冲突外，实现没有偏离计划。
