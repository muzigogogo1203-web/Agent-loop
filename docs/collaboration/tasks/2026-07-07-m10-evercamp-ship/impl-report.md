# M10 Core 实施报告(evercamp 第一轮:Core + 逻辑层)

日期:2026-07-14
(注:Codex 原始报告文件因沙箱视图同步问题丢失,本文件按其产出内容由 Claude 复原并补充最终验证结果。)

## 完成范围

- 迁移 `v9-evercamp`:`mission_template`(显式 budgetTokens 非空 + autonomy TEXT)与 `schedule`(frequency/hour/minute/weekday/enabled/lastFiredAt,均带 CHECK 约束)两表 + 索引;`ScheduleStore.swift` 新增 MissionTemplateRecord/ScheduleRecord 与 CRUD(saveMissionTemplate 校验预算>0 且 autonomy≤standard 拒绝 free;deleteMissionTemplate 级联删日程;updateScheduleLastFired CAS)。
- `Kernel/ScheduleMath.swift` 纯函数:nextFireDate(daily/weekly,显式 Calendar+TimeZone 注入,DST 用 .nextTime 策略——被跳过的本地时间顺延至首个有效时刻)、misfire 判定、sameSlot 同槽防双发。
- EventKind +2:`scheduleFired` / `scheduleMissed`。
- `KnowledgeStore.appendGuideBroadcast(campId:text:)`:role=guide 纯本地注入,不走 LLM。
- `MissionScheduler`(@MainActor,AppStore 持有):每启用日程一个 NSBackgroundActivityScheduler(tolerance 300s);触发时重读 schedule 防重(sameSlot)→ 模板校验(预算/档位/伙伴/营地存在且未归档,失败记 scheduleMissed + 播报)→ `Orchestrator.startMission` → CAS 更新 lastFiredAt + scheduleFired 事件 + 播报;启动 misfire 检查只产出 pendingCatchups 状态回调,不自动补跑。
- `ScheduledMissionNotifications.swift`:UNUserNotificationCenter 桥——bundle 运行时探测失败静默降级;首次启用日程请求授权;收营/失败/预算耗尽三类通知仅对 scheduled 任务;点击经 AppStore 导航闭包。
- AgentLoopApp.swift / AppDelegate:菜单栏常驻(UserDefaults `menuBarResidencyEnabled`;NSStatusItem + 关窗保活;菜单:打开牧场/下次日程/紧急收哨/退出);UNUserNotificationCenterDelegate 接线。
- AppStore:scheduler 与通知桥装配、模板/日程 CRUD 门面、pendingCatchup 状态、scheduledMissionIds 过滤、selectMission/nextScheduleMenuTitle 挂点。

## 验证(Claude 真机复核)

- `swift run RunTests`(前台真机):**376/376 全绿**(360 基线 + 16 新增),verify.log 归档本目录;
- `swift build --product AgentLoopApp`:通过(RunTests 不编译 App 目标,单独构建验证);
- Claude 修复一处 Codex 测试断言错误:scheduleMathSpringForwardUsesNextValidLocalTime 期望 03:30,与实现的 .nextTime 语义(03:00)不符,已按实现语义修正并注释。

## 偏差声明(留 Claude UI 轮)

- 通知点击导航只留 AppStore 闭包挂点;设置 UI(常驻开关)、日程管理界面、模板表单、misfire「现在补跑?」交互均属 UI 轮;
- NSStatusItem 菜单文案为占位,UI 轮可调。
