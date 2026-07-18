# 验收 — 牧场氛围资产进 App

## 改了什么

- `Package.swift`：`AgentLoopApp` target 增加 `resources: [.copy("Resources/RanchArt")]`（项目首个 SwiftPM 打包资源）。
- 新增 `Sources/AgentLoopApp/Resources/RanchArt/`：4 张黏土风 JPEG（牛棚日/夜、空基座日/夜，约 2000px，共 1.6MB）。
- 新增 `Sources/AgentLoopApp/Views/CodingRanch/RanchArtView.swift`：主题感知插画组件（亮=Day/暗=Night），显式 bundle 定位 helper（先查 `Contents/Resources/AgentLoop_AgentLoopApp.bundle`，退 `Bundle.module`），`@MainActor` 静态图片缓存，资源缺失静默不渲染。
- `CowRosterView`：牛棚页滚动内容首位插入 150pt 牛棚横幅。
- `CodingRanchHomeView`：「Coding 草原」空闲分支（无进行中行动）插入 170pt 空基座插画。
- `scripts/run-app.sh` / `scripts/package-app.sh`：**修复 P0**——两脚本此前都不拷贝 SwiftPM 资源 bundle，`Bundle.module` 仅靠 accessor 写死的构建机路径侥幸工作，分发包在用户机器上会 fatalError；现均把 `AgentLoop_AgentLoopApp.bundle` 拷入 `Contents/Resources/`（codesign 之前）。

## 验证了什么

- `swift run RunTests`：正常环境 409/409 全绿（两次独立复核）。Codex 受限沙箱中 4 项失败确认为环境产物（keychain -50、security-scoped bookmark 不可用、串行 runner 下两项卡片状态断言），未修改任何 Core/测试代码。
- 构建产物：`.build/AgentLoop.app/Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/` 四张 JPEG 齐全。
- 真机启动：`scripts/run-app.sh --preview` 冷启动进程存活。
- **干净机器模拟**：将 `.build/<triple>/debug/AgentLoop_AgentLoopApp.bundle` 临时改名（废掉 accessor 的写死候选路径）后直接 `open` .app，进程存活 → 证明 `Contents/Resources` 候选独立生效；验证后已恢复。

## 残留风险

- 屏幕访问未授权，横幅的像素级渲染效果未截图确认（进程级证据充分；用户可肉眼确认一次亮/暗两种主题下的观感）。
- `GRDB_GRDB.bundle` 依旧未打包（现状即如此，运行时未触达，仅备忘）。
- Review 长尾 P3：资源缺失时 nil 结果不缓存（重复 Bundle 查询，量级可忽略）。
