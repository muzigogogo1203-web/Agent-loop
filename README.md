# AgentLoop

AgentLoop is a macOS SwiftUI app for running small teams of AI companions through a durable, inspectable work loop.

The app combines a local orchestration kernel, persistent mission/card state, typed tools, handoff packets, and a camp-style interface for guiding multi-agent work. It is currently a private experimental project.

## What It Does

- Runs multi-step missions with planner-generated cards and per-companion dispatch.
- Streams model work into a native macOS UI with activity feeds, card details, and mission history.
- Persists state in SQLite through GRDB so work can be inspected and resumed.
- Supports typed tools for files, web fetch, progress notes, user questions, and structured handoffs.
- Stores API keys in Keychain and keeps runtime data under Application Support.
- Includes early knowledge features: camp notes, companion memory, guide chat, and distillation flows.

## Tech Stack

- Swift 6 / SwiftPM
- SwiftUI for macOS 14+
- GRDB / SQLite WAL
- Anthropic Messages API compatible provider client
- Swift Testing via the bundled `RunTests` executable

## Run Locally

```bash
swift run AgentLoopApp
```

On this machine, the canonical app launch path is:

```bash
scripts/run-app.sh
```

## Validate

```bash
CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests
swift build --product AgentLoopApp
```

## Status

The current line is around M4/M5 planning: orchestration, multi-companion interaction, gateway resilience, and knowledge/dialogue foundations are in place; crash recovery, global budget controls, multi-camp polish, and distributable packaging are next.
