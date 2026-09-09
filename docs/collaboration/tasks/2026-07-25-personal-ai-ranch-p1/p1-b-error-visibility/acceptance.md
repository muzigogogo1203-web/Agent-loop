# P1-B Independent Acceptance

> Final status: **CHANGES REQUIRED**
>
> Date: 2026-08-25
>
> Acceptance owner: fresh responsibility-isolated acceptance pass

## Boundary and evidence read

This pass was read-only except for this acceptance artifact. It did not rerun
tests, builds, previews, source gates, or migration tools; it did not modify
product, test, planning, manifest, review, report, or evidence bytes.

The active Revision16 planning inputs still match the hashes recorded by
Review18 and Review19:

```text
fad8c6a6726ce12f3cbc4a7a1706a540d3d0f8d10152fe10c76f0ca77a0d6527  plan.md
12ef7d9dac85a32ab9018afcb903b458634ab4b1349512d34722dfe345baff32  try-question-mark-inventory.md
1e3f7f8e92ae1ad888112f09f1b4bc4f56017ccf7aa6a06c5f961ee9d8681570  blocked.md
```

Review19 is present and says `APPROVED — 0 P0 / 0 P1 / 0 P2`. Its cited
focused evidence is present. The framed final evidence is also present:
`verify.log` SHA-256 is
`b31d645d92209ad0a79d6adc8da9134090502ab04ba87afc0f1faf65de29632b`,
and it records the fresh external terminal corpus, the cancellation-ignoring
shutdown test passing, `714 tests in 7 suites passed`, `EXIT: 0`, and
`RESULT: PASSED`.

## Independent finding

### P1 — Application target violates its frozen import boundary

Revision16 plan §3 states that `AgentLoopApplication` “may import only
Foundation and AgentLoopCore” and must not import `Security`. Current
`Sources/AgentLoopApplication/RuntimeProfileWorkflowController.swift` imports
both `CryptoKit` and `Security` on lines 2–3. Its `SHA256.hash` use is also
present at line 877, so this is not merely a stale comment in a plan or an
unexecuted artifact.

This is an acceptance-blocking P1 because R-07 is allowed to close only as the
reviewed consumer extraction with the frozen Application/Core boundary intact.
The full `RunTests` pass and Review19 do not override that explicit boundary.
No acceptance can truthfully record R-07 closed, nor can it claim every §14
gate green, while the prohibited import remains.

## Completion decision

| Completion item | Decision |
|---|---|
| Focused and framed 714/7 terminal evidence | PASS |
| Review19 implementation finding count | PASS as recorded |
| R-05/R-06 evidence | Not accepted pending the boundary correction |
| R-07 consumer extraction / Application import boundary | **FAIL — P1** |
| No unresolved P0/P1/open question | **FAIL — one P1 remains** |

**CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2.**

Required correction: remove the prohibited `Security`/`CryptoKit` dependence
from `AgentLoopApplication` (or obtain a bounded reviewed plan revision that
changes the frozen boundary), then regenerate the affected evidence and obtain
a fresh independent implementation review before a new acceptance pass.

This decision does not authorize P1-C planning or implementation, commit,
push, merge, release, deployment, or external action.

---

# P1-B Independent Acceptance23 — Revision17 Supersession

> Final status: **ACCEPTED**
>
> Date: 2026-08-25
>
> Acceptance owner: fresh responsibility-isolated acceptance pass

## Boundary and frozen inputs

This Acceptance23 pass is read-only except for this acceptance artifact. It
supersedes the Acceptance20 P1 after independently verifying the bounded
Revision17 correction; Acceptance20 remains above as the historical record of
the issue that required correction.

At the start of this pass, the frozen Revision17 inputs were:

```text
a30f65157d15b3c011b6922126279be74eddcbbb2cc868c16715aebd39336866  plan.md
262085f38c3098a2154b32ee9bb7557185ae3609dbab179eb667b731a31e82c6  try-question-mark-inventory.md
9695ca794de2cba6db26037cea3cc9233a5b2ef6344c12af31120e1d4bc9dac7  blocked.md
```

The existing dirty checkout was treated as input and preserved. No product,
test, planning, manifest, scanner, descriptor, seam, review, report, or
verification-log bytes were changed by this acceptance pass.

## Independent acceptance checks

- Review21 approved the exact two-file Revision17 correction with zero P0/P1;
  Review22 independently approved its implementation with zero P0/P1/P2.
- A target-wide import scan confirms every source in `AgentLoopApplication`
  imports only `Foundation` and/or `AgentLoopCore`; there is no `import
  Security` or `import CryptoKit` in that target.
- `OpenAIOAuthSession.swift`, the existing Core owner, now owns secure random
  secret construction (`SecRandomCopyBytes`) and S256 PKCE challenge
  construction (`SHA256` plus base64url). It throws for invalid/random-source
  failure rather than fabricating a fallback value.
- `RuntimeProfileWorkflowController.swift` delegates to that Core primitive
  while retaining its established conversion to
  `RuntimeOAuthBoundaryError.randomGeneration`; the Application-to-Core graph
  remains one-way.
- The framed authoritative `verify.log` is complete and records a fresh
  terminal AST corpus run: `714 tests in 7 suites passed`, `EXIT: 0`, and
  `RESULT: PASSED`. Its SHA-256 is
  `6eb521225e14d3de84595c0cd9bb2318ac3acbb072a3806f5543478fbabf2a87`.
  This postdates the Revision17 source correction.

## Completion decision

| Completion item | Decision |
|---|---|
| Acceptance20 prohibited Application imports | PASS — resolved by Revision17 |
| Core-owned secure random and PKCE derivation | PASS |
| Established runtime error boundary | PASS |
| Review21 and Review22 responsibility isolation | PASS |
| Framed authoritative 714/7 evidence | PASS |
| Unresolved P0/P1 | PASS — none |

**ACCEPTED — 0 P0 / 0 P1 / 0 P2.**

P1-B Revision17 is accepted. This acceptance does not authorize commit, push,
merge, release, deployment, or external action.
