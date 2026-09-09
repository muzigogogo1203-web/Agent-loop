# P1-B Responsibility-Isolated Plan Review03

> Date: 2026-08-12
>
> Reviewers: responsibility-isolated primary, mechanical, and runtime reviewers
>
> Verdict: **CHANGES REQUIRED — 0 P0 / 6 P1 / 2 P2**

## 1. Review boundary and frozen evidence

Review03 was read-only. The reviewers did not edit product, test, Package,
script, planning, evidence, or historical files and did not run a compiler,
build, test, preview, migration, matrix, App, or runtime operation. Each review
started and ended with the same frozen Candidate 03 Revision 02 bytes:

```text
plan.md                         5905ce494c853d2cf031148d7cf6f8e299c542935f2ed0cfb737f35f292ca07e
try-question-mark-inventory.md  9ca482b3e629a40653837ee2ac644e3abe7bb3827950f0050771f0b4b14f60a2
blocked.md                      b65c3879c26cfb645fc959dfde5c972b3be6717d6d024cb99861c86f0895491d
```

The review independently compared the accepted master spec, canonical P1
Stage/Plan, immutable Review01/02, current repository signatures/call graph,
the complete frozen plan/inventory/blocked set, and the embedded scanner and
typed-registry authority. Approval required zero P0/P1.

## 2. Findings

### P0

0.

### P1-01 — The mandatory terminal AST corpus has no executable producer

The inventory freezes scanner extraction and final corpus consumption, but the
bootstrap requires a caller-supplied `P1B_TERMINAL_AST_CORPUS`. No frozen
command/script derives the four SwiftPM debug/release driver jobs, transforms
them into per-primary AST jobs, creates the corpus schema/artifact ledger, or
hands the result to the authoritative RunTests/source gate. The implementer
would have to invent the mandatory compiler-evidence producer.

Revision03 must freeze an executable, extractable corpus producer with exact
invocation, output layout/schema, failure handling, and terminal handoff.

### P1-02 — The corpus validator does not prove the claimed SwiftPM/argv provenance

The embedded validator checks a short command prefix and selected flags but
does not independently reproduce/compare the SwiftPM dry-run, complete
transformed argv, source/module/SDK/target/conditional flags, canonical fresh
outside-workspace cache paths, or every job ledger field against its actual
exit/stderr/AST artifact and hash. An altered compiler job can satisfy the
current structural checks despite the plan claiming argv drift is fatal.

Revision03 must bind every corpus job to a recomputed SwiftPM job and complete
closed transform, and bind the manifest to the exact artifacts it validates.

### P1-03 — Generic OAuth callback cannot satisfy the physical-listener lease API

The retained generic OAuth route enters through SwiftUI `.onOpenURL` and
`AppStore.handleOAuthCallback`, while the only frozen callback command/claim
requires a nonoptional `RuntimeOAuthListenerLease` and the only consumer reads
the NWListener callback stream. A custom-scheme callback has no such physical
lease. The negative gates also forbid a lease-free command, leaving the
existing generic flow unrepresentable.

Revision03 must freeze a generation-safe direct custom-scheme ingress or
explicitly remove generic OAuth with the corresponding scope/inventory/UI
changes.

### P1-04 — Per-flow OAuth ownership aliases one shared verifier coordinate

App/controller lifecycle is keyed independently by `.chatGPT` and `.generic`,
but both preparations write the same `oauth-code-verifier` account. A second
flow can overwrite or delete the first flow's verifier between authorization
and callback; per-call locking cannot protect that interval.

Revision03 must freeze either global single-active OAuth authorization across
both flows or truly per-flow verifier/credential coordinates, with complete
cross-flow preparation/callback/cleanup/stale-retry tests and source guards.

### P1-05 — Schedule post-commit effects have no repair capability or owner

The plan promises DB-first schedule mutations followed by authorization and
registration effects, with retry limited to the failed effect. The exact
outcome/API and App carrier list expose no stage-bearing opaque repair value,
committed schedule identity, retry callable, attempt owner, or schedule repair
matrix. An implementer must decide whether to repeat authorization,
registration, or DB mutation and how to generation-guard it.

Revision03 must freeze the schedule repair stages/capability, controller retry
API, App carrier/apply rules, and failure-first no-repeat tests.

### P1-06 — Coding Ranch bootstrap can partially commit but is always `.notCommitted`

Current bootstrap first commits `ensureDefaultCamp()` in one transaction and
then performs Guide/base-cow/event work in another. Failure in the second
transaction leaves the first durable, yet the plan maps every bootstrap
failure to `.notCommitted` and permits a full retry. The root service file is
outside the allowlist, and neither the generic committed-visibility terminal
nor any opaque partial-bootstrap repair represents this durable truth.

Revision03 must either make the bootstrap one transaction by adding the root
file to scope, or freeze an exact partial-commit capability/retry with real
two-transaction fault coverage.

### P2-01 — MemoryDistill skip-watermark CAS is not mechanically covered

The plan requires a skip path to lose a race when the captured watermark was
already consumed, but the current `markDistilled` path lacks the conditional
update/change-count check and the frozen race descriptor/test wording covers
only the created-note persistence path. Freeze a dedicated conditional
watermark API and a skip/created by DM/guide race matrix.

### P2-02 — Path-universe terminology mixes 60 implementation and 42 production paths

The functional sets close, but scanner/validator prose alternates among 34,
42, and 60 without consistently naming their roles. Revision03 should use
“42 production paths within the 60-path implementation allowlist” and make
generic validator comments count-neutral.

## 3. Verified closure not reopened by this verdict

- The implementation allowlist is 60 and the production scanner universe is
  42 = 34 existing + 8 planned-new.
- The package dependency direction and v13 migration boundary are coherent.
- Embedded entry replay closes at 953 = 431 + 522, 2,956 exclusions, and 2,279
  standalone roots; the typed registry has 2,470 rows and `unclosed=0`.
- Catch/N/descriptor/variant/seam/delegate/resolution arithmetic closes at the
  frozen values; current 667 tests plus 46 planned declarations yields 713 in
  seven suites.
- Review01/02 findings are materially addressed. Runtime provider/credential
  typing outside the cross-flow OAuth issue, MCP maintenance/cleanup,
  context-degradation persistence, OAuth physical claim drain/teardown,
  callback candidate retarget/retry guards, App/TestSuite evidence separation,
  build/preview red lines, and no-raw-error rules are otherwise closed.

## 4. Verdict and legal next action

**CHANGES REQUIRED — 0 P0 / 6 P1 / 2 P2.**

Product, test, Package, script, migration, build, preview, and runtime
implementation remain blocked. The legal next action is a bounded Candidate 03
Revision 03 of `plan.md`, `try-question-mark-inventory.md`, and `blocked.md`,
followed by a new freeze and responsibility-isolated plan review.
