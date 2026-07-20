# 模型目录规则收敛重构 plan

任务级别:Level 2(跨模块重构,无 GRDB schema/交接包契约变化)。
来源:对 ab96834(fix(runtime): harden OAuth models and CLI transport)的 review 确认问题簇 1–5。

## 目标

1. 「该供给线是否允许手动模型」谓词收敛为 `RuntimeProfileKind` 上的单一计算属性,四处复用。
2. 「三档模型选择钳制回目录内」收敛为一个 helper,消除三份实现与不一致的兜底值。
3. 目录派生保持纯只读:消灭 `modelChoices.didSet` 把派生合并结果回写 scoped 键的循环(同时根治「网关目录缓存回声」)。
4. 启动期 OAuth 对账复用 `reconciliationReport` + 新增共享 apply,加「已对账」一次性标记做幂等,不再静默推翻用户在 D3 对账弹窗的显式选择。
5. SettingsView 目录行与 CompanionEditorView 模型候选的每次 body/键入重算消除。

## 非目标(防 scope creep)

- 不动 chip「编辑器覆写钉住模型」的行为:CompanionEditorView 打开档案时把目录外钉住模型改选为目录第一项、保存即覆写的问题**保持现状**,本次只做性能缓存,不改其语义。
- 不加派单时的模型-目录校验(维持现有 fail-closed 语义)。
- 不动 GRDB schema、不新增迁移。
- 不改 ModelCatalogService 的网络请求/解析逻辑。

## 已定决策(Codex 不得自行更改)

- **D3 裁决**:`RuntimeProfileBootstrap` 的 OAuth 对账只跑一次(per-profile 布尔标记 `oauthReconciled`,存 ProfileScopedDefaults)。理由:D3 弹窗(RuntimeProfileViews.beginSwitch → ReconciliationSheet)的语义是「未勾选=显式保持钉住,派单 fail-closed 兜底」(AppStore.switchDefaultRuntimeProfile 注释),且 OAuth 档案 UI 只能从静态目录选模型,不会新产生越界值;启动重跑只会推翻用户显式选择。三档设置的越界自愈由 load 时钳制 helper 承担。
- **目录派生统一设计**:派生目录 = `trustedCatalog ?? (scoped modelChoices + manualModels)`,网关**不再**混入 cachedCatalog。手动添加一律写 `manualModels`(官方与网关同一条路);网关「刷新目录」= 用服务端清单**替换** scoped 基础清单(manualModels 不受影响)。这是有意的行为变化,见「行为变化」节。
- **统一兜底值**:钳制时 default 档兜底 = 目录第一项;distill/planner 越界一律清空。`KernelDefaults.defaultGuideModel` 仅作为目录为空时的读取兜底保留。

## 触及文件与改动意图

### T1 `Sources/AgentLoopCore/Database/Records.swift`

`RuntimeProfileKind` 扩展里紧挨 `isCLI` 增加:

```swift
/// 该供给线是否允许手动录入/编辑模型目录;false = 受控静态目录(OAuth/CLI)。
public var allowsManualModelEntry: Bool {
    switch self {
    case .anthropicAPI, .openAIAPI: return true
    case .chatGPTOAuth, .cliCodex, .cliClaude: return false
    }
}
```

替换四处(全部删原 switch/布尔式):
- `CompanionEditorView.allowsCustomModel`(profile 为 nil 时保持返回 true)。
- `AppStore.currentModelCatalogAllowsManualInput`(profile 为 nil 时保持返回 false)。
- `AppStore.loadModelDefaultsForCurrentProfile` 的 `isStrictCatalog` → `!profile.kind.allowsManualModelEntry`。
- `AppStore.refreshCatalog` 的 `profile.kind == .chatGPTOAuth || profile.kind.isCLI` → `!profile.kind.allowsManualModelEntry`。

### T2 `Sources/AgentLoopCore/Provider/ProfileScopedDefaults.swift`

- 增加 `bool(profileID:suffix:) -> Bool` / `setBool(_:profileID:suffix:)`(标记用)。
- 增加统一钳制 helper:

```swift
/// 把三档模型选择钳制回目录内(default 兜底目录第一项;distill/planner 越界清空)。
/// 目录为空时 no-op。只写有变化的键;返回是否有改动。
@discardableResult
public func clampModelSelections(profileID: String, catalog: [String]) -> Bool
```

