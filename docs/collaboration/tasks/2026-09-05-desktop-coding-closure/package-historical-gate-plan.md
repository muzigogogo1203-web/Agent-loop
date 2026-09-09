# Packaging successor in the historical A4 gate

2026-09-06. One bounded test-boundary correction; no production behavior change.

## Authority and RED

The approved two-script packaging change and raw-path Fix 1 were independently reviewed and passed the parent's literal-path/17 argument checks. The first subsequent default full run (`runtime-base-full.log:1440–1441`) failed the historical A4 unaffected hash for `scripts/run-app.sh`. Its frozen hash is the exact captured package preimage, not a newly discovered production failure. The independent `source_boundary_review` confirmed this source-level cause and proposed the partition below. Root approves that concrete plan. Do not rerun a complete suite solely to reproduce this deterministic failure.

## Sole source allowlist

`Sources/AgentLoopTestSuite/DurablePlanningTests.swift`: add one dated private packaging successor singleton, and change only the existing A4 unaffected-file verification block around line 4770. No A3 changes, frozen-manifest edits, script changes, other tests, implementation changes or commits.

## Exact implementation

1. Add `desktopCodingClosureDevelopmentPackagingSuccessorFiles20260906: Set<String>` containing exactly `scripts/run-app.sh`, with a dated comment pointing to this reviewed packaging change.
2. Keep the existing `unaffectedEntries` filter and its literal count 105 unchanged. Partition those entries into the singleton `packagingSuccessorEntries` and complementary `byteExactEntries`.
3. Assert the declared set has count 1 and equals the literal expected path set; assert the selected entry path set equals that same literal, selected count 1, unchanged count 104, and the two counts sum to the original 105. Require the selected script to be a regular nonsymlink file.
4. Run the existing regular-file and original-manifest SHA loop over all 104 `byteExactEntries`, without changing any expected original hash.
5. Separately require the selected script's actual SHA-256 equals its independently reviewed Fix 1 identity `34ff641b68379e1978367cd2c5c9890638c5913627942858767efe56b475428c`. Never replace its old hash in the historical manifest. A future script change needs its own explicit reviewed checkpoint.
6. Preserve the original A4 frozen manifest hash, 206 rows, every other historical partition/count/assertion and A3 logic. `package-app.sh` already belongs to the existing P1-F1 exact allowlist; do not add an exemption for it or any directory.

## Execution and verification

Parent retains this one-file preimage and runs every build/test after the source writer releases. Implementer only patches the precise boundary, checks the scoped diff and writes an implementation report; no test/build/App calls. Independent reviewer checks the exact delta and hashes. Parent runs `swift run RunTests --filter broadcastFailureDoesNotRewriteStartedFire`, retaining full stdout/stderr and the actual exit. A focused pass resolves only this deterministic historical gate; the resource-contended full run and all other failures remain unresolved. No timeout relaxation or suite serialization.
