# 功能修复轮：反刍链路反馈 + 数据一致性 + 死路由/空回调

Level 2/3（涉及 AppStore/Adapter 逻辑）。依据 2026-07-20 UI 审计的 state-rigor/experience 视角发现，用户已授权直接修复。

## 允许触碰的文件

`CodingRanchStoreAdapter.swift`、`AppStore.swift`（仅列明处）、`Views/CodingRanch/CodingRanchLiveHosts.swift`、`Views/CodingRanch/RuminationViews.swift`、`Views/CodingRanch/ReturnSummaryView.swift`、`Views/TaskRunView.swift`、`Views/Components/FeedView.swift`、`Views/RootView.swift`、`Views/CodingRanch/CodingRanchHomeView.swift`（如挂载需要）。**禁止改 Core（AgentLoopCore）与数据库层。**

## 修复项

1. **反刍失败静默（高）**：`CodingRanchStoreAdapter.startRumination/retryRumination`（约 :69）的 guard 静默 return 改为把失败原因暴露给 UI：Adapter 增加可观察的 `ruminationActionError: String?`（或经 AppStore 转发），guard 失败时设置人话文案（拿不到 provider →「请先在设置里配置模型供给线」；item 缺失 →「这条材料不存在了，刷新看看」）。`RuminationInboxView` 与详情页在该字段非空时用 campToast 或 `campStatusPanel(Camp.charcoalRed)` 显示并可清除。`retryable` 不再硬编码 true（:358）：provider 缺失时仍为 true（配好就能重试）但按钮点击必须有上述反馈。
2. **反刍详情页死胡同（高）**：`RuminationDetailHost`（CodingRanchLiveHosts:107）对 `inboxItem?.status` 加 `onChange` 重新 `load()`：ruminating→needsReview 时自动加载 review 进入检查页；→failed 时显示失败态（含 retry 按钮，走修复项 1 的反馈）；→materialized 才显示「已处理」。
3. **「待你处理」假待办**：`dashboard.pendingItems`（Adapter:29）过滤只保留 `[.queued, .ruminating, .needsReview, .failed]` 状态再 prefix(4)，与头部计数同源。
4. **跨营地选牛**：TaskRunView 新任务表单（:187）与 `newcomerSingleCow`（:1076）的 companion 列表按 `($0.campId == campId || ($0.campId ?? "").isEmpty)` 过滤（campId 从表单上下文取；无 campId 上下文时维持现状）。
5. **反刍四阶段进度不动**：阶段回调（Adapter:63）更新 `ruminationStages` 后同步重建/更新对应 inbox 条目的 `.ruminating(stage:)`（最小实现：在回调里对 `codingRanchInbox` 中该 id 的条目做原地替换），使 RuminationProgressView 实时推进。
6. **dashboard 无失败态**：`loadDashboard`（Adapter:12）`guard let camp` 失败与查询抛错时设置 `loadState = .failed("...")`（把 `try?` 改为 do/catch 至少捕获一次性错误消息）；CowRosterView/RuminationInboxView 的 .failed 分支即可生效。
7. **老任务详情退化**：TaskRunView 的 `missionGoalLine`/`currentMission`/`budgetLine`（:573/:784/:1067）查不到时兜底从 `store.missionsByCamp` 各营地列表里找同 id 任务；仍找不到再用现有兜底文案。
8. **未读计数错误**：FeedView:74 `unseenCount += 1` 改为 `unseenCount += max(0, newCount - oldCount)`（onChange 提供新旧值）。
9. **空回调**：
   - CodingRanchLiveHosts:97 `onViewSource: {}` 接通：sheet 展示原文（RuminationReview/IngestionItem 的原文字段；若视图层拿不到原文数据则显示该条目的 title+摘要并注明），最小实现可弹 `RuminationSourceSheet`（简单 ScrollView + Text）。
   - ReturnSummaryView:119 `onOpenRoster: {}` 接导航：ReturnSummaryView 增加 `var onOpenRoster: () -> Void = {}` 参数并由挂载处（RootView 或宿主）传入切换到牛棚 Destination 的闭包。
10. **挂载新版牧场首页（产品级）**：RootView:167 `.camp` 路由从旧 `CampHomeView` 切到 `CodingRanchHomeHost`（CodingRanchHomeView）。前置核查：新首页必须已覆盖 喂牛入口、待你处理、发起放牛、进入牛棚/笔记 的入口；旧 CampHomeView 中独有且新页缺失的能力（如管家聊天、MCP 设置入口）若存在，把入口以按钮/链接形式补进新首页头部或直接在 blocked.md 列明缺口并停在本项（其余 1-9 项照常完成）。旧 CampHomeView 文件保留不删。

## 验证

- `swift build` + `swift run RunTests` 基线全绿（环境性失败照旧注明）。
- impl-report 逐项映射 1-10，并对第 10 项写明新旧首页能力对照结论。

## Open questions

（无——第 10 项的缺口处理规则已在项内给出。）

## 追加项（承接 UI 轮遗留）

11. **禁用态透明度叠加清理**：CampPrimary/SecondaryButtonStyle 已内建禁用变暗（isEnabled → opacity 0.45），以下四处残留的手动 `.opacity(0.5)`（或类似）会叠加成过度变暗，删除之：`CompanionEditorView.swift`、`DMChatView.swift`、`RootView.swift`、`CodingRanchHomeView.swift` 各一处（grep opacity(0.5) 定位）。允许触碰文件清单相应追加 `CompanionEditorView.swift`、`DMChatView.swift`（仅此一行清理，勿动其他逻辑）。
