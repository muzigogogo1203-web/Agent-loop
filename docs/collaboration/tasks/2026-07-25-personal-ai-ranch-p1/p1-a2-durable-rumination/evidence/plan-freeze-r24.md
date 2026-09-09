# R24 Plan Freeze — Single-Process Clean Execution and Isolated Preview

> Date: 2026-08-10
>
> Branch: `codex/personal-ai-ranch-p0`
>
> HEAD: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> Scope: planning/control plane only. No caller, BEGIN, test, build, migration
> matrix, source gate, bundle assembly/signing, preview, product/test/App-script
> implementation, Review02, acceptance, or later-slice work was run.

## 1. Frozen current route

All six current control surfaces use this exact status:

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18/R18-A PLAN CHANGES REQUIRED — NOT EXECUTED；R19 BEGIN REJECTED_CONTAMINATED — AUTHORITATIVE FULL TEST 651/652；R20 BEGIN REJECTED_CONTAMINATED — RELEASE CORE BUILD FAILURE AFTER AUTHORITATIVE FULL 652/652；R21 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED — VOLATILE ROOT STATE DRIFT；R22 PLAN CHANGES REQUIRED — NOT EXECUTED — PARTIAL HISTORICAL BUNDLE SKELETON；R23 BEGIN REJECTED_CONTAMINATED — TERMINAL 652/652 / PIPESTATUS UNKNOWN_NOT_CAPTURED；R24 In-Driver Bash Status-Capture Candidate Frozen；Review24 Pending；A2 Clean Re-verification Frozen`

R24 is the only current A2 planning gate. R15–R23 remain immutable predecessors.
R23 proved a terminal `652/652` result, but its zsh caller could not recover Bash
`PIPESTATUS` after the reviewed driver returned; the frozen R23 contract therefore
classified the invocation `REJECTED_CONTAMINATED`. That result is retained in full and
does not authorize reuse, repair, or reinterpretation of any R23 runtime evidence.

R24 closes only that same orchestration root cause: every gate from BEGIN through END,
including the unique unfiltered test pipeline and its immediate Bash status capture, runs
inside one reviewed system-Bash process. The future product/test/App-script source delta is
exactly zero.

## 2. Immutable predecessor anchors and source baseline

| Anchor | SHA-256 |
|---|---|
| `plan-freeze-r23.md` | `9c791a1bab22026ed2930eb120b9c82923390d42fad61a78f53b40080c6cef9a` |
| `reviews/23-p1-plan-review.md` | `13bd182b8701df2b83fa63c58e978b440ed55c75c0c4a6c3ac936116d411a8bc` |
| `r23-begin.sh` | `0d82a6cf04d4391117d0095bc3b7439f7402d965b45e4396fce50811f4ed4c6c` |
| `r23-entry.sha256` | `1776c5694ce8799258c5f4b37b623d230f3f37218d54817c25489c8dd63a4006` |
| `impl-report-r23.md` | `512e123bcd861043c3f57c08a364489f662582528ecd7f745f282ee9ab999c69` |
| R23 boundary | `4b17b1e7e8536fa88b7b41e68efc089f3b300dd801d42729a375fe2284cd5a78` |
| R23 hash log | `cdb9776b645f0db4b059d2c4e44a974da3788c565653741e1ff2635c22e3afeb` |
| R23 verify log | `c0f5fe79792c60eacfa266a12d53f79abdf3cea53d6e8c9e1f6bc42337100762` |

The immutable source baselines are:

- `Sources/AgentLoopCore/Loop/AgentLoop.swift`:
  `c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`;
- current `Sources/AgentLoopTestSuite/AgentLoopTests.swift`:
  `37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967`;
- R20-final stripped TestSuite:
  `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`;
- migration matrix script:
  `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`.

R24 may not alter any of those bytes. The current TestSuite already contains the exact
R21 debug guards; R24 re-verifies them and their strip-to-R20 equivalence but does not edit
them.

## 3. Frozen six control surfaces

| Surface | SHA-256 |
|---|---|
| canonical Stage `p1-stage-spec.md` | `a7dbf5196004a3cdb225b772309c4de00a98061211b5dc8e9c321ce9541c33b7` |
| canonical total Plan `p1-plan.md` | `c8955ab2643e5a380d7bf89736bc44f60a15a4723f157c58225720a7a4424071` |
| A2 leaf `plan.md` | `685de99eb63002768115c43bc1dead33e75311a653a7b257827706bd0ae8e2da` |
| A2 `blocked.md` | `b8c35cb4c301c329bb75c334309120295da40d6a66328201819d996ebeb7a008` |
| P1 Stage control index | `53ca22cd0a6aef06e696a1b07b6479ba14d171c27edc033e09b234f685be4c3d` |
| P1 Plan control index | `d826e915268d9a74eb594277d0193f03d4a8ed2f5ee0b31dde1106f8a5b31d47` |

The normalized canonical R24 body on all six surfaces has SHA-256
`e6600ce6901506e34c02db43a2c84aaeb69cab33dda7e04f1da56e747a0b286c`.
The controlling locations are canonical Stage `28.11.1`, canonical total Plan
`R24 final single-process clean-execution contract`, A2 leaf `15.1`,
`blocked.md` `33`, P1 Stage index `4.1`, and P1 Plan index `5.1`.
Those sections are the same final current override; earlier R24 handoff, ordinary `mv`,
`kill -0` ownership, or ignored-signal wording is non-controlling.

## 4. Frozen R24 driver and boundary

`r24-begin.sh` is a regular non-symlink file with:

- SHA-256:
  `1b224f442d1fdea856433d12141e5ea9f74190a380e554e4ec94872ba0b8655f`;
- 4,273 lines and 213,721 bytes;
- a successful system-Bash 3.2 syntax check;
- boundary identity `R24_SINGLE_BASH_FULL_CHAIN_AND_ISOLATED_PREVIEW`.

The caller supplies exactly one lowercase 64-hex argument: the current Review24 SHA.
The driver independently proves canonical cwd/self, the exact clean environment,
branch/HEAD, Review24 machine block, 178-entry manifest, predecessor anchors,
historical/current root facts, source baselines, and all pre-BEGIN absence conditions.
It repeats the volatile and source-sensitive checks immediately before exclusive BEGIN.

The BEGIN boundary uses O_EXCL under a defer-only HUP/INT/TERM window. After successful
ownership, the same process first commits `BOUNDARY_ACTIVE=true`, restores normal fail
traps, and immediately consumes any deferred signal. EEXIST fails pre-BEGIN without
append and without consuming authority. Once ownership succeeds, every failure or normal
signal permanently writes `REJECTED_CONTAMINATED`; no retry, evidence overwrite, patch,
cleanup-to-green, or root/object substitution is allowed.

## 5. One-process full-test and execution order

The only authoritative full test is executed by the reviewed driver itself:

```bash
if /usr/bin/swift run RunTests 2>&1 | /usr/bin/tee "$R24_VERIFY_LOG"; then
  r24_pipeline_status=("${PIPESTATUS[@]}")
