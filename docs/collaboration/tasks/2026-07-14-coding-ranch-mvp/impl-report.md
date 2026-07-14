# Coding 牧场 MVP 实施报告

日期：2026-07-14

基线：`a823d81e099ded877510f684bcfb6fd27313324a`

## 结果

已完成 AgentLoop 的应用层 Coding 牧场 MVP 改造，保留原有执行内核、Mission/Card 状态机、专家能力和本地状态目录。应用窗口与用户可见主术语改为 Coding 牧场；内部 target、Core 类型和历史数据路径保持兼容。

主路径已经接通：

1. 首次启动幂等创建默认营地、营地管家和基础牛；已有普通伙伴的老用户不被强制补基础牛；
2. 用户粘贴文章、资料或想法，原文先落库并进行同营地重复提示；
3. 反刍在后台通过现有 LLMProvider 无工具执行，提供 queued/ruminating/needsReview/failed/materialized 状态与重试；
4. 用户确认后，在单个事务中写入营地笔记、来源关系、行动候选和领域事件；重复确认不重复写入；
5. 建议任务形成可编辑放牛草稿，显式带入来源笔记和验收清单，并调用现有 `Orchestrator.startMission`；
6. 回营验收继续使用现有 artifact、card 和 closeout 能力；
7. 解锁进度从来源笔记、已转换 Mission、真实 artifact、用户确认和 accepted 状态派生；满足后幂等创建测试牛。

## Core 与数据

- migration `v8-coding-ranch`：`ingestion_item`、`rumination_result`、`knowledge_source_link`、`action_candidate`；
- `FeedService`：本地先保存、SHA-256 重复检测、保留原文和删除边界；
- `RuminationService`：无工具严格 JSON、确定性外层对象修复、失败保留原文、后台进度；
- `RuminationMaterializer`：营地笔记、来源和候选原子物化；
- `MissionDraftFactory`：候选草稿、来源注入、转换幂等关联；
- `ProductBootstrapService` / `CowTemplate`：稳定基础牛和测试牛模板；
- `NewcomerUnlockPolicy`：从权威记录派生进度并原子解锁。

## App 与 UI

- 增加纯 ViewState/Store protocol 边界和真实 `AppStore` adapter，UI 不直接复制数据库或解锁规则；
- 保留原有“左侧营地笔记本 + 右侧营地管家”的营地主页面，只在页头增加紧凑的“喂牛 / 待反刍”入口；
- 待反刍、进度、结果确认和放牛草稿都在营地内部 sheet 完成，不为每个营地增加重复侧栏项；
- `RootView` 恢复原有营地、进行中任务、归营和牛群层级，并保留全局停营 banner、设置和专家功能；
- 任务执行页改为 Coding 草原/基础牛/回营术语；
- 使用传统 `PreviewProvider`，避免 SwiftPM Command Line Tools 缺少 Preview macro plugin；
- 窗口标题改为“Coding 牧场”，最小宽度降为 640；
- 状态目录继续使用 `Application Support/AgentLoop`，避免迁移或丢失已有数据。

## 验证

- `swift build`：通过；
- 临时 `AGENTLOOP_STATE_DIR` + preview 模式启动应用：通过，无初始化崩溃；
- `swift run RunTests`：342 项全部通过；
- 完整测试输出：`verify.log`。

新增测试覆盖：迁移从 v7 回放、初始化幂等、老用户兼容、重复投喂、无工具反刍、后台进度、失败重试、物化幂等、Mission 转换幂等、真实任务证据解锁和重复领牛。

## 明确未做

- 硬件、录音、JoyInside、设备协议；
- 浏览器扩展、URL 自动抓取、PDF/文件解析；
- 向量数据库、知识图谱和自动历史再反刍；
- 重命名 `AgentLoopCore`、Swift target、历史表或既有状态目录；
- 通用成长经济、多条解锁树。

这些内容仍按产品方案留在后续阶段，不是本次 MVP 的假入口。
