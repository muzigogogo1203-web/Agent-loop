# 验收记录 — M9 债务清扫

日期:2026-07-14
分支:feat/v1.0

## 改了什么

1. **归档二次确认**:RootView 右键「归档营地」改走 confirmationDialog(标题带营地名,说明保留资料可恢复);恢复无需确认。
2. **归档只读补全(UI + AppStore 双闸)**:营地管家输入框/发送(占位文案「营地已归档」+ sendGuideChat guard)、喂牛(按钮 disabled + submitFeed guard 抛 CampArchivedError)、营地笔记(NoteListPane isReadOnly 贯穿行/右键/编辑 sheet + saveCampNoteEdits/deleteCampNote/toggleCampNotePin guard)。附带把笔记 CRUD 的 try? 吞错改为错误 toast。
3. **共事记录标题前缀**:`共事·<行动名前20字>:<蒸馏标题>`(Orchestrator.distillCoworkNotes)。
4. **补测试 4 项**:cardStatusTransitionMatrixKeepsReturnForReworkConservative(穷举含 done→ready 合法/accepted→ready 非法)、archivedCampRejectsNewMissionShell、returnCardForReworkRejectsAcceptedAndFailedMissions(负向)、closeoutDistillsCoworkNoteWithMissionGoalPrefix。

## 验证

- 真机 `swift run RunTests`:**360/360 全绿**(356 + 4),verify.log 归档本目录。
- Codex 自产 impl-report 因其会话重试机制再次丢失;本文件与 diff review 为准。

## 残留(P2 备忘)

- cardReviewCleared 事件无专项测试(计划第 4.3 项,清除路径有集成覆盖);
- AppStore 层归档 guard 未单测(@MainActor,计划允许声明人工冒烟)——已并入 v1.0 live-test 第 7 组;
- D7 HarvestStore 拆分 / idle timer / 侧栏归档折叠区:按 M9 补记决定记 V2 债。
