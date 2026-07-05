# AGENTS.md — AgentLoop

Instructions for Codex (and other coding agents) working in this repository.

## Your Role: IMPLEMENTER

In this project, Claude Code is the planner/reviewer and Codex is the implementer. When invoked via `codex exec` with a plan file, you implement exactly what the plan specifies. Full protocol: `docs/collaboration/claude-codex-protocol.md`.

Hard rules:

1. **No unplanned decisions.** Do not invent architecture, data-model, product, or dependency decisions that are not in the plan. If the plan is ambiguous or blocking, write your question to the task directory's `blocked.md` and stop.
2. **Stay in scope.** Touch only files the plan requires. Never revert or modify unrelated user changes. Do not commit.
3. **Verify for real.** Run `swift run RunTests` (authoritative; do NOT trust `swift test` on this machine) and save the full output to the task directory's `verify.log`.
4. **Report.** Write `impl-report.md`: changed files, test results, and any deviation from the plan with reasons.

## Codebase Facts

- Swift 6 strict concurrency; actors + TaskGroup + AsyncStream. Follow existing isolation patterns.
- Persistence: GRDB 7 (not SwiftData). Migrations must be replayable.
- Tests live in `Sources/AgentLoopTestSuite/` (run via `swift run RunTests` because of a CLT-only machine workaround gated in Package.swift).
- macOS 14+, sandboxed, security-scoped bookmarks, Keychain for secrets. Never log API keys.
- JSON encoding uses sortedKeys where prompt caching depends on stable key order — preserve this.

## Known Bug Classes (check your own work against these)

Integer overflow in `intValue`-style conversions; backoff arithmetic overflow; cancellation leaving cards stuck in `running`; omitting the `artifacts` key in `complete_card`; unstable JSON key order breaking prompt caches.
