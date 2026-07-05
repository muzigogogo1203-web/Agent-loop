# M3 并发与交互 — 验收记录（草稿，待用户正式测试）

日期：2026-07-05 ｜ 分支：`feat/m3`（基于 tag `m2`）｜ 流程：plan 经用户确认（Level 3）→ Codex 实现 → Claude 五路 review → 修复轮 ×2（第二轮为单点加固）。

## 改了什么（对照 plan v3 十项目标全数落地）

- **多伙伴并发**：per-companion 阀门（RunningEntry 注册表 + 两段式派发：事务内候选/缺伙伴 block，事务外无 await 循环）；同伙伴串行、异伙伴并发；跨 mission 确定性排序。
- **ask_user 持久门**：工具 schema + 单事务 suspend（request + blocked + 事件）+ 收紧 guard 的 answerUserRequest（requestId 匹配）+ 冷重启问答注入；提问不堵其他伙伴；needs_human_input 卡行只显「去回答」。
- **空闲挂起检测超时**：deadline 制 IdleWatchdog（每事件重置），同轮两次超时 → blocked(tool_failure)；取消严格优先于超时（CardRunner 级 DB 断言锚点 `cancelDuringArmedTimeoutLeavesCardReady`）。
- **小队动态流**：事件表驱动 FeedEntry 纯函数映射 + 右栏气泡流 + 多 pending 按序答题区（带卡题）+ 收营 CTA；作答即时 emit 刷新。
- **行动列表与导航状态机**：侧栏最近 20 行动 + 徽标 + 右键放弃；Destination 重构（.newMission/.mission）；事件按 currentMissionId 过滤不串台；启动领养（重启后遗留行动可见可调度）。
- **详情面板**：.inspector（时间线/交接包/Run 历史/产物/开发者视角），DB 读经 .task 缓存。
- **七态动画 + 篝火小剧场**：AnimStateDeriver 纯函数（当前 mission 作用域）；七态各有代码绘制微动画 + reduceMotion 静态姿势/角标；篝火 2 帧火苗 + 3 点火星 + 规划中向导摊地图场景；统一 paused（reduceMotion‖失焦）；清单⇄小剧场切换 + 30s 交互重置脉冲。
- **kernel_error 落库**（4 个带 missionId 的 emit 点）。

## Review 轮次

- 01-claude-review（五路并行 + 本人复核）：P1×3（小剧场缺规划场景且 live-test 被削减未申报、D4 取消优先零测试锚定、「新行动」按钮空白页陷阱）、P2×11、P3 若干。
- 修复轮 1：全部 P1/P2 + 便宜 P3 落地；**申报纪律已纠正**（live-test 恢复 plan 原文检查项）。
- 修复轮 2（单点）：CardRunner 增 turnTimeout 注入 + 取消/超时严格锚点测试（DB 副作用断言，防「取消误判超时」回归——历史 bug 类）。
- Claude 直接微调 ×1（Level 0，已申报）：慢流测试时间常量放大（并行负载下假失败，单跑全绿实证）。

## 验证

- **真机（权威）**：`swift run RunTests` 连续两轮 **138/138 全绿**（~1.27s）；`swift build` 干净。
- 覆盖：并发区间重叠/同伙伴串行/取消竞速、ask_user 全链路（含 guard 拒绝与多轮问答）、超时三态（超时转 blocked/不累计/慢而活不误杀）、feed 映射、动画派生矩阵、金路径升级版（两卡依赖 + 中途问答 + 下游冷启动，spec §15-4 完整形态）。

## 残留（已接受，见 plan「已接受的残留风险」）

- UI 层无自动测试，押在用户正式测试；空闲检测真机断网行为待 live-test 第 7 步验证。
- 多 mission 并行无全局预算节流（M5）。

## 用户正式测试

按 `docs/superpowers/2026-07-05-m3-live-test.md`（7 步）。通过后打 `m3` tag，本记录转正。

---

**2026-07-05 用户正式测试通过，M3 收口（tag `m3`）**。含三轮 UI 重做（m3.1 营地感设计系统 / m3.2 详情弹层+侧栏锁定 / m3.3 双栏开关+宽度自适应+弹窗瘦身+气泡解析），UI 分工变更为 Claude 亲自实现并以截图循环自验。遗留：网关中转在大体积 tool_use 流上频繁断流/超时（另开任务 gateway-resilience 处理）。
