# Coding 牧场最新版本整合实施报告

日期：2026-07-18

## 结论

本地 `main`、四条 Claude 修复线和 OpenAI 网页认证修复已经整合成同一份本地工作内容。组合版通过 423 项权威测试、release 打包、签名校验和安装版真实 UI/网络验收，已更新到 `/Applications/AgentLoop.app` 供体验。

## 版本真相

- 用户可见产品名是 `Coding 牧场`。
- 为保持 OAuth URL scheme、Keychain、历史数据库与升级兼容，bundle id、可执行文件、安装路径和数据目录继续使用 `AgentLoop`。
- `/Applications/AgentLoop.app` 是唯一当前安装并运行的版本。
- `dist/Coding 牧场.app` 是本轮 release 产物；`Install Backups` 下的其它 `.app` 是可恢复备份，不是同时运行的不同产品版本。

## 已整合提交

1. `ff607885` — package 版本号仅从当前提交祖先 tag 推导。
2. `1d4605c` — 模型目录策略、三档模型钳制和 OAuth 启动对账收敛。
3. `173d595` — CLI 管道退出后排空、残行 flush 和宽限期状态机。
4. `305a2c6` — Board socket fd 生命周期、listener 唤醒及 SIGPIPE 收口。

同时保留并叠加：

- `Sources/AgentLoopApp/AppStore.swift` 与 `SettingsView.swift` 的 UI 预览 OAuth 防误导修复。
- `Sources/AgentLoopCore/Provider/OpenAIResponsesProvider.swift` 的 ChatGPT backend 请求体兼容修复。
- `Sources/AgentLoopTestSuite/OpenAIChatGPTAuthTests.swift` 的回归断言。

## 整合方法

- 先在 `/private/tmp/agentloop-latest-probe.*` 隔离 worktree 中按顺序无提交应用四个提交。
- 再叠加当前 OpenAI 修复；所有补丁均三方干净应用。
- 隔离组合版运行 423/423 测试通过。
- 当前工作区先建立带未跟踪文件的安全 stash，再按相同顺序应用四条修复，随后恢复 OpenAI 修复。
- 逐文件比较确认主工作区与通过测试的隔离组合版本一致。
- 按仓库协议未创建 commit，也未 push。

## 主要改动范围

- 模型目录与 runtime profile：
  - `AppStore.swift`
  - `CompanionEditorView.swift`
  - `Records.swift`
  - `RuntimeProfileStore.swift`
  - `RuntimeProfileBootstrap.swift`
  - `ModelCatalogService.swift`
  - `ProfileScopedDefaults.swift`
- CLI / Board 生命周期：
  - `CliProcessBackend.swift`
  - `BoardServerBridgeMain.swift`
  - `BoardToolServer.swift`
  - `PosixSockets.swift`
- OpenAI 连接：
  - `OpenAIResponsesProvider.swift`
  - `SettingsView.swift`
- 对应测试及三条 Claude 任务档案一并保留。

## 验证

- 隔离组合：423 tests / 5 suites 全绿。
- 主工作区：423 tests / 5 suites 全绿。
- 完整测试输出：`verify.log`。
- release 打包：成功，完整输出见 `package.log`。
- `.app` 签名和资源 bundle：通过。
- 安装版：进程、生产数据库、任务恢复、牛棚插画、OAuth 状态及真实连接测试均已验证。
- 现场记录：`live-verify.log`。

## 已知但不阻塞的事项

- 两个 Board 测试中的 `weak var` 触发 Swift 6.2 `WeakMutability` 编译警告，测试仍通过；本轮没有扩展范围修改已审查的测试实现。
- 一份从 Claude 分支原样带入的历史 `verify.log` 含四行行尾空格；这是原始验证证据，不修改日志内容。生产源码的 diff 检查没有行尾问题。
- 因仓库协议禁止本轮提交，HEAD 和 build number 均未变化，所以安装版仍显示 `1.1.0 (124)`；可执行文件哈希已变化并在 `live-verify.log` 记录。
- 新 ad-hoc 签名二进制首次启动曾等待 macOS Keychain/Security 查询约一分钟，之后正常启动且真实连接通过。

## 恢复点

- 安装版备份：
  `/Users/muzi/Library/Application Support/AgentLoop/Install Backups/20260718-211458-latest-integration/AgentLoop-pre-integration-build124.app`
- Git 安全 stash：
  `codex-safety-before-latest-integration-20260718`
