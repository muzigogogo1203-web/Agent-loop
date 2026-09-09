# P1-B Responsibility-Isolated Plan Review16

> Date: 2026-08-16
>
> Reviewer: independent read-only review
>
> Verdict: **CHANGES REQUIRED — 0 P0 / 2 P1 / 1 P2**

## Frozen inputs reviewed

At review start, Revision14's planning inputs had these SHA-256 values:

```text
777b2185bdcc224a8b4f8f5f4b1a4deb88936f378a07751d9d25dce0942ff27b  plan.md
20a6b9659d8f606a62ef0bee69a6cc196f73202f854022fd4074e85d7a9bf9f9  try-question-mark-inventory.md
057a61eb3bb12e8bf1cdb54f9a0cd9f2609adc27741b1523f84346ed5044cf15  blocked.md
```

The reviewer preserved the pre-existing dirty worktree and wrote only this
review artifact. No production, test, planning, manifest, scanner,
declaration, or evidence-log byte was changed.

## Independent root-cause and ownership check

`R01CancellationIgnoringProvider.streamTurn` synchronously blocks on its
`NSCondition` before it returns an `AsyncThrowingStream`. The durable planning
route reaches `Planner.proposeDurable` from the Supervisor-owned detached
provider task. The stated design is therefore directionally correct: only
synchronous stream construction should move to an off-executor continuation;
that construction wait must not become cancellation-reactive, while the
Supervisor remains the owner of cancellation, the shutdown deadline, and the
reported uncooperative work ID. The existing `elapsed < .seconds(1)` assertion
and the post-report explicit `release()` must remain unchanged. This is not a
fixture rewrite or a timeout relaxation.

The documented Revision14 delta names only
`Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift` and
`Sources/AgentLoopCore/Kernel/Planner.swift`, and does not authorize a new
test declaration, scanner/descriptor/seam, migration, manifest-byte, or
ownership expansion. That is the appropriate bounded path class for the
described fix.

## Findings

### P0

None.

### P1-01 — Claimed exact 66-path allowlist has only 65 unique paths

Plan §2.1 says the implementation allowlist is “exactly” 66 paths, but its
listed pathnames contain 65 unique values: Core 26, Application 5, App 14,
Tests 17, and infrastructure 3. In particular,
`Sources/AgentLoopTestSuite/DistillerTests.swift` is listed twice (both as
item 52), and the subsequent numbering ends at 65. A frozen gate cannot prove
that Revision14 adds *only* Supervisor and Planner to the prior 64-path slice
until the missing distinct path or the advertised count is reconciled. This
would otherwise leave one implementation path ambiguously authorized.

### P1-02 — Revision identity is inconsistent inside the frozen authority

The active headers consistently say Revision14 / Review16, but plan §2.1's
post-allowlist authority paragraph and `blocked.md` call the same
Supervisor-plus-Planner delta “Revision13.” The latter also describes the
exact mechanism that the Revision14 gate must approve. Correct the stale
revision references before implementation so the immutable review, scope, and
later evidence all identify one authority.

### P2-01 — Planner entry fingerprint is not recorded alongside Supervisor

The plan records an entry SHA-256 for `DurableWorkSupervisor.swift`, but not
one for the newly added `Planner.swift`. Recording the latter is advisable for
the same bounded-delta traceability, but is not independently blocking once
the exact path count and revision labels are corrected.

## Gate decision

**CHANGES REQUIRED — 0 P0 / 2 P1 / 1 P2.**

Do not resume implementation under Revision14. Make one bounded planning-only
revision that reconciles the exact unique-path count and revision identifiers
(and preferably records Planner's entry fingerprint), then freeze new hashes
and obtain a fresh independent review. The root-cause design, strict
one-second bound, cancellation ownership, and uncooperative-ID expectation
remain unchanged.
