# 验收 — M1.1 冒烟反馈修复

- 日期：2026-07-04
- 流程：plan.md → Codex 实现（首轮）→ Claude review 01（P1×1 / P2×1 / P3×1）→ Codex resume 修复 → Claude 真机复验通过
- 首个 Claude×Codex 协议任务，全流程按 docs/collaboration/claude-codex-protocol.md 执行

## 改了什么

- **Fix A 运行活动时间线**：AgentEvent 新增 `turnStarted` / `turnRetrying`；AppStore 维护 ActivityItem 流（开工/工具进行中→完成/失败/重试/收尾），add_progress_note 成功即从 db 实时刷新进展；TaskRunView 在转录上方渲染时间线（图标+颜色分级）。
- **Fix B 伙伴编辑**：编辑器按 companionId 加载现有记录（自定义模型 id 回填正确），保存仅更新四字段、保留 id/createdAt/kind/campId/toolsJson；入口=侧栏右键「编辑…」+ 私聊工具栏「编辑伙伴」；编辑完成回到该伙伴私聊；保存失败有红字提示（不再吞错）。
- **Fix C 运行韧性**：AgentLoop 按轮重试（URLError 全部 / http 5xx / overloadedRetriesExhausted / malformedStream / apiError[overloaded_error,api_error]；unauthorized/4xx/取消不重试），退避可注入（默认 2s/4s，测试用 1ms），历史仅整轮成功后追加保证幂等；转录按 turnStarted 水位回卷防重复；ProviderError 人话化 description；CardRunner 失败前落 `run_error` 诊断事件；os.Logger（loop/provider 两类目，无 key/请求体）。

## 验证

- 真机 `swift run RunTests`：**75/75 绿，0.36s**（Codex 沙箱中 keychainRoundTrip 失败为其沙箱无钥匙串权限，已确认环境性）。
- `swift build` 干净。
- 新增测试 5：重试成功/重试耗尽/401 不重试/turnStarted 次序/错误描述人话。

## 残留风险与备忘

- 用户报的「单卡经常报错」根因假设（长会话传输错误无重试）已按方案加固，但未拿到原始错误文本实证——下次复现时看活动时间线的重试条目与 `run_error` 事件即可定位真因。
- 活动时间线为非 Lazy VStack，M2 长任务需换 LazyVStack+截断（P3 备忘已注释）。
- 协议经验：Codex 沙箱跑不了 Keychain 测试、SwiftPM 需 `--disable-sandbox` + Clang cache 重定向——已在其 impl-report 记录，后续任务书可预告知。
