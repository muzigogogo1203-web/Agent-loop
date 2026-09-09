# P1-C Control Contracts Plan Review — Review01G

> Date: 2026-08-25  
> Reviewer: current Codex implementation owner, separate read-only review pass  
> Process note: user explicitly directed Codex to proceed alone without Claude
> or delegated agents; this is a disclosed self-review and is not represented as
> independent  
> Checkout: `/Users/muzi/Agent-loop`  
> Review boundary: Revision 7 authoritative-full-test successor closure only,
> plus regression check of the approved Revision 6 boundary

## Conduct and authority

I reviewed the frozen Revision 7 plan without changing product or test code,
rerunning a failed gate, launching the App/preview, or performing an external
action. I checked it against `AGENTS.md`, the collaboration protocol, accepted
master spec, canonical P1 plan/stage spec, preserved Reviews01–01F, P1-B
acceptance, the complete authoritative red log, all three current test
pre-images, and the existing P1-C green evidence.

The user has overridden the Claude/reviewer choice and requested that Codex
continue alone. This artifact supplies a responsibility-separated review pass
but not reviewer independence. It does not weaken any product, test, migration,
source, build, or evidence gate.

## Frozen inputs and mechanical checks

| Check | Result |
|---|---|
| CWD | `/Users/muzi/Agent-loop` |
| Branch | `codex/personal-ai-ranch-p0` |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` |
| Revision 7 plan SHA-256 | `8be6a3fe026f6852d2bf205c8dc727741b6908435e397a2ddc9d76c70db02fc6` |
| Preserved Review01F SHA-256 | `30a43932985d9a74009a6d70f03ddfe8822e54a9665d674db2c5fac32d2120be` |
| Authoritative full red SHA-256 / lines | `d156975e9b5018419e48f17c66cfce645ea1702fb990095dcb6facc4bdc5fca1` / 1,680 |
| Red run result | 816 tests / 11 suites / exit 1 / 10 issues |
| P1-C suites in red run | all four passed; exact P1-C declaration/discovery gate remains 102 |
| `DurablePlanningTests.swift` pre/post | `c12b8594d96de9c59c3712a0e5446d53531ccec23e7e4279c2848d986ca308e9` / `4a2f01ba373247bd9912f2af84b405d98dc122e5e11ab421ef83342947d98d77` |
| `FailureVisibilityTests.swift` pre/post | `8bb8f168a150b4bae44163bbd8c86dedad81e5314a37a836517538f77906b553` / `1b12cab12cf4b1855ac1865c3314e60974b4df6f96c5952f252fe667ab8343d4` |
| `BoardServerTests.swift` pre/post | `2ab9a4cf8f843d3da6bca6f6bb2ad0fd82c007593ebbe46c0530bfc1eff5b1f9` / `249a9bae89e99c4e5608ae9b6677e13bd571cba26c8343f9708ee9fad85dc63b` |

The exact in-memory transformations reproduced all three planned post-image
hashes before approval. The embedded NUL-safe serializer passed with:

```text
dirty_total=490
allowlisted_present_count=44
outside_count=446
outside_manifest_v1=0d9b78388c5cc2e01dc31dd6250d71c7a55c1ca76d12a8b974225077ae455c75
```

The 54 Markdown fences are balanced, the one Ruby serializer executes, the
second Bash block parses with `bash -n`, and `git diff --check` passes. Adding
this allowlisted review changes only the informational dirty/allowlisted counts;
the outside count and digest remain frozen.

## Root-cause review

The 10 issues have three bounded causes, not ten independent product failures:

1. Five A3 issues and two A4 issues are exact consequences of historical tests
   hashing successor-owned P1-C paths. The proposed 24-path P1-C helper transfers
   only paths already owned by this reviewed leaf, proves exact manifest
   intersections, preserves both manifest files, and leaves EventKind protected
   by the stronger P1-C strip-to-preimage gate.
2. Both v13 failures arise before migration assertions because the historical
   helper conflates “immediate successor of v12 schedule” with “last migration
   forever.” Removing only the global-final conjunct retains v13 presence,
   adjacency, explicit `upTo` execution, schema, rollback, replay, and data
   checks while allowing accepted v14 to follow.
3. The board failure occurs at the test client's one-second receive timeout
   after 1.133 seconds in the loaded run. The same exact test passed alone in
   0.045 seconds. Extending only the test socket deadline to the suite's existing
   five-second cleanup bound retains every protocol, tool, terminal, and EOF
   assertion and adds no retry or production behavior.

All 102 P1-C tests and all migration/source/App-build gates preceding the full
run were green, which corroborates that no P1-C product change is implicated.
The plan correctly preserves the failed full run before any edit and requires
the five exact failures focused-green followed by the complete ordered matrix,
source gate, App build, and unfiltered authoritative run.

## Scope and safety review

Revision 7 authorizes only three test-file post-images. It does not edit product
source, schema, migration, package graph, production timeout, frozen manifest,
or runtime UI. It does not lower a behavioral assertion, add a fallback, swallow
an error, permit a blind retry, or cross the P1-D Outcome/active boundary. A new
failure returns to root-cause analysis and reviewed scope rather than widening
this plan.

## Findings

### P0

None.

### P1

None.

### P2

None.

## Decision

Revision 7 is decision-complete for the observed authoritative-full-test
successor failures and retains every approved P1-C product and evidence
boundary. It may proceed only with red-log preservation, the three exact test
post-images, the single five-test focused filter, and the ordered final gates.
This approval does not authorize P1-D work, commit, push, merge, release,
App/preview execution, destructive data mutation, or any external action.

approved_plan_sha256=8be6a3fe026f6852d2bf205c8dc727741b6908435e397a2ddc9d76c70db02fc6

verdict=APPROVED — 0 P0 / 0 P1
