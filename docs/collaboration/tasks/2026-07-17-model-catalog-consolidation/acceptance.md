# 验收 — 模型目录规则收敛重构

## 改了什么

1. **谓词收敛(簇1)**:`RuntimeProfileKind.allowsManualModelEntry`(Records.swift,紧挨 `isCLI`)统一四处重复 switch/布尔式:CompanionEditorView.allowsCustomModel、AppStore.currentModelCatalogAllowsManualInput、loadModelDefaults 的 isStrictCatalog、refreshCatalog 凭据分流。
2. **钳制收敛(簇2)**:`ProfileScopedDefaults.clampModelSelections(profileID:catalog:)` 取代三份实现;兜底统一为「default → 目录第一项,distill/planner 越界清空」;`normalizeCurrentModelSelections` 删除,remove/reset 的「load+normalize 连跑两遍」合并为 `loadModelDefaultsForCurrentProfile(clampAfterCatalogEdit: true)` 一次。
3. **目录纯派生(簇3,兼治「网关目录缓存回声」)**:`modelChoices.didSet` 回写循环删除;派生权威 = `ModelCatalogService.resolvedCatalog`(受控静态 / 官方 cached+manual / 网关 scoped+manual,**不含 cached**);手动添加统一进 manualModels;网关「刷新」改为显式替换 scoped 基础清单。
4. **对账统一 + 尊重 D3(簇4)**:`AppDatabase.applyReconciliation` 为唯一 apply 路径(切换弹窗与启动共用);`reconcileOAuthDefaults` 改为 `reconciliationReport + applyReconciliation + oauthReconciled 一次性标记`,不再每启动重写 UserDefaults/开 DB 写事务,不再静默推翻用户在 D3 弹窗「保持钉住」的显式选择;删除 KernelDefaults.chatGPTStaticModels 硬编码(权威入口 trustedCatalog)。
5. **热路径缓存(簇5)**:SettingsView 目录行改查预计算 `removableCatalogModels` 集合;编辑器候选改 `@State` 缓存,仅 onAppear/切换供给线时重算。

## 行为变化(有意)

- 网关派生目录不再混入 cachedCatalog(存量用户因旧回声已把 cached 复制进 scoped,无感)。
- 网关「刷新目录」= 服务端清单替换 scoped 基础清单;手动加的模型此后存 manualModels,刷新后保留。
- OAuth 启动对账仅首次执行;此后目录外钉住由 D3 弹窗与派单 fail-closed 处理。

## 验证了什么

- `swift build` 全绿(仅既有无害警告)。
- `swift run RunTests`:416 项,8 处失败与 HEAD 基线**逐项一致**(worktree 路径过长 socketPathTooLong ×6、CLI 取消用例 ×2,均为环境性/既有问题,后者另有任务在修);本次新增 9 个目录策略测试全绿。证据:verify.log、baseline-failures.log、with-changes-failures.log。
- Review 两轮:01 发现 P0×4(3 处缺 return 编译错误、1 处强解包)/P1×3(事务边界、测试 fixture 用错官方 host、T7 覆盖缺口)/P2×2,已全部修复并复验。

## 流程备注

- Codex 首轮实现完成;`codex exec resume` 修复轮连续两次静默失败(仅输出会话头),按协议兜底由 Claude 接管修复。
- Codex 沙箱无法编译本仓库(clang 模块缓存写权限被拒),其 verify.log 前段的构建失败为环境问题。
- 本机 `codex` 不在 PATH:实际用 `/Applications/ChatGPT.app/Contents/Resources/codex`(另一可用入口 `node ~/.npm-global/bin/codex`,支持 `-m gpt-5.5 -c model_reasoning_effort=xhigh`)。协议文档 §5 的裸 `codex` 命令建议后续更新。

## 残留风险

- 「编辑器覆写钉住模型」chip 的行为问题**未修**(plan 非目标):打开档案时目录外钉住模型仍会被改选为目录第一项、保存即覆写。
- 「网关目录缓存回声」chip 应已由簇3根治,建议用户核验后关闭该 chip。
- 机器磁盘接近满(Data 卷 897Gi/926Gi):验证期间曾出现瞬时 ENOSPC;未清理任何文件,待用户处置。
- socketPathTooLong ×6 与 CLI 取消 ×2 为本机既有失败,与本次无关(基线证实)。
