# M9 实施报告(补记)

日期:2026-07-14(补记;实现合入于 a823d81,基线盘点 @ main efb8564)

> 本报告为事后补记:M9 实现过程曲折——feat/m9 上的 WIP 抢救提交 e41960d 不编译(/tmp worktree 文件被清理所致),最终由合并提交 a823d81 补写收口进 main,当时未按惯例产出 impl-report。本文基于 2026-07-14 对 main 的逐块代码盘点。

## 结果总览

| 计划块 | 状态 | 说明 |
|---|---|---|
| D1 战利品中心 | ✅ 完整 | TrophyCenterView(311 行)+ HarvestDatabase.artifactLedger 四级 join 纯投影,QuickLook 预览、Finder 定位、钉选(AppStorage JSON),UI 文案随牧场主题化为「回营成果」 |
| D2 远征报告 | ✅ 完整 | ExpeditionReport 确定性拼装(零 LLM),收营后写 reports/<missionId>.md,失败不阻塞收营;入口:行动页 + 战利品中心;确定性有测试钉住 |
| D3 共事记录 | ✅ 完整(小偏差) | distillCoworkNotes 收营蒸馏链尾,按 done 卡 assignee 分组,输入仅交接包摘要+元数据,失败静默跳过;注入闭环经 pinnedAndRecentCompanionNotes。偏差:标题未加「共事·<行动名>」前缀 |
| D4 卡级退回 | ✅ 完整 | done→ready 状态机手术、意见必填、下游 done 卡标 stale_upstream 不级联、重跑上下文注入、产物防覆盖+「(重做)」label、仅收营前(mission ∈ executing/delivering)、rollup 回落——保守语义逐条兑现 |
| D5 闲置自动蒸馏 | ⚠️ 降级 | 复用 M4 的「切走线程触发」蒸馏(RootView onChange),计划中的「DM 视图内 5 分钟 idle timer」未实现 |
| D6 营地归档 | ⚠️ 部分 | 「禁新行动」双闸(UI 隐藏入口 + resolveCamp 硬抛 CampArchivedError)+ campArchived 事件 + 战利品中心归档标识到位;未实现:侧栏归档折叠区、向导发言/笔记只读、归档二次确认 |
| D7 HarvestStore 拆分 | ❌ 未做 | AppStore 绞杀第三刀未动,harvest 状态仍在 AppStore(+105 行) |

迁移 v7 精确落两列(card.reviewFlag、camp.archived),EventKind +3(card_returned/card_review_cleared/camp_archived)。e41960d 夹带的 M10 seeds(Sparkle/常驻/schedule 事件)在 main 上确认零残留。

## 验证

- `swift run RunTests`(2026-07-14 @ efb8564):**346 项全部通过**,完整输出见本目录 verify.log。
- M9 专项测试仅约 3 用例(HarvestTests 2 个 + BoardToolsTests 防覆盖 1 个),远低于计划预估 +20±。未覆盖:done→ready 穷举、退回仅收营前负向、归档只读、cardReviewCleared、共事闭环。

## 遗留处置(2026-07-14 决定)

- **并入 v1.0 收束轮修复**:归档二次确认、归档只读补全(向导/喂牛/笔记)、共事标题前缀、上述缺失测试(任务 2026-07-14-m9-debt-sweep)。
- **记 V2 债(不阻塞 v1.0)**:D7 HarvestStore 拆分(纯重构)、D5 idle timer(现有切走触发已覆盖主场景)、侧栏归档折叠区(营地数量少时收益低)。
