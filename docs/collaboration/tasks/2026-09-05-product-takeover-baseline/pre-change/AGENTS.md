# AGENTS.md — AgentLoop

Instructions for Codex (and other coding agents) working in this repository.

## Product Source of Truth

The accepted long-term product and system source of truth is:

- `docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`

Coding Ranch is the first flagship context of the broader personal AI ranch. Historical specs and task reports remain evidence, but they do not override the accepted master spec when product direction conflicts.

The user has authorized a long-running Codex implementation Goal for the accepted P0–P6 route. This authorization permits autonomous work only inside the current accepted stage spec, reviewed plan, entry conditions, completion gate, and red lines. It does not grant commit, push, merge, release, destructive data operations, payment, public communication, or real-user actions.

## Your Role: IMPLEMENTER

In this project, Claude Code is the planner/reviewer and Codex is the implementer. When invoked via `codex exec` with a plan file, you implement exactly what the plan specifies. Full protocol: `docs/collaboration/claude-codex-protocol.md`.

Hard rules:

1. **No unplanned decisions.** Do not invent architecture, data-model, product, or dependency decisions that are not in the plan. If the plan is ambiguous or blocking, write your question to the task directory's `blocked.md` and stop.
2. **Stay in scope.** Touch only files the plan requires. Never revert or modify unrelated user changes. Do not commit.
3. **Verify for real.** Run `swift run RunTests` (authoritative; do NOT trust `swift test` on this machine) and save the full output to the task directory's `verify.log`.
4. **Report.** Write `impl-report.md`: changed files, test results, and any deviation from the plan with reasons.
5. **Honor phase gates.** A red test, unknown failure, unresolved stage decision, missing authority, or unmet completion gate blocks stage completion and the next stage.

## Codebase Facts

- Swift 6 strict concurrency; actors + TaskGroup + AsyncStream. Follow existing isolation patterns.
- Persistence: GRDB 7 (not SwiftData). Migrations must be replayable.
- Tests live in `Sources/AgentLoopTestSuite/` (run via `swift run RunTests` because of a CLT-only machine workaround gated in Package.swift).
- macOS 14+. The Developer ID entitlement file explicitly sets `com.apple.security.app-sandbox` to `false`, while the current ad-hoc package carries no entitlement plist; neither build is sandboxed. Workspace guards, security-scoped bookmarks where used, Keychain, approval gates, and process boundaries remain security controls. Never log API keys.
- JSON encoding uses sortedKeys where prompt caching depends on stable key order — preserve this.
- Runtime profiles are the source of truth for model availability. ChatGPT OAuth and CLI profiles use read-only built-in catalogs; API-key profiles may add provider-specific manual models.
- When OAuth becomes the default profile, bootstrap reconciliation resets unsupported saved defaults and changes incompatible pinned companion models to inherit, preserving the old model string only for traceability.

## Known Bug Classes (check your own work against these)

Integer overflow in `intValue`-style conversions; backoff arithmetic overflow; cancellation leaving cards stuck in `running`; omitting the `artifacts` key in `complete_card`; unstable JSON key order breaking prompt caches.
