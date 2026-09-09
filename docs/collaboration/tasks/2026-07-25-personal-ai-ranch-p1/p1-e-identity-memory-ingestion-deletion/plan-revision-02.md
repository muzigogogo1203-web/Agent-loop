# P1-E Plan Revision 02 — Bound the authoritative compatibility closure

> Date: 2026-08-26  
> Scope: E5 compatibility-only correction after the first authoritative full run  
> Authority: base P1-E plan §§3, 8–12; canonical P1 plan §7; canonical Stage
> §§14–15, 18.6, 19, 26–27; user instruction to proceed without Claude  
> Frozen history: `plan.md`, Revision 01, Review01, and Review01a remain
> byte-immutable and are not rewritten

## 1. Trigger and red evidence

The first unfiltered `swift run RunTests` after E5 produced the required
compatibility red frame in `verify-red.log`:

```text
tests=990
suites=24
issues=118
command_status=1
tee_status=0
sha256=9cf63ce72bf30104132b736c53dd77fb0f4f1b60621dc438ed5fc7b4b8f1ea4b
```

All 90 P1-E tests passed inside that run. Standalone reproductions proved the
dominant failures deterministic, so retrying the full suite is not a remedy.
The base plan §10 explicitly requires `verify-red.log` when the first full run
reveals an unplanned existing regression and permits only a bounded root fix.

## 2. Root-cause partition

The 118 recorded issues reduce to these bounded classes:

1. 54 P1-C Input/Goal-Coach failures: post-v16 test databases raw-insert Camp
   rows without the mandatory lifecycle-v1 row. Production must continue to
   fail closed on missing lifecycle authority.
2. 12 user-request answer failures: the legacy GRDB record and both answer
   paths update `answerJson/answeredAt` but not the v16 `lifecycleState`.
3. 12 schedule/mission legacy-event failures: one schedule path still inserts
   `event` without typed scope.
4. Four large-integer failures: typed canonical payload bytes are decoded
   through `JSONValue`/`Double` before legacy-event persistence.
5. Cow bootstrap/planning failures: existing multiline role prompts are valid
   content but the new identity snapshot applies a single-line validator.
6. Legacy note/chat/event fixtures and writers omit their required immutable
   typed scopes.
7. Historical migration, redaction, immutable-row, durable-work, source-signature,
   and entry-boundary tests still assert pre-v16 behavior.
8. Four timing/socket/process observations are potentially load-sensitive and
   are not authorized for change unless they reproduce standalone after every
   deterministic class above is green.

No class authorizes a fallback, lifecycle auto-provision on ordinary writes,
trigger weakening, assertion deletion, F2 command/worker implementation, or
restoration of the removed direct-deletion seams.

## 3. Effective allowlist revision

The executable `scope-allowlist.txt` is revised from 88 to exactly 98 unique
newline-delimited paths. Its effective SHA-256 is:

```text
63f35456ff4dba564c17cbe52c02ee189c4b38c4f176eacba367907ba0b41b68
```

Revision 02 adds exactly one existing product path, seven existing historical
test paths, and these two task artifacts:

```text
Sources/AgentLoopCore/Database/ApprovalGrantStore.swift
Sources/AgentLoopTestSuite/ApprovalGateTests.swift
Sources/AgentLoopTestSuite/ApplicationWorkflowTests.swift
Sources/AgentLoopTestSuite/DurablePlanningTests.swift
Sources/AgentLoopTestSuite/FailureVisibilityTests.swift
Sources/AgentLoopTestSuite/FeedTests.swift
Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/plan-revision-02.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/reviews/01b-p1-e-compatibility-plan-review.md
```

The eight source/test pre-images are frozen before compatibility writes:

| File | SHA-256 |
|---|---|
| `ApprovalGrantStore.swift` | `22b0d2475c068f4d5b4813903998e3645bc74c9e465178b8629c7c567ae5ce2b` |
| `ApprovalGateTests.swift` | `592a07bf8ca7b791d10d6b068770acb8d965a75c8923b85268333956fcdce96e` |
| `ApplicationWorkflowTests.swift` | `62a0d216fc27dee9b3a703faf2145721aa1ab52a02c5480b832c7637bd1cdf01` |
| `DurablePlanningTests.swift` | `6fe42c5af097e1ca2a499eb2b6a2d2f502c2ae47be93c24537e1348d11a09b31` |
| `FailureVisibilityTests.swift` | `1b12cab12cf4b1855ac1865c3314e60974b4df6f96c5952f252fe667ab8343d4` |
| `FeedTests.swift` | `91f9aad065847385da280fdde296be21f12234f701bd7ee9493e7100ba6400bd` |
| `GoalCoachContractTests.swift` | `a1bf27a5fdf4a5640b1b00ecd4fdb0770877bb4c945683b2b42708fe3c34d411` |
| `InputEnvelopeContractTests.swift` | `81f3af4e05169595ec239a10668532d7e68f8a540d43c3180760613fa6114d89` |

