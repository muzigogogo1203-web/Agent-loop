# P1-F1 Independent Plan Review 01

> Reviewer: independent Codex reviewer (no Claude process used)  
> Date: 2026-08-27  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## Conclusion

**APPROVED — 0 P0 / 0 P1**

P1-F1 product, test, migration, Package, and runtime writes may open against
the reviewed plan and the exact machine allowlist/manifests below. This review
does not accept any implementation and does not reopen accepted P1-E.

## Reviewed immutable inputs

| Input | SHA-256 |
|---|---|
| P1-F1 `plan.md` | `9108b6103890220523379202beaddac29244d5e98c2918e037798be946ea0247` |
| `scope-allowlist.txt` | `d2dd35e1a9033268a72dbb04607e1efbfbdf82cda885efd631beb5abac544353` |
| `entry-source-manifest.sha256` | `6c7e2a3c851f7f84c8bb7b94c2a5725892a90e8dd449afc2344181ee11a0a2ed` |
| `focused-test-manifest.txt` | `03f69e8455d7d7b9c7a75f2489dd7499cf1611b5299542c84042d70b33615968` |
| canonical P1 stage | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| canonical P1 plan | `d499111f168e52a82485d70fd8aa412f34f8db92597d7c8dca3c22b68b24d18f` |
| accepted master spec | `5f942e58745500925c90405460a9bbd161dd07389d7e4d0ee10e156b374d4b4a` |
| P1-E acceptance | `114c3b6b157bce4e8de20bde5dbdc660bdeb8978629b5be1dcca0860891e50be` |
| P1-E Review02 | `77eae9651e0e907efc7a33810b5a4982d0be99ad13730069b7beee11227a06c0` |

The 90-line allowlist is byte-sorted and unique. It is exactly the canonical
67 paths from P1 plan §8.1 plus 23 task artifacts; there are no missing or
extra canonical paths. All 43 entry hashes verified against live bytes. The
remaining exact 24 canonical paths are absent. The 100-test manifest has
contiguous ordinals, unique identities, allowlisted paths, and exact band
counts F1A/F1B/F1C/F1D/F1E/F1F = 16/26/19/19/15/5.

## Decision-completeness review

No P0/P1 ambiguity remains in the implementation authority:

- v17 is registered once after v16, with no v18. The runtime authority is the
  Stage §18.7 content from the first table through final `END;`, excluding the
  fence separator: 770 lines, 29,934 bytes, SHA-256
  `a6ef8747ee3e8ffeb0856827f6cf8f858c681a70748cd373783ae1d23d2b4e99`.
  Live extraction confirmed 12 tables, 15 explicit indexes, 17 triggers, and
  the split token exactly once. The plan fixes 22 autoindexes and cumulative
  79 tables / 208 indexes / 84 triggers, preserving 67/171/67 through v16.
- The prefix/backfill/barrier/trigger-suffix transaction is explicit. Legacy
  origin Camp and both hashes are fully derived without filesystem access;
  count, join, origin, Camp, path-hash, attestation, and FK mismatch roll back
  to the v16 logical snapshot before any v17 trigger is installed.
- `EngineExecutionStore` is the sole execution and Run/Card terminal owner.
  Whole request/context/session/proposal/receipt identities, dispatch CAS,
  monotonic events, checked usage, terminal taxonomy, transaction rollback,
  recovery precedence, four dispatch windows, and exact session continuation
  are specified without adapter/Board/runner database authority.
- Artifact preparation is ordered across filesystem and SQLite, recovers the
  rename-before-row window, and never exposes staging/missing bytes. GC roots
  are the exact three `contentHash` sets; `proposalHash` is excluded. Age,
  quarantine, tombstone, same-hash restage, typed origin creation, no-follow
  evidence, and report filesystem ownership are all closed by positive and
  counterexample tests.
- Discussion budget/round/materialization, Attention rule-derived level and
  notification boundary, Growth evidence/injection rules, and the five §19
  reverse commands are explicit. Memory/Growth invalidation remains inside
  each existing OutcomeStore command transaction; any projection, receipt,
  event, or outbox failure rolls back the whole graph.
- Six pure-red bands, cumulative focused gates, exact compatibility set,
  source/migration/build/isolated-preview gates, final unfiltered
  `swift run RunTests`, independent Review02, and acceptance form a bounded
  completion gate. Narrow green evidence cannot substitute for the final gate.
- F1 carries only the `invalidCampDeletion` schema/type. Camp retirement,
  deletion supersession/worker/permit/registry/UI, F2 implementation, P2 UI,
  real provider login, normal user state, and all prohibited external actions
  remain closed.

## Dirty-boundary evidence

The plan's NUL-safe Git enumeration and binary node serialization was
recomputed before this report was written:

```text
dirty_total=629
allowlisted_present_count=36
outside_count=593
outside_manifest_v1=ce12c40362a7a119241a5179eb52ebca6625c0a5c7daede7a29e8a10aaf90a94
```

Only allowlisted task artifacts changed the live allowlisted counts; the
outside set is exact. Protected source/spec hashes reviewed in the plan match
live bytes. `git diff --check` for the reviewed plan/allowlist/manifests passed.

## Review boundary

This was a plan-and-boundary review only. No Swift test, build, migration,
packaging, App launch, credential, provider, normal-state, or user-data action
was run. Implementation acceptance remains exclusively gated by the plan's
red evidence, verification artifacts, Review02, and `acceptance.md`.
