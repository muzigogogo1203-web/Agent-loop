# V1.1a 供给线 Core 轮实施报告

日期:2026-07-14
(注:Codex 两次执行均受本机多谱系文件视图影响,产物经真实磁盘收敛后由 Claude 前台验证定稿;本报告以前台最终状态为准。)

## 完成范围

- 迁移 `v10-runtime-profiles`:仅建表——runtime_profile(kind CHECK、isDefault 部分唯一索引)+ companion 两列(runtimeProfileId 可空外键、modelPolicy CHECK inherit/pinned 默认 pinned)。
- `RuntimeProfileStore.swift`(165 行):Record + CRUD、defaultProfile/setDefaultProfile(事务内换默认)、删除守卫(被引用/默认拒绝)、reconciliationReport(switchingTo:) 纯查询。
- `RuntimeProfileBootstrap.swift`(137 行):SeedInputs 值结构、幂等种子(四种凭据组合)、凭据 account 常量单一来源(AppStore.apiKeyAccount 改引用此处)。
- `ModelCatalogService.swift`(123 行):/v1/models 拉取(20s 超时)、缓存+fetchedAt、失败保留缓存、chatgpt_oauth 静态表 ∪ manualModels;KernelDefaults.chatGPTStaticModels。
- `ProfileScopedDefaults.swift`(132 行,置于 Core/Provider):profile.<id>.* 键读写 + 全局旧值拷贝(幂等)。
- Orchestrator:makeProvider 闭包扩参为 `(model, companionId?) -> (any LLMProvider)?`,新增 typed `ProviderUnavailableError`(比计划的 nil 语义更进一步:规划/装配路径抛出人话错误);CardRunner 装配传 companion.id,规划/蒸馏/管家传 nil。
- AppStore:`resolveProvider(model:companionId:)` 解析链(伙伴→档案→凭据→modelPolicy)+ fail-closed 可信目录判定(kernelError 事件 + toast);`storedProviderCredential` 交叉回退删除;unauthorized 展示层按档案 kind 分流;isUIPreview 跳过种子。
- makeProvider 扩参波及的既有测试全部同步(AskUser/Budget/CrashRecovery/GoldenPath/GuideChat/Halt/KnowledgeGoldenPath/Mcp/MultiCamp/Orchestrator 等)。

## 验证(Claude 前台真机)

- `swift run RunTests`:**389/389 全绿(3 suites)**,verify.log 归档本目录;
- `swift build --product AgentLoopApp`:通过;
- Views/ 未触碰(git status 证实)。

## 偏差

- ProfileScopedDefaults 放在 Core/Provider(计划允许两可,便于 Core 测试);
- ProviderUnavailableError 为计划外增强(nil → typed error),review 判定为改善非越权;
- 测试计数与 Codex 自报(19 项/395)略有出入,以前台收敛后的 389/389 为准。
