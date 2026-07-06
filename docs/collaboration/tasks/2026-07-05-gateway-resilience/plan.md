# 网关韧性 — 实现计划（Level 2）

背景（M3 正式测试实证）：中转网关在**大体积 tool_use 生成**（如一次 write_file 写整个 22KB HTML）时频繁把 SSE 流掐断（`malformedStream`），叠加偶发长静默触发空闲超时；单卡曾连挂 4 个 run。传输重试每次全量重生成，越大越容易再挂——恶性循环。三管齐下（均为客户端可控）：

## 改动 1：分块写文件（治本——降低单轮生成体积）

- `ToolDef` 的 `write_file` schema 增加可选参数 `append: boolean`（缺省 false=覆盖，与现状兼容）；description 更新说明两种模式。
- `FileTools.write` 增加 `append: Bool = false` 参数：append 时对已存在文件追加写（`FileHandle` seekToEnd 或读-拼-写均可，选实现最简的；文件不存在时 append 等同新建）。路径校验逻辑不变。
- `FileToolHandler` 解析新参数透传。
- `ContextPacket` 工作契约追加一条（放在现有契约清单末尾）：「写长文件（约超过 3000 字）时分多次 write_file：第一次不带 append 建立文件，之后每次 append: true 续写一段，每段控制在 3000 字以内」。**确定性文案，无时间戳**。

## 改动 2：非流式兜底（治断流——同一轮内不再反复重生成）

- `AnthropicProvider.run()` 内：当 `consumeStream` 抛 `malformedStream` 且还有剩余尝试次数时，下一次尝试改用 **stream=false** 的普通 JSON 请求（请求体仅 stream 字段不同，system/tools/cache_control 逐字节保持）：
  - 新增 `consumeNonStreaming(data:continuation:)`：解析完整 message JSON → content blocks（沿用 `ContentBlock.init(from:)`）、stop_reason、usage → 先对全部 text 块合并 yield 一次 `.textDelta`（UI 连续性），再 yield `.turn(TurnResult)`。
  - 解析失败按既有 `.malformedStream` 路径抛出。
- 非流式只作为**断流后的兜底**，首选路径永远是流式（保持流式 UI 与缓存行为不变）。
- `requestBody` 增加 `stream: Bool = true` 参数（编码时按值写入）；既有断言测试更新为显式 `stream: true` 的期望不变。

## 改动 3：重试预算放宽（治偶发——给网关抖动更多机会）

- `KernelDefaults` 新增 `transportRetryDelays: [Duration] = [.seconds(2), .seconds(5), .seconds(10), .seconds(20)]`。
- `CardRunner` 构造 `AgentLoop` 时传入该值（现默认 [2s,4s]）；`Planner` 维持自己的 [2s,4s] 不变（规划轮小、快速失败回退更好）。
- AgentLoop 重试语义（history 快照重发、超时独立计数）零改动。

## 测试要求（`Sources/AgentLoopTestSuite/`）

1. `FileToolsTests.appendModeAppends`：覆盖写 → append 两段 → 读回全文顺序正确；append 到不存在文件 = 新建。
2. `ToolExecutorTests` 更新 write_file schema 断言（含 append 属性）。
3. `ContextPacketTests.contractMentionsChunkedWrites`（断言契约含「append」与「3000」）。
4. `AnthropicProviderTests.fallsBackToNonStreamingAfterMalformedStream`：Stub 第一次返回截断 SSE（无 message_stop）→ 第二次请求断言 body 的 stream==false → 返回完整 message JSON → 得到正确 TurnResult（content/stop_reason/usage），且事件流里有 textDelta。
5. `AnthropicProviderTests.nonStreamingParsesToolUse`：非流式响应含 tool_use 块 → toolUses 解析正确。
6. 既有 138 测试零回归。

## 验证

沙箱：`CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests`（keychain -50 环境性）+ 同法 swift build；输出到本目录 verify.log，写 impl-report.md。真机复跑为准。

## 完成定义

新测试 5 组全绿、零回归；plan 外零改动；不 commit。
