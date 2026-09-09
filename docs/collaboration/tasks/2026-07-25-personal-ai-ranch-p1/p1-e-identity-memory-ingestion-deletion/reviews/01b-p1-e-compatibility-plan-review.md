# P1-E Compatibility Plan Review — Review01b

> Date: 2026-08-26  
> Reviewer: current Codex implementation owner, fresh read-only pass  
> Process disclosure: the user explicitly directed Codex to proceed without
> Claude; this is a same-agent review and is not represented as independent  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

```text
base_plan_sha256=e258b68a91c375309728933b8c34619c8350afbfeb500040582fb7e07c5a8727
revision_01_sha256=a490e3408ae4deb227980a2af8a382fe47e2d2ff8651546baf7fc72e90a56198
revision_02_sha256=597646e6ee2152ddfff523fbe67d0651e3a0050dc3fae8e65496bd0dd6d4bca9
effective_allowlist_sha256=63f35456ff4dba564c17cbe52c02ee189c4b38c4f176eacba367907ba0b41b68
compatibility_red_sha256=9cf63ce72bf30104132b736c53dd77fb0f4f1b60621dc438ed5fc7b4b8f1ea4b
```

## Review scope and method

I reviewed the immutable base plan, both revisions, the exact 98-line machine
allowlist, canonical P1 Stage §§14–15/18.6/19/26–27, and all 118 recorded issue
lines in the first authoritative full-run red frame. I then inspected every
named production/test root path without modifying source or test code.

The review answers four gate questions:

1. Is the expansion compelled by the existing authoritative full-run gate?
2. Is every newly allowed path tied to a reproduced v16 compatibility root?
3. Does the correction preserve fail-closed lifecycle/scope/deletion rules?
4. Are all unrelated failing files still outside modification scope unless a
   later standalone reproduction proves a new root and receives another
   explicit revision?

## Findings

### Authority and scope

- Base plan §10 requires `verify-red.log` for this exact first-full-run case,
  and §11 requires the unfiltered suite to pass before P1-E acceptance.
- The original exact allowlist cannot repair five invalid historical fixtures
  or the P1-D approval answer writer without either weakening production guards
  or changing files outside scope. Revision 02 resolves that contradiction
  explicitly rather than hiding it in a fallback.
- The seven historical test paths are the minimum demonstrated fixture/boundary
  set. Schedule, Planner, BoardTools, Orchestrator, AskUser, GoldenPath,
  ApprovalGrant, and other failing suites remain outside new write scope because
  their failures must disappear through the named product root fixes.
- `ApprovalGrantStore.swift` is the only newly allowed production file and is
  required because it owns one of the two exact `open -> answered` mutations.

### Contract preservation

- Missing `camp_lifecycle` remains a hard error. Only test fixture creation is
  corrected; ordinary product writes do not synthesize authority.
- The event repair preserves already-canonical UTF-8 bytes and installs scope
  before the append-only event. It removes, rather than adds, an untyped path.
- User-request lifecycle is changed explicitly in the answer transaction; no
  serialization inference or trigger relaxation is allowed.
- Existing multiline cow personality text remains valid content while unsafe
  control bytes remain rejected.
- Old redaction tests must respect the v16 deletion phase/job fence or assert
  that the ordinary write is rejected. Dropping triggers or implementing F2 is
  forbidden.
- Old direct-ingestion-delete signatures remain absent. Compatibility source
  assertions must move to the four-phase prepare/execute/resolve contract.

### Frozen boundary

- The eight newly allowed source/test pre-images match Revision 02 exactly.
- The 98 allowlist lines are nonempty and unique.
- Current effective boundary after writing Revision 02 is:

```text
dirty_total=590
allowlisted_present_count=90
outside_count=500
outside_manifest_v1=6421b8c7061d5f035b57d10218a719942629077d7654ddc81c19cef47287c1f5
```

The task review artifact itself may increase the first two counters by one;
the outside count/hash must remain exact. `Package.resolved`, `RunTests`, the
canonical domain sources, and canonical JSON remain protected by the base plan.

### TDD and completion

- `verify-red.log` is a truthful pre-change compatibility red frame with
  command status 1 and tee status 0; it does not replace any E1–E5 red frame.
- The correction order is root-cause specific and requires narrow owning tests
  before the 90-test P1-E gate and the unfiltered authoritative gate.
- Potential load-sensitive failures receive no source change unless they still
  reproduce standalone after deterministic corrections.
- P1-F1 remains closed until all compatibility, source, build, matrix, full-run,
  report, and review gates pass.

`git diff --check` passes for the plan/allowlist/review preparation set.

## Verdict

**APPROVED — 0 P0 / 0 P1.**

Revision 02 is decision-complete for the bounded compatibility closure. Source
writes are open only for the exact responsibilities and paths named there.