### T3 `Sources/AgentLoopCore/Provider/ModelCatalogService.swift`

- 新增静态派生入口(纯读,无副作用):

```swift
/// 目录派生的唯一权威:受控目录直接返回;否则 scoped 可编辑清单 + 手动项(不含 cached);空则 fallback。
public static func resolvedCatalog(
    profile: RuntimeProfileRecord,
    defaults: ProfileScopedDefaults,
    fallback: [String]
) -> [String]
```

- `refresh(profile:credential:)` 对 API 两 kind 的落盘分流:`isOfficialCatalogProfile` → `setCachedCatalog`(不变);非官方(网关)→ 用 `uniqueModels(fetched)` **替换** scoped `modelChoices`,不写 cached。静态 kind 分支不变。

### T4 `Sources/AgentLoopApp/AppStore.swift`

- `modelChoices` 属性删除 didSet 持久化(纯展示态);`persistProfileModels` 随之删除(确认无其他调用后)。`defaultModel/distillModel/plannerModel` 的 didSet 保留。
- `catalogChoices(profile:)` 瘦身为调 `ModelCatalogService.resolvedCatalog(profile:defaults:fallback: Self.factoryModelChoices)`。
- `addModelToCurrentCatalog`:删分支,统一 append 进 `manualModels`。
- `removeModelFromCurrentCatalog`:官方档案只过滤 manual(现状);网关同时从 manual 与 scoped `modelChoices` 中过滤(scoped 基于**存储值**过滤,不再基于内存合并值)。
- `resetCurrentModelCatalog`:manual 清空(两类都做);网关另把 scoped 恢复为 `factoryModelChoices`(现状)。
- 新增 `private(set) var removableCatalogModels: Set<String>`,在 `loadModelDefaultsForCurrentProfile` 里一次算好(官方:manual 集合;网关:choices.count > 1 ? 全量 : 空;受控:空)。`canRemoveModelFromCurrentCatalog` 保留签名,改为 O(1) 查该集合(SettingsView 不用改)。
- `loadModelDefaultsForCurrentProfile(clampAfterCatalogEdit: Bool = false)`:装载 choices 后,当 `!profile.kind.allowsManualModelEntry || clampAfterCatalogEdit` 时调 `defaults.clampModelSelections(profileID:catalog:)`,再读存储值进三档属性(读取兜底保持 `choices.first ?? KernelDefaults.defaultGuideModel`)。删除 `normalizeCurrentModelSelections`;`removeModel/resetCatalog` 原来的「load + normalize 连跑两遍」改为一次 `loadModelDefaultsForCurrentProfile(clampAfterCatalogEdit: true)`;`addModel` 及其余调用点用默认参数。

### T5 对账统一 `Sources/AgentLoopCore/Database/RuntimeProfileStore.swift` + `RuntimeProfileBootstrap.swift` + AppStore

- `RuntimeProfileStore.swift` 新增:

```swift
/// 应用对账结论:伙伴项改 inherit(保留 model 字符串便于追溯);
/// defaultModel 项重置为 trustedCatalog 第一项;distill/planner 项清空。
/// 无伙伴项时不开写事务。
public func applyReconciliation(items: [ReconciliationItem], defaults: ProfileScopedDefaults) throws
```

- `AppStore.switchDefaultRuntimeProfile`:把 `inheritCompanionIds`/`resetSettingScopes` 过滤出选中的 items 子集,调 `db.applyReconciliation`,删除手写的 companion 循环与 scoped 写入(语义须与现状逐项等价)。
- `RuntimeProfileBootstrap.reconcileOAuthDefaults` 重写为:

```swift
guard !defaults.bool(profileID: profile.id, suffix: "oauthReconciled") else { return }
let report = try db.reconciliationReport(switchingTo: profile.id, defaults: defaults)
try db.applyReconciliation(items: report, defaults: defaults)
defaults.setBool(true, profileID: profile.id, suffix: "oauthReconciled")
```

  删除:precondition(由测试断言静态目录非空替代)、`KernelDefaults.chatGPTStaticModels` 直引、`setStringArray(catalog, "modelChoices")`、`setManualModels([], ...)`(对受控目录是死状态写入)。
