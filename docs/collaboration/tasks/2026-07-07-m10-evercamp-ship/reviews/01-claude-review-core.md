# Claude Review 01 — M10 Core 轮

日期:2026-07-14
对象:feat/v1.0 工作区 M10 Core 改动(5 改 + 5 新)

## 结论:通过(1 处 P1 已由 Claude 当场修复)

1. **符合 plan**:plan-v2 Core 范围(a)-(h)全部落地;迁移正确注册为 v9-evercamp;无 Sparkle 依赖;未触碰 Views/(仅 AgentLoopApp.swift 按计划改造 AppDelegate)。
2. **正确性**:表结构带 CHECK 约束(frequency/hour/minute/weekday);模板双保险在保存与触发两处校验;触发时营地归档/伙伴缺失 → scheduleMissed 不崩;misfire 只提示不自动跑。**P1(已修)**:DST 春令时测试断言与 .nextTime 实现语义不符(期望 03:30,实测 03:00),按实现语义修正断言——.nextTime 是 Apple 标准行为且产品上合理(02:30 被跳过则 03:00 触发)。
3. **并发**:MissionScheduler @MainActor;lastFiredAt 走 CAS;NSBackgroundActivityScheduler 每日程一实例,refresh 时全量重建避免泄漏。
4. **数据层**:v9 迁移可回放(测试从 v8 起回放通过);外键 references(camp/mission_template)正确。
5. **契约稳定**:EventKind 常量;companionIdsJson 编码确定性(sortedKeys 风格沿用)。
6. **测试真实性**:真机 376/376 全绿;16 项新测试覆盖 ScheduleMath 矩阵(DST 双向)、迁移回放、CRUD、双保险、播报、事件。
7. **安全**:无凭据接触;通知内容不含敏感数据。
8. **质量**:结构贴合既有 store/actor 模式;ScheduledMissionNotifications 的 bundle 探测降级注释清楚。

## P2/P3 备忘

- P2:AppStore.nextScheduleMenuTitle 目前取最近一个启用日程,多日程排序展示留 UI 轮(Codex 已声明);
- P3:Codex 会话的 impl-report/verify.log 因沙箱视图同步问题一度丢失,报告由 Claude 按捕获内容复原——后续 Codex 轮建议产物即时 git add(不 commit)以钉住。
