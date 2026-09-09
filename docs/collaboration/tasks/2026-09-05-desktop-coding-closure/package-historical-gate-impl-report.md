# Historical packaging gate implementation

2026-09-06. Implemented the exact approved `package-historical-gate-plan.md` scope. Independent review and parent-run verification remain pending; this is not a full-suite or stage completion claim.

## Changed files

- `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`: added the dated development-packaging singleton containing only `scripts/run-app.sh`; retained the original `unaffectedEntries` filter and count of 105; partitioned that original group into 104 original-manifest byte-exact entries and one separately pinned reviewed launcher. Assertions check the literal singleton declaration, selected path identity, both counts, total count, regular nonsymlink files, and every applicable SHA-256.
- This implementation report.

No A3 logic, historical manifest, production source, script, other assertion, or other test changed. `package-app.sh` receives no new exemption. No deviation from the approved plan.

## Evidence

- Branch observed: `codex/desktop-coding-closure-20260905`.
- Verified source preimage SHA-256 matches the parent-owned preimage: `b8b3640e1b7d0093e55efd4dc31a72ee0f500302743afd024ad014ce5e293a9f`.
- Read the existing behavioral RED at `runtime-base-full.log:1440–1441`: the historical A4 test reported `scripts/run-app.sh` hash drift. No duplicate RED run was performed.
- Inspected the full scoped preimage/current diff: one singleton declaration and the A4 verification block only.
- `git diff --no-index --check` against the supplied preimage emitted no whitespace findings; its actual exit was 1 (the compared files differ). This is a static diff check, not test evidence.
- Updated source SHA-256: `56b504731d1bff1432e36c82289c1013df033d1dd383c7fc7b5318ca3e6ff06b`.
- Independently measured launcher SHA-256 matches the new literal checkpoint: `34ff641b68379e1978367cd2c5c9890638c5913627942858767efe56b475428c`.
- Historical A4 manifest SHA-256 remains `6c59ed6d2e411ee2859f16833567471142b59958fabbc56f0f3f78a3602abc71`; its 206-row assertion is unchanged.

## Verification ownership and remaining gates

Per dispatch, no build, test, App, Provider, or commit was run. The parent owns the planned focused `broadcastFailureDoesNotRewriteStartedFire` verification and all full-suite evidence. Existing full-suite failures remain unresolved by this boundary-only change. Source-writer ownership is released for independent review and parent verification.
