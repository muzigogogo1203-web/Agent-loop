# 个人 AI 牧场 · Coding 牧场

个人 AI 牧场是面向 AI 原生独立创作者的个人多 Agent 工作操作系统。Coding 牧场是它的第一个旗舰场景：用户把目标、资料与想法交给牧场，Coding 教练先形成共同理解，随后由可插拔 AI 牧工持续执行，直到产生可验证、可验收、可复用的真实成果。

**AgentLoop** 继续作为内部 target、bundle id 和状态目录兼容名称。当前代码是长期产品的基础，不整体推倒；可靠内核继续保留，入口、成果契约、领域模型与长期连续性按阶段演进。

长期产品与系统单一事实源：

- [`docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`](docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md)

当前阶段：**P0 — 总 spec 与可执行基线**。P0 完成门通过前不修改产品代码。

## Current Implemented Ranch Loop

1. **喂牛 (Feed)** — paste articles, notes, or ideas; raw text is stored locally with SHA-256 dedupe.
2. **反刍 (Ruminate)** — a background LLM pass distills the material into camp notes, requirements, and action candidates (strict JSON, no tools, source treated as untrusted).
3. **放牛 (Graze)** — confirm a candidate into an editable mission draft with acceptance checklists, executed by the existing orchestration kernel.
4. **回营 (Return)** — accept results against real artifacts; trophies, expedition reports, and cowork records accumulate.
5. **领牛 (Unlock)** — the current prototype projects selected events and artifacts into an initial test-cow unlock; this is not yet the verified capability-growth contract targeted by P1/P2.

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

**Current implementation baseline (`main@02334ec8`)**: the ranch product layer, orchestration kernel, approvals, MCP, harvest/trophy center, scheduled missions, runtime profiles, Codex/Claude CLI backends, pixel world, and packaging chain are in place.

**Accepted target direction**: Coding Coach → shared understanding → outcome contract → bounded multi-agent execution → independent verification → delivery → user/policy acceptance → evidence-backed memory and growth. P0–P6 progress and completion gates are tracked in the master spec.
