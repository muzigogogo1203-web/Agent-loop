# 反刍启动反馈与营地/牛生命周期入口实现报告

日期：2026-08-31

## 结果

- 修复“开始反刍”命令已经成功、但 Coding 牧场界面仍停留在旧投影的问题。启动命令现在返回提交后的营地快照，UI 立即应用，并在请求期间显示“正在开始反刍…”且阻止重复点击。
- 增加营地归档/恢复入口。营地主界面提供“营地操作 → 归档营地…”，归档营地进入独立分区并可恢复；归档当前营地后不再显示旧详情。
- 增加自定义普通牛的“移出牛群…”入口。移出后保留 companion、私聊、任务和记忆历史，只退出活跃牛群并禁止后续任务/日程继续选择。
- 系统牛、基础牛、测试牛受保护；进行中的任务、启用中的日程、待确认入营关系会明确阻止对应生命周期操作。
- 隔离真机验证发现并修复了一个亚毫秒时间精度问题：SQLite 按毫秒持久化时间，旧实现却与内存中的亚毫秒时间逐字段精确比较，导致移出事务回滚。现在以数据库回读状态作为提交回执，同时校验退休状态与聚合版本。

## 真实问题核对

真实数据库仅做只读核对。`P1-E 删除预览合成资料` 对应的反刍工作已经成功，资料状态已进入 `needsReview`；原问题是命令提交后界面投影没有立即刷新，而不是工作没有执行。

## 任务范围内改动

- `Sources/AgentLoopApplication/InputWorkflowController.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchHomeView.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift`
- `Sources/AgentLoopApp/Views/CompanionEditorView.swift`
- `Sources/AgentLoopApp/Views/RootView.swift`
- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/CowResidencyStore.swift`
- `Sources/AgentLoopCore/Database/Records.swift`
- `Sources/AgentLoopCore/Database/ScheduleStore.swift`
- `Sources/AgentLoopCore/Domain/CowIdentity.swift`
- `Sources/AgentLoopCore/Observability/FailureRecord.swift`
- `Sources/AgentLoopCore/Product/ProductBootstrapService.swift`
- `Sources/AgentLoopTestSuite/CodingRanchTests.swift`
- `Sources/AgentLoopTestSuite/CowResidencyContractTests.swift`
- `Sources/AgentLoopTestSuite/HarvestTests.swift`

## 验证

- `swift build --product AgentLoopApp`：通过。
- 相关回归：10/10 通过，见 `focused-final.log`。
- 权威完整命令 `swift run RunTests`：共 1085 项、31 个 suite；并行运行出现 6 个既有的 Socket/子进程时序问题，因此不能记为完整绿灯，见 `verify.log`。
- 上述 6 个失败逐项串行复跑：6/6 通过，见 `serial-reruns-final.log`。首轮并行日志保存在 `verify-initial-parallel.log`。
- 隔离原生预览（独立 bundle、独立状态目录）：
  - 自定义牛移出成功；`cow_identity.status=retired`、版本从 1 到 2；`companion` 主记录仍在；活跃牛群查询为 0。
  - 营地归档成功，归档后显示空选中态与“恢复”；恢复后自动返回营地主页，生命周期回到 `active`。
  - 正式运行中的 `/Users/muzi/Agent-loop/dist/Coding 牧场.app` 未退出、未替换；隔离预览已停止。

## 未执行

- 未提交、未推送、未打包、未安装或替换正式应用。
- 未修改真实业务数据库。
