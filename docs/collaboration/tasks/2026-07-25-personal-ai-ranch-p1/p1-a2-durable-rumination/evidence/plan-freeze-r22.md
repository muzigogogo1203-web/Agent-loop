# R22 Plan Freeze — Volatile Containment and Automatic Attestation

> Date: 2026-08-10
>
> Branch: `codex/personal-ai-ranch-p0`
>
> HEAD: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> Scope: planning/control plane only; no caller, BEGIN, test, build, matrix, source gate,
> bundle, signing, preview, or product/test/App-script implementation was run.

## 1. Frozen current status

All six current control surfaces use this exact status:

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18/R18-A PLAN CHANGES REQUIRED — NOT EXECUTED；R19 BEGIN REJECTED_CONTAMINATED — AUTHORITATIVE FULL TEST 651/652；R20 BEGIN REJECTED_CONTAMINATED — RELEASE CORE BUILD FAILURE AFTER AUTHORITATIVE FULL 652/652；R21 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED — VOLATILE ROOT STATE DRIFT；R22 Volatile-Containment Candidate Frozen；Review22 Pending；A2 Clean Re-verification Frozen`

R22 is the only current A2 gate. R12–R20 and R21 are immutable predecessors; historical
approval or partial green evidence does not authorize or prove R22 completion.

## 2. Immutable R21 stop fact

The exact R21 terminal anchors remain:

| Anchor | SHA-256 |
|---|---|
| `plan-freeze-r21.md` | `82ec117359bb0172867ed476c0da4a8d7d0fc60c5bd24f25c0f42e360f7996a4` |
| `reviews/21-p1-plan-review.md` | `13f75ac2979a25c8cf643e83f264663087c6bc18836696c518b247d7f6d3176b` |
| `r21-begin.sh` | `c56db7b465ae3d54923d958892e07e5575d4cf67b8b4946c7d6793e4f1bfb835` |
| `r21-entry.sha256` | `d5567a05e61e61a94b732814e24a89ecdb8e2a988d970dac33939f31798a9d86` |

The R21 external caller passed all four anchors and the 155/155 static manifest. The driver
then exited 70 in `pre_begin_r19_containment`, before exclusive boundary creation, UUID/root
creation, or any R21 runtime artifact write. R21 authorization was not consumed. All twelve
R21 runtime paths and both R21 root globs remain absent and must never be backfilled or reused.

Core and TestSuite still match the R20-final entry bytes:

- `Sources/AgentLoopCore/Loop/AgentLoop.swift`:
  `c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`;
- `Sources/AgentLoopTestSuite/AgentLoopTests.swift`:
  `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`.

## 3. Frozen six surfaces

| Surface | SHA-256 |
|---|---|
| canonical Stage `p1-stage-spec.md` | `752c4658d5b2b27ae8237e92dd81cc7e1945862c24988d4236ec946a05eb1139` |
| canonical total Plan `p1-plan.md` | `eae8099921fd1a904973f620d0a5a57848ff1fc7cfff283f139f0386e7d5b1f9` |
| A2 leaf `plan.md` | `22d673c1fd207b36e7a2293f4bc74cd841d503c31ff9e12079df49e2244c1ed1` |
| A2 `blocked.md` | `5f801bd139a0518a1895f9691431a8d6a6888d7f86e48e4763f32d5e83d9e1d3` |
| P1 Stage control index | `7d366d021173ca6d6774da3220fead8e45d2e58780fa24bebad76ba950661d55` |
| P1 Plan control index | `7c3aa79bde47c1b13abf19a197ebd98ab3cf1411fbdd2f01770564181b1ed011` |

The three current Open Questions headings are Stage §30, total Plan §20, and leaf §14; each
contains exactly `无。`.

## 4. Volatile historical-root contract

The planning-time read-only observation was:

- R19 state `/private/tmp/agentloop-r19-state.dNgUXh`: `ABSENT`;
- R19 bundle `/private/tmp/agentloop-r19-bundle.49xVDm`: `ABSENT`;
- R20 state `/private/tmp/agentloop-r20-state.3QwlQa`: `ABSENT`;
- R20 bundle `/private/tmp/agentloop-r20-bundle.30V5RH`: `PRESENT_CANDIDATE`.

R19 state/bundle and R20 state are frozen as
`HISTORICAL_CANONICAL_EMPTY → ABSENT_TOMBSTONE`, cause `UNKNOWN`, with ABSENT absorbing.
Every driver observation uses exact `-e || -L` bookends plus a full
`find -P /private/tmp -mindepth 1 -maxdepth 1 -print0` universe drained by Bash 3.2
`read -r -d ''`. R19 additionally rejects every alternate
`agentloop-r19-{state,bundle}.*` identity; R20 rejects every alternate R20 identity.

The R20 bundle state machine permits only:

- `VERIFIED_RETAINED → VERIFIED_RETAINED`;
- `VERIFIED_RETAINED → ABSENT_TOMBSTONE` between two complete observations;
- `ABSENT_TOMBSTONE → ABSENT_TOMBSTONE`.

The first complete observation is stored separately and cannot be overwritten by a repeated
preflight. Every later pre/post observation advances the same monotonic state. A single
classification's initial observation, complete 36-node/hash/codesign validation, and late
full-parent bookend permit only retained-to-retained or absent-to-absent. Verification failure
can never be relabeled disappearance.

## 5. R22 driver and boundary

`r22-begin.sh` SHA-256 is:

`55c87eca611f5d6fad6efdc1d21de79650301f3134e0b3416e638d392e98a713`

It accepts exactly one lowercase 64-hex argument: the automatically computed current Review22
SHA-256. It independently parses Review22, verifies all four current anchors, branch/HEAD,
manifest shape/bytes, R21 absence, R19/R20 lifecycle, processes, runtime names, and inherited
R15/RanchArt invariants before BEGIN.

Boundary consumption is exact:

1. HUP/INT/TERM are masked only for the exclusive-create operation.
2. EEXIST fails pre-BEGIN with no append to the existing path.
3. Successful exclusive-create immediately sets the in-process boundary active and restores
   signal handlers before initialization.
4. Partial initialization, command failure, or signal after ownership leaves permanent
   `REJECTED_CONTAMINATED` evidence, including fixed recovery invocation/authority/create facts.
5. The first actions after initialized boundary creation, before hash-log creation, are read-only
   R21, R19, and R20 reproofs. Later and post-fresh-root reproofs use the same monotonic state.

The Bash 3.2 outer capture inventory was mechanically classified by unique source block; repeated
calls do not duplicate a block and inline validator child hashes remain enclosed by their parent:

| Class | Unique blocks |
|---|---:|
| P | 9 |
| S | 4 |
| core C | 8 |
| **total** | **21 = 9P / 4S / 8C** |

P comprises pre/post anchors, historical fresh-root absence, R19 tombstones/artifacts, R20 root
classification/exact-child/all-node aggregate, and RanchArt. S comprises pre/post manifest checks,
process tri-state, and codesign. C comprises Review22 machine parsing, R22/R21 manifest logical
counts, empty-directory probe, R15 enumeration, fresh-root realpath, R20 retained-parent realpath,
and post-manifest logical count. Each P immediately copies full `PIPESTATUS`; expected nonzero S/C
states are captured inside conditionals with inherited ERR disabled where applicable.

## 6. Static manifest

`r22-entry.sha256` is a regular non-symlink file with:

- SHA-256: `57100ca88f871e79632e891b69a70b3696cb64d3b67f8b0c9805ff1eb31728e8`;
- record count: `159`;
- path-set SHA-256: `9f05ff05ab0201995cea6f903fd466f0b1fc3fd32cdf424f086da1cf47252803`;
- construction: complete R21 155-path set plus exactly R22 driver, immutable R21 manifest,
  immutable R21 freeze, and immutable Review21;
- exclusions: itself, this freeze, Review22, all R22 runtime paths, and all temp roots.

The immutable R21 manifest currently yields exactly 149 PASS plus the six current control-surface
mismatches. The R22 manifest currently passes strict 159/159. Future implementation must yield
exactly 158 unchanged plus `AgentLoopTests.swift` as the sole authorized mismatch; Core must remain
at its R20-final entry hash. A second mismatch is fatal.

## 7. Standing Goal and Review22 machine authority

The user's standing Goal authorizes the agent to continue through the accepted implementation
route without asking the user to echo hashes at each step. This removes only the repetitive hash
confirmation turn; it does not remove independent review, freeze, manifest, branch/HEAD, boundary
consumption, fail-once behavior, or any product/completion red line.

Review22 must be written only by a reviewer who did not write the R22 six surfaces, driver,
manifest, or this freeze. It must contain exactly one line:

`Verdict: APPROVED — 0 P0 / 0 P1`

and no other line beginning `Verdict:`. It must also contain one unique
`R22_MACHINE_BLOCK_BEGIN/END` block with exactly these twelve internal fields:

1. `authority_mode=standing_goal_automatic_after_review22`
2. `standing_goal_authority_verified=true`
3. `reviewer_independence_attested=true`
4. `reviewer_write_scope=review22_only`
5. `user_hash_echo_required=false`
6. `review_verdict=APPROVED_0_P0_0_P1`
7. `freeze_sha=<current SHA-256 of this freeze>`
8. `driver_sha=55c87eca611f5d6fad6efdc1d21de79650301f3134e0b3416e638d392e98a713`
9. `manifest_sha=57100ca88f871e79632e891b69a70b3696cb64d3b67f8b0c9805ff1eb31728e8`
10. `branch=codex/personal-ai-ranch-p0`
11. `head=02334ec8d21533be81d93d39191bc7d9b9c24f7f`
12. `manifest_count=159`

The freeze does not self-embed its own hash because that would be cyclic. The reviewer computes it
from final bytes. The machine block provides local filesystem/caller-to-driver consistency only;
it is not a human anti-rewrite guarantee, cryptographic identity proof, or external signature.

After Review22 approval, the agent must first confirm no newer user turn revoked the standing Goal,
compute the current Review22 SHA, and invoke only:

```bash
/usr/bin/env -i \
  PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  LC_ALL=C LANG=C TMPDIR=/private/tmp \
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
  /bin/bash --noprofile --norc \
  /Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r22-begin.sh \
  "<automatically-computed-current-Review22-SHA-256>"
