# P1-C Control Contracts Plan Review — Review01E

> Date: 2026-08-25  
> Reviewer: fresh responsibility-isolated read-only Codex session  
> Role: independent reviewer only; not the plan author or implementation owner  
> Checkout: `/Users/muzi/Agent-loop`  
> Review boundary: P1-C Revision 5 plan through `Goal.ready`

## Review conduct

I reviewed the frozen Revision 5 plan against:

- `AGENTS.md`;
- `docs/collaboration/claude-codex-protocol.md`;
- the accepted Personal AI Ranch master spec;
- canonical `p1-plan.md` and `p1-stage-spec.md` under the P0 authority directory;
- P1-B Acceptance23, Review24, and authoritative verification evidence;
- immutable Review01, Review01A, Review01B, Review01C, and Review01D;
- relevant current Swift 6, GRDB, DurableWork, Application, migration-matrix,
  package, and test-runner sources.

The dirty worktree was treated as immutable input. I did not edit or create any
file. I did not run tests, builds, migrations, matrix lanes, the App, preview,
packaging, or Git writes, and did not invoke Claude.

Apple Git emitted sandbox-related temporary-cache diagnostics in this read-only
environment. As in prior isolated reviews, the plan's exact serializer was
therefore executed unchanged with the repository-provided fallback Git 2.53.0.

## Checkout and worktree verification

Start and end results were identical:

| Check | Result |
|---|---|
| CWD | `/Users/muzi/Agent-loop` |
| Branch | `codex/personal-ai-ranch-p0` |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` |
| Dirty paths | 463 |
| Tracked modified | 63 |
| Untracked | 400 |
| Staged | 0 |
| Raw porcelain-v1 NUL-stream SHA-256 | `d2a0bbaee233127b639e5bd332cdadbe5d635f4a3d4fc443f2b51a47ca414e5e` |

The exact embedded outside-worktree serializer returned:

```text
dirty_total=463
allowlisted_present_count=15
outside_count=448
outside_manifest_v1=bd09656fe85d57b2b53d2a871acbdacb8fbf2429fe1bacaf30ce78460ed4e4a0
```

This exactly matches the Revision 5 entry snapshot. No checkout or worktree
drift occurred during review.

## Frozen hashes

All values matched at review start and end.

| Artifact | SHA-256 |
|---|---|
| Revision 5 candidate plan | `9e71818078b18c63f445e08da39a9526fb7a3e02db4332ac3e201bcea3c9aea5` |
| `AGENTS.md` | `046010f8f693130aa7b0dd7b3727d5ea3370705051fbc0433bd981dab084b242` |
| Collaboration protocol | `9eab1e22f4d285bff77a84107216f6dfa1fb0a8470064822441154f282c78fc1` |
| Accepted master spec | `5f942e58745500925c90405460a9bbd161dd07389d7e4d0ee10e156b374d4b4a` |
| Canonical P1 plan | `d499111f168e52a82485d70fd8aa412f34f8db92597d7c8dca3c22b68b24d18f` |
| Canonical P1 stage spec | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| P1-B Acceptance23 | `da21f00e3eecdf2c69cbbe681f1568f00dec820f4320baaa6d184ac1b5755384` |
| P1-B Review24 | `3f91981a7a3fe40e92f21b64d7169cd8de340a5662d6853dbb88e47fb9a95bd8` |
| P1-B authoritative `verify.log` | `6eb521225e14d3de84595c0cd9bb2318ac3acbb072a3806f5543478fbabf2a87` |
| Review01 | `08fce8b86f3a7caef3d56c7457fa27cb2d1d2ac86f0d84c9629b50e7645e726b` |
| Review01A | `cacf4d3b718f192d1ee1b68e81dba003fde9b405ac4fece180a0cf09124c8d7a` |
| Review01B | `52391a6cf2612211f1a3612e5fb5379101cb2c90f644430c7fe04e5398a4e4de` |
| Review01C | `c07a305be3c0fae8e8f26fb02622c4d862997f20b5fc6b5ffe1778a89c7f9053` |
| Review01D | `b734b7e810f881945c8530a8ec5f9effe7e40dac9ef73c5d73e9063d987fb43b` |

Protected source hashes also matched:

| Carrier | SHA-256 |
|---|---|
| `CanonicalJSON.swift` | `7b14b628b14e8f10854116d029bbb7af480a3f9f2c7f5562ad8daae764113b79` |
| `AppDatabase.swift` | `29d4deaac25840ca8f8f826e4829441857893f171784bf692920dbef9bab0b2b` |
| `EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` |
| `DurableWorkStore.swift` | `3e0ada2a6f7fb79a8aa23ccc467e4577d86863e2c971fbc187c334de2bbf60fa` |
| `DurableWorkSupervisor.swift` | `decfbc90e891580acc55c8f6ab03d4014bf6667a7fa486d6a959150cc4de7095` |
| `InputWorkflowController.swift` | `1963a8d101a9d6ed57fb4ce8ef8577f63a1b7502ba0b0eb11b9569ef0e35a1bb` |
| Matrix runner | `951fdbf6a4f9dacefaa4712318984540f9f8109ce34626e6c7afcf8ce95a20f4` |
| Matrix script | `ab8d91fe04ca38007110c7ad8466e4dd0904fa05e859c1474dea0ac51247a84f` |
| `DurableWork.swift` | `5882ffddaedf6c6f00a73121f3948f903119ff0f6f29e29a6945344eb3c46433` |
| `DurableWorkTests.swift` | `061b23b239592ae7f6803ef3174c5ade2f29f73193781f621f8b16643669b3ad` |
| `Package.swift` | `b55b600fc7489aca6bc4e305ea968ac5c9d9e438b4b70be48bf47527e445b99c` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |

## Authority and boundary determination

Revision 5 is consistent with the accepted authority and is limited to
canonical P1-C:

- Event, Input, Goal, Coach, and Understanding contracts are implemented only
  through `Goal.ready`.
- OutcomeContract, activation, `active`, pause/resume, achieve, Verification,
  Acceptance, and Grant behavior remain closed for P1-D and later.
- The v14 forward-compatible Goal columns and status cases do not authorize
  forward-state mutations.
- Legacy ingestion remains display-only and cannot manufacture Input or Goal
  authority.
- Cross-Camp ambiguity cannot infer or select a default Camp.
- No SwiftUI flow, App execution, external provider call, preview, release, or
  real-user action is authorized.

The exact write allowlist is bounded to 23 product/test/matrix carriers plus
enumerated task artifacts. Existing writable carriers are protected by
marker-delimited strip-to-preimage authentication. Read-only DurableWork,
package, canonical JSON, and test-runner carriers are individually hash-frozen.

## Prior-finding closure matrix

| Prior finding group | Revision 5 determination |
|---|---|
| Review01: replay identity, durable lifecycle, Camp ownership, safe JSON/inbox, Application seam, reproducible gates | Closed. Persisted vocabulary, ID ownership, receipt-first replay, complete graph validation, structured claim ownership, immutable audit Camp, closed JSON types, exact Application capture seam, and executable gates are frozen. |
| Review01A: persisted result/replay consistency, redacted inbox, C2 factories/test set, Understanding revision reachability | Closed. Prepared/new authority is separated; result/audit membership is exact; tombstones are classified before conflict CAS; pure replay factories are allowed in C2; all revision branches and event heads are reachable and sealed. |
| Review01B: production carrier, worker envelopes, decision key, Input branch result, redaction, stranded parsing, reopened Coach failure, installation identity | Closed. Marker-confined processor, attempt-scoped envelopes, derived decision key, exact active-work branches, v16-compatible tombstones, zero-active-work requirements, ready-revision failure preservation, and atomic installation identity are specified and tested. |
| Review01C: prepared/new split, expired adoption, terminal clock, actor matrix, one Coach session, provider interfaces, inbox savepoint, Goal hash carrier, process-wide lock | Closed. Each contract now has exact APIs, transaction boundaries, identity sources, failure behavior, and named positive/negative/replay tests. |
| Review01D P1-01: undefined Input boundaries | Closed. `InputParseRouteV1`, exact-key `InputParseResultV1`, terminal-disposition derivation, `InputCaptureReceiptV1`, separate capture actor, and explicit request initializer are frozen. |
| Review01D P1-02: undefined shared lease | Closed. One non-overridable `ControlWorkerLeasePolicyV1` fixes 60-second claim/renew leases and 15-second cadence for both processors, with exact expiry-boundary tests. |
| Review01D P1-03: invalid output recovery loop | Closed. Invalid Input and Coach output maps to exact deterministic failure codes and the latest-claim terminal transaction; it cannot fall into unbounded lease adoption. |
| Review01D P1-04: incomplete marker/delta/P1-D fence | Closed. All five existing-product deltas are authenticated; top-level/package surfaces are constrained; v14 SQL is authority-backed; new files and authenticated deltas are scanned for Outcome, raw Goal SQL, forward reducers, and alternative activation APIs. |

## Static mechanical results

| Check | Result |
|---|---|
| Candidate SHA-256 | Pass |
| Immutable authority/review/source hashes | Pass |
| Exact outside serializer | Pass: `448` / frozen manifest |
| Code-fence count and balance | Pass: 50 fences, balanced |
| Ruby serializer syntax | Pass |
| Source-gate Bash syntax | Pass |
| v14 authority SQL authentication | Pass: 292 lines |
| v14 authority SQL SHA-256 | `a62302bf5f45ef07caded2899322ce3e94e51d21ddc28b3cdb9c102d6936d531` |
| Current seven writable-carrier pre-images | Pass |
| Test manifest count | Pass: 102 |
| Test manifest uniqueness | Pass: 102 unique names |
| Test manifest suite order | Pass: 9 C1, 25 C2, 33 C3, 35 C4 |
| Swift AST top-level gate design | Executable and fail-closed; generated carriers are intentionally absent before implementation |
| P1-D raw/API fence | Covers new product files and all authenticated existing-carrier deltas with narrow v14/Goal forward-carrier exceptions |

The source gate's implementation-time checks that require newly generated
source/test files or `Review01E` were not executed during this
pre-implementation review. Running them now would necessarily fail on
intentionally absent implementation artifacts and would violate the
prohibition on invoking the test runner. Their syntax, extraction logic,
expected surfaces, and fail-closed behavior were reviewed statically.

## Findings

### P0

None.

### P1

None.

### P2

None.

## Feasibility

The plan is decision-complete and implementable on the current checkout:

- GRDB owns the v14 migration transaction and existing migration carriers can
  be extended without package changes.
- Existing transaction-local DurableWork primitives support atomic P1-C
  work/domain mutations.
- The bounded control-only expired adoption extension is compatible with
  current work records and attempt/event ownership.
- Swift 6 concurrency ownership is explicit through structured task groups and
  the actor-isolated latest-claim cell.
- Receipt replay, projection CAS, event/outbox identity, inbox savepoint
  behavior, terminal failure, rollback, and joined Understanding authority are
  mechanically testable.
- The dedicated `InputCaptureWorkflowController` preserves the existing
  controller's source/API bytes.
- The red/green batches, exact 102-test declaration/discovery manifest, matrix,
  source, build, and authoritative full-test gates are executable and
  scope-bound.

No material product, architecture, package API, data-model, concurrency,
identity, or recovery decision is left for the implementer.

## Gate decision

Revision 5 has zero P0 and zero P1 findings. It may proceed to implementation
under its exact allowlist, TDD batches, evidence requirements, completion
gates, and prohibited-action boundary. This approval does not approve an
implementation, acceptance, P1-D work, commit, push, merge, release, App
execution, or external action.

approved_plan_sha256=9e71818078b18c63f445e08da39a9526fb7a3e02db4332ac3e201bcea3c9aea5

verdict=APPROVED — 0 P0 / 0 P1
