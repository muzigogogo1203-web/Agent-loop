# M9 实现计划 v1 — 归营清点（战利品中心 + 远征报告 + 共事记录 + 卡级退回 + 营地归档）(Level 3，待用户过目)

> 基于 feat/m6 + V2 设计 §5-M9。前置：M8 验收通过（本里程碑刻意排在最大深水区之后作缓冲垫；与 M8 无强依赖，若 M8 延期可与用户商议换序）。
> **Level 3 项：① 卡级退回状态机手术（done→ready 新增转移）② 迁移 v7（camp.archived + card.reviewFlag）**。
> 附注：主循环自写自查（子代理评审因额度触顶未跑，可补）。

验收（V2 设计 §5-M9 活体验收）：**跑完一次 ≥3 卡真实远征后，战利品中心可见并预览历史全部交付物；远征报告随收营落盘且内容与事实一致；退回一张已完成卡并附意见，同伙伴重做、产物 v2 落盘、下游卡出现待复核标记、全程事件可查；参战伙伴的共事记录出现在其下一次行动的上下文中。**

## 现状盘点（已逐条核实）

- **状态机**：`Records.swift:10-20` CardStatus.canTransition 穷举——**done 无出边**（终态），退回=新增 `done→ready` 转移；`Records.swift:28` MissionStatus.rollup：accepted/failed 不可逆，其余按卡片推导——**退回把一张卡变非终态后，delivering 会自然回落 executing**（:41-42 的 contains 非终态分支），需专项测试钉住。
- **产物耐久路径有覆盖隐患**：`BoardTools.swift:58` copyItem 到 `artifactStoreRoot/<cardId>/<relativePath>`——**同卡重跑同名产物会 copy 失败/覆盖**，退回重做必须处理（D4）。artifact 表 (id, cardId, path, kind, label, createdAt)，每次 complete 插新行。
- **收营蒸馏管线**：`Distiller.swift:46` distillCloseout(goal:cards:[CardDigest]) → 营地笔记，失败确定性回退（:160 拼接，无时间戳）；`Orchestrator.closeout` → scheduleCloseoutDistillation 旁路异步。远征报告与共事记录都挂这条钩子。
- **记忆管线**：`MemoryDistillService`（autoMinMessages=4、distillDM(minMessages:)、distillGuideChat）+ `Distiller.distillMemory`（:63）——共事记录复用 distillMemory 形状；闲置阈值蒸馏复用 autoDistillOnLeave 既有管线。
- **外键图**（实测 schema）：camp ←4（squad/companion(guide)/camp_note/chat_thread）、card ←3（run/artifact/user_request）、mission ←2（card/event）、chat_thread ←2（chat_message/companion_note.sourceThreadId）。**event 表有 BEFORE UPDATE/DELETE 触发器（追加式硬约束）——「级联删除」与它正面冲突**，见 D6。
- 事件与投影同事务纪律、`EventKind` 命名空间、QuickLook（QLPreviewPanel/quickLookPreview modifier macOS 14 可用）。

## 决策（D1–D8，待用户过目）

