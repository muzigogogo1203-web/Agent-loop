# 个人 AI 牧场 · Coding 牧场

个人 AI 牧场是面向 AI 原生独立创作者的个人多 Agent 工作操作系统。Coding 牧场是它的第一个旗舰场景：用户把目标、资料与想法交给牧场，Coding 教练先形成共同理解，随后由可插拔 AI 牧工持续执行，直到产生可验证、可验收、可复用的真实成果。

**AgentLoop** 继续作为内部 target、bundle id 和状态目录兼容名称。当前代码是长期产品的基础，不整体推倒；可靠内核继续保留，入口、成果契约、领域模型与长期连续性按阶段演进。

长期产品与系统单一事实源：

- [`docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`](docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md)

当前状态（2026-09-05）：**P1 实施与桌面 Coding 收口正在进行**。P1-F1 尚未正式验收，P1 和 P2 也未 Accepted。当前接手决策见 [`spec.md`](docs/collaboration/tasks/2026-09-05-product-takeover-baseline/spec.md)；本轮证据与结论以 [`impl-report.md`](docs/collaboration/tasks/2026-09-05-product-takeover-baseline/impl-report.md) 实际记录为准，不预先宣布验证结果。

## Current Feed-led UI (Implemented Behavior)

下列 Feed 驱动流程是现有界面行为，不是桌面 Coding 收口后的最终默认旅程：

1. **喂牛 (Feed)** — paste articles, notes, or ideas; raw text is stored locally with SHA-256 dedupe.
2. **反刍 (Ruminate)** — a background LLM pass distills the material into camp notes, requirements, and action candidates (strict JSON, no tools, source treated as untrusted).
3. **放牛 (Graze)** — confirm a candidate into an editable mission draft with acceptance checklists, executed by the existing orchestration kernel.
4. **回营 (Return)** — accept results against real artifacts; trophies, expedition reports, and cowork records accumulate.
5. **领牛 (Unlock)** — the current prototype projects selected events and artifacts into an initial test-cow unlock; this is not yet the verified capability-growth contract targeted by P1/P2.

## Target Desktop Journey

```text
目标输入 → 教练与共同理解 → 确认成果契约 → 持续执行
→ 独立验证 → 用户验收 → 项目记忆
```

当前方向是将喂牛/反刍作为知识输入能力并入这条统一流程，而不是整体重写现有可靠内核。

## Under the Hood

- Multi-step missions with planner-generated cards and per-companion dispatch.
- Native macOS UI: activity feeds, card details, mission history, campfire theater.
- SQLite via GRDB (WAL) — core Mission/Card/Run transitions are durable and support crash recovery plus a persistent emergency halt; known App-layer in-flight gaps in planning and rumination are explicit P1 risks.
- Typed tools: files, shell (approval-gated), web search/fetch, MCP servers (stdio), progress notes, user questions, structured handoffs.
- Scheduled missions (daily/weekly) with notifications and guide broadcasts; optional menu-bar residency.
- Providers: Anthropic Messages API (and compatible gateways), OpenAI Chat Completions, and ChatGPT web login (Responses API with automatic token refresh).
- Keys in Keychain; runtime data under `Application Support/AgentLoop`.

## Tech Stack

- Swift 6 / SwiftPM, strict concurrency
- SwiftUI for macOS 14+
- GRDB / SQLite WAL
- Swift Testing via the bundled `RunTests` executable

## Run Locally

```bash
scripts/run-app.sh        # canonical: builds an .app shell and launches it
```

(`swift run AgentLoopApp` also works on machines where bare binaries render text correctly.)

## Validate

```bash
CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests
swift build --product AgentLoopApp
```

## Package

```bash
scripts/package-app.sh                       # ad-hoc signed .app + DMG + zip in dist/
SIGN_ID="Developer ID Application: …" NOTARY_PROFILE=<profile> scripts/package-app.sh   # full chain when certificate is available
```

## Status

**Historical base identity**: `02334ec8d21533be81d93d39191bc7d9b9c24f7f` was the base HEAD before the current P1 work. The active implementation is that historical base plus substantial tracked and untracked dirty-workspace changes on `codex/product-takeover-baseline-20260905`; it must not be described as the state of `main` or as an accepted baseline.

**Accepted target direction**: Coding Coach → shared understanding → outcome contract → bounded multi-agent execution → independent verification → delivery → user/policy acceptance → evidence-backed memory and growth. P0–P6 progress and completion gates are tracked in the master spec; current baseline-audit evidence does not itself accept P1-F1, P1, or P2.
