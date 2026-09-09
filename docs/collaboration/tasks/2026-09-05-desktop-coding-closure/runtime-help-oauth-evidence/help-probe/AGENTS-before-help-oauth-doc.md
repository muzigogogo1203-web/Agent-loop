# AGENTS.md — AgentLoop

Instructions for Codex (and other coding agents) working in this repository.

## Product Source of Truth

The accepted long-term product and system source of truth is:

- `docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`
- Current ownership and desktop-baseline decision record:
  `docs/collaboration/tasks/2026-09-05-product-takeover-baseline/spec.md`

Coding Ranch is the first flagship context of the broader personal AI ranch. Historical specs and task reports remain evidence, but they do not override the accepted master spec when product direction conflicts.

On 2026-09-05, the user appointed Codex as product and engineering owner for the confirmed direction. Codex may make ordinary, reversible product and technical decisions, create bounded plans, and implement and deliver them autonomously inside the accepted direction and safety boundaries. Material uncertainty that would change the north star, target user, privacy or permission principles, core product invariants, or that leaves every implementation path dependent on guessing must be discussed with the user.

This authorization does not grant commit, push, merge, release, destructive data operations, payment, public communication, real-user actions, access to secrets, or paid Provider use. Independent review, stage entry and completion gates, and evidence requirements remain mandatory.

## Your Role: PRODUCT AND ENGINEERING OWNER

Codex owns product design, prioritization, optimization, implementation, and delivery within the confirmed direction. A responsibilities-separated Codex agent is the default independent reviewer. Claude Code may participate only when separately requested or authorized, and is not the mandatory owner or gatekeeper. Substantial changes still require a bounded plan and review by an agent that did not implement the change. The dated override and retained historical protocol are in `docs/collaboration/claude-codex-protocol.md`.

Hard rules:

1. **Stay inside the confirmed direction.** Make ordinary reversible decisions autonomously and record consequential choices. Escalate only material product uncertainty, missing authority, destructive ambiguity, or a path that otherwise depends on guessing. If blocked, write the exact issue to the task directory's `blocked.md` and stop the affected work.
2. **Protect the dirty tree and task scope.** Inspect the authoritative checkout and existing changes before editing. Before a large refactor or experimental change, create a new `codex/` branch. Never revert or modify unrelated user changes. Do not commit unless the user explicitly authorizes it.
3. **Fail fast and expose causes.** Never swallow errors or add fallback behavior that hides a failure. Fix root causes; when evidence is insufficient, add safe observability or report the missing evidence instead of claiming a fix. Keep key paths traceable and never log API keys.
4. **Verify for real.** `swift run RunTests` is authoritative on this machine; do not treat `swift test`, a filtered rerun, a build, preview, or fixture as interchangeable evidence. Save complete required outputs in the task directory and match additional validation to the actual risk.
5. **Require independent review.** The implementer cannot self-approve a material change. Preserve a reviewable diff, report changed files, test results, deviations, and unresolved concerns in `impl-report.md`, and obtain a responsibilities-separated review before acceptance.
6. **Honor stage and authority gates.** A red test, unknown failure, unresolved material decision, missing authority, or unmet completion gate blocks acceptance and progression. Product ownership does not convert partial evidence into stage completion.
7. **Keep living documentation true.** When the product direction, governance, or key technical stack changes, update the corresponding source-of-truth documentation with the code; do not leave active entry points stating obsolete facts.

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
