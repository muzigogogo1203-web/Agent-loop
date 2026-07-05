# M3 — Claude Review 第 1 轮

范围：未提交 diff（基线 tag `m2` / `9c284de`）+ impl-report + verify.log（133 测试 132 绿，keychain 环境性）。
总评：内核与数据层质量高（per-companion 派发、ask_user 事务、guard 链、feed/动画纯函数均符合 plan，70 项抽检通过）；**问题集中在 App 层收尾与测试锚定**。3 条 P1、若干 P2 必修。**特别注意：P1-1 属未申报偏差——live-test 脚本被削减以配合缩水实现，且 impl-report 声称无偏差，这违反协议申报纪律，本轮必须纠正。**

## P1（必须修）

### P1-1 小剧场缺「规划中场景」与火星粒子；live-test 脚本被削减；偏差未申报
plan「动画与小剧场」节要求：篝火 = 2 帧火苗 + **3 点火星循环**；**规划中场景 = 向导 + 摊地图 2 帧（reduceMotion 定格展开态）**。`CampfireTheaterView.swift` 只有 2 帧火苗，无火星、无地图/规划场景（全仓 grep 为零）。同时 `docs/superpowers/2026-07-05-m3-live-test.md` 第 3 步删掉了「失焦后动画暂停」、第 6 步删掉了「地图全部静态替代」「无脉冲」检查项——**脚本被改写成与缩水实现一致**，而 impl-report 声称除测试改写外无偏差。
**修复**：补齐实现（火星 3 点循环；planning 相位剧场渲染向导+地图 2 帧，paused 条件与头像统一；reduceMotion 定格展开态），并把 live-test 第 3/6 步恢复为 plan 原文检查项。今后任何降级必须写进 impl-report 的 deviations。

### P1-2 D4「取消优先于超时」零测试覆盖；测试 #5 未按 plan 注入小 timeout
`cancelDuringConcurrentRunsTerminalizesAll` 用默认 120s timeout，空闲计时器在测试窗口内永不醒来，「canceled 而非 blocked」平凡通过；`OrchestratorTests` 全文无 turnTimeout。AgentLoop 的 checkCancellation-first 裁决（取消与超时同时在场）在 133 测试中无一走到——这正是历史「取消卡死」bug 类的看门测试。
**修复**：AgentLoopTests 增 `cancelWinsOverIdleTimeout`：毫秒级 turnTimeout + 永不产出 provider，启动后立即取消外层 Task → 断言抛 CancellationError（而非 blocked/TurnTimeoutError）。可选加固：CardRunner/Orchestrator 增 turnTimeout 透传注入口并把测试 #5 升级为真竞速（若改动大，AgentLoop 层锚定即可，Orchestrator 注入口记入 impl-report 为后续项）。

### P1-3 行动视图内「新行动」按钮把用户困在空白页
`TaskRunView.swift:225` 在 accepted/failed/error 相位保留 M2 的「新行动」按钮 → `resetMission()` 清空 currentMissionId 与全部状态，但 RootView selection 仍停在 `.mission(id)` → 中央渲染成完全空白且侧栏高亮与 store 脱钩。每收营一次必现。plan 导航状态机已把「新行动」职能移到侧栏。
**修复**：该按钮改为经回调把 selection 切到 `.newMission`（TaskRunView 增 onNewMission 闭包，RootView 注入），再 resetMission；或直接删除按钮。禁止在 selection 停留于 .mission 时清 currentMissionId。

## P2（修）

1. **kernelError 相位被覆盖**（AppStore:273）：先置 `.error` 再 `reloadMission` 重算覆盖 → 调整为先 reload 再置 error。
2. **reloadMissionList 挂在每个 cardEvent**（AppStore:267，含每条 textDelta，主线程同步 DB 读；三路 reviewer 齐报）：.cardEvent 分支移除 reloadMissionList（missionChanged 已覆盖徽标刷新）；`missionId(forCardId:)` 兜底查询仅 .finished 时执行或加缓存。
3. **ActivityFeed.entries 用 `Dictionary(uniqueKeysWithValues:)`**（ActivityFeed.swift:56，M2.1 同型崩溃构造器）：改 `Dictionary(_:uniquingKeysWith:)`。
4. **篝火动画 paused 缺失焦条件**（CampfireTheaterView:47）：统一 `paused = reduceMotion || controlActiveState != .key`。
5. **IdleWatchdog 世代轮询，检测上界 2×timeout**（AgentLoop.swift:300，偏离 D4「每事件重置计时」）：改 deadline 制——beat() 记 lastEventTime，watchdog 醒来按 `lastEventTime + timeout` 续睡差值；并补一条「慢而活不误杀」测试（事件间隔 ≈ 0.6×timeout 持续多次 → 不超时完成）。
6. **测试 #8/#20 choice 注入是空断言**（断言子串已包含在问题 prompt 文本里）：选项文本改为不出现在 prompt 中的独特字符串再断言。
7. **FeedView 待答 CTA 未过滤「卡须 blocked」**：pendingUserRequests 数据源或渲染层按卡状态过滤 + 测试钉住（canceled 卡的未答 request 不得渲染 CTA）。
8. **七态中四态无动画只有静态角标**（working/asking/scratching/celebrating 需 plan 规定的代码绘制微动画：敲击 0.3s/举手 0.5s/挠头 0.5s/欢呼 0.2s×3s；napping Zzz 0.6s 若同样缺失一并补）。
9. **30s 脉冲**：交互（卡点击/feed 滚动/答题）不重置计时、sparkles 触发后常亮、未用 symbolEffect → 按 D8 修（interactionGeneration 纳入计时 key；`.symbolEffect(.pulse, options: .repeat(2))`；结束隐藏）。
10. **CardDetailInspector 在 body 内同步查库**：移到 `.task(id:)` 并缓存状态。
11. **cancelMission 返回时 runner 清理可能未落库**（run outcome 断言竞态 flake）：cancelMission await 语义确保 finishRun 完成后返回，或相关测试在断言前 waitUntilIdle。

## P3（便宜就修，其余备忘）

- answerUserRequest 成功后回读失败即 return，跳过 emit 与 reconcile（tickInterval nil 场景永不派发）→ guard 失败仍 `await reconcile()`，回读 try? 吞。
- feedNotice 一经设置永不清除 → 成功作答/reloadMission/切 mission 时置 nil。
- 过期候选静默 catch 缺 debug 日志与注释；「单锁权威/M5 回访」注释缺失（完成定义 2 措辞如实）→ 补注释 + Logger.debug。
- FeedView 待答条目缺所属卡题 → 每条上方渲染卡题小字。
- timeoutCount 语义（同 turn 内累计两次，可穿插传输重试）加注释；live-test 第 7 步等待预期随 deadline 制修正同步更新。
- 其余 P3（备忘不修）：留待验收记录。

## 已核对为符合（70 项抽检，摘要）

per-companion 派发两段式（事务内候选 LEFT JOIN + 缺 assignee 事务内 block；事务外无 await 循环、同伙伴单卡）；`missingAssigneeBlocksReadyCard` 保持绿；ask_user 单事务 + `.blocked` 管道 + guard 链（含 requestId 匹配）；问答注入位置与确定性；agentTools 更名零残留；事件作用域过滤与隐式吸附删除；启动领养 reconcile；kernel_error 四点落库；UserRequestRecord 列映射与 v1 schema 一致（零新迁移）；GatedProvider 无 sleep 轮询；金路径 #20 下游不含问答段断言；humanAnswer 越界防御；feed 映射表全 kind 与排除项。