```

No new user hash-confirmation turn is required or permitted by this route.

## 8. Authorized future implementation and order

The sole future source delta remains six direct directive lines in R20-final
`AgentLoopTests.swift`: three matching `#if DEBUG` / `#endif` pairs around the exact helper block,
`startControlledLoop`, and the exact five-test block frozen in Stage §28.8 and leaf §2.7. No logic,
ordering, whitespace, fourth guard, nesting, else/elseif, Core byte, package graph, API, schema,
migration, other product/test file, App script, RunTests runner, or matrix-script expansion is allowed.

Only after an attested R22 BEGIN may the implementer execute this fail-once order:

```text
six-line TestSuite guard edit
→ one unfiltered swift run RunTests
→ mechanical same-log 46/46 audit
→ debug App build
→ fresh bundle assembly/sign and POST_BUILD/PRE_SIGN/LAUNCH_READY
→ guard-shape and strip-to-R20 source proof
→ release --target AgentLoopCore
→ release --target AgentLoopTestSuite
→ exact four-object release-zero/debug-positive symbol gates
→ migration matrix and restoration
→ remaining source/privacy/final-hash gates
→ same-bundle bootstrap/cold-start preview
→ END
```

Any failure permanently rejects that invocation and forbids retry, patching, root/object swapping,
or overwriting negative evidence.

