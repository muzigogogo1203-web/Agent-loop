# OpenAI 接入加固实施计划(Level 2.5)

日期:2026-07-14
分支:feat/v1.0
基线:efb8564(main 同步点)
授权:用户已在会话中明确批准本轮加固范围(v1.0 收束计划第 ④ 项),故不再单独等待 plan 确认。

## 背景

2026-07-14 的 OpenAI Auth 修复(64f6327)打通了 ChatGPT OAuth → Responses API 主路径,但遗留五个工程缺口:

1. **refresh_token 存而不用**:`oauth-refresh-token` 已写入 Keychain(AppStore.swift `saveWebCredential`),但全仓无刷新逻辑。access token 过期后 `OpenAIResponsesProvider` 对 401/403 直接抛 `ProviderError.unauthorized`(OpenAIResponsesProvider.swift:164-165),用户只能手动重新网页登录,且无 UI 引导。
2. **token 请求体双实现漂移**:`OpenAIChatGPTAuth.tokenRequestBody`(OpenAIChatGPTAuth.swift:30)在主路径未被使用——`AppStore.exchangeOAuthCode` 用自己的 `formURLEncoded` 构造(AppStore.swift:696-702),仅测试引用前者。
3. **toolResult isError 丢失**:Responses 输入映射丢弃工具结果的 isError 标志,模型看不到「这次工具调用失败了」。
4. **webLogin 静默忽略自定义 baseURL**:`makeProvider` 在 webLogin 分支不传 baseURL(AppStore.swift:420-427),用户设置的自定义 API 端点被静默忽略,无任何提示。
5. **回调端口 1455 冲突文案**:与本机真 Codex CLI 登录冲突时,报错未给出可操作指引。

## 目标

上述 1/2/3/5 修复;4 显式化(不改行为,给用户可见说明)。

## 非目标

- 不实现 reasoning item 的跨轮回放(需要 ContentBlock 契约扩展,记为已知限制,本轮只在代码注释声明);
- 不改 OAuth 授权流程本身(authorize URL、PKCE、回调监听均不动);
- 不改 API key 路径(OpenAIProvider / LLMProviderFactory 不动);
- 不做 token 过期的主动预刷新(仅 401 反应式刷新;JWT exp 解析留后续)。

## 决策

### D1 刷新会话 `OpenAIOAuthSession`(新文件,Core)

`Sources/AgentLoopCore/Provider/OpenAIOAuthSession.swift`,public actor:

- 依赖注入:`CredentialStore` protocol(`get(account:)/set(_:account:)/delete(account:)`,与 KeychainStore 方法签名一致;KeychainStore 加 extension 声明 conformance;测试用内存假实现)。构造参数:store、四个 account 名(access/refresh/id/accountID)、tokenEndpoint(默认 `OpenAIChatGPTAuth.tokenEndpoint`)、URLSession(默认 .shared,测试注入 URLProtocol stub 的 session)、`onPermanentFailure: (@Sendable () -> Void)?`。
- `func refreshedAccessToken() async throws -> String`:**单飞**——已有进行中的刷新 Task 则 await 同一个(actor 持 `inFlight: Task<String, Error>?`);无 refresh_token → 触发 `onPermanentFailure` 后抛 `ProviderError.unauthorized`。
- 刷新请求:POST tokenEndpoint,`application/x-www-form-urlencoded`,body 用新增的 `OpenAIChatGPTAuth.refreshTokenRequestBody(refreshToken:)`(见 D2),头带 `Accept: application/json`、`User-Agent: codex-cli`(与现有 exchange 一致)。
- 响应处理:2xx 且有 `access_token` → 写回 store(access 必写;`refresh_token` 有则轮换写回;`id_token` 有则更新并重提取 chatgpt_account_id 更新);返回新 access token。HTTP 400/401/403(invalid_grant 等)→ **永久失败**:清除 access token(保留 refresh/id 供诊断)、调 `onPermanentFailure`、抛 `ProviderError.unauthorized`。其他状态码/网络错误 → **瞬时失败**:抛原错误,不动凭据、不调回调(下次再试)。
- 不打日志输出 token 内容(协议 §6.7)。

### D2 `OpenAIChatGPTAuth` 收口请求体构造

- 新增 `static func refreshTokenRequestBody(refreshToken: String) -> Data?`:`grant_type=refresh_token`、`client_id`、`refresh_token`、`scope=openid profile email`(Codex CLI 同款)。
- `AppStore.exchangeOAuthCode` 的 OpenAI 分支(clientID == OpenAIChatGPTAuth.clientID)改用 `OpenAIChatGPTAuth.tokenRequestBody(code:codeVerifier:)`;通用 OAuth 分支(genericOAuthClientID)保持现状 formURLEncoded。消除双实现。

### D3 Provider 401 反应式刷新

`OpenAIResponsesProvider` 增加可选构造参数 `tokenRefresher: (@Sendable () async throws -> String)?`(默认 nil,不破坏现有调用):

- 请求发出前用当前 token;收到 401/403 且 `tokenRefresher != nil` 且本次调用尚未刷新过 → `try await tokenRefresher()` 拿新 token 重发一次(每次 `stream()` 调用至多刷新一次);仍 401/403 → 抛 `ProviderError.unauthorized`。
- 刷新后的重试不消耗 429/5xx 的退避重试次数(独立分支)。
- token 存储为 `var` 局部(struct 内以 let accessToken 保存初始值,重试时用刷新返回值构造新请求头,不改存储属性——保持 Sendable struct 语义)。

