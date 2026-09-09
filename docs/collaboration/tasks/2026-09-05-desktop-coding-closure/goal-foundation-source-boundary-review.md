# A1 source-boundary successor — independent review

Status: PASS for this focused source-inventory change only. No actionable spec or quality findings remain. This does not approve the four files' functionality, complete A1, admit a full runtime gate, or establish strict App/package acceptance.

## Scope and authority

Reviewed the actual preimage `goal-foundation-source-boundary-before.swift` against current `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`, not against HEAD. The approved A1 plan's exact A3 boundary section (lines 112–135) and Task 1 brief authorize a separate exact four-file successor; they do not authorize relaxing historical manifests or broad directory exclusions. No source edits, compiler/test execution, or application/database actions were performed by this reviewer. This report is the only review write.

## Source and specification findings

- The diff has exactly three bounded additions: the dated four-literal-path successor set (around line 2479), its assertions (around lines 5645–5675), and one exact-set exclusion in the enumerated-source filter (line 5700). There is no change to `liveEntries`.
- The set contains only `Sources/AgentLoopCore/Domain/DesktopGoalWorkflow.swift`, `Sources/AgentLoopCore/Database/DesktopGoalWorkflowStore.swift`, `Sources/AgentLoopTestSuite/DesktopGoalFoundationTests.swift`, and `Sources/AgentLoopTestSuite/DesktopGoalMigrationTests.swift`.
- Count four and exact-set equality are both asserted. Disjointness is checked against `manifestPaths` and the union of every existing historical source allowlist/exclusion: original A3, A4, P1-B/C/D/E/F1, both R9F sets, and the runtime-diagnostics singleton. Each admitted path must pass the existing regular-file/non-symlink check. No wildcard, prefix, directory-wide, or optional-missing-file exemption was added.
- The 206-entry manifest, its hash, sorted uniqueness, all historical count/set checks, the 102-entry frozen remainder, and every remainder-file hash comparison are unchanged. Enumerated paths must still equal the sorted frozen remainder exactly after the explicit successor exclusions.
- The runtime-diagnostics successor remains a separate one-file set with its existing checks. The explicit `Package.resolved` and `Sources/RunTests/main.swift` hash checks are unchanged. The actual manifest remains 206 lines with SHA-256 `3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e`; current `Package.resolved` and RunTests entry hashes remain `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` and `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` respectively.

## Observed RED → GREEN evidence

Read the complete retained RED and GREEN logs and their process/hash evidence. Both execute the same focused command: `swift run --jobs 2 RunTests --filter a3Revision02EntryBoundaryRemainsByteExact`.

- RED: PID 74861, build 0.14 s, one test in zero suites, 0.031 s, two issues, exit 1, no signal. Its only failures were enumerated count 106 versus 102 and exact enumerated-list equality; the inserted paths were exactly the four approved files. No historical count/hash assertion failed. This is the expected unregistered-successor RED, not evidence of a defect in those files' functionality.
- GREEN: PID 75010, build 33.61 s, the test passed in 0.046 s, one-test run passed in 0.047 s, exit 0, no signal; process evidence ended at `2026-09-06T22:08:49+08:00`. The retained log includes compiler/linker warnings; this review does not claim a warning-free build.
- Independently parsed both process records: each contains 305 before hashes and 305 matching `after OK` hashes, zero mismatches. After GREEN, an independent read-only check of its complete source manifest also matched all 305 current inputs. The reviewed sentinel source hash was identical at initial and closing review reads.

## Frozen review inputs

| Input | SHA-256 |
| --- | --- |
| Actual preimage | `56b504731d1bff1432e36c82289c1013df033d1dd383c7fc7b5318ca3e6ff06b` |
| Reviewed/final DurablePlanningTests.swift | `7d5e260dcd9cf5e0ab724d49a352cf0661cd3139340384051141fb42d098bdfd` |
| goal-foundation-source-boundary-fix1.diff | `78574759e1ed43e097e93d96607073613630b5acd33ba74c8937155ba17d3aef` |
| goal-foundation-plan.md | `c2f0a874bdaf4bfcd1a4d31f8a31c88199d51fd1a92f0b35274a945fe893b4fc` |
| Task 1 brief | `f476f42ded75f509ed677295addf5763cc9f676e3d7ad1aafa14247547b35e82` |
| RED log | `751aec4cfbb840db6aff61e229b4d6f9f4138f8080bf3b80460abbf3ec4d5d09` |
| GREEN log | `0884c5983204f49b253f7385d91c69e9694c46279dba596dea3466a5d3a94332` |

Conclusion: the exact approved A1 successor is registered without weakening the historical frozen boundary. Focused boundary approval is supported at the final source hash above; all separate functional and stage-completion gates retain their own authority.
