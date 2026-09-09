# P1-C Control Contracts Plan Review — Review01

> Date: 2026-08-25  
> Reviewer: fresh responsibility-isolated Codex session, authorized as the no-Claude alternative reviewer  
> Role: reviewer only; not the plan author or implementer  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` / `02334ec8d21533be81d93d39191bc7d9b9c24f7f`  
> Review boundary: P1-C decision-complete plan only

## Review conduct

The accepted dirty worktree was treated as immutable input. No repository file was created or edited. No tests, builds, migrations, matrix runners, App process, preview, packaging, database mutation, Git write, or later-stage design inspection was performed.

The review covered the named authority documents, P1-B Acceptance23 and Review24, the frozen candidate plan, and only the current Swift/GRDB surfaces necessary to assess P1-C feasibility.

## Frozen-input verification

Every protected digest matched at both review start and review end.

| Input | Start and end SHA-256 |
|---|---|
| Candidate `plan.md` | `9f803de9b210741e0b61895c473e4dcb5bcf7d9529e565a4b3fd074213a07777` |
| `AGENTS.md` | `046010f8f693130aa7b0dd7b3727d5ea3370705051fbc0433bd981dab084b242` |
| Collaboration protocol | `9eab1e22f4d285bff77a84107216f6dfa1fb0a8470064822441154f282c78fc1` |
| Canonical P1 plan | `d499111f168e52a82485d70fd8aa412f34f8db92597d7c8dca3c22b68b24d18f` |
| Canonical P1 stage spec | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| Accepted master spec | `5f942e58745500925c90405460a9bbd161dd07389d7e4d0ee10e156b374d4b4a` |
| P1-B Acceptance23 | `da21f00e3eecdf2c69cbbe681f1568f00dec820f4320baaa6d184ac1b5755384` |
| P1-B Review24 | `3f91981a7a3fe40e92f21b64d7169cd8de340a5662d6853dbb88e47fb9a95bd8` |
| `CanonicalJSON.swift` | `7b14b628b14e8f10854116d029bbb7af480a3f9f2c7f5562ad8daae764113b79` |
| `AppDatabase.swift` | `29d4deaac25840ca8f8f826e4829441857893f171784bf692920dbef9bab0b2b` |
| `EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` |
| `InputWorkflowController.swift` | `1963a8d101a9d6ed57fb4ce8ef8577f63a1b7502ba0b0eb11b9569ef0e35a1bb` |
| Matrix runner | `951fdbf6a4f9dacefaa4712318984540f9f8109ce34626e6c7afcf8ce95a20f4` |
| Matrix script | `ab8d91fe04ca38007110c7ad8466e4dd0904fa05e859c1474dea0ac51247a84f` |
| `DurableWork.swift` | `5882ffddaedf6c6f00a73121f3948f903119ff0f6f29e29a6945344eb3c46433` |
| `DurableWorkSupervisor.swift` | `decfbc90e891580acc55c8f6ab03d4014bf6667a7fa486d6a959150cc4de7095` |
| `DurableWorkStore.swift` | `3e0ada2a6f7fb79a8aa23ccc467e4577d86863e2c971fbc187c334de2bbf60fa` |
| `DurableWorkTests.swift` | `061b23b239592ae7f6803ef3174c5ade2f29f73193781f621f8b16643669b3ad` |
| `Package.swift` | `b55b600fc7489aca6bc4e305ea968ac5c9d9e438b4b70be48bf47527e445b99c` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |

Applying the prior NUL-safe mode/type/path/content serializer to the P1-C exclusion set produced the same result at start and end:

```text
dirty_total=458
allowlisted_present_count=10
outside_count=448
outside_manifest_v1=bd09656fe85d57b2b53d2a871acbdacb8fbf2429fe1bacaf30ce78460ed4e4a0
```

The difference from the plan’s planning-entry `457 / 9` snapshot is the now-materialized candidate `plan.md`; the protected outside set remains unchanged.

## Confirmed plan strengths

- The two-carrier migration exception is justified by canonical P1 plan §10: P1-C must extend the existing real-GRDB/literal SQLite 3.51/3.52 matrix through v14 and add the v13 predecessor. The existing SwiftPM target already supports this without changing `Package.swift` or dependency resolution.
- Stage §18.4 statically contains 292 SQL lines at SHA-256 `a62302bf5f45ef07caded2899322ce3e94e51d21ddc28b3cdb9c102d6936d531`, with exactly 10 tables, 13 named indexes, and 4 triggers.
- The proposed `41 tables / 94 indexes / 8 triggers` checkpoint arithmetic is consistent: v14 adds 10 tables, 13 named indexes, and 16 SQLite autoindexes to the frozen v13 `31 / 65 / 4` checkpoint.
- GRDB 7’s registered migration transaction can provide the proposed all-or-nothing DDL and `grdb_migrations` rollback semantics.
- Existing transaction-local generic durable-work mutations support `.inputParsing` and `.coach`; planning, rumination, and Camp deletion remain sealed. The four frozen A1/A2 files need not be edited for enqueue/claim/renew/adopt/complete/retry/cancel primitives.
- The four TDD batches name exactly 51 tests: 9 C1, 13 C2, 15 C3, and 14 C4.
- P1-D remains outside the proposed production API. Outcome columns and forward status values are retained only for v14 decoding/schema compatibility; no activation, pause, resume, achieve, OutcomeContract creation, or active-state flow is authorized.

## Findings

### P0

None.

### P1

#### P1-01 — Creation-command replay identity and persisted command/event contracts are not decision-complete

`executeCommand` receives a fully prepared result and ordered event list before it checks the receipt. Creation commands nevertheless create Input, Goal, CoachSession, CoachQuestion, and Understanding identities, while the plan does not define whether those aggregate IDs are caller-supplied sealed payload fields, deterministically derived, or recovered from an existing receipt before new IDs/events are prepared.

A retry that generates a new aggregate ID would produce different event keys and conflict with the already committed command even when the envelope and business payload are identical. The same ambiguity affects state-dependent `abandon`/`fail` event counts if current state has advanced before replay.

The plan also does not enumerate the persisted `commandType`, `eventType`, aggregate-type, result-code, audit-code, or derived work-idempotency-key strings. `EventKind.swift` is writable, but implementers are given no exact constants.

Required revision:

- Freeze every persisted command/event/aggregate/code string and work-key derivation.
- Define stable ID ownership for every creation command.
- Define receipt-first replay behavior before new IDs or state-dependent branches are selected.
- Validate the complete stored event graph and one existing outbox per event, not only count/ordinal/key.
- Add post-commit retry tests for every creation path and for a replay after the current projection branch has changed.

#### P1-02 — Input and Coach durable lifecycle ownership is incomplete under Swift 6

The existing generic ledger primitives are sufficient, but the plan does not fully bind them into safe processors.

For `InputParsingWorker`, lease renewal changes the claim version. The plan does not specify the Swift 6-safe owner of the latest renewed claim, how renewal is stopped and awaited before terminal mutation, or how `commitParseResult` avoids using a stale pre-renewal claim.

For Coach work, the plan creates and terminalizes successful `.coach` turns but defines no processor/supervisor ownership for claim, renewal, adoption, transient retry, cancellation propagation, or deterministic/exhausted failure. A generic failed Coach work can otherwise leave the session nonterminal with no active work. `fail` is not an atomic substitute unless its exact claimed-work failure path is defined.

Required revision:

- Specify the sendable/actor-isolated latest-claim handoff and renewal shutdown protocol for Input parsing.
- Define the Coach processor or equivalent owner using the existing frozen generic APIs.
- Add an atomic Coach failure/retry operation and stable event counts.
- Cover restart adoption, renewal-versus-completion, cancellation, retry exhaustion, and rollback for Coach work.

#### P1-03 — Input audit Camp versus projection Camp is not fully specified

The explicit `auditCampId` is a reasonable way to satisfy non-null `domain_event.campId` without inventing a projection Camp. However, the plan leaves these material cases undecided:

- Whether a non-null `initialCampId` must equal `auditCampId`.
- Which Camp owns the `.inputParsing` durable work.
- Which Camp is recorded on the assignment event itself.
- Which Camp subsequent Input events use after assignment.
- What happens when capture context and assigned Camp differ.

“Reuse the first event’s Camp until assignment” is insufficient for a durable authorization/audit contract and can allow a projection in one Camp with events or work scoped to another without an explicit bridge.

Required revision: freeze the complete Camp rule for capture, work, assignment, post-assignment events, initial assignment, mismatch rejection, and archive checks, with negative cross-Camp tests.

#### P1-04 — Safe JSON and inbox conflict semantics remain semantically escapable

Exact-key decoding and canonical re-encoding are good foundations, but arbitrary `CampSafeRefV1(kind,id)` and related generic `kind` fields can still carry an actor, device, account, path, URL, or external operation value under an allowed `id` key. Rejecting forbidden key names alone does not establish Camp-safe content.

Inbox replay also compares only key/hash in the stated contract. Canonical bytes with the same claimed/recomputed hash must still be byte-compared, and the conflict transition does not specify inbox `version`, `appliedAt`, or exact CAS behavior.

Required revision:

- Replace caller-defined reference kinds with closed enums or internal per-domain constructors and exact value validation.
- Freeze explicit-null encoding for optional envelope fields and the matching milliseconds-since-1970 decoder configuration.
- Require inbox replay equality across canonical payload bytes and recomputed hash.
- Define the exact durable conflict-row mutation, version increment/CAS, timestamp treatment, and outside-transaction throw.
- Add same-key/same-hash/different-bytes and semantically forbidden-reference tests.

#### P1-05 — The application capture seam is not specified enough to preserve compatibility

The current `InputWorkflowPorts` has a large explicit initializer and `InputWorkflowController` has established actor/error-reporting APIs. The plan says only that package-level P1-C ports and methods will be added while preserving existing initializers.

It does not freeze:

- New port and method signatures.
- Capture command/result DTOs.
- Which dependency owns `LocalCaptureIdentity`.
- Defaulted initializer wiring that preserves existing call sites.
- Required Input ID/idempotency fields.
- `auditCampId`/`initialCampId` parameters.
- Failure mapping into the existing `OperationCommitOutcome` and trace model.
- The promised read API.

These are package API and application ownership decisions, not mechanical implementation details.

Required revision: provide the exact port structs, initializer defaults, controller method signatures, DTO fields, trace/correlation mapping, returned outcome types, and identity-storage injection boundary.

#### P1-06 — The final source and outside-manifest gates are not independently reproducible from this plan

The outside hash can be reproduced only by importing the serializer from the earlier P1-B `closeout-plan.md`, which is neither a frozen input nor copied into this candidate. “NUL-safe, mode/type/path/content” does not uniquely define binary serialization.

Likewise, the source gates are bullet requirements rather than fail-fast commands. They do not define:

- NUL-safe modified/untracked path enumeration and exact exclusions.
- How untracked new files participate in the allowlist gate.
- The exact Outcome/active lexical exception list.
- How all 51 declarations are counted exactly once and matched to test discovery.
- How `rg` exit 2 differs from a valid no-match.
- The exact command that proves controller GRDB-write absence and one v14 registration.

Required revision: embed the complete deterministic manifest serializer and executable source-gate commands, including exact patterns, exception lists, counts, path sets, exit handling, and expected sentinels.

### P2

None.

## Gate decision

The migration schema/counts, narrow carrier exception, GRDB transaction model, generic durable-work reuse, 51-test arithmetic, and P1-D exclusion are feasible. The six P1 findings nevertheless require the implementer to invent persisted contracts, replay identity, concurrency ownership, Camp authority, package APIs, and verification procedures. That violates the repository’s decision-complete plan gate.

No P1-C implementation, Review02, acceptance, P1-D planning, or later authorization is opened by this review.

## Final verdict

CHANGES REQUIRED
