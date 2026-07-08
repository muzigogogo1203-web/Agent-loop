# M10 实现计划 v1 — 长明火（定时行动 + 正式分发 + 首跑引导 + 定名 = v1.0）(Level 3，待用户过目)

> 基于 feat/m6 + V2 设计 §5-M10。前置：M7（预算硬顶+自主档位锁）与 M9（可信账本）验收通过——无人值守烧钱的两道保险；Apple Developer 个人账号就绪（收官门已排队）。
> **Level 3 项：迁移 v8（mission_template + schedule 两表）**。
> 附注：主循环自写自查（子代理评审因额度触顶未跑，可补）。

验收（V2 设计 §5-M10 活体验收）：**「每日晨报」定时行动连续 3 天无人值守成功产出并通知、向导播报可见；一台全新 Mac 下载 DMG 双击直开（无右键过 Gatekeeper），跟随首跑引导 10 分钟内完成第一次行动；Sparkle 从 0.9 自动升级 1.0 且 SQLite 迁移无损。**

## 现状盘点（已逐条核实）

- **App 生命周期就绪**：AgentLoopApp.swift 已有 `@NSApplicationDelegateAdaptor(AppDelegate)`（M7 会先用它接退出钩子）——NSStatusItem 常驻与「关窗不退出」的改造点现成；当前 WindowGroup 单窗口。
- **调度入口现成**：`Orchestrator.startMission(goal:companionIds:workspacePath:plannerModel:budgetTokens:campId:)`（Orchestrator.swift:70）——scheduler 可直调，参数与模板字段一一对应；autonomy 参数 M7 后加入。
- **播报通道现成**：`findOrCreateGuideThread(campId:)` + `appendChatMessage(threadId:role:text:)`，role 现有 user/guide 两种渲染——播报=系统注入 role "guide" 纯文本消息，**不走 LLM**。
- **打包脚本**：scripts/package-app.sh（M5-5）：release 构建 + Info.plist（VERSION=0.5.0 硬编码）+ 代码绘制图标 + `SIGN_ID` 注入口（默认 ad-hoc）+ zip；**无公证、无 DMG、无 Sparkle、无 entitlements 文件**。
- 通知：项目未引入 UserNotifications；沙箱已明确弃权（V2 设计 §5-M10），Developer ID 非沙箱路线对 Sparkle 是最简单形态。
- 预算/档位保险（M7/M9 交付）：mission.autonomy 列 + 预算三选 + 可信账本（规划轮已入账）。

## 决策（D1–D9，待用户过目）

