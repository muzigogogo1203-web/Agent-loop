# Implementation report

## Changed files

- `Sources/AgentLoopCore/Database/Records.swift`
- `Sources/AgentLoopCore/Provider/ProfileScopedDefaults.swift`
- `Sources/AgentLoopCore/Provider/ModelCatalogService.swift`
- `Sources/AgentLoopCore/Database/RuntimeProfileStore.swift`
- `Sources/AgentLoopCore/Product/RuntimeProfileBootstrap.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/Views/CompanionEditorView.swift`
- `Sources/AgentLoopTestSuite/ModelCatalogPolicyTests.swift`(新)
- `Sources/AgentLoopTestSuite/RuntimeProfileTests.swift`

## Implementation

按 plan 实现 T1–T7:`allowsManualModelEntry` 谓词收敛、三档钳制统一为 `clampModelSelections`、目录派生纯只读(`resolvedCatalog`,网关不再混入 cached)、对账统一为 `reconciliationReport` + `applyReconciliation`、OAuth 启动对账加 `oauthReconciled` 一次性标记、SettingsView/编辑器候选缓存。

## 分工与修复轮记录(Claude 补记)

- 首轮实现:Codex(session 019f7047,gpt-5.6-luna)。
- Review 01 发现 P0×4 / P1×3 / P2×2(编译错误 3 处、applyReconciliation 强解包与事务边界、测试 fixture 用错官方 host、T7 覆盖缺三组)。
- 修复轮:`codex exec resume` 连续两次静默失败(输出仅会话头,零改动),按协议兜底由 Claude 接管完成全部 P0/P1/P2 修复与测试补齐。

## 偏差说明(修正首版报告的「无偏差」)

- 首版 T7 只交付了 plan 六组测试中的两组半,且网关 fixture 误用官方 host 导致断言错误;修复轮已补齐:网关 refresh 落盘、applyReconciliation(含空 items 与幽灵档案容错)、bootstrap 幂等/尊重 D3、resolvedCatalog 官方与全空 fallback 用例。
- Codex 沙箱无法编译本仓库(模块缓存权限被拒),verify.log 中的构建失败为环境问题;权威验证由 Claude 在沙箱外执行,结果见 verify.log 追加段。

## Verification

见 `verify.log`(Claude 沙箱外实测追加):`swift build` 全绿;`swift run RunTests` 412 项,仅余 8 处本机环境性失败(worktree 路径过长导致 socketPathTooLong ×6、CLI 取消用例 ×2),与 HEAD 基线完全一致(baseline-failures.log),本次改动相关测试全绿。
