# AgentLoop / Coding 牧场历史文档权威索引

> 状态：Active
>
> 日期：2026-07-25
>
> 当前产品方向 SSOT：`docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`

## 1. 使用规则

本索引区分“规范性方向”和“历史证据”：

1. `Superseded` 只表示产品方向被取代，不删除、不伪造历史事实。
2. 历史 task plan 的非目标、禁止范围和验收，只约束原任务。
3. Live-test 文件是测试定义；只有真实填写结果、匹配日志、acceptance 或 tag 才可能成为执行证据。
4. Impl report 是时点自述；完整日志、commit、真实运行证据和外部回执的证明力更强。
5. 旧证据只证明其记录的 branch、HEAD、版本和环境，不能替代当前 P0 在 `02334ec8` 上重建的基线证据。
6. 历史文件原文默认冻结。只有三个直接冲突的产品方向 spec 增加最小 Superseded banner。

允许的分类：

- `Active SSOT`
- `Superseded — product direction only`
- `Historical task plan`
- `Historical test definition`
- `Historical implementation evidence`
- `Historical verification evidence`
- `Missing external input`

## 2. 产品方向文档

| Path | 原始日期 / 基线 | 当前分类 | 被取代内容 | 保留价值 | 证据限制 |
|---|---|---|---|---|---|
| `docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md` | 2026-07-25 / `02334ec8` | Active SSOT | — | 长期产品、领域模型、P0–P6、阶段门与红线 | 实现事实仍需 evidence matrix 独立证明 |
| `docs/superpowers/specs/2026-07-04-agentloop-macos-mvp-design.md` | 2026-07-04 | Superseded — product direction only | API-only、无 CLI/Shell/MCP、旧目标用户与产品闭环 | 确定性状态机、一卡一主、成果耐久、恢复内核 | 只对原 MVP 基线有效 |
| `docs/superpowers/specs/2026-07-06-agentloop-v2-design.md` | 2026-07-06 / `332a75b` | Superseded — product direction only | 旧 M6–M10 路线、CLI/云端等延期或排除结论 | “能力 × 信任”、权限先于能力、预算与可观测性 | 不能覆盖个人账户云基础设施和当前阶段顺序 |
| `docs/superpowers/specs/2026-07-15-coding-ranch-visual-design.md` | 2026-07-15 | Superseded — product direction only | 黏土微缩、明确排除像素的视觉方向 | 状态驱动动画、主题正交、Reduce Motion | 当前正式方向为数据驱动像素世界 |

## 3. 历史实施计划

以下分类为 `Historical task plan`，原文冻结：

- `docs/superpowers/plans/2026-07-04-m1-single-companion-loop.md`
- `docs/collaboration/tasks/2026-07-04-m2-kernel/plan.md`
- `docs/collaboration/tasks/2026-07-05-m3-concurrency-interaction/plan.md`
- `docs/collaboration/tasks/2026-07-05-m4-knowledge-dialogue/plan.md`
- `docs/collaboration/tasks/2026-07-05-m5-camps-recovery-ship/plan.md`
- `docs/collaboration/tasks/2026-07-07-m6-scout-tools/plan.md`
- `docs/collaboration/tasks/2026-07-07-m7-sentry-approvals/plan.md`
- `docs/collaboration/tasks/2026-07-07-m8-traderoute-mcp/plan.md`
- `docs/collaboration/tasks/2026-07-07-m9-harvest-return/plan.md`
- `docs/collaboration/tasks/2026-07-07-m10-evercamp-ship/plan.md`
- `docs/collaboration/tasks/2026-07-07-m10-evercamp-ship/plan-v2.md`
- `docs/collaboration/tasks/2026-07-14-coding-ranch-mvp/plan.md`
- `docs/collaboration/tasks/2026-07-14-oauth-model-cli-integration/plan.md`
- `docs/collaboration/tasks/2026-07-14-v1.1a-runtime-profiles/plan.md`
- `docs/collaboration/tasks/2026-07-14-v1.1b-cli-backends/plan.md`
- 后续 OAuth、运行时、UI、黏土、像素和整合任务目录中的 `plan.md`

