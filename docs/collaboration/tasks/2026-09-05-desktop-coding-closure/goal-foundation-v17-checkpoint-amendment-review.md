# Independent implementation review — A1 V17 checkpoint amendment

Date: 2026-09-06  
Reviewer: responsibilities-separated Codex reviewer (did not implement this change)  
Approved plan: `goal-foundation-v17-checkpoint-amendment-plan.md`  
Actual diff: `goal-foundation-v17-checkpoint-amendment.diff` (SHA-256 `27cc349e9d29168d72726f70fd5650ee0833e5bdb698ba381542adfb86dceefb`)  
Frozen preimage: `goal-foundation-v17-checkpoint-amendment-before.swift` (SHA-256 `0be4efc3a864edce266b95d8b0bb2c74abec5c466b472bf122132698bf45f609`)  
Accepted source hash: `Sources/AgentLoopTestSuite/CampLifecycleMigrationTests.swift` = **`570b26b9d72263fcbb6f69c62f725beef2dd28f7da50d8ecf7ebcc800da36c8f`**

## Verdict

- Specification: **PASS**
- Code quality: **PASS**
- Findings: **0 P0 / 0 P1 / 0 P2**

## Review

1. **The actual implementation is exactly the approved bounded correction.** `goal-foundation-v17-checkpoint-amendment.diff:12-16` replaces only the complete-list binding with the dated comment, required `desktop-goal-workflow-v1` lookup, and strict prefix before that marker. Current source lines 283-286 match the reviewed plan. No production migration, SQL, schema count, golden, allowlist exclusion, Provider path, or application behavior is changed.

2. **The historical assertions are unchanged and remain strong.** Current source lines 287-292 retain the original V15/V16/V17 lookups and all three assertions byte-for-byte. The strict prefix makes the unchanged final-index assertion equivalent to requiring V17 immediately before the desktop successor; a missing desktop marker fails at `#require`, and an unknown migration inserted between V17 and desktop still fails. Later reviewed migrations after desktop do not redefine the historical checkpoint.

3. **The whole-file boundary is byte-proven.** Removing only current source lines 283-286 and restoring the one preimage binding reproduces SHA-256 `0be4efc3a864edce266b95d8b0bb2c74abec5c466b472bf122132698bf45f609`. The extracted nine-line block containing the three original lookups and assertions has the same SHA-256 (`7f1a416cca9e283aa02978225a94a976f5e64f079f220b25d322974b4efb7706`) in preimage and current source. Replacing one line with the four reviewed lines accounts for the complete net 704→707 line change.

4. **Focused GREEN closes the observed RED without collateral P1-E regression.** `goal-foundation-v17-checkpoint-amendment-green1.log:8-36` shows all 13 `P1ECampLifecycleMigrationTests` passing, including the corrected adjacency test at lines 9-10 and all twelve unchanged historical tests at lines 11-34; build is 0.34s, tests 0.979s, exit 0. Its process record identifies PID 80742, records 305 before and 305 matching after inputs with zero mismatches, and pins the target at the accepted source hash before and after (`process.txt:236,314,542,620-622`).

5. **The previously blocked compatibility lane is independently green.** `goal-foundation-read-retention-outcome-regression.log:7-45` shows all 18 `P1DOutcomeContractTests` passing, including the explicit V17 checkpoint test at lines 8-9; its process record identifies PID 80766, exit 0, and the same 305 stable inputs. This is correctly separate from the P1-E amendment result.

## Scope limitation

This approval pins only the exact `CampLifecycleMigrationTests.swift` hash above and the single reviewed setup/comment hunk. It does not review the separately authorized read/retention implementation, does not reopen the accepted desktop migration tests, and does not mark the broader A1 stage complete or substitute for root's same-revision full verification.