| # | 决策 | 理由 |
|---|---|---|
| D1 | **数据模型（迁移 v8）**：`mission_template`（id, name, goal, companionIdsJson, workspacePath?, budgetTokens, autonomy, campId, createdAt）+ `schedule`（id, templateId, frequency('daily'/'weekly'), hour, minute, weekday?, enabled, lastFiredAt?, createdAt）。**不做 cron 表达式**——UI 只给「每天 / 每周几 + 时间」 | 覆盖「每日晨报」核心场景；cron 是伪需求 |
| D2 | **无人值守双保险（建模层强制）**：模板必须显式 budgetTokens（不许继承「当时的全局默认」）且 `autonomy ≤ standard`（放手档模板保存时拒绝）——审批弹窗在无人值守时无人点，谨慎/标准档挂起的卡由用户回来再批（持久门语义天然支持） | 设计明示；持久门让「无人值守+需要审批」优雅降级为「等你回营」 |
| D3 | **MissionScheduler**（@MainActor，AppStore 持有）：每个启用 schedule 注册一个 `NSBackgroundActivityScheduler`（interval 到下次触发点、tolerance 5min、系统自动处理睡眠恢复）；触发时校验 lastFiredAt 防重（同一天不双发）→ startMission → 更新 lastFiredAt + `EventKind.scheduleFired`；**启动补跑检查**：错过的排程（lastFiredAt < 上一个应触发点）只弹「昨晚的日程没跑，现在补跑？」提示（记 scheduleMissed），不自动补 | NSBackgroundActivityScheduler 是 App Nap/睡眠下最省心的原生手段；自动补跑会在长时间未开机后炸预算 |
| D4 | **菜单栏常驻（设置项，默认关）**：开启后 NSStatusItem（篝火图标）+ `applicationShouldTerminateAfterLastWindowClosed=false` + 关窗保活；菜单：打开营地 / 今晚的日程（下次触发时间）/ 紧急收哨（M7 emergencyStop）/ 退出。关闭常驻则回归普通关窗即退（定时行动仅 App 运行期生效——含常驻保活，UI 明示这一点） | 设计明示不做 launchd；常驻开关给用户选择权 |
| D5 | **通知**：UNUserNotificationCenter，首次启用任一 schedule 时请求授权；行动收营/失败/预算耗尽三类通知，点击激活窗口并导航到该行动；**向导播报**：同三类事件向该营地 guide 线程注入 role "guide" 消息（「晨报来了：…」/受阻人话化复用 CampCopy），营地对话即留存回路闭合点 | 通知拉人回来，播报承接叙事——同一事件两个出口 |
| D6 | **正式分发链**：package-app.sh 升级——① VERSION 提参数化（默认读 git tag）；② Developer ID 签名（SIGN_ID + `--options runtime` + entitlements 文件显式声明非沙箱）；③ `xcrun notarytool submit --wait` + `stapler staple`（凭据用 notarytool store-credentials 本地 keychain profile，脚本引用 profile 名）；④ `hdiutil create` 出 DMG（背景图+拖拽 Applications 布局可后补，先出朴素 DMG）；⑤ 产出物：dist/AgentLoop-<ver>.dmg + zip（Sparkle 用 zip） | 全部标准姿势；公证失败的错误面留够脚本日志 |
| D7 | **Sparkle 2（SwiftPM）**：Package.swift 引 Sparkle（pin）；Info.plist 加 SUFeedURL + SUPublicEDKey；设置页「检查更新」+ 自动检查开关；appcast.xml + EdDSA 签名（`generate_appcast` 工具）；**发布物走 GitHub Releases（appcast 与 zip 同仓 Releases 托管）**；发布说明模板固化「从 ad-hoc 旧版升级需手动替换一次」 | 非沙箱 SwiftPM 集成是 Sparkle 最简路径；GitHub Releases 零运维 |
| D8 | **首跑引导（UserDefaults hasOnboarded）**：四步居中弹层（复用 M6.ui 自绘弹层模式）——① 欢迎（产品名+「数据都在本机」一句话）；② API key（去哪申请的链接 + SecureField + 「测试连接」按钮 = 用 defaultModel 发 1 token ping 验证连通）；③ 自动创建「新手营地」+ 两名预设伙伴（斥候·全工具/文书·禁写文件，人设文案随 M10 设计稿给用户过目）；④ 引导式第一次行动：预填目标「把这个营地的用法整理成一份 quickstart.md」（单伙伴、小预算、无需工作目录走暂存区）——**依赖 ② 完成**；若跳过 key 则第 ④ 步替换为「配好 key 后从这里出发」的占位引导。可随时跳过整个引导 | 「装得上也用得起来」：10 分钟到第一次收营是 v1.0 外部反馈回路的成立条件 |
| D9 | **定名与收尾**：产品名决策清单交用户（显示名/图标文案/appcast 域名）；**bundle id 保持 com.muzi.agentloop 不变**（改名=Keychain service + UserDefaults + Application Support 目录三重迁移，纯风险零收益）；冒烟清单固化 docs/superpowers/smoke-checklist.md；打 v1.0 tag | 显示名可随便换，身份标识别动 |

新增 EventKind：`scheduleFired`/`scheduleMissed`。迁移 v8。

## 触及面

- Core：迁移 v8 + 两表 CRUD、`Kernel/`（scheduler 触发的 nextFireDate/misfire 判定抽成纯函数进 Core 便于单测）、EventKind +2、播报注入方法（AppDatabase 一个便捷方法）。
- App：MissionScheduler、模板/日程管理 UI（营地首页「日程」区 + 模板编辑表单）、NSStatusItem + AppDelegate 生命周期、通知授权与路由、首跑引导四步弹层、SettingsView（常驻开关/检查更新）、Sparkle 集成。
- 脚本：package-app.sh 大版（签名/公证/DMG/参数化）、release-notes 模板、appcast 生成说明文档。
- 测试：+14±（nextFireDate 纯函数全矩阵：daily/weekly/跨周/DST、misfire 判定、防重、模板校验（预算必填/放手档拒绝）、v8 迁移、播报消息落库）；通知/StatusItem/Sparkle/公证走人工冒烟清单（App 层惯例）。

## 实现顺序

D1 迁移与模板 → D3 scheduler（纯函数先行）→ D2 保险校验 → D5 通知+播报 → D4 常驻 → D8 首跑引导 → D6/D7 分发链（依赖证书到位，可与前面并行推进脚本部分）→ D9 定名收尾。**外部依赖**：Developer ID 证书（个人，已排队）、公证工具链（Xcode CLT 的 notarytool）、Sparkle 框架、GitHub Releases。

## Open questions（待用户拍板）

1. **D7 appcast 托管走 GitHub Releases**（公开仓或专门的 release 仓？私仓的 Releases 资产对未登录用户不可下载——若仓库保持私有，需要建一个公开的 release 仓或换自有服务器）——你的仓库计划公开吗？
2. **D9 bundle id 不改**（只改显示名，避免 Keychain/数据三重迁移）——OK？
3. **D8 预设伙伴**（斥候/文书）的人设文案与首跑行动目标，随 M10 设计稿先给你过目再落地——OK？
4. **D4 常驻默认关**（用户主动开启才有菜单栏篝火）——还是首次创建日程时引导开启？推荐后者作为软引导。