特别边界：

- `2026-07-14-coding-ranch-mvp/plan.md` 中硬件、录音、云端和 Runtime 的禁止范围只约束当次 MVP。
- M10 原任务内部由 `plan-v2.md` 取代 `plan.md`；这一关系不升级为当前产品权威。

## 4. 历史人工测试定义

以下分类为 `Historical test definition`：

- `docs/superpowers/2026-07-04-m1-live-smoke.md`
- `docs/superpowers/2026-07-04-m2-live-smoke.md`
- `docs/superpowers/2026-07-05-m3-live-test.md`
- `docs/superpowers/2026-07-06-m4-live-test.md`
- `docs/superpowers/2026-07-06-m5-live-test.md`
- `docs/superpowers/2026-07-07-m6-live-test.md`
- `docs/superpowers/2026-07-07-m7-live-test.md`
- `docs/superpowers/2026-07-08-m8-live-test.md`
- `docs/superpowers/2026-07-14-v1.0-live-test.md`

### v1.0 不能被推定为已验收

2026-07-25 的只读审计确认：

- `2026-07-14-v1.0-live-test.md` 明写 m4–m8 的独立 live-test 从未执行；
- 文件仍有 45 个 `☐`，结果区为空；
- Git tag 只有 `m1`、`m2`、`m3`，没有 `v1.0`。

因此该文件只证明“验收曾被定义”，不能证明 v1.0 已执行或通过。

M2、M3 的 acceptance 和对应 tag 是更强的历史证据，但仍不构成 P0–P6 当前完成证据：

- `docs/collaboration/tasks/2026-07-04-m2-kernel/acceptance.md`
- `docs/collaboration/tasks/2026-07-05-m3-concurrency-interaction/acceptance.md`
- tags `m2`、`m3`

## 5. 历史实现与验证证据

以下类型保留原文：

- `docs/collaboration/tasks/*/impl-report.md`
- `docs/collaboration/tasks/*/acceptance.md`
- `docs/collaboration/tasks/*/reviews/**`
- `docs/collaboration/tasks/*/verify.log`
- `docs/collaboration/tasks/*/build.log`
- `docs/collaboration/tasks/*/live-verify.log`
- `docs/collaboration/tasks/*/package.log`
- `docs/collaboration/tasks/*/pre-impl-status.txt`
- `docs/collaboration/tasks/*/pre-codex-status.txt`

关键限制：

- `docs/collaboration/tasks/2026-07-07-m10-evercamp-ship/impl-report.md` 自述 verify log 不完整，且当轮未覆盖 SwiftUI、Sparkle 和打包，不能独立证明整个 M10 完成。
- 2026-07-18 的多份 `live-verify.log` 是较强历史现场证据，但基线约为 `3f11d08`，不能替代当前 `02334ec8` 的 P0 复验。
- 当前像素方向的实现历史集中在：
  - `docs/collaboration/tasks/2026-07-20-pixel-ranch-app/`
  - `docs/collaboration/tasks/2026-07-20-pixel-world-integration/`
  - `docs/collaboration/tasks/2026-07-20-pixel-world-round2/`
  - `docs/collaboration/tasks/2026-07-20-ui-polish-round/`
  - `docs/collaboration/tasks/2026-07-21-cow-walk-frames/`

## 6. 缺失外部输入

以下分类为 `Missing external input`，本轮未找到可读副本：

- `/Users/liyongwan.3/Desktop/heima-joyinside-workspace/02_product/Coding牧场-AgentLoop应用层产品化改造方案-v1.md`
- `/Users/liyongwan.3/Desktop/heima-joyinside-workspace/02_product/Coding牧场-UI实施任务书-Claude-v1.md`
- 牛哒 / JoyInside 的独立产品正文

当前长期总 spec 只依据现存仓库、当前代码和牧场主最新访谈重建方向，不声称恢复了这些缺失文件的未读内容。