else
  r24_pipeline_status=("${PIPESTATUS[@]}")
fi
```

In each branch the exact two-element `PIPESTATUS` copy is the first command after the
pipeline. A defer-only commit then records Swift rc, tee rc, and
`status_captured=true`. Only exact `0/0`, unique `652/652`, seven suites with zero
failures, and the same-log mechanical `46/46` audit may continue.

The fail-once order is:

```text
BEGIN
→ unique unfiltered swift run RunTests | tee and immediate Bash PIPESTATUS capture
→ same-log 46/46 audit
→ debug App build
→ fresh bundle assembly/sign and POST_BUILD/PRE_SIGN/LAUNCH_READY
→ guard shape and strip-to-R20 source proof
→ release --target AgentLoopCore
→ release --target AgentLoopTestSuite
→ exact four-object release-zero/debug-positive symbol gates
→ matrix 177+1 window and mandatory restoration
→ remaining source/privacy/final-hash gates
→ same-bundle bootstrap preview
→ isolated fixture installation
→ same-bundle cold-start preview
→ final predecessor/source/root reproof
→ staged report publication
→ END
```

There is no caller continuation, handoff, second full test, or post-driver status
reconstruction. Any failed or unknown gate rejects the same invocation and closes all
later gates.

## 6. Historical and current root lifecycle

The immutable R23 fresh roots are:

- state: `/private/tmp/agentloop-r23-state.GsQHd1`;
- bundle: `/private/tmp/agentloop-r23-bundle.PuKOJy`.

At R24 planning time both are exact real non-symlink empty directories and form the fixed
two-bit R24 baseline `11`. Every R24 observation drains a complete NUL-delimited capture
twice and permits only equality or 1→0. A 0→1 transition, alternate identity, wrong type,
extra node, malformed record, read/status failure, or mismatch permanently rejects. R24
does not modify or clean any historical root.

The R20 fixed 38-bit baseline remains
`11101011100000000000000000000000000010` and retains the R23 monotonic A/B rules.
The R15 exact tombstones
`/private/tmp/agentloop-r15-state.Zq6Jvm` and
`/private/tmp/agentloop-r15-bundle.2xROcy` remain absent. All immutable predecessor
zero-write and fresh-name exclusions are re-proved at the frozen checkpoints.

The two R24 fresh roots must begin as exact real non-symlink empty directories. Their
only accepted current phases are:

- `empty`;
- `bundle_ready`;
- `preview_live`, where state is exactly
  `{.agentloop.lock, agentloop.sqlite, agentloop.sqlite-shm, agentloop.sqlite-wal}`;
- `preview_quiescent`, where state has the exact base two nodes and WAL/SHM are either
  both absent or both regular files.

Any extra, link, special, alternate, or wrong-phase node fails closed.

## 7. Bundle, source, release, and matrix gates

The fresh App uses an invocation-unique valid `CFBundleIdentifier`. Its signed
`Info.plist` contains only the exact `LSEnvironment` values for the isolated R24 state
root and preview flag `1`. The debug executable and bundle hashes are fixed after
assembly; the same exact signed executable and bundle are used by bootstrap and cold
preview.

Source gates prove exact Core/TestSuite bytes, exact three matching debug guard pairs,
the exact guarded helper/start/five-test regions, no other conditional shape, and
strip-to-R20 identity. Release gates use target-exact:

- `swift build -c release --target AgentLoopCore`;
- `swift build -c release --target AgentLoopTestSuite`;
- four exact object-symbol checks proving release zero and debug positive in both
  required directions.

The migration matrix is an exact `177 unchanged + 1 authorized matrix-script mismatch`
window. Backup, mutated stage, and restore stage each have an independent ownership flag:

- `R24_MATRIX_BACKUP_OWNED`;
- `R24_MATRIX_MUTATED_STAGE_OWNED`;
- `R24_MATRIX_RESTORE_STAGE_OWNED`.

Each flag becomes true only after that exact hidden path is created O_EXCL. There is no
pre-delete; copy/write targets only an owned path; successful publish or cleanup clears
the corresponding flag. EEXIST preserves the unowned node and rejects. Error/signal
cleanup and restoration act only on exact owned identities; restore failure remains
contaminated and cannot be hidden.

## 8. Direct preview and isolated fixture

Both launches directly execute the same exact signed executable with the isolated state
root and preview flag, stdin `/dev/null`, and PID taken only from `$!`. The driver does
not use `open`, display-name or bundle-id fallback, or `pgrep` to establish ownership.

Before fork, signals become defer-only through `$!` assignment, PPID capture, and
`lstart` capture. After stable identity commit, normal fail traps are restored and any
deferred signal is consumed. Normal Quit and containment both require two stable
`jobs -pr`/`jobs -ps` running-plus-stopped snapshots. Before TERM/KILL, the driver again
proves `PPID == driver $$` and, after commit, exact `lstart`. A pre-exec command mismatch
is diagnostic only and cannot prevent containment of an already proven owned child.
Cached `wait` is consumed only after the Bash active-job set is absent. `kill -0` never
authorizes a kill of a potentially reused OS PID.

Bootstrap B01–B06 is exact: onboarding → `进入我的营地` → dashboard with one feed hero
and zero `查看全部` → App menu → one `Quit AgentLoop` → Quit. Only after quiescence does
the driver install the exact synthetic fixture into the isolated database:

- ingestion `a2-preview-ingestion-recovering`;
- work `a2-preview-work-recovering`;
- title `隔离恢复验证`;
- raw text `A2 isolated synthetic rumination fixture`;
- rumination attempt 1;
- queued attempt 0, max 4;
- exact canonical input, trace, idempotency, nullable, FK, and integrity checks.

Cold C01–C09 is exact: dashboard with one `查看全部` → inbox fixture with one
`查看进度` → recovering detail. C05 metrics are title 1,
`保存原文，已完成` 2, `正在恢复，正在进行` 3, and each later stage 0.
C06 copies only the already captured C05 screenshot URL to the exact raw path; it performs
no new UI read or action. Then App menu → one Quit → Quit. Every UI observation uses the
full App path, full state, `disableDiff=true`, exact nonce reply, and unique label count.
Coordinates and fallbacks are forbidden; no UI call occurs after B06 or C09.

## 9. No-clobber evidence publication and terminal commit

The screenshot raw file must pass magic, byte-count, and SHA checks. Its normalization
stage is an invocation-unique hidden path in the evidence directory, created O_EXCL and
marked owned before `sips` writes only that path. PNG header/IHDR, dimensions, full
decode, MIME, and SHA are proved before publication. The fixed final is re-proved absent
immediately before `mv -n`. Success requires stage absent, final regular non-symlink,
and final SHA equal to the staged SHA. EEXIST/no-op can remove only this invocation's
owned stage and never an unowned final. After successful publication raw/stage are
removed; failed isolated raw remains contaminated evidence.

`impl-report-r24.md` follows the same pattern: task-directory invocation-owned hidden
O_EXCL stage, complete content/privacy/type/SHA proof, immediate final-absent proof,
`mv -n`, then stage-absent/final-regular/non-symlink/exact-SHA postconditions.
Before END, failure may remove only the owned stage or an untampered published final that
still matches the exact staged SHA. An unowned or changed final is never deleted.

Signals during report publication are deferred only through postconditions, then normal
traps are restored and the signal immediately rejects. The sole commit-wins exception
begins only in the following fresh, tiny END-append window: one append writes a complete
block ending with `status=END` and `result=PASS`. One simple assignment then sets
`END_COMMITTED=true` and `BOUNDARY_ACTIVE=false` before traps are cleared. Failure before
that commit deletes an uncommitted PASS report when exact ownership permits and records
`REJECTED_CONTAMINATED`; after END commit, rejected evidence is never appended.

## 10. Static entry manifest

`r24-entry.sha256` is a regular non-symlink file with:

- SHA-256:
  `55a6c2e8a657166de8b983cd0edfb2a7b1ae1943dc291819c0c2ea417338a80c`;
- record count: `178`;
- path-set SHA-256:
  `6729bc1c34b9664ccdc78397a83e0946b45918adcc8826d56da293f809588b18`;
- construction: the complete R23 163-path set plus exactly 15 additions;
- exclusions: itself, this freeze, Review24, all 12 R24 runtime paths, both fresh
  roots, and every invocation-owned hidden publish stage.

The 15 additions are the R24 driver; immutable R23 manifest, freeze, and Review23;
R23 boundary, hash log, verify log, targeted/build/migration/source/bundle/bootstrap/cold
logs; and `impl-report-r23.md`.

The manifest is bytewise path-sorted and unique. All 178 paths are regular non-symlink
files and strict current verification passes `178/178`. The immutable R23 manifest now
yields exactly `156 unchanged + 7 expected mismatches`: the TestSuite plus the six
current control surfaces. Future R24 execution must preserve all 178 entries exactly.

## 11. Standing Goal and Review24 machine authority

The user's current instruction removes the repetitive user hash-echo turn; it does not
remove this freeze, independent Review24, manifest, branch/HEAD, exclusive boundary,
fail-once behavior, implementation scope, completion gates, or red lines. Before an
automatic caller, the root agent must confirm that no newer user turn revoked or narrowed
the standing Goal.

Review24 must be written only by a reviewer who did not write or revise the R24 six
surfaces, driver, manifest, or this freeze. Its sole repository write may be
`reviews/24-p1-plan-review.md`. It must contain exactly one line:

`Verdict: APPROVED — 0 P0 / 0 P1`

and no other line beginning `Verdict:`. It must contain one unique
`R24_MACHINE_BLOCK_BEGIN/END` block with exactly these twelve internal fields:

1. `authority_mode=standing_goal_automatic_after_review24`
2. `standing_goal_authority_verified=true`
3. `reviewer_independence_attested=true`
4. `reviewer_write_scope=review24_only`
5. `user_hash_echo_required=false`
6. `review_verdict=APPROVED_0_P0_0_P1`
7. `freeze_sha=<current SHA-256 of this freeze>`
8. `driver_sha=1b224f442d1fdea856433d12141e5ea9f74190a380e554e4ec94872ba0b8655f`
9. `manifest_sha=55a6c2e8a657166de8b983cd0edfb2a7b1ae1943dc291819c0c2ea417338a80c`
10. `branch=codex/personal-ai-ranch-p0`
11. `head=02334ec8d21533be81d93d39191bc7d9b9c24f7f`
12. `manifest_count=178`

This freeze cannot embed its own final hash without a cycle. The independent reviewer
computes that hash from these final bytes. The machine block proves local
filesystem/caller-to-driver consistency only; it is not reviewer cryptographic identity
or external anti-rewrite protection.

Only after approved Review24, exact machine-block verification, and the no-revocation
check may the root agent compute the current Review24 SHA and invoke exactly:

```bash
/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C LANG=C TMPDIR=/private/tmp GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null /bin/bash --noprofile --norc /Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r24-begin.sh "<automatically-computed-current-Review24-SHA-256>"
```

No additional user hash-confirmation turn is required.

## 12. Evidence claims, completion, and red lines

R24 evidence may claim only what its observations establish: every observed preview
process was an exact isolated direct child; observed normal-root access count was zero;
and no replacement was observed. It may not claim coverage of unobserved intervals,
filesystem transaction/lock, absolute absence of TOCTOU, zero preference writes, or
stronger process identity than its recorded gates. The invocation-unique UserDefaults
onboarding write must be disclosed in the report.

The R24 implementer may write only the 12 fresh frozen R24 runtime/report evidence paths,
fresh distinct `agentloop-r24-state.*` and `agentloop-r24-bundle.*` roots,
invocation-owned hidden publish stages, and the frozen narrow matrix temporary/restore
window. It may not modify product, test, App, package, schema/migration source, permanent
scripts, or any predecessor evidence.

Only after `R24 END` and every technical gate may a new independent implementation
reviewer write `reviews/02-p1-a2-review.md`. Only a zero-P0/P1 Review02 opens independent
acceptance. Review02 and acceptance must disclose the complete R19–R24 history, including
R23's terminal 652/652 and unavailable caller-side PIPESTATUS, without reclassifying any
rejected or stopped predecessor.

Commit, push, merge, release, destructive data operations, normal-data access, payment,
public communication, external action, and real-user action remain unauthorized. A3 and
all later slices remain closed.

## 13. Planning-safe verification performed

Before this freeze, only read/static planning checks were performed:

- system Bash 3.2 syntax check of `r24-begin.sh`;
- exact branch/HEAD, immutable predecessor anchors, and source baselines;
- exact six-surface hashes and normalized canonical-body identity;
- driver regular/non-symlink identity, line count, byte count, and SHA;
- manifest regular/non-symlink type, sorted/unique paths, exact set equation,
  exclusions, path-set SHA, and strict `178/178` verification;
- immutable R23 manifest partition `156 unchanged + 7 expected mismatches`;
- R24 runtime/Review24/root absence, R23 exact-empty roots, R20 baseline, and R15
  tombstones;
- static review of status capture, boundary signaling, matrix ownership,
  direct-launch containment, exact fixture/UI flow, no-clobber screenshot/report
  publication, END commit, and fail-once order;
- `git diff --check` over the seven R24 planning files.

No driver, caller, BEGIN, test, build, matrix, source gate, bundle/sign, preview,
product/test/App-script edit, Review02, acceptance, or later-slice action was run.

## 14. Review24 checklist

The independent reviewer must verify at least:

1. reviewer independence and Review24-only write scope;
2. branch/HEAD and exact six-surface, driver, manifest, and freeze hashes;
3. unique current status, exact canonical-body synchronization, and no conflicting
   current route;
4. immutable R23 rejection, exact terminal 652/652 evidence, and the
   caller-side PIPESTATUS root cause;
5. exact clean system-Bash caller and one reviewed process from BEGIN through END;
6. immediate two-element PIPESTATUS capture in both test branches, defer-only capture
   commit, unique full test, same-log 46/46, and fail-once sequence;
7. O_EXCL BEGIN ownership, deferred-signal consumption, permanent rejection, and no
   unowned cleanup;
8. R23 two-bit and R20 38-bit monotonic A/B lifecycle, R15 tombstones, predecessor
   zero-write, and fresh R24 phase/type gates;
9. direct same-executable launch, pre-fork deferred signals, PPID/lstart and stable
   Bash-job containment, and no `kill -0` kill authority;
10. exact B01–B06/C01–C09 UI and isolated fixture contracts;
11. screenshot/report O_EXCL ownership, `mv -n` no-clobber postconditions, report
    signal window, and sole tiny END commit-wins exception;
12. independent matrix ownership flags and mandatory exact restoration;
13. `178 = 163 + 15`, strict `178/178`, old `156 + 7` partition, exclusions, and future
    all-178 preservation;
14. exact Review24 verdict/machine block, no-revocation check, caller, evidence claim
    limits, Review02/acceptance sequencing, and all red lines.

Any P0/P1, hash drift, conflicting verdict, scope pollution, unknown state, missing
evidence, or unowned mutation must produce `CHANGES REQUIRED` and keep execution closed.

## 15. Terminal state

`PLAN_FROZEN — REVIEW24_PENDING — EXECUTION_NOT_AUTHORIZED`
