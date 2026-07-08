# M6 计划评审 01 —— plan v1 → v2（2026-07-07，子代理评审，Claude 修订）

**Verdict: issues_found**（无 P0；2 P1 + 5 P2，全部已修入 plan v2。评审员总体判断：计划质量高，现状盘点基本全部属实，D1-D13 骨架成立，修补后可开工。）

## 事实核查结论

计划「现状盘点」九条断言逐条抽查：八条完全属实（CardRunner 双消费点、GuideChatService:152 switch 与 propose_squad 捕获约束、WebFetchTool「字节判断+字符截断」真 bug、KeychainStore 单 account、defaultModel 无回读真 bug、Planner usage 丢弃、toolsJson 零读取、事件 kind 实测 24 种）；一条措辞偏差（P2-1，饱和加法内联在 finishRun、非独立函数）。

## 问题与处置

| # | 级别 | 问题 | 处置（plan v2） |
|---|---|---|---|
| P1-1 | P1 | 白名单**保存语义**未决（「全勾」写 `"[]"` 还是显式列表）——M8 MCP 继承白名单的地基螺栓，两种写法在 M8 行为分叉 | 新增 **D5b**：编辑器永远写显式列表；`"[]"` 仅存量兼容读语义，且「空=全量」只覆盖内置工具、外部/MCP 工具必须显式勾选；存量伙伴配 key 后获得 web_search 定为有意行为（只读）。列入 Open question 2 请用户确认 |
| P1-2 | P1 | 设计 §5-M6 点名「蒸馏/**规划**轻任务可配轻量模型」，规划模型未被覆盖（AppStore:218/:820 锁死 defaultModel） | D12 增「规划用模型」设置，与蒸馏项同构 |
| P2-1 | P2 | 「饱和加法入账函数已存在」不准——内联于 finishRun 且依赖 run 行 | 盘点措辞修正；D13 改为新增 `addMissionSpentTokens`，并写明跨轮累计口径（含 fallback 路径入账） |
| P2-2 | P2 | ContextPacket 无工具清单节；工作契约规则 6 硬编码 write_file，白名单剔除后成裂缝 | D4 补渲染规则：规则 6 随 write_file 在场性渲染；文件工具不可用两种成因统一措辞 |
| P2-3 | P2 | WebSearchTool 超时/失败行为未指定；无 key 时编辑器勾选表现未定 | D6 补专用 URLSession/20s/.error 自愈；D5 补置灰+去设置提示；测试清单补超时/无网项 |
| P2-4 | P2 | 注入防线只做了包裹、漏了 system prompt 硬化（设计 §7-2 是两件套） | D9 补硬化条款（与 D4 同一施工面） |
| P2-5 | P2 | 「全仓机械替换+测试兜底」自相矛盾——测试字面量若也被替换则兜底失效 | D2 补约束：仅替换生产代码，测试断言保留裸字符串钉住持久化值 |

## 评审员定向核查（风险面）

- 向导 switch→ToolExecutor 合流对**提案确认闭环**影响：低——CAS 确认/回滚/崩溃自愈全在 Orchestrator/DB 层，与分发机制正交；GuideChatTests 兜底。
- ClosureToolHandler 与 Swift 6 严格并发：无坑——ToolHandler 已要求 Sendable，continuation 可安全捕获。
- 测试可行性：WebFetchTests 已有 URLProtocol stub 基建，新测试可落地。
