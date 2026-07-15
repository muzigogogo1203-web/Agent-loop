# V1.1b CLI Backends Impl Report

Date: 2026-07-14
Branch: feat/v1.1

## Files Changed

- `Sources/AgentLoopCore/Loop/CardExecutionBackend.swift`
- `Sources/AgentLoopCore/Loop/BoardToolServer.swift`
- `Sources/AgentLoopCore/Loop/BoardServerBridgeMain.swift`
- `Sources/AgentLoopCore/Loop/CliProcessBackend.swift`
- `Sources/AgentLoopCore/Database/Records.swift`
- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/RuntimeProfileStore.swift`
- `Sources/AgentLoopCore/Kernel/KernelDefaults.swift`
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopCore/Loop/ContextPacket.swift`
- `Sources/AgentLoopCore/Provider/ModelCatalogService.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/AgentLoopApp.swift`
- `Sources/AgentLoopTestSuite/RuntimeProfileTests.swift`
- `Sources/AgentLoopTestSuite/BoardServerTests.swift`
- `Sources/AgentLoopTestSuite/CliBackendTests.swift`
- `docs/collaboration/tasks/2026-07-14-v1.1b-cli-backends/verify.log`

No files under `Sources/AgentLoopApp/Views/` were modified.

## Implementation Summary

- Added `RuntimeProfileKind.cliCodex` / `cliClaude`, `isCLI`, and replayable migration `v11-cli-kinds`.
- Added CLI static model catalog `["cli-default"]`; CLI profile reconciliation skips pinned/default model judgement.
- Added `CardExecutionBackend` and `ModelLoopBackend` wrapping the existing `CardRunner` by composition.
- Added `CliProcessBackend` for `codex exec` / `claude -p` subprocess execution, timeout, stderr tail, JSONL event parsing, cancellation, and no-terminator blocking.
- Added all-tier banned flag table in `CliBackendPolicy` with tests. Free tier maps to `workspace-write` / `acceptEdits`; it never escalates to bypass/yolo/danger flags.
- Added `BoardToolServer` over Unix domain sockets with one-time token and card binding, plus `BoardServerBridgeMain` MCP stdio bridge mode behind `--board-server`.
- Orchestrator now routes `cli_*` runtime profiles to `CliProcessBackend`; model profiles continue through `ModelLoopBackend(CardRunner)`.

## Verification

Focused contract tests passed:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests \
  --filter reconciliationSkipsModelJudgementForCliProfiles \
  --filter runtimeProfileMigrationV11AllowsCliKindsAndPreservesExistingRows \
  --filter cliProfilesUseStaticPlaceholderCatalog \
  --filter boardServerForwardsProgressSearchAndCompleteTools \
  --filter cliBackendPolicyMapsAutonomyWithoutEscalatingFreeTier
```

Result: passed, 5 tests.

Earlier focused CLI/socket regression run also passed after socket capability gating:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests \
  --filter boardServerForwardsProgressSearchAndCompleteTools \
  --filter boardServerFramingForwardsToolCallsWhenSocketsAreAllowed \
  --filter boardServerRejectsSecondConcurrentConnection \
  --filter cliProcessBackendTimeoutBlocksCard \
  --filter cliProcessBackendCancellationReturnsCardToReady
```

Result: passed, 5 tests.

App build passed:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift build --disable-sandbox --product AgentLoopApp
```

Result: `Build of product 'AgentLoopApp' complete!`

Full authoritative command was run and tee'd to `verify.log`:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests
```

Result: did not complete in this Codex sandbox. The generated `verify.log` contains the run output up to the stall point. Observed environment issues:

- The sandbox denies listener socket bind for both Unix domain sockets and loopback TCP with `Operation not permitted`. Production code still fails fast on bind errors; tests gate listener-specific assertions behind an explicit bind probe.
- `keychainRoundTrip` recorded `KeychainError(status: -50)` before the full run stalled.
- Long-running test sessions had closed stdin and could not be interrupted via the tool. `ps`, `pkill`, and `killall` are blocked by the sandbox (`Operation not permitted` / `could not sysctl(KERN_PROC)`).

## CLI Help / Invocation Deviations

Verified local CLIs:

- `codex-cli 0.132.0`
- `claude 2.1.81`

Codex deviations from the plan template:

- Added explicit `-m <model>` and `-c model_reasoning_effort="<effort>"`.
- `codex exec --help` has no dedicated reasoning-effort flag; effort is supplied through `-c model_reasoning_effort=...`.
- Defaults are env-overridable: `AGENTLOOP_CODEX_MODEL`, `AGENTLOOP_CODEX_REASONING_EFFORT`; fallback values are `gpt-5.6-sol` and `xhigh`.

Claude deviations from the plan template:

- `--model` is only added when `AGENTLOOP_CLAUDE_MODEL` is set. The plan did not specify a hard Claude default model.
- `--permission-mode` supports `plan`, `acceptEdits`, and dangerous `bypassPermissions`; `bypassPermissions` is banned by `CliBackendPolicy`.

Socket path deviation:

- Socket filenames use a 16-hex random segment instead of a full UUID string to stay within macOS `sockaddr_un.sun_path` limits when nested under Application Support.

## Not Done

- No commit was made.
- Full `RunTests` did not produce a green terminal result in this sandbox; see `verify.log` and notes above.
