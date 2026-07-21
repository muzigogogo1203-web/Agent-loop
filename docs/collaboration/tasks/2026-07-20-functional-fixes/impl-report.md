# Implementation Report — 2026-07-20 Functional Fixes

## 结果

已按 `plan.md` 完成修复项 1–11。未修改 AgentLoopCore、数据库结构、迁移或测试文件；未提交。

## 逐项映射

1. **反刍失败反馈**
   - `AppStore` 新增可观察的 `ruminationActionError`。
   - `startRumination` 不再静默吞掉 item/provider guard：材料缺失显示“这条材料不存在了，刷新看看”，provider 缺失显示“请先在设置里配置模型供给线”；启动失败和后台处理失败也进入同一可见错误通道。
   - `RuminationInboxView` 和 `RuminationDetailHost` 均显示可关闭的红色状态面板。
   - failed item 的 `retryable` 改为由原文是否仍可重试决定，不再写死；provider 缺失不改变 retryable，点击后会显示配置反馈。

2. **反刍详情页状态跃迁**
   - `RuminationDetailHost` 监听 `inboxItem?.status` 并重新 `load()`。
   - `ruminating → needsReview` 自动载入检查页；failed 有原文和重试操作；materialized 才显示“已经处理”；discarded 有独立状态。

3. **“待你处理”真实过滤**
   - dashboard 的 `pendingItems` 仅保留 queued、ruminating、needsReview、failed，再取前 4 条；materialized/discarded 不再混入。

4. **新任务按营地选牛**
   - 新任务表单、空态、单牛新手判断和默认基础牛选择统一使用当前营地或无 campId 的 companion。
   - helper 在没有 campId 上下文时仍返回原完整列表。

5. **反刍四阶段实时推进**
   - 阶段回调在更新 `ruminationStages` 的同时原地重建 `codingRanchInbox` 对应条目的 `.ruminating(stage:)`，详情进度可响应 reading/extracting/organizing。

6. **dashboard / inbox 失败态**
   - `loadDashboard` 的 camp 缺失和查询错误都写入 `.failed(message)`，不再由 `try?` 伪装为空数据。
   - `loadRuminationInbox` 同样把查询异常写入 inbox `.failed`，使现有失败分支可见。

7. **老任务详情回退**
   - `currentMission` 先查 `missionList`，再跨 `missionsByCamp` 查相同 id。
   - `missionGoalLine` 和 `budgetLine` 统一基于该回退结果；都找不到时保留原兜底文案。

8. **Feed 未读增量**
   - `entries.count` 变化时使用 `max(0, newCount - oldCount)`，不再把任意一次数组变化固定算作 1 条新动态。

9. **空回调接通**
   - “查看原文”会异步读取 `IngestionItem.rawText` 并展示 `RuminationSourceSheet`；读取失败时展示标题/摘要并明确注明不是完整原文。
   - `ReturnSummaryView` 新增默认 `onOpenRoster`，由 `RootView` 传入当前任务营地的 `.cowRoster` 导航。

10. **新版牧场首页挂载**
    - `RootView` 的 `.camp` 已切换为 `CodingRanchHomeHost`；旧 `CampHomeView` 保留，并继续承载 `.campGuide` 辅助页。
    - 新首页头部补充“管家与工具”“笔记”“牛棚”“驿站设置”，分别接到旧辅助页、营地笔记、牛棚和设置。

    | 能力 | 旧 `CampHomeView` | 新首页挂载后 |
    |---|---|---|
    | 喂牛 | 头部按钮打开 composer | 首页 feed hero 直接输入并打开 composer |
    | 待你处理 / 反刍 | 头部计数 + sheet | dashboard 待办区 + 独立 inbox/detail 路由 |
    | 发起放牛 | 头部主按钮 | Coding 草原区按钮，进入同一营地的新任务表单 |
    | 牛棚 | 依赖侧栏/其他入口 | 首页头部“牛棚”直达 `.cowRoster` |
    | 营地笔记 | 左侧内嵌笔记本 | 最近笔记可打开，且头部“笔记”在空状态下也可直达 `.campNotes` |
    | 管家聊天 / 沉淀 | 首页右侧常驻 | 头部“管家与工具”进入保留的 `.campGuide`，继续使用旧管家聊天与沉淀能力 |
    | 营地 MCP 驿站 | 左栏按营地启用 | “管家与工具”进入原营地驿站开关；“驿站设置”直达全局 MCP 设置 |
    | 日程、往期任务、营地改名 | 旧页内直接操作 | 通过头部“管家与工具”进入保留的旧辅助页继续操作 |

    结论：计划列明的首页核心入口均已覆盖；旧首页独有能力仍有明确入口，不需要 `blocked.md`。

11. **禁用态透明度清理**
    - 删除 `CompanionEditorView.swift`、`DMChatView.swift`、`RootView.swift`、`CodingRanchHomeView.swift` 各一处按钮手动 `.opacity(0.5)`，只保留按钮样式的统一禁用透明度。

## 修改文件

- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/ReturnSummaryView.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchHomeView.swift`
- `Sources/AgentLoopApp/Views/TaskRunView.swift`
- `Sources/AgentLoopApp/Views/Components/FeedView.swift`
- `Sources/AgentLoopApp/Views/RootView.swift`
- `Sources/AgentLoopApp/Views/CompanionEditorView.swift`
- `Sources/AgentLoopApp/Views/DMChatView.swift`
- `docs/collaboration/tasks/2026-07-20-functional-fixes/verify.log`
- `docs/collaboration/tasks/2026-07-20-functional-fixes/impl-report.md`

## 验证

- `git diff --check`：通过。
- 裸 `swift build`：在 manifest 编译前被当前受限环境的 `~/.cache/clang` 写权限与 CLT/SDK module 版本检查阻断，未进入项目源码编译。
- 沙箱兼容构建：
  - `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-functional-fixes-clang-cache SWIFTPM_CUSTOM_CACHE_PATH=/private/tmp/agentloop-functional-fixes-swiftpm-cache swift build --disable-sandbox`
  - 通过；`AgentLoopApp` 完成编译和链接。最终增量复核同样通过。
- 按要求执行裸 `swift run RunTests`，完整输出已写入 `verify.log`；它同样在 manifest 阶段被默认 module cache 权限阻断。
- 随后使用仓库既有的受限环境跑法完整串行复跑三次：
  - `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-functional-fixes-clang-cache SWIFTPM_CUSTOM_CACHE_PATH=/private/tmp/agentloop-functional-fixes-swiftpm-cache swift run --disable-sandbox RunTests --no-parallel`
  - 最终结果：423 tests / 5 suites，419 通过、4 个受限环境/既有时序问题。
  - 最终 4 项为 security-scoped bookmark 无法生成、Keychain `-50`，以及未触碰 Core 的两项 halt 状态时序断言。相邻任务的同环境基线也是 4 项；halt 组具体用例在本轮复跑间会互换，确认属于该 runner 的既有时序波动。
  - 初次兼容复跑曾多出同组 1 项 halt 时序失败；后续两次均恢复到基线 4 项。所有输出均保留在 `verify.log`。

## 偏离计划

无功能范围偏离。唯一差异是裸 SwiftPM 命令受当前执行沙箱阻断，因此在保存其完整失败输出后，按仓库既有方式重定向缓存并关闭 SwiftPM sandbox 完成真实构建和测试复跑。
