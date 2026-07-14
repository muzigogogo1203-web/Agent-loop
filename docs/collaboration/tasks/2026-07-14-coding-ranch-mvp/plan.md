# Coding 牧场 MVP 实施计划

日期：2026-07-14

## 权威输入

- `/Users/liyongwan.3/Desktop/heima-joyinside-workspace/02_product/Coding牧场-AgentLoop应用层产品化改造方案-v1.md`
- `/Users/liyongwan.3/Desktop/heima-joyinside-workspace/02_product/Coding牧场-UI实施任务书-Claude-v1.md`
- 仓库 `AGENTS.md`

## 基线

- 起始提交：`a823d81e099ded877510f684bcfb6fd27313324a`
- 权威测试：`swift run RunTests`
- 已知用户文件：`.understand-anything/`，不得修改或删除

## 实施范围

1. Coding 牧场 App 层品牌、术语和导航；
2. 幂等默认营地、基础牛和营地管家初始化；
3. 主动文本喂牛、待反刍区和结构化反刍；
4. 反刍确认后原子写入营地笔记、来源关系和行动候选；
5. 候选转换现有 Mission，继续使用 Orchestrator；
6. 从真实 Mission、Artifact、来源和确认事件派生新手进度；
7. 满足规则后幂等领回测试牛；
8. SwiftUI 首页、反刍、Coding 草原、回营、牛棚和 Preview；
9. 保持既有专家功能和 333 项测试行为。

## 禁止范围

- 硬件、录音、JoyInside、设备协议；
- 浏览器扩展、URL 自动抓取和 PDF 解析；
- AgentExecutionRuntime、云端迁移；
- 向量数据库、完整知识图谱；
- 修改 Mission/Card 状态机；
- 大规模重命名 Core 类型或数据库表；
- 删除或重置用户数据。

## 实施顺序

### P0 共享契约

- App 层 ViewState、Store protocol 和 Preview fixtures；
- Core 稳定 CowTemplate 与 ProductBootstrapService；
- 新老用户兼容和幂等测试。

### P1 喂牛与反刍

- migration v8；
- ingestion_item、rumination_result、knowledge_source_link、action_candidate；
- FeedService、RuminationService、严格 JSON 解析和错误恢复；
- 物化事务与测试。

### P2 UI 并行

- UI 子代理只改 AgentLoopApp/Views、Theme 与薄装配；
- 使用共享 ViewState/protocol 和 fixtures；
- 缺少接口写入 `ui-interface-needs.md`，不得修改 Core。

### P3 Mission 与解锁

- MissionDraftFactory；
- action_candidate 到 Mission 幂等转换；
- 显式来源/笔记关联；
- NewcomerUnlockPolicy 和稳定测试牛模板；
- 真实 Store 接线。

### P4 集成与验证

- 合并 UI 与功能；
- Golden Path；
- `swift run RunTests` 全绿；
- 完整输出保存到本目录 `verify.log`；
- 写 `impl-report.md`。

## 完成门槛

- 全新数据库首次启动出现“我的营地”和“基础牛”；
- 用户粘贴文本，反刍后确认形成带来源营地笔记；
- 可从建议任务启动现有 Mission；
- 回营后真实证据驱动测试牛 eligible；
- 领回测试牛幂等；
- 旧用户数据和专家入口保留；
- 原有测试与新增测试全部通过。
