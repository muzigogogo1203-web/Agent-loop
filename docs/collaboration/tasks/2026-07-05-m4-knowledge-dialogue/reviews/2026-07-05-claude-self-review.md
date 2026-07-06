# M4 评审记录（2026-07-05）

原计划为五路多智能体对抗评审（并发/数据层/契约申报/LLM 卫生/UI）。工作流启动后五路 agent 均因**用户会话额度触顶**（resets 3:20pm PT）被拒，无法执行。改为 Claude 主循环内按同一五镜头清单自查（代码均为本会话所写、上下文完整）。额度恢复后可按 `plan.md` 的评审要求补跑多智能体轮。

## 确认并已修复

| # | 严重度 | 发现 | 修复 |
|---|---|---|---|
| 1 | P2 | **非流式兜底 × 聊天层 delta 累积 = 文本重复**。gateway 兜底会在断流后重发合并全文 textDelta；ChatService/GuideChatService 用累积 delta 构造落库正文，断流场景下气泡与落库文本重复拼接（卡片执行不受影响——AgentLoop 只用 TurnResult） | Provider 断流前已流出增量时兜底不再重发合并 delta（`suppressMergedTextDelta`）；ChatService/GuideChatService 改以 TurnResult 为落库权威（delta 只管显示）。新增 2 组测试断言两种兜底路径 |
| 2 | P3 | **切走沉淀竞态**：快速来回切 DM 线程时，两个在途 distillDM 可能读到同一批未蒸馏增量 → 重复记忆条目 | AppStore `autoDistillInFlight` 在途防重 |
| 3 | P3 | **预览模式读钥匙串**（截图循环中实证）：autoDistillOnLeave/沉淀按钮经 provider() 触发系统授权弹窗 | `provider()` 在 isUIPreview 下直接返回 nil（预览语义=不读钥匙串），LLM 动作统一得到「请先填 key」提示 |
| 4 | P3 | **宽度自适应阈值错基准**（截图循环中实证）：营地首页 860 阈值量的是 detail 宽度，默认 1060 窗口下笔记本被误收起 | 阈值改 780 并注明基准；已申报 impl-report |
| 5 | P3 | GuideChatService 中间轮 turnText 被丢弃（`_ = turnText`），重启后向导的过程性发言丢失 | 随 #1 修复：各轮 turnText 依序落库（join） |

## 核对未见问题（要点摘录）

- **提案 CAS**：确认幂等（二次抛 StaleProposalError）、驳回、补偿回滚、missionId 回写均有测试；「CAS 后建队前崩溃 → 提案停在 confirmed 无 mission」为 plan D10 明示取舍（宁可回滚不重复建队），UI 对 confirmed-无-missionId 有降级展示。
- **proposal 解析容错**：普通 `{"text":…}` 或含 "squad_proposal" 字样的文本消息不会误判（必填字段缺失 → decode nil + type 校验）。
- **LIKE 检索**：`\ % _` 转义 + 参数化查询 + ESCAPE 子句；空查询短路。
- **迁移 v3**：仅新增表+索引，老库(v1/v2)升级路径干净；fresh DB 全量可重放（198 测试均走全迁移）。
- **注入纪律**：D2 数值（800/150/3）与顺序（置顶 ASC→最近 DESC；营地→记忆→上游交接）逐点有测试；prompt 模板无时间戳；system 前缀仅追加确定性契约条款（缓存友好）；营地笔记注入走 user 消息不动 system。
- **已知雷类**：intValue 溢出（budget 走 intValue→Int 精确转换+正数校验）、JSON 键序（提案块/事件均 sortedKeys）、退避算术（沿用 DurationProtocol 乘法）、取消卡死（GuideChat 取消不落库、CardRunner 语义未动）、artifacts 键（未触碰）。
- **事件三件套**：camp_note_created(source: closeout/fallback/guide_chat)、companion_note_created、squad_proposal_confirmed 均落库且有测试。
- **Swift 6 并发**：全量编译零警告口径未变；@Observable MainActor 状态只在主线程动。

## 验证

- `swift run RunTests`（沙箱跑法 + CLANG_MODULE_CACHE_PATH）：**198/198 绿 ×2**（见 verify.log）。真机 `swift run RunTests` 复跑为准（用户正式测试前建议再跑一次）。
