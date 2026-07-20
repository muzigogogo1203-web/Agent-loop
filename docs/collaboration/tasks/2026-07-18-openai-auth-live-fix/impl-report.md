# OpenAI 网页认证回流修复实施报告

日期: 2026-07-18

## 根因

1. 用户当时运行的是 `scripts/run-app.sh --preview --dark` 启动的 UI 预览实例。预览模式按设计使用隔离数据库且不读取真实 Keychain，但设置页仍允许拉起 OpenAI OAuth，导致浏览器认证与 token exchange 成功后，预览界面继续显示“未配置 API”。
2. 切换真实模式后又暴露出请求层问题：`OpenAIResponsesProvider` 向 ChatGPT Codex backend 发送了 `max_output_tokens`，后端明确返回 HTTP 400 `Unsupported parameter: max_output_tokens`。因此授权虽已落地，连接测试仍无法成功。

## 改动文件

- `Sources/AgentLoopApp/AppStore.swift`
  - UI 预览模式下拒绝发起真实网页登录，并给出明确的真实模式启动提示。
- `Sources/AgentLoopApp/Views/SettingsView.swift`
  - UI 预览模式下禁用网页登录按钮，避免再次产生“浏览器成功、预览无变化”的矛盾状态。
- `Sources/AgentLoopCore/Provider/OpenAIResponsesProvider.swift`
  - 保留 provider 接口的 `maxTokens` 参数，但不再向 ChatGPT Codex backend 序列化不受支持的 `max_output_tokens`。
- `Sources/AgentLoopTestSuite/OpenAIChatGPTAuthTests.swift`
  - 增加请求体回归断言，确保 `max_output_tokens` 不会重新出现。

## 验证

- 定向回归：
  - `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests --filter openAIResponsesRequestPreservesConversationAndTools`
  - 结果：1/1 通过。
- 权威全量测试：
  - `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests`
  - 结果：409/409 通过，4 suites。
  - 完整输出：`verify.log`。
- App 构建：
  - `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift build --disable-sandbox --product AgentLoopApp`
  - 结果：通过。
  - 完整输出：`build.log`。
- release 打包：
  - `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache scripts/package-app.sh --version 1.1.0`
  - 结果：`Coding 牧场.app`、ZIP 与 DMG 均生成；App 为 v1.1.0 build 124，ad-hoc 签名验证通过。
  - 未配置 `NOTARY_PROFILE`，按现有打包脚本跳过公证。
  - 完整输出：`package.log`。
- 真实链路：
  - 开发版真实模式：显示“网页登录已授权”，连接测试显示“连接正常（gpt-5.5）”。
  - 安装版 `/Applications/AgentLoop.app`：确认进程与生产数据库路径，显示“网页登录已授权”，连接测试显示“连接正常（gpt-5.5）”。
  - 现场证据：`live-verify.log`。

## 安装与恢复

- 已把修复后的 build 124 安装到 `/Applications/AgentLoop.app`。
- 原 build 120 已移动到可恢复备份：
  - `/Users/muzi/Library/Application Support/AgentLoop/Install Backups/20260718-204818-openai-auth-live-fix/AgentLoop-build120.app`

## 计划偏差

- 无架构或依赖偏差。
- 现场验证时发现并修复了同一用户症状背后的第二层请求兼容性根因；否则仅修正预览入口仍无法让真实模式连接成功。
- 未提交、未暂存任何改动。