## 9. Completion and red lines

The R22 implementer may write only fresh twelve `r22-*`/report evidence paths, fresh distinct
`agentloop-r22-state.*` and `agentloop-r22-bundle.*` roots, the six directive lines, and the already
frozen narrow matrix Stage-hash restoration exception. It writes `impl-report-r22.md`; it does not
write Review02 or acceptance.

Only after R22 END and every technical gate may a new independent implementation reviewer write
`reviews/02-p1-a2-review.md`. Only a zero-P0/P1 Review02 opens independent acceptance. Review02 and
acceptance must disclose R19 651/652, R20 release failure, R19/R20 historical-empty/current-absence
with unknown cause, the final R20 bundle state, and R21 pre-BEGIN zero-write/unconsumed authority.
They may claim zero normal-data access only inside the R22 boundary.

Commit, push, merge, release, data reset, payment, public communication, normal-data access,
external action, and real-user action remain unauthorized. A3 and all later slices remain closed.

## 10. Planning-safe verification performed

Before this freeze, only read/static planning checks were performed:

- `/bin/bash -n r22-begin.sh` on system Bash 3.2;
- exact R21 four-anchor and Core/TestSuite hashes;
- old R21 manifest result `149 PASS + 6 exact surface mismatches`;
- R22 manifest shape, regular/non-symlink path types, sorted/unique paths, and strict 159/159;
- R21/R22 runtime/root absence and read-only exact R19/R20 root observations;
- current six-surface, driver, manifest, path-set, branch, and HEAD hashes;
- static review of Review22 parser, boundary, status capture, lifecycle, and fail-once ordering.

No driver, caller, BEGIN, test, build, matrix, source gate, bundle/sign, preview, product/test/App
script edit, Review02, acceptance, or later slice action was run.

## 11. Review22 checklist

The independent reviewer must verify at least:

1. reviewer independence and Review22-only write scope;
2. branch/HEAD and the six surface, driver, manifest, and current freeze hashes;
3. exact current status, Open Questions, and no conflicting current R21 route;
4. R21 four-anchor/155 pass followed by pre-BEGIN exit70, zero write, and unconsumed authority;
5. R19 alternate-root rejection and R19/R20 full-parent NUL/bookend semantics;
6. R20 first-observed/repeated-pre/multiple-post monotonicity and same-observation late bookend;
7. EEXIST zero-append, owned boundary consumption, partial-init recovery, and immediate reproof;
8. `159 = 155 + 4`, strict 159/159, old 149+6, and future 158+1;
9. `9P / 4S / 8C = 21` unique-source capture inventory and Bash 3.2 compatibility;
10. exact verdict/machine block, standing Goal, local-consistency limitation, and single-SHA caller;
11. sole six-line future delta, target-exact/four-object gates, fail-once order, Review02/acceptance,
    and all unchanged red lines.

Any P0/P1, hash drift, conflicting verdict, scope pollution, unknown state, or missing evidence must
produce `CHANGES REQUIRED` and keep execution closed.

## 12. Terminal state

`PLAN_FROZEN — REVIEW22_PENDING — EXECUTION_NOT_AUTHORIZED`

