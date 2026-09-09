# P1-C Control Contracts Plan Review — Review01H

> Date: 2026-08-25  
> Reviewer: current Codex implementation owner, separate read-only review pass  
> Process note: user explicitly directed Codex to proceed alone without Claude
> or delegated agents; this is a disclosed self-review and is not represented as
> independent  
> Checkout: `/Users/muzi/Agent-loop`  
> Review boundary: Revision 8 historical-manifest ownership closure only, plus
> regression check of the approved Revision 7 boundary

## Conduct and authority

I reviewed Revision 8 without changing source/test bytes, rerunning a test,
launching the App/preview, or performing an external action. I checked the plan
against `AGENTS.md`, the accepted product/P1 authorities, preserved
Reviews01–01G, the authoritative full red log, the complete Revision 7 focused
capture, both historical manifests, and the exact current file hashes.

The user has overridden the Claude/reviewer choice and requested that Codex
continue alone. This is a responsibility-separated self-review, not an
independent review, and it does not relax any implementation or evidence gate.

## Frozen inputs and mechanical checks

| Check | Result |
|---|---|
| CWD / branch / HEAD | `/Users/muzi/Agent-loop` / `codex/personal-ai-ranch-p0` / `02334ec8d21533be81d93d39191bc7d9b9c24f7f` |
| Revision 8 plan SHA-256 | `142ce6fdce15dec73d45a72ebb8840fb7e5e131cc45e17e728131fcffa3ee52c` |
| Preserved Review01G SHA-256 | `18b744362a1732716af8f3c42128e06e4634df7e9e47902f21cf7e21483ba920` |
| Revision 7 focused capture | 438 lines / `44a4c621e0d7c70da18d9080283bf56de5dd346e924aa23efdebe453a685c85f` |
| Current DurablePlanning pre-image | `4a2f01ba373247bd9912f2af84b405d98dc122e5e11ab421ef83342947d98d77` |
| Mechanically derived exact post-image | `f125868304f7f6929e3ec2f20ec15a90761ec131797db135d1f018eee2618ed4` |
| BoardServer exact current image | `249a9bae89e99c4e5608ae9b6677e13bd571cba26c8343f9708ee9fad85dc63b` |

The embedded NUL-safe outside serializer passed after the Revision 7 writes:

```text
dirty_total=492
allowlisted_present_count=46
outside_count=446
outside_manifest_v1=0d9b78388c5cc2e01dc31dd6250d71c7a55c1ca76d12a8b974225077ae455c75
```

All 56 Markdown fences are balanced, the Ruby serializer executes, the source
gate Bash block parses under `/bin/bash`, and `git diff --check` passes. This
allowlisted review and the planned red snapshot alter only informational
allowlisted counts, not the outside set or digest.

## Failure and root-cause review

Revision 7's exact five-test run produced three green functional tests:

- both historical v13 migration tests passed with adjacency preserved; and
- the board framing/tool-call test passed with all protocol and terminal
  assertions intact.

Only the A3 and A4 historical byte-boundary tests remained red, one issue each.
Independent manifest enumeration after applying the exact P1-B and 24-path
P1-C exclusions reports exactly the same sole mismatch in both manifests:
`BoardServerTests.swift`, whose historical hash is the frozen Revision 7
pre-image and whose live hash is its separately frozen Revision 7 post-image.
There is no other mismatching path.

The cause is therefore exact: the Revision 7 ownership helper lists the 24
original P1-C carriers but not the Revision 7 Board test carrier that the same
approved plan changed. Adding only that already-authorized path transfers
successor ownership; it does not forgive unknown drift. The revised assertions
still prove the complete exact intersection sets and counts, enumerate every
remaining live historical file, hash every unaffected entry, and leave both
manifest artifacts immutable.

The focused test capture includes complete command, checkout, UTC start/finish,
test exit, expected result, and `RESULT: FAILED`. The outer interactive zsh
wrapper subsequently rejected Bash-only `PIPESTATUS`; the unique capture was
preserved and appended verbatim. Revision 8 explicitly uses `/bin/bash` for the
next evidence wrapper, so this logging-shell incompatibility cannot recur or
hide the actual test exit.

## Scope and safety review

Revision 8 adds no write path and changes no product, migration, package,
timeout, protocol, or behavioral assertion. It changes only one exact
historical ownership set and the directly derived exact intersection/count
assertions in `DurablePlanningTests.swift`. It preserves the Revision 7 red
frame before the next append and requires the same five-test filter green before
any final gate. No retry, fallback, assertion lowering, or manifest rewrite is
authorized.

## Findings

### P0

None.

### P1

None.

### P2

None.

## Decision

Revision 8 is decision-complete for the sole observed successor-ownership
omission and preserves all P1-C product, historical, and evidence boundaries.
It may proceed only with the frozen focused-red snapshot, the one exact
DurablePlanning post-image, the same five-test focused run, and then the ordered
final gates. This approval does not authorize P1-D, commit, push, merge,
release, App/preview execution, destructive data mutation, or external action.

approved_plan_sha256=142ce6fdce15dec73d45a72ebb8840fb7e5e131cc45e17e728131fcffa3ee52c

verdict=APPROVED — 0 P0 / 0 P1
