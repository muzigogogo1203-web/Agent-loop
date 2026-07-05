# Review 01 — M1.1 冒烟修复

真机验证：`swift run RunTests` **75/75 全绿**（Codex 沙箱里的 keychainRoundTrip 失败确认为沙箱无钥匙串权限，status -50，非代码问题——记入协议经验：Codex 环境跑不了 Keychain 测试，以真机复跑为准）。

按 §6 清单逐项：符合 plan（无越权改动，pre-impl 快照比对干净）✓；重试分类与幂等依据正确（history 仅整轮成功后追加，CancellationError 即时上抛，睡前 checkCancellation）✓；并发（Logger Sendable、事件同任务顺序消费、转录回卷与 flush 次序正确）✓；数据层（appendDiagnosticEvent 走既有 appendEvent、无 schema 变更）✓；契约（schema/handoff/sortedKeys 未动）✓；安全（日志只有轮号/状态码/stop_reason/人话错误，无 key/headers/请求体）✓；UI 两个编辑入口 + 编辑态保 id/createdAt/kind/campId/toolsJson ✓。

## 待修

- **P1-1（性能回归）**：重试退避 2s/4s 硬编码在 `AgentLoop.providerTurnWithRetry`，两个新测试真睡 → 测试套件从 ~0.4s 变 6.5s（16 倍）。修法：`AgentLoop.init` 增加参数 `retryDelays: [Duration] = [.seconds(2), .seconds(4)]`（默认值保持产品行为；重试上限即数组长度，替换 `retryCount < 2` 硬编码），`CardRunner` 不传沿用默认；`turnRetriesTransientErrorThenCompletes` / `turnRetryExhaustionSurfacesLastError` 两测试构造 AgentLoop 时传 `[.milliseconds(1), .milliseconds(1)]`。目标：全套件回到 <1s。
- **P2-1（错误吞没）**：`CompanionEditorView.save()` 的空 `catch {}` 把 DB 错误吞掉且 `onDone()` 不会执行，用户会看到点击无反应。修法：加 `@State private var saveError: String?`，catch 里 `saveError = "保存失败：\(error.localizedDescription)"`，按钮下方渲染红色小字；成功路径清空。
- **P3-1（备忘，不修）**：`AgentEvent` 枚举加一行注释说明「每次重试尝试都会重新发出 turnStarted」；活动时间线是非 Lazy VStack，M1 规模（≤30 轮）可接受，M2 长任务时换 LazyVStack + 上限截断。注释顺手加即可。

## 结论

P1×1、P2×1，其余通过。修复后预期 75 测试全绿且套件耗时 <1s。
