# M7「哨卡」实现报告（2026-07-07，全部代码 Claude 亲自实现）

基线 1d84c98（feat/m7 自 feat/m6 分出）→ 收尾 HEAD。**264 测试全绿**（M6 收尾 245 + 新增 19）；App 目标编译通过；UI 截图自验通过（档位签/花销浮层/收哨横幅/表单分段选择/设置页默认档位，均对照营地感）。

## 交付对照（plan v1 D1–D9 全部落地）

| 决策 | 落点 | 提交 |
|---|---|---|
| D1 风险分级 | `Tools/ApprovalPolicy.swift`：ToolRisk 三级单点映射（板工具+只读豁免；`mcp__` 前缀默认 write 为 M8 预留）；`run_shell` = dangerous | m7.0-1 |
| D2 自主档位 | 迁移 v5 `mission.autonomy`；MissionAutonomy（谨慎/标准/放手）× 放行矩阵；startMission/提案确认透传；`setMissionAutonomy` 中途可改+事件；表单分段选择、行动头部菜单签、设置页全局默认 | m7.0-1 / m7.4-7 |
| D3 审批持久门 | `suspendCardForApproval` 完全复用 ask_user 门语义（`user_request.kind="approval"` 零迁移，optionsJson 存 {tool, input 全文, inputHash}）；`approval_requested/decided` 事件；模型伪造 approval kind 的 ask_user 被拒 | m7.2 |
| D4 一次性令牌 | `ApprovalGateHandler` 装饰非只读工具；SHA256(tool+规范化 JSON) 哈希；**批准令牌用过即耗**（同参第二次调用再挂起）；拒绝记录不耗（同参反复调一直拒），拒绝以 is_error+理由让模型改道不挂卡；冷启动重跑从已答复请求装罐 | m7.2 |
| D5 紧急收哨 | `Orchestrator.emergencyStop/resume`：取消全部在途（复用 card_interrupted→ready 领养语义）+ 终止子进程 + halted 挡 reconcile；camp_halted/resumed 事件 + haltStateChanged 内核事件；UI 红色收哨按钮（Cmd+.）+ 收哨横幅带恢复出哨；`willTerminateNotification` → 子进程清理 | m7.4-7 |
| D6 ShellTool | zsh -c、cwd 锁工作目录（无目录不装配）、120s 超时（SIGTERM→300ms 宽限→SIGKILL）、输出 20KB 字节安全截断、退出码非零算结果不算错误；`ShellProcessRegistry`（锁式，收哨/退出清理）；`LoginShellEnvironment`（zsh -l 一次性捕获+5s 卡死兜底，M8 MCP 共用） | m7.3 |
| D7 成本面板 | `missionSpendBreakdown`（run 按伙伴聚合 + planning_tokens 事件求和）；头部「花销 ~Nk」签 → 分账浮层（伙伴/规划轮/合计对预算），口径标注「本地估算」 | m7.4-7 |
| D8 全局限流 | 重试耗尽的 429/overloaded 冒泡至 Orchestrator → 冷却期（默认 15s，可注入）挡新派发（在途不动），rate_limit_cooldown 事件 | m7.4-7 |
| D9 拆分第一刀 | **偏差申报**：未拆独立 store——@Observable 单实例模式下拆 store 需连带改全部视图注入，纯重构风险大于收益；新增哨卡状态/方法集中在 AppStore 的「哨卡（M7）」标记区，与 M8 第二刀合并执行真拆分 | m7.4-7 |

新增 EventKind 六个（approval_requested/approval_decided/autonomy_changed/camp_halted/camp_resumed/rate_limit_cooldown），测试断言全部钉裸字符串。

## 与计划的其它偏差（申报）

1. **429 全局冷却的覆盖面**：只处理「provider 内部重试耗尽后抛出」的限流错误（per-request 层已有 retry-after 退避）；provider 内部消化掉的 429 不触发全局冷却——计划已预判此取舍，落地一致。
2. **run_shell 进内置白名单集**：存量「空=全量」伙伴自动获得 run_shell 能力面——有意行为，危险面由审批矩阵把守（标准档必审）；显式 v2 名单伙伴不受影响。
3. **顺手修死一个既有计时抖动**：`timeoutThenSuccessDoesNotAccumulate`（M6 报告备案项）5ms 看门狗在并行负载下偶发——超时提至 60ms（hang 语义不变），复跑多次未再现。

## 验证

- `swift run RunTests`：264/264 绿（审批门全链路：挂起/一次性令牌/拒绝改道/标准档直行；shell：执行/退出码/超时终止/截断/注册表清理/登录 PATH；收哨：停派发+恢复续跑+事件；冷却：429→冷却→过点恢复，全部 Mock/真子进程驱动）。
- `swift build`（App 目标）通过。
- UI 截图循环（fixture 库直连）：行动头部三件（档位·标准菜单签/花销 ~52k 签/收哨红钮）、花销分账浮层（合计 52k/200k+口径）、收哨横幅（恢复出哨）、新行动表单自主档位分段选择+说明、设置页默认档位。

## 遗留

- 用户活体验收（`docs/superpowers/2026-07-07-m7-live-test.md`）→ 通过打 `m7` tag。
- 前置提醒：收官门（M4/M5）与 M6 正式测试仍在你手里排队；tag 顺序 m4→m5→m6→m7。
- 已知限制（申报）：shell 只终止直接子进程（孙进程靠超时兜底）；审批弹窗在放手档不出现（预算是唯一护栏）——live-test 专项盯审批疲劳体验。