| # | 决策 | 理由 |
|---|---|---|
| D1 | **战利品中心**：侧栏全局区新入口「战利品」→ 视图按营地→行动分组聚合 artifact 表（跨营地投影，零迁移）；每件支持 QuickLook 预览（`.quickLookPreview` 绑定 URL）+ Finder reveal；**钉选存 UserDefaults（[artifactId] 数组）**不动 schema——钉选是个人视图偏好非事实 | 纯投影 UI；钉选进 DB 是过度建模 |
| D2 | **远征报告 = 确定性生成，不走 LLM**（设计补遗）：收营时由事件日志 + 各卡交接包 + 花销数据拼装 markdown（时间线人话化复用 ActivityFeed 映射、产物清单、各伙伴贡献=卡数+tokens、总花销），写入 `Application Support/AgentLoop/reports/<missionId>.md`；行动页与战利品中心给「远征报告」入口（QuickLook + reveal）。**不进 artifact 表**（该表 REFERENCES card，报告是行动级产物，不为此动 schema）；蒸馏营地笔记照旧走 LLM | 报告是数据整理不是概括任务：零成本、零幻觉、内容必然与事实一致（正中活体验收判据） |
| D3 | **共事记录**：closeout 钩子里对参战伙伴（done 卡 assigneeId 去重）各生成一条 CompanionNoteRecord（title 前缀「共事·<行动名>」，sourceThreadId=nil）；输入源**仅限交接包摘要 + 行动元数据**（V2 §7-2 记忆污染边界：不喂网页原文）；走 Distiller.distillMemory，失败跳过不阻塞收营；注入沿用置顶+最近 3 条既有机制 | 护城河 8:2 里最便宜的兑现；管线全部现成 |
| D4 | **卡级退回（Level 3 状态机手术）**：① canTransition 增 `done→ready`（穷举测试同步）；② 入口=详情弹层 done 卡「退回重做」+ 意见必填；③ 同事务：转移 + `EventKind.cardReturned`（payload 含意见）+ 下游依赖卡（dependsOn 含它且已 done）标 `reviewFlag='stale_upstream'`（迁移 v7 加 `card.reviewFlag TEXT`），**不级联重跑**；④ 重跑上下文 = 原上下文包 + 「上次交付被退回，用户意见：…」+ 原交接包摘要（进 answeredRequests 同位注入）；⑤ **产物防覆盖**：BoardTools 耐久目的地已存在同名文件时自动加 ` (2)` 序号后缀，artifact 新行 label 标「(重做)」——v1 保留不覆盖（产物先耐久不变量）；⑥ **仅收营前可用**（mission ∈ executing/delivering），accepted/failed 不可逆语义不动；⑦ 待复核 UI：卡片行琥珀「待复核」签，点开可一键清除标记或也退回 | 全部按设计 §5-M9 保守语义；rollup 自然回退 delivering→executing 补专项测试 |
| D5 | **闲置自动蒸馏**（spec 开放问题 4 收口）：DM 视图内 5 分钟无新消息且未蒸馏增量 ≥4（autoMinMessages）→ 静默触发既有 autoDistillOnLeave 管线；阈值常量进 KernelDefaults，不加设置项 | 复用切走管线，改动一个 timer；可配置是伪需求 |
| D6 | **营地归档（迁移 v7 加 `camp.archived INTEGER NOT NULL DEFAULT 0`）**：归档=侧栏隐藏（收进「营地档案」折叠区）+ 只读（禁新行动/禁向导发言/笔记只读）；**「删除」在 V2 = 归档语义**——设计文档写的「删除+级联清理」与 event 追加式触发器（禁止 DELETE）正面冲突，物理级联需要先设计事件保留策略，**申报为设计偏差、物理删除进 V3**；归档走二次确认，记 `EventKind.campArchived` | 宁可少一个功能，不破「事件不可变」这条命根子不变量 |
| D7 | **AppStore 绞杀第三刀**：`HarvestStore`（战利品/报告/钉选/成本视图状态）拆出；若 M8 顺延了 StreamSession 合并，在此一并完成 | 设计明示的第三刀 |
| D8 | 实现顺序上**退回手术放最后压轴**：D1/D2/D3/D5/D6 全是低风险投影或管线复用，先落，让里程碑始终有可交付增量；状态机手术独占最后一段带全量回归 | 风险后置 + 缓冲垫定位（设计 §3） |

新增 EventKind：`cardReturned`/`cardReviewCleared`/`campArchived`。迁移 v7：card.reviewFlag + camp.archived（一次迁移两列）。

## 触及面

- Core：`Database/Records.swift`（canTransition + reviewFlag 字段）、迁移 v7、`Database/BoardCardTransactions.swift` 或 BoardTools（防覆盖后缀）、`Kernel/Orchestrator.swift`（closeout 钩子扩展：报告生成 + 共事记录；退回入口方法）、`Knowledge/`（报告生成器新文件 ExpeditionReport.swift）、EventKind +3。
- App：战利品中心视图（新）、详情弹层退回 UI + 待复核签、DM 闲置 timer、营地归档 UI（侧栏折叠区 + 只读态）、`HarvestStore` 拆分。
- 测试：+20±（done→ready 穷举、rollup 回退专项、退回事件与 reviewFlag 同事务、重做产物防覆盖、退回仅收营前、报告内容与事件一致性（golden path）、共事记录生成与注入闭环、闲置阈值触发/不触发、归档只读约束、v7 迁移）。

## Open questions（待用户拍板）

1. **D6 设计偏差**：V2 的「删除营地」降级为归档语义（物理级联删除与事件追加式触发器冲突，进 V3 与事件保留策略一起设计）——接受？
2. **D2 远征报告确定性生成**（零 LLM 成本、内容必然属实）而非蒸馏概括——OK？
3. **D4-⑤ 产物防覆盖**：同名加 ` (2)` 后缀 + label 标「(重做)」——OK？
4. 战利品中心入口放**侧栏全局区**（与伙伴名册同级）——还是营地首页内？推荐全局（跨营地聚合的定位）。
