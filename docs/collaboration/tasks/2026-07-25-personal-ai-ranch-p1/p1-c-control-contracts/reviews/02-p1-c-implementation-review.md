# P1-C Control Contracts Implementation Review — Review02

> Date: 2026-08-25  
> Reviewer: current Codex implementation owner, separate read-only review pass  
> Process note: the user explicitly directed Codex to proceed alone without
> Claude or delegated agents; this is a disclosed self-review and is not
> represented as independent  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## Review boundary and conduct

I reviewed the complete P1-C implementation in a separate read-only pass. I did
not modify source, tests, migrations, build inputs, or evidence logs; rerun a
test; launch the App/preview; or perform an external action. I inspected the
Revision 8 plan, all preserved plan reviews, implementation report, exact
source/test images, authenticated marker deltas, v14 authority comparison,
focused/full evidence, and current dirty-worktree boundary.

The user-directed no-Claude/no-delegation override removes reviewer
independence, not review scope. This artifact makes no independent-review claim.

## Frozen review inputs

| Input | SHA-256 / result |
|---|---|
| Approved Revision 8 plan | `142ce6fdce15dec73d45a72ebb8840fb7e5e131cc45e17e728131fcffa3ee52c` |
| Review01H | `615392ebb1c051fec0d4ca63f8c4972cc0259f5b32d83a8890ac9d0b5afb92d9`, approved 0 P0/P1 |
| Implementation report | `02587073c70dbd2e5469a5b20ce5867c217c616f07a927fde87819db7e5dd5f0` |
| Migration matrix | `957fcc38bbcccdf6dabe465f4673e6e3c0dba890a67cc554133bfbca6374ccfe`, passed |
| Source/hash/scope gate | `8a8145219c4e54a48c089a3b2a75ba6b5e75ebc90be480b8dd3703c6b579a4e2`, final frame passed |
| App build | `5bafc273fbd225c0bb2e64232c22cfaa984ea1bad79b8b524280e6c53967e731`, passed |
| Authoritative full tests | `9262b2b9c9725a41215cecaf9d0c75151e5f2de6a4b91edd13e433b3e51d1cbe`, 816/11 passed |

Before writing this artifact, the plan's exact serializer reproduced:

```text
dirty_total=495
allowlisted_present_count=49
outside_count=446
outside_manifest_v1=0d9b78388c5cc2e01dc31dd6250d71c7a55c1ca76d12a8b974225077ae455c75
```

All protected authority, package, read-only carrier, red-evidence, review, and
three Revision 7/8 test hashes match the plan. `git diff --check` passes.

## Scope and architecture review

The changed set is exactly 16 new regular P1-C nodes plus 11 existing
hash/strip-gated carriers. The five product carriers reconstruct their frozen
pre-images after removing the one reviewed marker block. The preview change is
compile-only. The three historical test-harness repairs and final ownership-set
completion match their exact post-image hashes. No manifest file, package graph,
unrelated accepted dirty byte, or unplanned path changed.

The v14 migration matches stage-spec §18.4 exactly: ten tables, thirteen named
indexes, and four append-only triggers, immediately after v13. Both real and
literal lanes replay from every required predecessor and finish at 41 tables,
94 indexes, and 8 triggers on SQLite 3.51 and 3.52. Rollback, FK, integrity,
duplicate-key, CHECK, no-op update, delete, and replay sentinels are present and
green.

## Correctness review

- Command execution is receipt-first and transaction-local. New execution
  seals projection/event/outbox effects; replay validates result bytes, every
  event ordinal/version/payload/hash, and outbox cardinality before returning.
  Inbox mutation runs inside a savepoint so typed rejection rolls back handler
  writes while the outer transaction persists exact rejection evidence.
- Input capture owns one Camp audit scope, caller IDs, local installation
  identity, body/hash/retention shape, and parsing-work enqueue atomically.
  Parsing uses one persisted pre-await snapshot, latest-claim renewal handoff,
  expired-only recovery, bounded checked backoff, monotonic terminal time, and
  deterministic invalid-output terminalization. No `parsing` projection state
  or Camp inference fallback exists.
- Goal conversion is atomic and replay-stable. The P1-C transition policy writes
  only clarifying, ready, abandoned, and failed. Goal ready requires the joined
  confirmed Understanding head; one total Coach session and one open question
  are enforced, provider history is persisted/ordered, and all command
  actor/device combinations fail before SQL when unauthorized.
- Coach and Input terminal paths preserve work/projection/event/outbox totality,
  latest claims after renewal, safe cancellation, and failure-scope semantics.
  Independent local identity adapters converge on one persisted value without
  overwrite. Error catches map to typed integrity/terminal errors; none swallow
  a failure or continue with fabricated authority.
- The source fence proves exact closed vocabulary/package surfaces, 102 P1-C
  declarations and discovered tests, and absence of P1-D reducers or APIs.
  Schema-reserved active/paused/achieved strings and outcome-reference columns
  remain unwritten; no `OutcomeContract` implementation or v15 dependency was
  introduced.

## Evidence review

The four TDD batches retain their intended red-to-green chains: C1 9, C2 25,
C3 33, and C4 35, for 102 exact P1-C tests. The failed App build and failed
authoritative full run are preserved byte-for-byte. Revision 7's five-test
failure is preserved in `focused-rev7-red.log`; Revision 8's identical filter
then passes 5/5. The loaded final run proves the Board framing test at 1.216
seconds under full-suite contention, within the test-only five-second deadline.

The final ordered gates are green: migration matrix, source gate, App build,
then unfiltered full run. The source log transparently retains an earlier
wrapper-only failure caused by its own in-repository temporary capture; after
that file was moved to ignored `.build`, the exact unchanged source body
reproduced the frozen outside digest and passed. This is observable evidence,
not a hidden retry or product workaround.

## Findings

### P0

None.

### P1

None.

### P2

None.

## Decision

P1-C implementation conforms to the approved Revision 8 plan, canonical P1
stage contract, and master-spec boundary. The implementation, migration, test,
source, build, and dirty-worktree gates are satisfied. It may proceed to the
separate acceptance pass. This review does not authorize P1-D implementation,
commit, push, merge, release, App/preview launch, destructive data mutation, or
external action.

verdict=APPROVED — 0 P0 / 0 P1
