# Blocked: OAuth Model Binding + CLI Runtime Integration

Date: 2026-07-14

## Why implementation stopped

No decision-complete Claude plan exists for this scope. The completed
`2026-07-14-openai-auth-hardening` plan covers token refresh and OAuth transport
hardening only; it does not authorize model-catalog migration, companion schema
changes, or CLI execution backends.

The current worktree is also dirty, including `Sources/AgentLoopApp/AppStore.swift`,
which this task must change. Per AGENTS.md, this large architectural change must
start on a separate branch and must not overwrite unrelated user work.

## Confirmed current behavior

- OAuth completion only sets `preferredCredentialSource = .webLogin`.
- `modelChoices`, `defaultModel`, `distillModel`, `plannerModel`, and persisted
  `CompanionRecord.model` values are not reconciled after an auth/provider change.
- Both regular companions in the live database currently use `glm-5.2` while the
  active credential source is OpenAI web login.
- Credential resolution silently falls back from the preferred source to the
  other stored credential.
- `ProviderError.unauthorized` always says `API key`, even for OAuth.
- The local Codex CLI is installed and logged in with ChatGPT; Claude Code is
  installed; Kimi Code is not currently installed.

## Planner decisions required

1. Define the persistent runtime-profile schema and migration. Decide whether a
   companion stores `(runtimeProfileID, modelPolicy, modelID)` and how the existing
   single `model` column is migrated replayably.
2. Define source-specific model discovery:
   - OpenAI ChatGPT OAuth model catalog source and cache/refresh policy.
   - First-party API-key `/models` behavior.
   - Custom gateway best-effort discovery plus manual unverified IDs.
3. Define switching semantics for defaults, planner/distiller models, regular
   companions, guide/system companions, and already-running missions. Specify
   fail-closed behavior and whether incompatible bindings require a migration
   confirmation sheet.
4. Remove or explicitly retain credential fallback. If retained, specify the UI
   and event-log evidence that makes the resolved credential source observable.
5. Define the CLI backend boundary. A CLI is a full agent runtime, not an
   `LLMProvider`; decide whether `Orchestrator` dispatches through a new
   `CardExecutionBackend` parallel to `CardRunner`.
6. Define the first supported adapters and protocols:
   - Codex SDK/app-server versus `codex exec --json`.
   - Claude Agent SDK versus `claude -p --output-format stream-json`.
   - Kimi ACP versus `kimi -p --output-format stream-json`.
7. Define how CLI agents satisfy the existing board contract. Preferred design
   needs a plan decision: expose `complete_card`, `block_card`, `ask_user`, and
   progress tools through an AgentLoop-owned local MCP server, or define another
   structured completion protocol.
8. Map Ranch autonomy levels to each CLI's sandbox/permission modes. The plan must
   prohibit unattended `--yolo`/permission bypass outside an explicitly isolated
   workspace.
9. Define process supervision, cancellation, timeout, session resume, stdout JSONL,
   stderr diagnostics, exit-code handling, and emergency-stop integration.
10. List the exact files in scope, tests, migrations, live UI acceptance steps,
    and whether this ships as one task or two milestones (OAuth/model profiles
    first, CLI runtimes second).

## Worktree decision required

Choose one before implementation:

- Finish/commit the current `feat/v1.0` dirty work, then branch from its new tip; or
- Create `codex/oauth-model-cli-integration` in a separate worktree from commit
  `86532758c2f612ef67bf0377e0d91beb24eda069`, knowingly excluding current
  uncommitted changes.

Once Claude writes `plan.md` in this directory and resolves the worktree choice,
Codex can implement it, run `swift run RunTests`, save the full output to
`verify.log`, and write `impl-report.md`.
