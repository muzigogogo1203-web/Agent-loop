# M9 债务清扫实现报告

## Changed files

- `Sources/AgentLoopApp/Views/RootView.swift`
  - 归档营地改为二次确认后执行；恢复营地保持直接执行。
- `Sources/AgentLoopApp/Views/CampHomeView.swift`
  - 归档营地下禁用页头「喂牛」入口。
  - 管家输入框归档态 disabled，placeholder 改为「营地已归档」。
- `Sources/AgentLoopApp/Views/Components/NoteListPane.swift`
  - 增加只读模式，归档营地下禁用笔记编辑、置顶与删除入口。
- `Sources/AgentLoopApp/AppStore.swift`
  - 管家发送入口增加 archived guard，拒绝时 toast「营地已归档,恢复后才能继续对话」。
  - 营地笔记保存、删除、置顶增加 archived guard，并把原先静默 `try?` 改为显式 toast 错误。
- `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
  - `AppStore.submitFeed` 的实际实现位于此 extension；喂牛提交入口增加 archived guard，拒绝时 toast 并抛 `CampArchivedError`。
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
  - 共事蒸馏伙伴记忆标题改为 `共事·<行动名>:<蒸馏标题>`，行动名取 mission goal 去首尾空白后截断 20 字符。
- `Sources/AgentLoopTestSuite/DatabaseTests.swift`
  - 补 `CardStatus.canTransition` 穷举矩阵断言，锁住 `done -> ready`。
- `Sources/AgentLoopTestSuite/HarvestTests.swift`
  - 补归档营地拒绝新行动的内核断言。
  - 补 `accepted` / `failed` mission 下 `returnCardForRework` 拒绝断言。
  - 补 `stale_upstream` 清除与 `card_review_cleared` 事件断言。
- `Sources/AgentLoopTestSuite/OrchestratorTests.swift`
  - 补共事标题前缀断言。

## Verification

- `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift build --disable-sandbox --product AgentLoopApp`
  - Passed.
- `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests > docs/collaboration/tasks/2026-07-14-m9-debt-sweep/verify.log 2>&1`
  - `verify.log` 已写入完整输出，末尾为 `Test run with 360 tests in 2 suites passed after 2.211 seconds.`
- `git diff --check`
  - Passed.

## Deviations / Notes

- `CodingRanchStoreAdapter.swift` 不在计划的文件名枚举里，但它是 `AppStore.submitFeed` 的实际实现位置；为落实 plan 中「AppStore 的 feed 提交路径 guard」必须触及该文件。
- `AgentLoopTestSuite` 只依赖 `AgentLoopCore`，不能导入 `AgentLoopApp`，因此管家发送与喂牛 AppStore guard 未做自动化 UI/AppStore 层测试。本轮用内核归档拒绝新行动测试覆盖可测部分，并用 `AgentLoopApp` build 覆盖编译；UI 交互仍需人工冒烟确认 disabled/placeholder/toast。
- 裸 `swift build --product AgentLoopApp` 在当前沙箱下会尝试写 `/Users/muzi/.cache/clang` 并失败；使用计划同款 `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache` 加 `--disable-sandbox` 后 build 通过。
- `RunTests` 日志已经输出最终通过行，但 Codex 执行会话在日志完成后未释放；当前环境禁止 `ps` / `pkill` 读取进程表，无法主动确认或清理父进程。以 `verify.log` 的最终通过摘要作为本轮测试结果依据。
- 本 Codex 会话没有执行 `git commit`、`git reset` 或 `git checkout`。实现后检查发现 `HEAD` 已由外部进程前移到 `024358f`（`fix(m9-debt): archive read-only + confirm dialog, cowork note prefix, conservative-semantics tests`），该提交包含本轮源码改动以及 plan 外文件；本报告保持为当前工作区新增文件。
