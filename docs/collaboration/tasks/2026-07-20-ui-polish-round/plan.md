# UI 优化轮：设计语言统一 + 交互安全 + 显示严谨 + 反馈完整

Level 2。依据 2026-07-20 全面 UI 审计（37 条发现，四视角）。整体调性不变：牧场像素语言、Camp 主题、木牌/胶囊/爪印词汇。

## 允许触碰的文件

`Theme.swift`、`TaskRunView.swift`、`MissionDraftConfirmationView.swift`、`CardDetailInspector.swift`、`CowRosterView.swift`、`CodingPastureTheaterView.swift`、`SettingsView.swift`、`ReturnSummaryView.swift`、`TrophyCenterView.swift`、`CodingRanchLiveHosts.swift`、`RuminationViews.swift`、`FeedComposerView.swift`、`CodingRanchCommonViews.swift`、`ScheduleManagerView.swift`、`CampHomeView.swift`。禁止改 Core 与 AppStore 逻辑（本轮纯视图层）。

## A. 设计语言统一

1. **页面标题统一两档**：一级 detail 页标题一律 `title2.weight(.bold)`（改：SettingsView:18、TaskRunView:118 新任务表单、MissionDraftConfirmationView:63 从 largeTitle 降档；RuminationViews:30 待反刍从 headline 升档；CodingRanchLiveHosts:224 营地笔记、TrophyCenterView:59 从 semibold 提为 bold）；页内分区标题走 RanchSectionHeader。
2. **RanchSectionHeader 推广**：把主流程页面的 `CampSectionTitle` 换成 `RanchSectionHeader`（图标+tint 按语义选）：ReturnSummaryView「成果预览」等、MissionDraftConfirmationView 各卡（goalCard「这次的目标」flag/ember、acceptanceCard「验收清单」checkmark.seal/moss、knowledgeCard「带上的营地知识」book/amber、deliveryCard「交付方式」shippingbox/creek）、RuminationViews 结果页分区、SettingsView 各分区、CampHomeView 各分区。次要小标签（卡内两列小头）可保留 CampSectionTitle。
3. **语义色归位**：amber 只表「等待用户」——RuminationViews:496 「需求」分区头换 `Camp.creek`、营地知识书图标处换 `Camp.stone` 或 hay 底 ink 前景；CowRosterView:159 迷你名册角色 chip 从 creek 换成中性（`Camp.stone`）；CodingRanchCommonViews 专长 chips 从 moss 换 `CampTag`（hay 底）。
4. **杂项归一**：TaskRunView:668 planning 状态签改用标准 `CampChip(text:"正在规划路线…", color: Camp.creek, icon:"sparkles")`（TypingIndicator 保留在页头 sprite 气泡里即可）；CodingPastureTheaterView:830 LoopStage.handoff 颜色换 `Camp.dynamic` 系（新增 `Camp.lavender = dynamic(light: 0x7A61C4, dark: 0x9B85D6)` 进 Theme 并引用）；FeedComposerView/RuminationViews/MissionDraftConfirmationView 内容 gutter 统一 20。

## B. 交互安全

1. **回车误提交修复（高危）**：TaskRunView:303 与 MissionDraftConfirmationView:178 的主按钮把 `.keyboardShortcut(.defaultAction)` 改为 `.keyboardShortcut(.return, modifiers: .command)`，按钮旁加 caption2 灰字「⌘↩ 开始」提示。多行目标输入内回车恢复为换行（不再触发提交）。
2. **退回意见脏状态保护**：TaskRunView:80 弹层关闭路径（背景点击与 Esc）在 CardDetailInspector 的 returnFeedback 非空时改为不直接关闭：把「是否有未提交意见」通过 Binding/回调暴露给 TaskRunView（如 `@Binding var hasDraftText: Bool`），有草稿时点背景/Esc 第一次触发 campToast「意见还没提交，再点一次关闭」，2 秒内再次触发才关闭。
3. **按钮禁用态**：`CampPrimaryButtonStyle`/`CampSecondaryButtonStyle` 读 `@Environment(\.isEnabled)`，禁用时 opacity 0.45 + 去阴影；同时移除调用点手动补的 `.opacity(0.5)`（搜全仓调用处清理，避免叠加）。
4. **收哨防误触**：TaskRunView:892 收哨按钮与「小队动态」按钮之间 spacing 提到 20，收哨改为 `confirmationDialog("收哨会暂停全营任务并终止牛群的执行进程", ...)` 二次确认（恢复操作 resumeCamp 不需确认）。
5. **验收清单防崩溃**：MissionDraftConfirmationView:117 的 `ForEach(draft.acceptance.indices, id: \.self)` 改为基于稳定元素的绑定（把 acceptance 改为本地 `@State var items: [AcceptanceItem]`，`struct AcceptanceItem: Identifiable { let id = UUID(); var text: String }`，提交时映射回 [String]；删除按稳定 id）。
6. **canStart 就地提示**：MissionDraftConfirmationView 开工按钮置灰时，按钮上方显示一行 caption `Camp.charcoalRed` 文案，内容按缺失项生成：「还差：目标 / 工作目录 / 至少一条验收条件」（startBlockReason 存在时优先显示它）。
7. **解锁卡可达性**：CowRosterView:140 展开/收起改为真正的 `Button`（整行 label），chevron 随展开旋转，加 `.accessibilityLabel("展开解锁条件")`。

## C. 显示严谨

1. **Token 格式化 helper**：Theme.swift 新增 `CampFormat.tokens(_ n: Int) -> String`：n<1000 → "\(n)"；否则四舍五入到一位小数 "X.Yk"（1999→"2.0k"）；千位分组用 `n.formatted()`。替换 TaskRunView:618/659/784、CardDetailInspector:376（后者用千位分组全值）。
2. **草原名牌宽度约束**：CodingPastureTheaterView:257 名牌 VStack 加 `.frame(maxWidth: 132)`、Text 加 truncationMode(.tail) + .help(全名)。
3. **日期本地化**：ScheduleManagerView:348 换 `Date.FormatStyle`（`.formatted(date: .numeric, time: .shortened)` 风格，与系统偏好一致）。
4. **花销签可供性**：TaskRunView:614 花销 CampChip 加尾部 `chevron.down` caption2 图标、`.help("查看花销分账")`、hover 时描边加深（onHover + overlay）。

## D. 反馈完整

1. **解锁成功反馈**：CowRosterView unlock() 成功后 `campToast("🐮 \(cow.name) 领回营地了")`（Toast state 加到视图）+ 名册/场景刷新用 `withAnimation(.spring(duration: 0.5))`。
2. **文案修正**：Theme.swift:456 CampCopy 的「小目标面板」改「工作卡详情」；全仓 grep「小目标面板”确认无残留。

## 验证

`swift build` + `swift run RunTests` 基线全绿（环境性失败照旧注明）；impl-report 逐项映射（A1-D2 编号）。

## Open questions

（无）