- 已知无害语义差:旧实现对「存储 default 为空」不写;新实现经 report(以 defaultGuideModel 兜底读出越界)会把存储 default 写为目录第一项——生效值不变,可接受。

### T6 `Sources/AgentLoopApp/Views/CompanionEditorView.swift`

- `allowsCustomModel` 改用 T1 谓词。
- `editorModelChoices` 由计算属性改为 `@State` 缓存 + `reloadEditorModelChoices()`:onAppear/loadCompanion 时算一次,`profileChoice` 的 onChange 里先重算再跑 `normalizeModelChoiceForSelectedProfile`。回退链保持:选中档案拿不到时用 `store.modelChoices`。行为不得变化(候选内容与现状一致)。

### T7 测试 `Sources/AgentLoopTestSuite/ModelCatalogPolicyTests.swift`(新文件)+ 改 `RuntimeProfileTests.swift`

先写测试锁行为,再动实现;新语义的测试按红→绿顺序。

新文件(工具函数可仿照 RuntimeProfileTests 的 temp db/defaults 写法):
1. `allowsManualModelEntry` 五 kind 矩阵;`chatGPTStaticModels`/`cliStaticModels` 非空(替代被删的 precondition)。
2. `resolvedCatalog`:OAuth/CLI 返回静态;官方 = cached+manual;**网关 = scoped+manual,显式断言 cached 里的模型不出现**(锁回声修复);全空 → fallback;调用无写副作用(前后 dump scoped/manual/cached 键不变)。
3. `refresh` 网关分支:替换 scoped `modelChoices`、不写 cached、manual 不动(官方分支已有测试覆盖,不重复)。
4. `clampModelSelections`:目录内不动/返回 false;default 越界 → 目录第一项;distill/planner 越界 → 清空;空目录 no-op;只改越界键。
5. `applyReconciliation`:只翻列出的伙伴且保留 model 字符串;未列出的钉住伙伴不动;三档 scope 按规则重置;空 items 状态零变化。
6. **bootstrap 幂等/尊重 D3**:首次 ensureSeeded 后把某伙伴重新钉回目录外模型、把 distill 设为目录外值,再次 ensureSeeded → 伙伴保持 pinned、distill 不被改写、标记为 true。

改动:
- `runtimeProfileBootstrapOAuthDefaultReconcilesLegacyModels`:删 `modelChoices(profileID:) == ["gpt-5.5"]` 断言(bootstrap 不再写该键),改断言 `ModelCatalogService.trustedCatalog == ["gpt-5.5"]` 与标记已置位;伙伴翻转/三档钳制断言保留。

## 行为变化(验收时向用户说明)

1. 网关派生目录不再混入 cachedCatalog。存量用户无感:旧 didSet 回声早已把 cached 复制进 scoped。
2. 网关「刷新目录」从「写 cached 再合并」改为「替换 scoped 基础清单」;用户手动加的模型今后进 manualModels,刷新后保留。存量 scoped 里的手动模型会被下一次显式刷新替换掉(刷新本就是拉服务端权威清单的显式动作,可接受)。
3. OAuth 启动对账只跑一次;之后目录外钉住伙伴仅由 D3 弹窗与派单 fail-closed 处理。
4. 每次启动不再无条件写 UserDefaults + 开 DB 写事务。

## 边界与错误路径

- 目录为空:clamp no-op;resolvedCatalog 返回 fallback;removable 集合为空。
- `currentRuntimeProfile == nil`:各入口维持现有 guard 行为。
- 伙伴 id 已删除:applyReconciliation 跳过该项不抛错(与现状 try? 等价,但整体事务内其余项仍生效)。
- `uniqueModels` 继续负责去重/trim。

## 验证命令与完成定义

- `swift run RunTests` 全绿(输出存 verify.log)。
- `swift build`(需连 AgentLoopApp 可执行 target 一起编过,App 层改动无单测覆盖)。
- 完成定义:上述全过 + 五个问题簇的原始重复点全部只剩单一实现 + 无 plan 外改动。

## Open questions

(空——D3 裁决与网关刷新语义已在「已定决策」节定死。)
