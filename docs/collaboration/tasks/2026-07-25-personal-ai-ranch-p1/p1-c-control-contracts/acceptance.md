# P1-C Control Contracts — Acceptance

> Date: 2026-08-25  
> Acceptance owner: current Codex implementation owner, separate read-only pass  
> Process note: the user explicitly directed Codex to proceed alone without
> Claude or delegated agents; this is a disclosed self-acceptance and is not
> represented as an independent acceptance  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## Decision

P1-C — Event / Input / Goal / Coach / Understanding is accepted. The approved
plan, implementation, migration, focused tests, source/scope gate, App build,
authoritative full suite, implementation report, and Review02 satisfy every
frozen completion condition with zero P0/P1.

This acceptance closes P1-C and authorizes only P1-D formal planning. It does
not authorize P1-D implementation, commit, push, merge, release, App/preview
launch, destructive data mutation, payment, public communication, real-user
operation, or other external action.

## Frozen authority and review chain

| Artifact | SHA-256 / decision |
|---|---|
| Revision 8 plan | `142ce6fdce15dec73d45a72ebb8840fb7e5e131cc45e17e728131fcffa3ee52c` |
| Review01H | `615392ebb1c051fec0d4ca63f8c4972cc0259f5b32d83a8890ac9d0b5afb92d9`, approved 0 P0/P1 |
| Implementation report | `02587073c70dbd2e5469a5b20ce5867c217c616f07a927fde87819db7e5dd5f0` |
| Review02 | `9aa429822dadf2986f96173114965071f61bb02ce3a1c95b05e2d18c4faecd5f`, approved 0 P0/P1 |

Approved Review01E/01F/01G and rejected Review01/01A/01B/01C/01D remain
immutable. Review01H is the sole approval of the final plan hash; Review02 is
the sole implementation-review decision.

## Acceptance evidence

| Gate | Evidence |
|---|---|
| Four P1-C TDD batches | C1 9 + C2 25 + C3 33 + C4 35 = 102 exact tests; red and green frames retained |
| Focused successor closure | identical five-test filter passed 5/5; `focused-verify.log` SHA `fcf88c948991543a0512774bde2a247d3e3a1a50cc5c9bccbcc6dbd0995f3424` |
| SQLite migration matrix | SQLite 3.51.0 and 3.52.0, every predecessor and literal/real v14 lane passed; `957fcc38bbcccdf6dabe465f4673e6e3c0dba890a67cc554133bfbca6374ccfe` |
| Source/hash/scope gate | final frame passed exact plan/protected hashes, 16 new nodes, 102 declaration/discovery set, P1-D fence, outside manifest, and diff check; `8a8145219c4e54a48c089a3b2a75ba6b5e75ebc90be480b8dd3703c6b579a4e2` |
| App build | `swift build --product AgentLoopApp`, exit 0; `5bafc273fbd225c0bb2e64232c22cfaa984ea1bad79b8b524280e6c53967e731` |
| Authoritative full run | `swift run RunTests`, 816 tests / 11 suites passed in 44.151 seconds, exit 0; `9262b2b9c9725a41215cecaf9d0c75151e5f2de6a4b91edd13e433b3e51d1cbe` |

The failed App build, failed authoritative full run, and failed Revision 7
focused attempt remain preserved as `build-red.log`, `verify-red.log`, and
`focused-rev7-red.log`. Their fixes were frozen and approved before exact
writes. The source-gate log also transparently preserves the wrapper's
self-contamination failure before the unchanged gate passed.

## Completion checklist

- v14 replays from fresh, v11, all required v12/v13 predecessors, and literal
  authority on both SQLite lanes; FK/integrity/DDL/append-only/rollback and
  41/94/8 final checkpoints pass.
- Receipt, projection, event, outbox, inbox/savepoint, work, and terminal
  mutations are transactionally total; replay validates the complete persisted
  graph without provider/factory recall.
- Input parsing adoption/retry/cancel/rollback passes with no `parsing`
  projection. Same-owner expired recovery and foreign live-lease protection
  pass for both control kinds; renewal handoff, terminal time, and checked
  backoff are monotonic.
- Cross-Camp ambiguity writes no assignment or Goal. Input Camp audit scope is
  stable, archived/deleted Camps fail closed, and no default-Camp inference
  exists.
- Goal reaches ready only after confirmed joined Understanding; it does not
  require v15. No active/paused/achieved reducer or OutcomeContract behavior is
  present.
- Every Input/Goal/Coach command actor/device combination is positively and
  negatively covered before SQL. Typed inbox rejection rolls back handler
  writes and persists exact rejection evidence.
- Coach restart restores exactly one open question from the sole Goal session;
  provider history is persisted and ordered, and ready-head identity/version/
  hash/event joins are sealed.
- Independent local installation identity adapters converge atomically without
  overwrite. Append-only JSON remains canonical, sorted where required, Camp
  safe, and free of secret/raw external authority.
- App build and unfiltered 816-test suite are green. Open Questions is empty.
- No commit, push, merge, reset, revert, release, package publication, App or
  preview launch, destructive data action, external provider/user action,
  payment, or public communication occurred.

Before this artifact, the exact outside serializer produced
`dirty_total=496`, `allowlisted_present_count=50`, `outside_count=446`, and
`outside_manifest_v1=0d9b78388c5cc2e01dc31dd6250d71c7a55c1ca76d12a8b974225077ae455c75`.
Because `acceptance.md` is explicitly allowlisted, its materialization changes
only the first two informational counts by one; the frozen outside count and
digest must remain identical after write.

verdict=ACCEPTED — 0 P0 / 0 P1
