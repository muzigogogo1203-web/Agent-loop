# Coding 牧场 (Coding Ranch)

Coding 牧场 is a macOS SwiftUI app where you feed knowledge to a small herd of AI "cows" that turn it into verifiable coding work — backed by a durable, inspectable multi-agent work loop.

Formerly known as **AgentLoop** (the internal target, bundle id `com.muzi.agentloop`, and state directory keep that name for compatibility). It is currently a private experimental project.

## The Ranch Loop

1. **喂牛 (Feed)** — paste articles, notes, or ideas; raw text is stored locally with SHA-256 dedupe.
2. **反刍 (Ruminate)** — a background LLM pass distills the material into camp notes, requirements, and action candidates (strict JSON, no tools, source treated as untrusted).
3. **放牛 (Graze)** — confirm a candidate into an editable mission draft with acceptance checklists, executed by the existing orchestration kernel.
4. **回营 (Return)** — accept results against real artifacts; trophies, expedition reports, and cowork records accumulate.
5. **领牛 (Unlock)** — real usage evidence (materialized knowledge, referenced missions, artifacts, accepted work) unlocks the test cow.

## Under the Hood

- Multi-step missions with planner-generated cards and per-companion dispatch.
- Native macOS UI: activity feeds, card details, mission history, campfire theater.
- SQLite via GRDB (WAL) — every state transition is inspectable and resumable, with crash recovery and a persistent emergency halt.
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

**v1.0 line (Coding Ranch)**: the ranch product layer, orchestration kernel (M1–M9), sentry approvals, MCP traderoute, harvest/trophy center, scheduled missions, and packaging are in place. Known limitations: Sparkle auto-update deferred (private repo, no Developer ID certificate yet); OpenAI reasoning-item replay not implemented.
