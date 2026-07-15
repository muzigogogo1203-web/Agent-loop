# Blocked: RuntimeProfileKind CLI cases conflict with no-Views rule

## Blocking conflict

This round's implementation contract requires adding `cli_codex` and `cli_claude`
to `RuntimeProfileKind` and allowing those values in migration `v11-cli-kinds`.

The current app target has exhaustive switches over `RuntimeProfileKind` inside
`Sources/AgentLoopApp/Views/RuntimeProfileViews.swift`, specifically
`RuntimeProfileSection.kindLabel(_:)` and `RuntimeProfileSection.kindIcon(_:)`.
Adding the two required enum cases without updating those switches will make
`swift build --product AgentLoopApp` fail with non-exhaustive switch errors.

The user hard rule for this implementation round says:

> Do NOT touch Sources/AgentLoopApp/Views/ — UI is a separate round.

## Decision needed

Please choose one of these before implementation continues:

1. Allow a minimal compile-only edit in `Sources/AgentLoopApp/Views/RuntimeProfileViews.swift`
   to add labels/icons for `.cliCodex` and `.cliClaude`, without implementing the UI round; or
2. Change the contract so CLI profile kinds are represented somewhere other than
   `RuntimeProfileKind` for this Core round; or
3. Defer `RuntimeProfileKind`/migration v11 CLI-kind support to the UI round and
   scope this round to backend/policy code that does not persist CLI profiles.

I stopped here before making code changes because continuing would require
violating either the authoritative implementation contract or the no-Views hard rule.
