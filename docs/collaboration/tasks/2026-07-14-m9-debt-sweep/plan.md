# M9 债务清扫实施计划(Level 2)

日期:2026-07-14
分支:feat/v1.0
来源:M9 补记盘点(docs/collaboration/tasks/2026-07-07-m9-harvest-return/impl-report.md「遗留处置」)
授权:用户已批准 v1.0 收束计划,本轮为其中 M9 欠账部分。

## 目标

把 M9 计划承诺但未兑现的用户可感知项补齐,并补上保守语义的回归测试。

## 非目标

- 不做 D7 HarvestStore 拆分(纯重构,记 V2);
- 不做 DM 闲置 5 分钟 idle timer(现有切走触发已覆盖,记 V2);
- 不做侧栏归档折叠区(记 V2);
- 不改 Mission/Card 状态机与既有事件语义。

## 改动清单

### 1. 归档营地二次确认

RootView.swift 右键菜单「归档营地」(约 :460-475)改为触发 confirmationDialog(沿用现有「放弃任务」对话框模式,约 :280):标题「归档营地「<名>」?」,说明「归档后不能发起新的放牛,资料和历史保留;可随时恢复。」,确认按钮「归档」。恢复操作无需确认。

### 2. 归档只读补全(禁写三处)

归档语义 = 只读:除「禁新行动」(已有)外,补:

- **营地管家发言**:AppStore 的管家发送路径(GuideChatService 调用处)入口 guard:camp.archived → 不发送,toast「营地已归档,恢复后才能继续对话」;CampHomeView 管家输入区在归档营地下 disabled + 占位文案「营地已归档」。
- **喂牛**:FeedComposer 入口(CampHomeView 页头「喂牛」按钮)在归档营地下 disabled(hover/help 说明);AppStore 的 feed 提交路径同样 guard(防路由绕过)。
- **营地笔记编辑/删除**:NoteListPane 的编辑与删除操作在归档营地下 disabled;对应 AppStore 方法 guard。

实现原则:**UI disabled + AppStore 方法双闸**(与「禁新行动」的双闸模式一致);内核层(AppDatabase)不加新约束,避免影响收营蒸馏等系统写入(归档前已存在的运行中任务收尾写入不受影响)。私聊(DM)不在本轮范围——伙伴记忆是跨营地资产。

### 3. 共事记录标题前缀

Orchestrator.distillCoworkNotes(约 :1137)落库标题改为 `共事·<行动名>:<蒸馏标题>`(行动名取 mission goal 截断 20 字符,与计划 D3 原文对齐)。已有历史笔记不迁移。

### 4. 补测试(Sources/AgentLoopTestSuite/)

1. `canTransition` 穷举断言更新:done→ready 合法、accepted/failed→ready 非法(DatabaseTests 或就近文件);
2. 退回仅收营前:mission=accepted 时 returnCardForRework 抛 MissionStateError(负向);
3. clearCardReviewFlag:stale_upstream 清除 + cardReviewCleared 事件落库;
4. 归档只读:归档营地上管家发送 guard 拒绝、feed 提交 guard 拒绝(AppStore 层可测的话;若 AppStore @MainActor 不便测,则测内核可测部分并在 impl-report 声明 UI 层走人工冒烟);
5. 共事标题前缀断言(可并入现有蒸馏测试或新增)。

## 触及文件

RootView.swift、CampHomeView.swift、NoteListPane.swift、AppStore.swift、Orchestrator.swift(标题一行)、AgentLoopTestSuite 相应测试文件。

## 边界

- 归档时正在运行的行动:不中断(计划 D6 原语义),其收营蒸馏/报告写入照常;
- toast 文案沿用现有 CampCopy 人话化风格;
- 全部 guard 幂等,重复点击无副作用。

## 验证命令

```
CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests
swift build --product AgentLoopApp
```

## 完成定义

四组改动落地;新增测试全绿;全量测试通过;不动本计划未列文件。

## Open questions

无。