The effective outside boundary excludes the seven already-dirty prior-stage
test/store paths newly brought into scope. It is frozen at:

```text
outside_count=500
outside_manifest_v1=6421b8c7061d5f035b57d10218a719942629077d7654ddc81c19cef47287c1f5
```

`dirty_total` and `allowlisted_present_count` may increase only as the two new
artifacts and currently-clean `FeedTests.swift` become present/dirty. The
outside count/hash may not change.

## 4. Decision-complete correction map

### 4.1 Production root fixes

1. `UserRequestRecord` gains explicit v16 lifecycle, terminal-reason, and
   redaction fields with source-compatible open defaults. Both ordinary and
   approval answer paths perform the exact active-Camp `open -> answered`
   transition in the same transaction. No encoding-time inference is allowed.
2. `appendLegacyEventAndScope` gains a raw canonical-JSON/created-at overload
   that validates canonical bytes, resolves scope from the exact event, writes
   scope first, then writes the event. The existing `JSONValue` overload
   delegates to it.
3. Every typed durable mission/schedule event passes the already-canonical
   payload string directly to that overload. No typed payload may round-trip
   through `JSONValue`, `Any`, or `Double`.
4. The raw schedule event insertion is removed and routed through the same
   scope-owning helper.
5. companion-note saves route through `LegacyContentScopeStore`: source-thread
   notes use `.sourceThread`; other companion notes use `.manualCow`. Missing
   or mismatched scope fails closed.
6. Cow personality validation accepts trimmed, nonempty multiline content and
   rejects NUL and unsafe C0/C1 controls while preserving tabs/newlines. ID,
   display name, appearance, and base-role validation remain unchanged.

### 4.2 Compatibility fixture corrections

1. Input/Goal-Coach database fixtures create lifecycle-v1 atomically with each
   raw Camp fixture; no product auto-provision is added.
2. durable-work raw Camp fixtures create lifecycle-v1; raw work rows include
   `campLifecycleVersion=1`.
3. Feed diagnostic events reference a real persisted Run.
4. the malformed-approval fixture is born malformed in an otherwise legal open
   request; it no longer mutates immutable request identity/options in place.
5. Application duplicate-row read tests use isolated fixture databases instead
   of deleting protected candidate/link/note rows for cleanup.
6. historical failure/schedule/inbox redaction tests assert the v16 ordinary
   mutation fence, or create the exact authorized deletion phase/job when the
   tombstone reader itself remains the subject. They never drop v16 triggers.
7. domain-event graph corruption fixtures insert the matching immutable scope
   before inserting an extra event.
8. Outcome migration assertions retain v15 DDL checks while recognizing v16 as
   the current migration head and the accepted `67/171/67` checkpoint.
9. legacy source assertions require the current prepare/execute/resolve
   deletion seam and continue to require the removed direct delete signatures
   absent.
10. the A3 frozen-entry boundary verifies the exact effective P1-E allowlist
    hash and subtracts that reviewed successor scope before checking the
    historical byte manifest.

### 4.3 Load-sensitive observations

After deterministic corrections, rerun each remaining failing test standalone
at least three times. A source change is authorized only if it still fails and
a single root cause is demonstrated. Retry-only green evidence is not a fix;
if standalone and final authoritative runs are green, record it as an observed
full-run load interaction and leave source unchanged.

## 5. Ordered execution and gates

1. Freeze this revision, the 98-line allowlist, pre-images, and Review01b.
2. Keep `verify-red.log` immutable as the pure compatibility red frame.
3. Apply one root-cause class at a time and run the smallest owning tests.
4. Run all tests named in the 118-issue red frame; zero recorded issue is the
   compatibility focused gate.
5. Re-run the exact 90-test P1-E gate, source/scope gate, build, and dual SQLite
   matrix. Existing E1–E5 red evidence stays immutable.
6. Run unfiltered `swift run RunTests` with pipefail and save full stdout/stderr
   to `verify.log`; command and tee must both exit zero.
7. Update `impl-report.md`, perform the disclosed same-agent read-only Review02
   required by the user's no-Claude instruction, and write acceptance only if
   every gate is green.

## 6. Completion gate

Revision 02 is complete only when:

- effective base plan + Revision 01 + Revision 02 and the 98-line allowlist are
  reviewed with zero P0/P1 before compatibility source writes;
- all deterministic reproductions and every test named by `verify-red.log`
  pass without weakened assertions;
- the P1-E 90-test focused gate remains 90/90;
- authoritative unfiltered `swift run RunTests`, build, source/scope gates, and
  both migration-matrix lanes pass;
- the outside boundary remains exactly `500` and the frozen manifest matches;
- no v17/F1/F2 product behavior, normal-state mutation, or prohibited external
  action occurs.

Until then P1-E remains not accepted and P1-F1 is closed.
