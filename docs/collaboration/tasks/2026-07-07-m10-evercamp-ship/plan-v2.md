# M10 实现计划 v2 — 长明火(定时行动 + 分发 + 收束 = Coding 牧场 v1.0)

日期:2026-07-14(v1 → v2 修订)
分支:feat/v1.0
授权:用户已在会话中明确指示「把 M10 也做了,作为第一版本」;v1 计划的 Open questions 按下方拍板执行,拍板项在交付报告中列给用户复核。

## v1 → v2 修订要点

1. **迁移序 v8 → v9**:v8 已被 Coding 牧场 MVP(`v8-coding-ranch`)占用;本轮两表迁移注册为 `v9-evercamp`。
2. **定名已定**:产品显示名 **Coding 牧场**(用户 2026-07-14 正式宣布);bundle id 保持 `com.muzi.agentloop`(v1-D9 推荐,避免 Keychain/UserDefaults/状态目录三重迁移);分发产物名用 ASCII:`CodingRanch-<ver>.dmg` / `.zip`。
3. **Sparkle(v1-D7)整体延后**:仓库为 PRIVATE(私仓 Releases 资产对未认证请求不可下载,appcast 无处托管)+ 本机无 Developer ID 证书 → Sparkle 在 v1.0 阶段不可测试。决策:**本轮不引入 Sparkle 依赖**;package-app.sh 预留 `--feed-url` 参数位并在脚本注释记录集成步骤;设置页不出现「检查更新」(避免假入口,遵循牧场 MVP 的「不做假入口」原则)。仓库转公开或证书到位后再做。
4. **签名公证(v1-D6)降级为「参数就绪 + ad-hoc 实测」**:本机 `security find-identity` 无有效签名身份。脚本升级为完整参数化链路(SIGN_ID / NOTARY_PROFILE / entitlements),无证书时走 ad-hoc + 跳过公证并明确打印提示;DMG 产出与安装路径本机实测。
5. **首跑引导(v1-D8)收敛**:Coding 牧场 MVP 已有 `CodingRanchOnboardingView`(欢迎页 + 基础牛卡片 + 两步引导 + 模型连接状态),覆盖 v1-D8 的 ①③④;本轮只补 **②模型连接自检**——设置页「测试连接」按钮(用当前凭据发一次最小请求,结果人话化),onboarding 的模型状态行点击可直达设置。不再做四步弹层、不做预设伙伴(基础牛已承担该角色)。
6. **播报术语对齐牧场**:v1-D5 的「向导播报」对象更名为营地管家(guide 线程机制不变,role "guide" 注入)。

## 保留的 v1 决策(细节见 plan.md)

- **D1 数据模型**(改为迁移 `v9-evercamp`):`mission_template`(id, name, goal, companionIdsJson, workspacePath?, budgetTokens, autonomy, campId, createdAt)+ `schedule`(id, templateId, frequency('daily'/'weekly'), hour, minute, weekday?, enabled, lastFiredAt?, createdAt)。不做 cron。
- **D2 无人值守双保险**:模板必须显式 budgetTokens;`autonomy ≤ standard`(保存时校验拒绝 free);审批挂起自然落在持久门语义上。
- **D3 MissionScheduler**:@MainActor、AppStore 持有;每个启用 schedule 一个 `NSBackgroundActivityScheduler`(tolerance 5min);触发时 lastFiredAt 防重(同槽不双发)→ `Orchestrator.startMission(goal:companionIds:workspacePath:plannerModel:budgetTokens:campId:autonomy:)` → 更新 lastFiredAt + `scheduleFired` 事件;错过的排程只提示补跑(`scheduleMissed`),不自动补。**nextFireDate/misfire 判定抽成 Core 纯函数**(`Sources/AgentLoopCore/Kernel/ScheduleMath.swift`),全矩阵单测。
- **D4 菜单栏常驻**:设置项默认关;开启后 NSStatusItem(篝火 SF Symbol)+ `applicationShouldTerminateAfterLastWindowClosed=false`;菜单:打开牧场 / 下次日程 / 紧急收哨 / 退出。首次创建日程时软引导开启(一次性提示)。UI 明示「定时行动仅在 App 运行期间生效(含常驻)」。
- **D5 通知**:UNUserNotificationCenter;首次启用任一 schedule 时请求授权;收营/失败/预算耗尽三类通知,点击激活窗口并导航到该行动;同三类事件向营地管家线程注入 role "guide" 播报消息(复用现有 `findOrCreateGuideThread` + `appendChatMessage`,不走 LLM)。裸二进制/未打包运行时通知 API 不可用——运行时探测失败则静默降级(播报仍生效),不崩溃。
- 新增 EventKind:`scheduleFired` / `scheduleMissed`(生产代码用常量,测试按惯例可用裸字符串钉持久值)。

## D6' 分发链(修订版)

`scripts/package-app.sh` 升级:

- `VERSION`:优先取 `--version` 参数,否则取 `git describe --tags --abbrev=0` 去掉前缀 v,兜底 1.0.0;`BUILD_NUMBER` 沿用 rev-list count。
- Info.plist:`CFBundleDisplayName=Coding 牧场`、`CFBundleName=AgentLoop`(可执行体/内部名不动)、bundle id 不变;加 `LSUIElement` 不设(常驻由运行时 activation policy 控制)。
- 签名:`SIGN_ID` 非空且非 `-` 时用 `codesign --options runtime --entitlements scripts/agentloop.entitlements`(新文件:显式非沙箱 + 允许网络 client + JIT 不需要);否则 ad-hoc(现状)并打印「ad-hoc:跨机需右键打开」。
- 公证:`NOTARY_PROFILE` 非空时 `xcrun notarytool submit --wait` + `stapler staple`;无 profile 跳过并打印指引(一次性 `notarytool store-credentials` 步骤写脚本头注释)。
- DMG:`hdiutil create -volname "Coding 牧场" -srcfolder <staging: app + /Applications 软链> -format UDZO dist/CodingRanch-<ver>.dmg`;同时保留 zip(`dist/CodingRanch-<ver>.zip`)。
- `--feed-url <url>` 参数位:传入时写 SUFeedURL 进 Info.plist(为未来 Sparkle 预留,本轮无消费方)。

## 触及面

- Core:`AppDatabase.swift`(v9-evercamp 迁移)+ 模板/日程 Record 与 CRUD(新文件 `Sources/AgentLoopCore/Database/ScheduleStore.swift` 或并入现有 store 风格——**跟随现有 Record 文件组织惯例**)、`Kernel/ScheduleMath.swift`(纯函数)、EventKind +2、播报便捷方法(如 `appendGuideBroadcast(campId:text:)`)。
- App:`MissionScheduler.swift`(新)、AppDelegate 扩展(常驻/通知代理)、营地首页「日程」区 + 模板编辑表单(牧场风格,复用 CampLayout 断点)、SettingsView(常驻开关、测试连接按钮)、通知授权与点击路由。
- 脚本:package-app.sh 大版 + `scripts/agentloop.entitlements`(新)。
- 测试(Sources/AgentLoopTestSuite/,目标 +14±):ScheduleMath 全矩阵(daily/weekly/跨周/DST 用固定时区构造/misfire 判定/防重)、模板校验(预算必填、free 档拒绝)、v9 迁移回放(从 v8 起)、schedule CRUD、播报消息落库、scheduleFired 事件。调度器实际触发/通知/StatusItem 走人工冒烟(App 层惯例,并入 v1.0 live-test 脚本)。

## 实现顺序与分工

1. **Codex(Core 轮)**:v9 迁移 + Record/CRUD + ScheduleMath + EventKind + 播报方法 + 全部 Core 测试。
2. **Codex(App 接线轮,同一任务第二段)**:MissionScheduler + 通知授权/路由 + AppDelegate 常驻改造(逻辑层,不含视觉)。
3. **Claude(UI 轮,亲自)**:日程区 UI、模板表单、设置页(常驻开关/测试连接)、状态栏菜单文案、软引导提示;截图循环亮暗自验。
4. **Claude(脚本轮)**:package-app.sh + entitlements + DMG 实测。

## 边界与错误路径

- 模板引用的伙伴/营地被删:触发时校验,缺失 → `scheduleMissed`(reason 带人话)+ 通知,不崩;
- 触发时已有 emergency halt:遵守现有 startMission 守卫(直接被拒),记 scheduleMissed;
- 预算/档位:D2 校验在保存与触发两处都执行(触发时模板可能是旧数据);
- 时钟回拨/夏令时:nextFireDate 用 Calendar(identifier: .gregorian)+ 显式 timeZone 计算,misfire 判定只比较「上一个应触发点」;
- 通知授权被拒:记一次性提示,播报照常;
- App 未常驻且窗口关闭退出:属预期(UI 已明示),启动补跑检查兜底。

## 验证命令

```
CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests
swift build --product AgentLoopApp
scripts/package-app.sh   # 产出 dist/CodingRanch-1.0.0.dmg,本机挂载安装实测
```

## 完成定义

Core 测试全绿(基线 346 + 新增);DMG 本机产出且挂载可安装启动;日程 Golden Path(建模板 → 建日程 → 手动「立即试跑」→ 收营通知+管家播报)可走通;v1.0 live-test 脚本(任务 9)含定时行动人工冒烟组。

## 遗留声明(进 v1.0 已知限制)

- Sparkle 自动更新未集成(私仓 + 无证书,见修订要点 3);
- Developer ID 签名与公证待证书(脚本已就绪,`SIGN_ID`/`NOTARY_PROFILE` 即插即用);
- 「连续 3 天无人值守晨报」验收由用户在 live-test 中执行(需真机长期运行)。
