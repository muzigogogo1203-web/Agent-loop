# M1.1 冒烟反馈修复 — 实现计划（Level 2）

来源：M1 活体冒烟通过后用户反馈的三个问题（docs/superpowers/2026-07-04-m1-live-smoke.md 结果记录）。

## 目标

A. 单卡运行的中间过程实时可见（活动时间线）。
B. 伙伴创建后可编辑（入口 + 编辑器加载/保存现有记录）。
C. 单卡运行的传输级错误可自愈（按轮重试）且错误可读、可诊断。

## 非目标

- 不改卡片状态机、GRDB schema、HandoffPayload/工具 schema、交接包校验规则。
- 不加「停止运行」按钮（已在 backlog，另做）。
- 不做伙伴删除。
- 不改 Provider 的 HTTP 状态码重试策略（429/5xx 逻辑保持）。

## Fix A：运行活动时间线

**改动文件**：`Sources/AgentLoopApp/AppStore.swift`、`Sources/AgentLoopApp/Views/TaskRunView.swift`、`Sources/AgentLoopCore/Loop/AgentLoop.swift`（仅加事件枚举 case，见 Fix C——两处共用）。

1. AppStore 增加：
   ```swift
   struct ActivityItem: Identifiable, Equatable {
       let id = UUID()
       var text: String
       var kind: Kind   // enum Kind { case start, tool, toolDone, toolError, note, retry, finish }
   }
   var activityLog: [ActivityItem] = []
   ```
   startRun 开始时清空；事件驱动追加：
   - 循环开始（消费到第一个事件前）→「阿规开工了」（用伙伴名）。
   - `.toolStarted(name)` →「正在\(人话(name))…」。
   - `.toolFinished(name, isError)` → 把最近一条同名 tool 项改为完成态（✓/✗ 文案）；**若 name == "add_progress_note" 且非错误 → 立即从 db 重读 progressNotes**（进展实时上屏，不再等收尾）。
   - `.turnRetrying(attempt, reason)`（Fix C 新事件）→「网络波动，正在重试（\(attempt)/2）：\(reason)」。
   - `.finished` → 保持现有逻辑另加一条 finish 项。
   工具名人话映射（app 层私有函数）：write_file→写文件、read_file→读文件、list_dir→查看目录、web_fetch→查网页、complete_card→提交交接包、block_card→报告受阻、add_progress_note→汇报进展；未知名原样。
2. TaskRunView `runView`：在 transcript 之上加活动时间线区（`ForEach(store.activityLog)`，每项一行小字：kind 图标 + 文本；自动滚动到最新可不做）。progressNotes 区保留但改为随时显示（非空即显示，现已如此——确认即可）。
3. transcript 回卷（配合 Fix C 重试防重复文本）：AppStore 在收到 `.turnStarted` 时记录 `transcript.count` 到私有变量 `turnStartTranscriptCount`；收到 `.turnRetrying` 时 `transcript = String(transcript.prefix(turnStartTranscriptCount))`。

## Fix B：伙伴编辑

**改动文件**：`Sources/AgentLoopApp/Views/CompanionEditorView.swift`、`Sources/AgentLoopApp/Views/RootView.swift`、`Sources/AgentLoopApp/Views/DMChatView.swift`。

1. CompanionEditorView：
   - `companionId != nil` 时 `.onAppear`（或 `.task`）用 `store.db.companion(id:)` 加载：name/color/rolePrompt 直接填；model 若在 `AppStore.modelChoices` 里则选中，否则 `modelChoice = customTag; customModel = model`。
   - 保存：编辑态下取出现有记录，仅更新 name/color/rolePrompt/model 四个字段（**保留 id/createdAt/kind/campId/toolsJson**），`store.db.saveCompanion`（GRDB save 按主键 UPDATE）。新建态逻辑不变。
   - `onDone` 语义不变（由调用方决定去处）。
2. 入口两个：
   - RootView 侧栏伙伴行 `.contextMenu { Button("编辑…") { selection = .editCompanion(c.id) } }`。
   - DMChatView `.toolbar { Button("编辑伙伴") … }`——需要能改 RootView 的 selection：把回调经由环境/闭包传入（实现建议：RootView 在构造 DMChatView 时传 `onEdit: { selection = .editCompanion(companion.id) }`）。
   - 编辑完成后 onDone 回到该伙伴私聊：RootView 对 `.editCompanion(id)` 的 detail 构造时传 `onDone: { selection = id == nil ? .newTask : .chat(id!) }`（注意 editCompanion(nil) 为新建，回 .newTask 或名册即可，保持现状）。
3. 陷阱提醒：编辑器当前用 `@State` 初始值——切换不同伙伴编辑时要用 `.task(id: companionId)` 或 `.id(companionId)` 保证重载。

## Fix C：单卡运行韧性 + 可观测

**背景假设**（写进 acceptance 供后续验证）：私聊=单轮短请求很少碰到传输错误；单卡=多轮长会话，URLError（超时/断流）与网关抖动概率高得多，而当前传输错误零重试、直接 failed，且错误信息是枚举插值不可读。

