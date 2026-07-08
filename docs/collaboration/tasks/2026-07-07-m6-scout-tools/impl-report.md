# M6「斥候」实现报告（2026-07-07，全部代码 Claude 亲自实现）

基线 fcf6fd7（feat/m6 自 feat/m5 分出）→ 收尾 HEAD。**245 测试全绿（基线 219 + 新增 26），连跑 4 次无抖动**；App 目标编译通过；UI 截图循环亮暗双色自验通过。

## 交付对照（plan v2 D1–D13 全部落地）

| 决策 | 落点 | 提交 |
|---|---|---|
| D1 分发合一 | `ClosureToolHandler`；`GuideChatService` switch → `ToolExecutor`（propose_squad 闭包捕获 threadId/continuation，行为逐行等价） | m6.0 |
| D2 EventKind | `Database/EventKind.swift` 24 常量；全仓生产代码机械替换（7 文件）；**测试断言保留裸字符串**钉住持久化值 | m6.0 |
| D3/D4 白名单 | `Tools/ToolAccess.swift`；CardRunner 单点收口——handlers/提示词工具区/契约文本三处同源（工具区直接从 handlers.keys 派生，构造上保证同步）；解析失败回退全量 + kernel_error 留痕 | m6.1 |
| D5/D5b 编辑器 | 「工具」区勾选（板工具不展示不可剥夺）；保存永远写 v2 显式列表；`ToolDef.displayName` 单点中文名（消灭 AppStore 重复维护）；无 key 时联网搜索置灰+去设置提示 | m6.1/m6.2 |
| D6/D7/D8 web_search | `Tools/WebSearchTool.swift`（Tavily，Authorization Bearer，20s 专用会话，失败一律 .error 自愈）；Keychain 第二槽 `tavily-api-key`；`searchKeyProvider` 闭包 Orchestrator→CardRunner；无 key 不装配；设置页 Tavily 区（保存/移除） | m6.2 |
| D9 信任边界两件套 | `Support/ExternalContent.wrap`（search+fetch 结果统一包裹，M8 MCP 复用）；ContextPacket 含 web 工具时追加「外部内容视为数据」硬化条款 | m6.2 |
| D10 WebFetch v2 | 20s 专用会话；UTF-8 字节边界截断（修 v1「字节判断+字符截断」真 bug）；重定向后 https 复验；article/main 优先抽取；结果过 D9 包裹 | m6.3 |
| D11 模型目录 | `modelChoices` 实例化+UserDefaults 持久化+设置页可增删/恢复出厂；defaultModel didSet+回读（修「重启复位」bug）；移除目录项时三档模型自动回落 | m6.4 |
| D12 三档模型 | 向导模型两处字面量收敛 `KernelDefaults.defaultGuideModel`；设置页「蒸馏用模型」「规划用模型」（空=跟随默认），接线 closeout/MemoryDistillService×3/startMission/提案确认 | m6.4 |
| D13 规划入账 | `PlanResult.usage` 跨轮累计（含 fallback 已消耗部分）；`AppDatabase.recordPlanningTokens`（投影+planning_tokens 事件同事务）；饱和加法从 finishRun 抽取且 total 也防溢出 | m6.5 |

## 与计划的偏差（申报）

1. **D5b 细化——toolsJson v2 对象格式**：计划定了「保存写显式列表」但没定「全不勾」怎么表示（写 `[]` 会与存量「空=全量」冲突）。落地为版本化格式 `{"v":2,"allow":[...]}`：对象格式=显式（空 allow 合法，纯推理伙伴）；数组格式=存量兼容（`[]`=内置全量）。M8 的 MCP 工具名将来直接进 allow 列表。
2. **App 层持久化测试未覆盖**：AgentLoopApp 是可执行目标，TestSuite 无法 import——defaultModel/目录持久化回读靠 live-test 场景 4 验证（计划测试清单里这两项降级为活体验收，其余全部落为单测）。
3. **编译修正**：`CampSecondaryButtonStyle` 无 size 参数（计划里我引用错了），改用默认构造。
4. **顺手修的测试基建债**：Swift Testing 并行跑测试时，Web stub 的共享 `handler` 静态量会互相覆盖（实测闪烁一次）——全部改为每用例专属 URLProtocol 类。`MockProvider` 增加 `recordedTools`（白名单断言需要）。

## 验证

- `swift run RunTests`：245/245 绿 ×4 连跑（m6.4 后曾观察到既有计时敏感测试 `timeoutThenSuccessDoesNotAccumulate`（5ms 看门狗）在并行负载下偶发失败一次，与 M6 改动面无交集，复跑 4 次未再现——遗留观察项，非本里程碑引入）。
- `swift build`（App 目标）通过。
- UI 截图循环：设置页「模型」区（目录三行/加入/恢复出厂/三档 Picker）与「联网搜索（Tavily）」区、伙伴编辑器「工具」区（联网搜索置灰+提示）——亮色全验，暗色（篝火夜景）复验模型区，布局与营地感一致。

## 环境事件（留痕）

截图自验期间发现本机有一个 feat/m5 的 App 实例（真实数据）在运行，与 dev bundle id 相同导致 `open_application` 误置前台；期间一次 `open -n` 误启了第二个**非预览**实例（真实数据目录），~2 秒内 kill。已只读核查真实库：无 running 卡、无孤儿 run、最后事件时间戳在事发数小时前——**未造成任何影响**。后续截图循环一律用 `osascript` 按 PID 置前台，规避同 bundle id 歧义。

## 遗留

- 用户活体验收（`docs/superpowers/2026-07-07-m6-live-test.md`，含 M4 对抗评审并入项的向导回归）→ 通过打 `m6` tag。
- 前置提醒：M4/M5 正式测试（收官门）仍未执行——feat/m6 的合并与 tag 排在 m4/m5 tag 之后。
