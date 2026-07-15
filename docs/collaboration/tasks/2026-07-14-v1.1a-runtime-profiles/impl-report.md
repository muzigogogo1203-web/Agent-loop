# V1.1a 供给线 Core 轮实施报告

日期:2026-07-14

## 完成范围

- 迁移 `v10-runtime-profiles`:仅建表和列,未在 migration 内读取 Keychain/UserDefaults。
- Runtime profile Core: `RuntimeProfileStore`, `RuntimeProfileBootstrap`, `ProfileScopedDefaults`, `ModelCatalogService`, `KernelDefaults.chatGPTStaticModels`。
- `CompanionRecord`:新增 `runtimeProfileId` 与 `modelPolicy`,既有伙伴默认 `pinned`。
- Orchestrator: `makeProvider` 扩参为 `(model, companionId?) -> (any LLMProvider)?`;卡片路径传 companion id,规划/蒸馏路径传 nil。
- AppStore:按 runtime profile 解析 provider,删除 `storedProviderCredential` 交叉回退,可信目录 fail-closed 记录 kernelError/toast,401/403 展示按档案 kind 分流。
- AppStore 供给线逻辑钩子:保存/删除/切默认、对账选择应用、目录刷新、目录候选、credential account 映射。
- 测试:新增 `RuntimeProfileTests.swift`,并同步既有 Orchestrator 测试闭包签名。

## 验证

- `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests`
  - 结果:**389/389 通过,3 suites**
  - 完整输出已保存到 `docs/collaboration/tasks/2026-07-14-v1.1a-runtime-profiles/verify.log`
  - `keychainRoundTrip` 本轮通过,未遇到已知 `-50` sandbox 限制。
- `swift build --product AgentLoopApp`
  - 结果:在当前 Codex sandbox 下失败于 Swift/clang module cache 权限,错误为无法写 `/Users/muzi/.cache/clang/.../SwiftShims-*.pcm`。
- `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift build --disable-sandbox --product AgentLoopApp`
  - 结果:**通过**,`Build of product 'AgentLoopApp' complete!`

## 当前工作区注意事项

- 未执行 commit/reset/checkout。
- 当前 HEAD 为 `ae4ead3 feat(v1.1a.ui): 供给线 management UI, reconciliation sheet, profile-aware companion editor`;该提交在本轮验证过程中由外部推进,非本次 Codex 执行提交。
- 当前工作区剩余:本文件(`impl-report.md`)未提交修改,以及外部未跟踪文件 `docs/collaboration/tasks/2026-07-14-v1.1b-cli-backends/plan.md`。
- 本轮未用编辑工具修改 `Sources/AgentLoopApp/Views/`。AppStore 逻辑钩子已满足当前 HEAD 中 UI 文件的编译需求。
- 任务目录中原有 `pre-impl-status.txt` 保留未动。
