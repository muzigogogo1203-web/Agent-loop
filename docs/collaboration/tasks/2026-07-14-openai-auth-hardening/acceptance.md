# 验收记录 — OpenAI 接入加固

日期:2026-07-14
分支:feat/v1.0

## 改了什么

- **refresh token 激活**(核心):新增 `OpenAIOAuthSession` actor(单飞刷新、轮换写回、永久/瞬时失败分类)+ `CredentialStore` protocol(KeychainStore conformance);`OpenAIResponsesProvider` 增加 tokenRefresher 钩子,401/403 时刷新一次并重试,仍失败才抛 unauthorized;AppStore 双路接线(orchestrator makeProvider 闭包 + provider(model:)),永久失败置 `oauthNeedsRelogin` 并提示重新登录,登录成功复位。
- **双实现收口**:OpenAI 官方 OAuth 分支改用 `OpenAIChatGPTAuth.tokenRequestBody`;新增 `refreshTokenRequestBody`(Codex CLI 同款 scope)。
- **isError 保留**:双 provider(Responses + Chat Completions)对失败工具结果统一加 `[tool_error] ` 前缀。
- **UI 显式化**:设置页 webLogin 模式下说明「自定义端点仅对 API key 生效」;「登录已过期」琥珀提示;端口 1455 冲突文案人话化。

## 验证

- 真机 `swift run RunTests`:**356/356 全绿**(基线 346 + 新增 10),verify.log 归档本目录。
- review:reviews/01-claude-review.md,无 P0/P1,两处 P2 备忘。

## 残留风险

- reasoning item 跨轮回放未实现(计划声明的非目标)→ v1.0 已知限制;
- 刷新链路真实 ChatGPT 账号端到端行为待用户 live-test(测试用 URLProtocol stub);
- Codex 会话竞态导致其自产 impl-report 丢失,过程记录以本文件与 review 为准。
