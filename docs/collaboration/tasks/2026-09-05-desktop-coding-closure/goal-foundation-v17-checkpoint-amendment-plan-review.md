# Independent review — A1 V17 checkpoint amendment plan

Date: 2026-09-06  
Reviewer: responsibilities-separated Codex reviewer (did not author the plan or implement source)  
Reviewed plan: `goal-foundation-v17-checkpoint-amendment-plan.md` (SHA-256 `28cd6ec5180099c5f0024dd72646f0d0fd02764a1ce2b05c9cd8f72a2d230416`)  
Authoritative source preimage: `Sources/AgentLoopTestSuite/CampLifecycleMigrationTests.swift` (SHA-256 `0be4efc3a864edce266b95d8b0bb2c74abec5c466b472bf122132698bf45f609`)  
RED log: `goal-foundation-migration-compat-v16.log` (SHA-256 `ad5552ca4f1901557178443babc7b079782f14b32bc9b18d6d5edc737630e3d9`)

## Verdict

- Specification: **PASS**
- Plan quality: **PASS**
- Findings: **0 P0 / 0 P1 / 0 P2**

## Review

1. **The factual erratum is necessary and exact.** The frozen source at `CampLifecycleMigrationTests.swift:282-289` reads the complete registered migration array and requires V17 to be its last element. This contradicts the original plan/brief claim that the test checks order without assuming V17 remains latest. The RED log records only that expected consequence at line 9 (`v17` index 18 versus current last index 19); the other twelve P1-E tests pass at lines 12-34, and the suite exits with one issue at lines 35-36. The amendment corrects this one inspection claim without rewriting the frozen original plan or brief.

2. **The prefix mechanism preserves rather than weakens all three historical assertions.** Plan lines 15-20 first require the concrete registered `desktop-goal-workflow-v1` marker, then present only the strict prefix before that marker to the unchanged V15/V16/V17 lookups and expectations. If the desktop marker index is `d`, the unchanged assertion `v17 == migrations.count - 1` becomes `v17 == d - 1`; therefore V17 must immediately precede desktop. Any unreviewed migration inserted between V17 and desktop still fails, while migrations added after the reviewed desktop boundary do not redefine the historical checkpoint. The first two unchanged assertions continue to require V15→V16→V17 adjacency. A superficially shorter direct `desktop == v17 + 1` assertion would require replacing the original third assertion, so it is not an equally suitable correction under the binding preservation requirement.

3. **The edit and gate scope are appropriately narrow.** Plan lines 24-32 admit only the setup/comment hunk in this existing test file, expand the A1 source allowlist to exactly fourteen paths, and prohibit source-inventory exclusions, schema/count/golden changes, Provider or application activity, and broader authority. `AppDatabase.swift` remains the already reviewed migration source; the separate desktop migration tests retain responsibility for the real latest head and new DDL. The planned full 13-test P1-E rerun and later P1-D compatibility run are distinct gates, and the plan explicitly keeps overall A1 acceptance closed.

4. **The RED evidence is attributable and frozen.** `goal-foundation-migration-compat-v16-process.txt:1,9-621` records the focused command, PID 78022, 305 before hashes, 305 matching after hashes with zero mismatches, and exit 1. The target source hash at process lines 236 and 542 matches the stated preimage. This supports a source-caused historical-head expectation failure rather than an environment interruption or concurrent-input drift. The stopped P1-D run is correctly reported as not executed, not inferred green.

## Scope limitation

This approval covers only the written amendment plan and the exact future setup/comment correction described at plan lines 13-22. It does not approve an implementation diff or GREEN evidence in advance, does not reopen the three already accepted desktop migration tests, and does not mark A1 complete.
