# Review 01 — 模型目录规则收敛

结论:方向与 plan 一致,但存在编译错误与测试缺口,**不通过**。P0/P1 修完再验。

重要环境说明:你的沙箱无法编译本仓库(模块缓存权限)。修复后**不要**再尝试 `swift run RunTests`/`swift build`,由 Claude 在沙箱外验证。专注改代码。

## P0(必须修)

1. **AppStore.swift `currentModelCatalogAllowsManualInput`(~:751)缺 `return`** —— 多语句计算属性,`profile.kind.allowsManualModelEntry` 前必须加 `return`。当前 App target 编译失败。
2. **AppStore.swift `canRemoveModelFromCurrentCatalog`(~:756)缺 `return` + 死绑定** —— `guard let profile`、`let defaults` 均未使用(编译警告),末行缺 `return`(编译错误)。建议整体简化为:
   `currentModelCatalogAllowsManualInput && removableCatalogModels.contains(model)`(profile 判空已含在前者内)。
3. **CompanionEditorView.swift:43 `allowsCustomModel` 缺 `return`** —— 同类编译错误。
4. **RuntimeProfileStore.applyReconciliation 强解包** —— `try RuntimeProfileRecord.fetchOne(db, key: item.profileId)!`:档案在 report 与 apply 之间被删即崩溃(review 清单明令禁止可选值强解包)。改 `guard let`,取不到则跳过该项。

## P1(应修)

5. **applyReconciliation 事务边界不符 plan** —— plan 明确「无伙伴项时不开写事务」,且 UserDefaults 写入不应发生在 DB 写事务闭包内。重构:先把 items 按 scope 分组;companion 项非空时才开 `pool.write` 并只在事务内更新 companion;三档设置的 defaults 写入放在事务外。defaultModel 的目录取值可在事务外先解析(profile 取不到则跳过)。
6. **ModelCatalogPolicyTests fixture 错误(当前红)** —— `catalogProfile(.openAIAPI)` 的 baseURL 是 `https://api.openai.com`(官方 host),`isOfficialCatalogProfile == true`,走的是 trusted 路径,返回 `["cached","manual"]`。网关用例必须用非官方 host(如 `https://gateway.example.com`)。同时补一条官方档案断言(cached+manual)以锁双路径。
7. **T7 覆盖缺口(plan 明确要求,impl-report 却称无偏差)** —— 补齐:
   - refresh 网关分支:替换 scoped `modelChoices`、不写 cached、manual 不动(仿 RuntimeProfileTests 的 URLProtocol stub 写法);
   - `applyReconciliation`:只翻列出的伙伴且保留 model 字符串、未列出的钉住伙伴不动、三档 scope 按规则重置、空 items 状态零变化、profileId 指向已删除档案时不崩溃(锁 P0-4);
   - bootstrap 幂等/尊重 D3:首次 ensureSeeded 后把伙伴重新钉回目录外模型、distill 设为目录外值,再次 ensureSeeded → 伙伴保持 pinned、distill 不被改写、`oauthReconciled` 为 true;
   - `resolvedCatalog` 全空 → fallback 用例。
   并更新 impl-report.md 的偏差说明(原「No plan deviations」不实)。

## P2(便宜就修)

8. **loadModelDefaultsForCurrentProfile 残留旧内存钳制三元式** —— 存储层 `clampModelSelections` 之后,`isStrictCatalog && !choices.contains(...)` 对严格目录恒为假,是死逻辑。收敛为:钳制后直接读存储值(`choices.first ?? KernelDefaults.defaultGuideModel` 的读取兜底保留)。
9. **reconcileOAuthDefaults 文档注释过时** —— 现语义是「仅首次(标记)收敛,之后由 D3 对账与派单 fail-closed 接管」,注释仍写「清单升级后」会重跑。更新注释。

## P3(备忘,不阻塞)

10. 删除 normalize/persistProfileModels 后遗留的连续空行;`allowsManualModelEntry` 可补一行说明注释(plan 原文)。
11. `removableCatalogModels` 在 `reloadRuntimeProfiles(loadModelDefaults: false)` 路径下可能短暂陈旧——与 modelChoices 既有陈旧行为同类,暂不处理。

## 验证记录(Claude 沙箱外实测)

- `swift build`:App target 3 处 missing return(P0-1/2/3)。
- `swift run RunTests`(带改动):412 测试 9 失败 = 基线 8(本机环境:socketPathTooLong ×6、CLI 取消 ×2,与本 diff 无关)+ 新增 1(P1-6 fixture)。
- 基线(HEAD)对照:8 失败,见 baseline-failures.log / with-changes-failures.log。
- 除上述外,Core 层 diff(Records/ProfileScopedDefaults/ModelCatalogService/Bootstrap)与 plan 一致,已通过逐项核对。
