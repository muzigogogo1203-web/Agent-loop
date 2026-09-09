# P1-E Acceptance — Identity / Memory / Ingestion / Deletion

Status: **ACCEPTED**  
Accepted checkout: `/Users/muzi/Agent-loop`  
Branch / HEAD: `codex/personal-ai-ranch-p0` /
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## Accepted authority

- Base plan SHA-256:
  `e258b68a91c375309728933b8c34619c8350afbfeb500040582fb7e07c5a8727`
- Revision 06 SHA-256:
  `6894971b1a39bc004ffde1f71bc2954843b5b4eccc88dbeffc383aa30722b0f9`
- Revision 08 SHA-256:
  `413c8dbcb4f8d13c17e7f014307fc3e58900ccc70d60e964497bc55e6bb260a4`
- Effective Revision 09 SHA-256:
  `84026df99830853a101ca5aa41daec028da7e99545059a88451efe74d1d1ccb5`
- Approved compatibility plan Review01i SHA-256:
  `8b82999ec282ef321ed3f1dffdb42c09a85e398c9eec79fdec95ce35fba3120d`
- Implementation report SHA-256:
  `e6e151322281179bf7283e8786d15597b669f8b430ed7f8ae7bbaec8248ce4cf`
- Independent implementation Review02 SHA-256:
  `77eae9651e0e907efc7a33810b5a4982d0be99ad13730069b7beee11227a06c0`
- Review02 verdict: `APPROVED — 0 P0 / 0 P1 / 0 P2`.

The user explicitly excluded Claude. Review01i and Review02 were performed by
responsibility-isolated Codex reviewers; Review02 did not author the plans,
implementation, report, or evidence it reviewed.

## Accepted product result

P1-E's typed identity, Event/Input/Goal/Coach/Understanding compatibility,
memory provenance and materialization, camp-scoped provider dispatch, legacy
event/scope repair, Cow residency, ingestion deletion preview/execute/recovery,
shared graph validation, and exact v16 migration are implemented.

Deletion stays fail-closed and operation-keyed across prepared, executing,
committed, integrity-blocked, conflict, cancellation, process-death, and
refresh-failure states. Raw SQLite mutation capability remains private to the
single permit owner; generic durable work, grant, engine, UI, and legacy
archive surfaces cannot acquire it. UI privacy and scope seams remain preview-
only and DEBUG-scoped.

The final compatibility correction removes four default-parallel harness
false observations without weakening product behavior: shutdown proves the
injected 25 ms deadline causally; cooldown uses an exact test clock while live
code remains on `ContinuousClock.now`; Board framing uses distinct ready test
queues; and failed-connect ownership is proved by real per-descriptor close
events rather than process-global FD counts. Product durations, socket timeout,
runner parallelism, provider semantics, and `DurableWorkSupervisor` remain
unchanged.

## Accepted gates

- Tests-first red evidence is retained, including the unrelated-FD failure and
  missing `acceptQueue` / `rateLimitNow` compile failures.
- Root four, repeated timing/Board/resource gates, exact 112 successors, and
  exact 90 P1-E tests are green.
- Source/scope gate is green: 135 unique allowlist entries; outside 494 with
  manifest
  `b43597a523f6001057b226272b7b5eb95b099691f2b142e87e310b4ce5a5d740`;
  A4 raw/owned/unaffected 40/10/128; A3 raw/owned/live 42/10/124.
- Dual SQLite 3.51/3.52 real/literal/replay/rollback/FK/integrity evidence is
  retained with every protected input hash unchanged.
- `swift build --product AgentLoopApp` is green.
- Fresh isolated packaged-app verification passed executable identity, 27
  resources, codesign inspection, migration v16/v15/v14, SQLite integrity/FK,
  exact process termination, and absence of a residual app process.
- Final authoritative exact `swift run RunTests`: 992 tests / 24 suites passed
  under default parallel execution in 50.505 seconds; command/tee 0; no rerun.
- Full `git diff --check` is green.
- Independent Review02 found zero P0/P1/P2.

## Evidence hashes

- `verify-revision-07-red.log`:
  `8ab32c3445412823bf0f4ccf117c79f3b7d5ed464a4da43cebdf81dd66640f7d`
- `diagnostic-revision-07.log`:
  `162dd725a87b3ce0b12dc715f8c08ff16fe3f386310798a1bb56453384543b6b`
- `red-revision-08-tdd.log`:
  `370566efabebd27ae43767b2acff04d148257002e719fd69c5bfa6618677de77`
- `revision-08-narrow-gates.log`:
  `3a7de4497d2fd529306cfbc771a64937e844d9e4658149bf49d241f45f6cd9d3`
- `focused-verify.log`:
  `5c20c836cedcdbd0c0703505b3e0ff9f5d5b69b2db6ea70812bdbc3faa380649`
- `source-gates.log`:
  `a2a510c1ea2895f372ffa81ebcef5ae33a81eac1d45eb6d8d395870c06fe01b5`
- `build.log`:
  `67b6b8a18690e9d68e853e196739f8beb84aeac969cf4532fcb08230eaed9802`
- `migration-matrix.log`:
  `060c9af4f9b8c336918871e4324a304efd6d39b554a2d3919d255c13c0aea40d`
- `preview.log`:
  `4563da916861f4bcc57de2832c46e10d2a2f8dfc6d222eab484558209e532f55`
- `verify.log`:
  `0a0be3ef6b29fd949c97628183e07514476fc4545ed396fd4fa7e691c23d51e6`

## Prohibited actions and next boundary

No commit, push, merge, release, payment, public communication, real-user
action, normal-user-data mutation, or P1-F implementation was performed.

P1-E is closed. The only product leaf now opened is P1-F1 decision-complete
planning. P1-F2 and P2 implementation remain closed until their canonical
entry conditions and reviewed plans are satisfied.
