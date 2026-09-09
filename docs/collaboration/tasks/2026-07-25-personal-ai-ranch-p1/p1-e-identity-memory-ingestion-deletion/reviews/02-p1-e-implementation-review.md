# P1-E Implementation Review — Review02

> Date: 2026-08-27  
> Reviewer: responsibility-isolated Codex subagent  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. Independence and review boundary

The user explicitly directed this task to proceed without Claude. I did not
author the P1-E plans, product/test changes, implementation report, or evidence
logs. This pass was read-only for every product, test, plan, log, and report
byte; its only repository write is this Review02 artifact. I did not rerun the
full suite, build, migration matrix, or App preview, and I did not reopen
frozen P1-E history beyond the effective compatibility authority.

Reviewed authority hashes:

```text
plan.md=e258b68a91c375309728933b8c34619c8350afbfeb500040582fb7e07c5a8727
plan-revision-06.md=6894971b1a39bc004ffde1f71bc2954843b5b4eccc88dbeffc383aa30722b0f9
plan-revision-08.md=413c8dbcb4f8d13c17e7f014307fc3e58900ccc70d60e964497bc55e6bb260a4
plan-revision-09.md=84026df99830853a101ca5aa41daec028da7e99545059a88451efe74d1d1ccb5
Review01i=8b82999ec282ef321ed3f1dffdb42c09a85e398c9eec79fdec95ce35fba3120d
impl-report.md=e6e151322281179bf7283e8786d15597b669f8b430ed7f8ae7bbaec8248ce4cf
```

## 2. Implementation conformance

The Revision-09 compatibility implementation is confined to the five frozen
source/test paths and closes the demonstrated roots without relaxing product
behavior:

1. `BoardToolServer.swift` adds only a source-compatible `acceptQueue`, keeps
   both live defaults at global utility QoS, and changes `start()` to dispatch
   only the accept loop through that queue. Handler dispatch remains on the
   distinct existing `handlerQueue`; listener, socket protocol, stop, retry,
   and timeout behavior are unchanged.
2. `BoardServerTests.swift` gives the framing test two different ready serial
   user-initiated queues while preserving the real socket and functional
   assertions. The failed-connect regression keeps an unrelated pipe open and
   observes twenty ordered real `socket` / `Darwin.close` pairs, requiring
   every close result to be zero and both unrelated descriptors to remain
   valid. The five-second receive timeout, twenty ownership iterations, and
   `<10` lifecycle threshold remain present.
3. `Orchestrator.swift` stores a package-testable clock closure; the public
   initializer explicitly supplies `{ ContinuousClock.now }`, both package
   initializers live-default to the same value, and exactly the cooldown check
   and cooldown-set sites read `rateLimitNow()`.
4. `HaltAndCooldownTests.swift` uses a lock-backed manual continuous clock,
   proves no second dispatch before time advances, advances exactly 400 ms,
   and then requires the second card to complete. It does not lengthen or
   sleep through the cooldown.
5. `DurablePlanningTests.swift` controls only the injected 25 ms shutdown
   deadline and delegates every other sleep to the original cancellable
   `Task.sleep`. It proves the shutdown is incomplete before deadline release,
   retains the cancellation-ignoring provider until after the report, and
   requires the exact uncooperative work ID.

The historical ownership arithmetic independently recomputes from both frozen
206-entry manifests and the current allowlists as:

```text
A4 raw / P1-E-owned / unaffected = 40 / 10 / 128
A3 raw / P1-E-owned / live       = 42 / 10 / 124
P1-E-owned set equals the original ten-entry exclusion set in both manifests
```

No `DurableWorkSupervisor`, RunTests runner, Package dependency/lockfile,
duration, socket protocol, broad serialization, fallback, or P1-F surface was
introduced by this correction. The protected current hashes are exact:

```text
DurableWorkSupervisor.swift=e4efbd3679549cb3db6d87aa7a1272c7b200ba5ac35781a2d626b7e1b75beaae
Sources/RunTests/main.swift=70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3
Package.resolved=d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a
Package.swift=0a4b9d3c4eba1a06bda535e69c54c3a5186dcaf148bcb489f1667b4c069cba48
```

## 3. Evidence review

I independently hashed and inspected the named evidence rather than relying
on the implementation report's conclusions:

```text
verify-revision-07-red.log=8ab32c3445412823bf0f4ccf117c79f3b7d5ed464a4da43cebdf81dd66640f7d
diagnostic-revision-07.log=162dd725a87b3ce0b12dc715f8c08ff16fe3f386310798a1bb56453384543b6b
red-revision-08-tdd.log=370566efabebd27ae43767b2acff04d148257002e719fd69c5bfa6618677de77
revision-08-narrow-gates.log=3a7de4497d2fd529306cfbc771a64937e844d9e4658149bf49d241f45f6cd9d3
focused-verify.log=5c20c836cedcdbd0c0703505b3e0ff9f5d5b69b2db6ea70812bdbc3faa380649
source-gates.log=a2a510c1ea2895f372ffa81ebcef5ae33a81eac1d45eb6d8d395870c06fe01b5
build.log=67b6b8a18690e9d68e853e196739f8beb84aeac969cf4532fcb08230eaed9802
migration-matrix.log=060c9af4f9b8c336918871e4324a304efd6d39b554a2d3919d255c13c0aea40d
preview.log=4563da916861f4bcc57de2832c46e10d2a2f8dfc6d222eab484558209e532f55
verify.log=0a0be3ef6b29fd949c97628183e07514476fc4545ed396fd4fa7e691c23d51e6
```

The red log contains the exact unrelated-FD `+2` failure followed by only the
missing `acceptQueue` and `rateLimitNow` compile roots, with command 1 / tee 0
for both phases. The narrow log preserves and classifies the first over-broad
shutdown probe failure, then records the bounded exact-25-ms correction and
all required repeated gates green: root four, timing five times, Board four
five times, full Board suite three times, resource-sensitive eight three
times, exact 112 successors, exact 90 P1-E tests, and the migration-input hash
retention gate.

The exact P1-E run is 90 tests / 9 suites with command and tee zero. The final
source calculation passes all 19 sections and Revision-09 deltas, including
the sole raw-SQLite owner, 90-test identity, v16/no-v17 boundary, two cooldown
clock reads, Board queue/FD checks, privacy seams, and `git diff --check`.
Independent NUL-safe recomputation immediately before this review write gave
135 unique allowlist entries, 494 outside paths, and outside manifest
`b43597a523f6001057b226272b7b5eb95b099691f2b142e87e310b4ce5a5d740`.
This review path is allowlisted, so its creation does not change that outside
boundary.

The App build records command/tee zero. Protected migration inputs still match
the retained dual-SQLite 3.51/3.52 matrix, whose real/literal/replay/rollback/
FK/integrity lanes end in pass with command/tee zero. The freshly appended
Revision-09 packaged preview records the isolated state/database, 27 bundled
resources, codesign verification, integrity/FK and v16/v15/v14 migration tail,
exact PID termination, and command/tee zero. The final unfiltered default-
parallel `swift run RunTests`, after all other gates, records 992 tests / 24
suites passed in 50.505 seconds with command/tee zero. No `RunTests` or
`AgentLoopApp` process remained during this review.

## 4. Findings and verdict

- P0 findings: **0**
- P1 findings: **0**
- P2 findings: **0**

**APPROVED — 0 P0 / 0 P1.**

The implementation conforms to the effective P1-E authority and its bounded
compatibility corrections. P1-E may proceed to evidence-backed acceptance;
this review authorizes no commit, push, merge, release, external action, or
P1-F implementation by itself.