**改动文件**：`Sources/AgentLoopCore/Loop/AgentLoop.swift`、`Sources/AgentLoopCore/Provider/LLMProvider.swift`、`Sources/AgentLoopCore/Loop/CardRunner.swift`、`Sources/AgentLoopApp/AppStore.swift`（重试事件显示，已并入 Fix A）。

1. **AgentEvent 增加两个 case**：
   ```swift
   case turnStarted
   case turnRetrying(attempt: Int, reason: String)
   ```
   循环每轮开始（调 provider 前）yield `.turnStarted`。
2. **按轮重试（AgentLoop 内）**：把「消费 provider 流得到 TurnResult」包进重试环：
   - 可重试错误：`URLError`（任何 code）、`ProviderError.http(status: 500...599, _)`、`.overloadedRetriesExhausted`、`.malformedStream`（流中断）、`.apiError(type:)` 中 type 为 "overloaded_error" 或 "api_error"。
   - 不可重试：`CancellationError`（立即上抛）、`.unauthorized`、`.http(4xx)`、其余 `.apiError`。
   - 每轮最多 2 次额外尝试，退避 2s、4s（`Task.sleep`，睡前 `try Task.checkCancellation()`）。重试前 yield `.turnRetrying(attempt:reason:)`，reason 用错误的人话描述（见 3）。
   - **安全性依据（不得破坏）**：history 只在整轮成功后追加，重试重发相同 history 幂等；工具绝不在失败轮执行。
   - 耗尽后把最后错误原样上抛（走 CardRunner 现有 failed+blocked 路径）。
3. **ProviderError 可读化**：`extension ProviderError: CustomStringConvertible`——unauthorized→「API key 无效或无权限（401/403）」；http(s,_)→「服务端返回 \(s)」+body 前 120 字；overloadedRetriesExhausted→「服务持续过载，已多次重试」；apiError→「API 错误 \(type)：\(message)」；malformedStream→「响应流异常中断：\(detail)」。CardRunner 的 blockCard detail 与 AppStore 的 failed 文案用 `String(describing:)` 即自动受益；URLError 用 `localizedDescription`。
4. **诊断事件**：CardRunner 的 catch 分支在 blockCard 之前 `AppDatabase.appendEvent`（走既有公开写路径；若无公开单事件方法，在 AppDatabase 加 `appendDiagnosticEvent(cardId:runId:kind:payload:)` 薄封装）：kind "run_error"，payload {"error": 人话描述, "turns": 已完成轮数}。**不得写入 API key 或完整请求体**。
5. **日志**：`import os`，AgentLoop/AnthropicProvider 加 `Logger(subsystem: "com.muzi.agentloop", category: "loop"/"provider")`：每轮开始/stop_reason/重试/最终错误 各一条 `.info`/`.error`。禁止记录 headers、request body、API key。

## 测试要求（Sources/AgentLoopTestSuite/）

在 `AgentLoopTests.swift` 追加（需要一个测试内的小型 provider 桩，可包装 MockProvider 或新写 `FlakyProvider: LLMProvider`，前 N 次 streamTurn 抛指定错误，之后转发给内部 MockProvider）：

1. `turnRetriesTransientErrorThenCompletes`：第一次抛 `URLError(.networkConnectionLost)`，第二次正常 complete_card → outcome completed；事件序列包含一个 `.turnRetrying(attempt: 1, …)`；provider 总调用 2 次。
2. `turnRetryExhaustionSurfacesLastError`：连抛 3 次 URLError → run() 上抛错误（CardRunner 层不必测，AgentLoop 层断言 throw）；`.turnRetrying` 出现 2 次。
3. `unauthorizedNotRetried`：抛 `.unauthorized` → 立即上抛，无 `.turnRetrying`，provider 调用 1 次。
4. `turnStartedPrecedesEachTurn`：两轮脚本，断言事件序列里每轮 deltas 前有 `.turnStarted`（数量 == provider 调用数）。
5. `providerErrorDescriptionsAreHuman`：对 5 个 case 断言 description 含关键词（如 "401"、"过载"）。

UI（Fix A/B）无自动测试（app target 不在测试套件），以构建通过 + 下述完成定义人工核对。

## 验证命令

- `swift run RunTests` 全绿（预期 70 → 75）。
- `swift build` 干净；`swift run AgentLoopApp` 可启动（构建通过即可，无需 GUI 验证）。

## 完成定义

1. 五个新测试全绿，既有 70 个不回归。
2. AgentLoop 重试语义如上（历史不重复追加、取消即时上抛——不得破坏既有 `runnerCancellationLeavesCardReady` 等测试）。
3. 编辑器加载现有伙伴、保存保 id；两个入口可达（代码可见即可）。
4. 活动时间线数据流完整（事件→ActivityItem→视图 ForEach）。
5. impl-report.md + verify.log 齐全。

## Open questions

（无——方案已决策完备。）