### D4 isError 标志保留

Responses 输入映射中,`toolResult.isError == true` 的输出文本前加固定前缀 `[tool_error] `(与 Chat Completions 路径 OpenAIProvider 的现有处理对齐——实现时先查 OpenAIProvider 怎么处理 isError,若它也丢,两处一起加同一前缀常量,常量放 `OpenAIResponsesProvider` 内 `static let toolErrorMarker`)。代码注释声明:Responses function_call_output 无原生 error 字段,用文本标记传达。

### D5 AppStore 接线与 UI 显式化

- AppStore 增加存储属性 `private let openAIOAuthSession: OpenAIOAuthSession`(init 处构造,onPermanentFailure 回调 hop 到 MainActor:置 `oauthNeedsRelogin = true` + `oauthLoginStatus = "ChatGPT 登录已过期,请在设置里重新登录"`)。新增 `@Published var oauthNeedsRelogin = false`(登录成功 saveWebCredential 时复位)。
- `provider(model:)` 的 webLogin+openAIChatCompletions 分支把 `tokenRefresher` 闭包(捕获 session,调 `refreshedAccessToken()`)传给 OpenAIResponsesProvider。`makeProvider` 静态方法签名加参数 `tokenRefresher:`(默认 nil)。
- SettingsView:apiFormat == .openAIChatCompletions 且凭据源为网页登录时,端点输入框下方加一行 caption:「网页登录固定使用 ChatGPT 官方后端,自定义端点仅对 API key 生效」;`oauthNeedsRelogin == true` 时在凭据区显示橙色提示「登录已过期」+ 现有登录按钮即可(不新增按钮)。
- 端口冲突文案(AppStore.swift:571)改为:「OpenAI Auth 需要本机端口 1455,当前被占用(可能是 Codex CLI 或上次未完成的登录);请关闭占用程序后重试」。

## 触及文件

| 文件 | 改动 |
|---|---|
| Sources/AgentLoopCore/Provider/OpenAIChatGPTAuth.swift | +refreshTokenRequestBody |
| Sources/AgentLoopCore/Provider/OpenAIOAuthSession.swift | 新增(actor + CredentialStore protocol) |
| Sources/AgentLoopCore/Support/KeychainStore.swift | +CredentialStore conformance(extension,一行) |
| Sources/AgentLoopCore/Provider/OpenAIResponsesProvider.swift | +tokenRefresher 参数、401 刷新重试、isError 标记 |
| Sources/AgentLoopCore/Provider/OpenAIProvider.swift | isError 处理对齐(若需要) |
| Sources/AgentLoopApp/AppStore.swift | session 接线、tokenRequestBody 收口、relogin 状态、端口文案 |
| Sources/AgentLoopApp/Views/SettingsView.swift | caption + 过期提示 |
| Sources/AgentLoopTestSuite/OpenAIChatGPTAuthTests.swift | +refreshTokenRequestBody 用例 |
| Sources/AgentLoopTestSuite/OpenAIOAuthSessionTests.swift | 新增(见测试要求) |

## 边界与错误路径

- 刷新期间并发多个 CardRunner 同时 401:单飞保证只发一次刷新请求,全部 await 同一结果。
- 刷新成功但 Keychain 写失败(`set` 抛错):视为瞬时失败抛错,不吞。
- 无 refresh_token(老登录残留):直接永久失败路径。
- 取消传播:`stream()` 被取消时,await 中的刷新 Task 不被连带取消(单飞 Task 独立生命周期),下一个调用者可复用其结果。
- UI 预览模式(isUIPreview)不构造 session、不读 Keychain(沿现有 guard)。

## 测试要求(Sources/AgentLoopTestSuite/)

- OpenAIChatGPTAuthTests:refreshTokenRequestBody 字段断言(grant_type/client_id/refresh_token/scope,百分号编码)。
- 新文件 OpenAIOAuthSessionTests(内存 CredentialStore + 每测试独立 URLProtocol stub,沿用 m6.4 的 per-test class 模式):
  1. 刷新成功 → access/refresh/id/accountID 按响应更新,返回新 token;
  2. refresh_token 轮换(响应含新 refresh_token)被写回;
  3. 400 invalid_grant → 永久失败:access 被清、onPermanentFailure 被调、抛 unauthorized;
  4. 网络错误 → 瞬时:凭据不动、回调不调;
  5. 单飞:并发 5 个 refreshedAccessToken 只发 1 次 HTTP(stub 计数);
  6. 无 refresh_token → 永久失败。
- OpenAIResponsesProvider 现有测试文件内追加:
  7. 401 → refresher 被调 → 新 token 重试成功(断言 Authorization 头两次不同);
  8. 401 → 刷新后仍 401 → 抛 unauthorized 且 refresher 只调一次;
  9. isError toolResult → 输出含 `[tool_error] ` 前缀。
- 全量 `swift run RunTests` 通过(当前基线 346)。

## 验证命令

```
CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests
swift build --product AgentLoopApp
```

## 完成定义

刷新链路 6 用例 + provider 3 用例全绿;双实现收口(grep 确认 exchangeOAuthCode OpenAI 分支引用 OpenAIChatGPTAuth.tokenRequestBody);SettingsView 两处 UI 文案落地;全量测试通过;不动本计划未列文件。

## Open questions

无(用户已授权按推荐决策执行;reasoning 回放为声明的已知限制)。
