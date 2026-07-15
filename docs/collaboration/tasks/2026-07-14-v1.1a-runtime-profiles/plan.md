# V1.1a 供给线(运行时档案)Core 轮实施计划

日期:2026-07-14
分支:feat/v1.1
母计划:`docs/collaboration/tasks/2026-07-14-oauth-model-cli-integration/plan.md` §V1.1a(D1-D4 已决策完备,拍板记录在末节)
本轮范围:**Core + AppStore 逻辑层**。SettingsView/CompanionEditor/对账 sheet 等一切 SwiftUI 视图不做(Claude UI 轮负责)——Views/*.swift 不得改动。

## 实现契约(母计划之外的落地决策,按此执行)

1. **迁移只建表**:`v10-runtime-profiles` 仅创建 `runtime_profile` 表与 companion 两列(runtimeProfileId TEXT NULL、modelPolicy TEXT NOT NULL DEFAULT 'pinned')。**种子不进迁移**(迁移内不得碰 Keychain/UserDefaults)。
2. **种子走引导服务**(仿 ProductBootstrapService 模式):新文件 `Sources/AgentLoopCore/Product/RuntimeProfileBootstrap.swift`,输入为值结构 `SeedInputs { apiKeyPresent, apiFormat, apiBaseURL, oauthTokenPresent, preferredSource }`(App 层从 Keychain/UserDefaults 读好传入,Core 可测)。幂等:runtime_profile 非空则跳过。种子规则见母计划 D1。
3. **档案命名空间设置**:新类型 `ProfileScopedDefaults`(Core 或 App 皆可,倾向 App):key 形如 `profile.<id>.defaultModel` / `.distillModel` / `.plannerModel` / `.modelChoices`;bootstrap 时把现有全局值拷入默认档案命名空间(仅当目标 key 不存在,幂等),旧全局 key 保留不读。AppStore 的 defaultModel/distillModel/plannerModel/modelChoices 属性改为读写「当前默认档案」的命名空间(didSet 落盘路径改)。
4. **Orchestrator makeProvider 闭包扩参**:`(model: String) -> (any LLMProvider)?` → `(model: String, companionId: String?) -> (any LLMProvider)?`。Core 侧:CardRunner 装配处传 companion.id;规划/蒸馏/管家路径传 nil(= 默认档案)。这是唯一的 Core 签名变更,注意同步全部调用点与测试。
5. **解析链(AppStore)**:`resolveProvider(model:companionId:)` 顺序:companionId → companion.runtimeProfileId(NULL=默认档案)→ 档案 kind 决定凭据(anthropic_api/openai_api → 档案 credentialAccount 指向的 Keychain 值 + baseURL;chatgpt_oauth → oauth token + OpenAIResponsesProvider + 现有 tokenRefresher)→ modelPolicy(inherit → 档案命名空间 defaultModel;pinned → 传入 model)。**fail-closed 目录判定**:档案目录可信(官方 anthropic/openai 域名或 chatgpt_oauth 静态表)且 pinned 模型不在目录 → 返回 nil,同时记 kernelError 事件(人话:「<伙伴名>钉着 <model>,供给线「<档案名>」没有这个模型」)并 showToast。网关(非官方域名)不做该判定。
6. **静默回退删除**:`storedProviderCredential` 的交叉回退逻辑删除;webCredentialPresent/apiKeyPresent 语义不变(UI 展示用)。`ProviderError.unauthorized` 的 description 保持通用,**分流在展示层**:AppStore 现有错误人话化处(readableError/CampCopy 一侧)按当前档案 kind 输出「ChatGPT 登录已过期,请在设置重新登录」或「API key 无效或无权限」。
7. **ModelCatalogService**(`Sources/AgentLoopCore/Provider/ModelCatalogService.swift`,actor):`catalog(profile:) -> [String]?`(nil=不可信/未获取)、`refresh(profile:credential:) async throws -> [String]`(GET <baseURL>/models,anthropic 走 `/v1/models` 兼容、openai 走 `/v1/models`,20s 超时,解析 data[].id);缓存与 fetchedAt 存 ProfileScopedDefaults;chatgpt_oauth 返回 `KernelDefaults.chatGPTStaticModels`(新常量,起步:["gpt-5.5"])∪手动追加。手动未验证 id 存档案命名空间 `manualModels`。
8. **RuntimeProfileStore**(`Sources/AgentLoopCore/Database/RuntimeProfileStore.swift`,extension AppDatabase):CRUD + `defaultProfile()` + `setDefaultProfile(id:)`(事务内旧默认清零/新默认置一,CAS 风格)+ 删除档案守卫(被伙伴引用或 isDefault 时拒绝,抛人话错误)。
9. **对账数据接口**(UI 轮消费):`reconciliationReport(switchingTo profileId:) -> [ReconciliationItem]`(伙伴/三档设置中 pinned 模型不在目标档案可信目录者;网关目标档案返回空)。纯查询,不改写。

## 测试要求(Sources/AgentLoopTestSuite/RuntimeProfileTests.swift 新文件,~16 项)

迁移 v10 回放(从 v9 起);种子矩阵(仅 key/仅 oauth/双有 preferred 分流/皆无);种子幂等;companion 两列默认值与既有行为不变;setDefaultProfile 唯一性;删除守卫;解析链矩阵(pinned/inherit × 指定档案/NULL);fail-closed 判定(官方目录内外 + 网关跳过);目录刷新解析与失败保留缓存(URLProtocol stub,沿 per-test class 模式);ProfileScopedDefaults 拷贝幂等;makeProvider 扩参后既有路径(companionId=nil)行为不变。

## 验证命令

```
CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests
swift build --product AgentLoopApp
```

## 完成定义

全量测试绿(376 基线 + 新增);App 构建过;不触碰 Views/;不 commit;不重置工作区;impl-report.md + verify.log 落本目录。
