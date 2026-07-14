# Coding 牧场窗口适配加固实现报告

日期：2026-07-14

## 结果

本轮完成了 App 层窗口响应式加固。最小窗口、断点窗口、宽窗口与最大化窗口下，主导航、复杂页头、辅助面板、表单和工作卡详情会按可用空间降级，不再把中文和按钮挤成逐字竖排，也不会让固定尺寸弹层越出窗口。

核心布局规则：

- 640–899px：详情优先，主侧栏自动收起；笔记、任务动态和记忆抽屉锁定收起；复杂页头和工具条分行；
- 900–1199px：主侧栏显示，页头仍使用紧凑分组；辅助面板按 1180px 断点自动收起；
- 1200px 及以上：恢复横向页头；空间足够时显示用户已开启的笔记、任务动态和记忆抽屉；
- 工作卡详情按当前窗口与视图可用宽高动态收缩，内容继续在弹层内部滚动。

`NavigationSplitView` 在窄窗时会保留大于窗口的理想布局尺寸，因此单用 `GeometryReader` 不能稳定判断真实窗口宽度。本轮增加了只读的 AppKit 窗口尺寸探针，把真实 `NSWindow` 尺寸同步到 SwiftUI 环境，所有主页面共享同一组断点。

## 修改文件

- `Sources/AgentLoopApp/Views/Theme.swift`
  - 增加集中式 `CampLayout` 断点、安全边距和弹层尺寸计算；
  - 增加真实窗口尺寸环境值与窗口缩放监听。
- `Sources/AgentLoopApp/Views/RootView.swift`
  - 跨越 900px 时在 `.detailOnly` 与 `.all` 间切换；
  - 紧凑窗口下重排全局停营提示条。
- `Sources/AgentLoopApp/Views/CampHomeView.swift`
  - 营地页头、控制区和管家输入区支持分行；
  - 笔记本按真实窗口宽度收起；
  - 喂牛和待反刍 sheet 改为可伸缩尺寸。
- `Sources/AgentLoopApp/Views/TaskRunView.swift`
  - 任务标题、状态、牛与操作、预算提示和视图工具条分级响应；
  - 小队动态按真实窗口宽度收起；
  - 工作卡详情按可用空间定尺。
- `Sources/AgentLoopApp/Views/Components/CardDetailInspector.swift`
  - 移除内部固定 620 × 640 尺寸；
  - 预期产出允许换行。
- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchHomeView.swift`
  - 新版首页页头和双栏区域按统一断点降级；
  - 喂牛 sheet 改为可伸缩尺寸。
- `Sources/AgentLoopApp/Views/CodingRanch/FeedComposerView.swift`
  - 来源 URL 与作者字段在空间不足时改为纵向排列。
- `Sources/AgentLoopApp/Views/CodingRanch/CowRosterView.swift`
  - 能力与解锁条件在窄卡片中改为纵向排列。
- `Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift`
  - 检查页页头、底部操作区和原文 sheet 支持紧凑布局。
- `Sources/AgentLoopApp/Views/DMChatView.swift`
  - 记忆抽屉改用真实窗口宽度判断是否可展开。
- `docs/collaboration/tasks/2026-07-14-responsive-layout-hardening/plan.md`
  - 记录本轮尺寸矩阵、范围与完成门槛。
- `docs/collaboration/tasks/2026-07-14-responsive-layout-hardening/verify.log`
  - 保存权威测试的完整输出。
- `docs/collaboration/tasks/2026-07-14-coding-ranch-mvp/blocked.md`
  - 记录原阻塞及用户授权后的解除状态。

## 视觉验收

使用 `AGENTLOOP_UI_PREVIEW=1` 和隔离的临时状态目录启动已签名 App，并用真实窗口复核：

| 尺寸 / 模式 | 验收结果 |
|---|---|
| 640 × 680，亮色 | 主侧栏自动收起；营地页、任务页无竖排或重叠；喂牛与待反刍 sheet 可完整滚动到底部操作；工作卡详情不越界。 |
| 640 × 680，暗色 | 营地页、任务页和私聊页布局与对比度正常；辅助面板保持收起。 |
| 900 × 700 | 主侧栏在断点处正常显示；营地页和任务页使用紧凑页头；笔记与小队动态保持收起。 |
| 1280 × 800 | 主侧栏、营地笔记和任务动态正常组成多栏；主内容仍保持可读宽度。 |
| 最大化（约 1470px 宽） | 宽版页头、营地双栏、任务动态栏和新任务表单正常。 |

另外复核了牛棚、设置、新任务表单、私聊、喂牛 sheet、待反刍 sheet 和工作卡详情。未发现文字逐字竖排、控件遮挡、主要操作不可达或弹层越界。

视觉验收使用真实数据库的一份临时只读来源备份作为展示数据；原数据库未被预览实例修改。

## 构建与测试

- `swift build`：通过；
- `swift run RunTests`：通过，346 个测试全部成功；
- 完整输出：`verify.log`（701 行）。

## 偏差

无产品范围、数据模型、依赖或业务行为偏差。未修改 Core、持久化、任务状态机和 Store 协议，也未提交代码。
