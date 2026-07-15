# Claude Review 01 — OpenAI 接入加固

日期:2026-07-14
对象:feat/v1.0 工作区改动(7 改 + 2 新,+259/-34)
备注:Codex 执行期间发生一次内部会话重试(rollout 10:59 → 11:02 竞态),其自产 impl-report.md 与 verify.log 被竞态覆盖丢失;本 review 直接对 diff 进行,验证以 Claude 真机复跑为准。

## 结论:通过(无 P0/P1)

## 逐项核对

1. **符合 plan**:D1-D5 全部落地,触及文件与计划清单一致。偏差一处(可接受):provider 刷新测试放在 OpenAIChatGPTAuthTests.swift 而非新建 OpenAIResponsesProviderTests.swift(该文件本不存在,计划笔误)。
2. **正确性**:401/403 刷新仅一次(refreshedThisCall),刷新重试不消耗 429 退避次数(独立 retryAttempt);刷新响应缺 access_token → malformedStream;400/401/403 永久失败清 access 保留 refresh 供诊断;仅 OpenAI 官方 clientID 走 OpenAIChatGPTAuth.tokenRequestBody,通用 OAuth 分支不受影响。
3. **并发**:OpenAIOAuthSession actor 单飞(inFlight Task 复用),并发 5 刷新只发 1 请求有测试钉住;OpenAIOAuthReloginHandler 以 @unchecked Sendable + @MainActor weak store 解决 init 顺序,回调 hop 主线程,无跨 actor 数据竞争。
4. **数据层**:无迁移,无 schema 变化。
5. **契约稳定**:requestBody 编码仍 sortedKeys;[tool_error] 前缀双 provider 同源常量(OpenAIResponsesProvider.toolErrorMarker)。
6. **测试真实性**:真机复跑 356/356 全绿(346 基线 + 10 新增:session 6 + 请求体 1 + isError 1 + provider 刷新 2);Codex 沙箱跑会出现 keychainRoundTrip -50 为已知环境限制。
7. **安全**:token 不入日志;刷新失败不清 refresh_token(诊断留痕);Keychain 写失败按瞬时错误抛出不吞。
8. **代码质量**:makeRequest 抽取消除重复;注释解释 Responses 无原生 error 字段。

## P2/P3 备忘

- P2:端口冲突文案硬编码「1455」,未插值 OpenAIChatGPTAuth.callbackPort;丢了底层错误详情。可留待后续。
- P2:OpenAIOAuthSessionTests.swift:185 有一处 nonisolated(unsafe) 冗余 warning(编译器提示),不影响行为。
- P3:reasoning item 跨轮回放仍为已知限制(计划声明的非目标),记入 v1.0 已知限制清单。
