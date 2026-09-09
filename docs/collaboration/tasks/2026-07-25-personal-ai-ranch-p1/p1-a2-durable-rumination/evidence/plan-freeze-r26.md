# R26 Plan Freeze — ERR-Subshell Root-Cause Closure and Clean A2 Re-verification

> Date: 2026-08-10
>
> Branch: `codex/personal-ai-ranch-p0`
>
> HEAD: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> Scope: planning/control plane only. This freeze did not call the R26 driver and
> did not run BEGIN, tests, builds, the migration matrix, source/privacy gates,
> bundle assembly/signing, preview, Review02, acceptance, or later-slice work.

## 1. Frozen current route

R25 remains an immutable executed predecessor. Review25 approved its exact
freeze, driver, and manifest, but execution permanently ended
`REJECTED_CONTAMINATED` in `phase=preview_bootstrap_direct_start`. The inherited
`ERR` trap ran root-owned containment twice from a command-substitution child and
the root caller then failed with `preview_command_read_failed_bootstrap_ready`.
R25 received no UI challenge and did not reach END.

R26 closes only that demonstrated Bash `set -E` / command-substitution root cause.
It changes no product, test, App, Package, schema, migration, public/package API,
target/dependency edge, or permanent-script bytes. Review26 is the only next gate.
Before Review26 approves this exact freeze, driver, and manifest, caller/BEGIN and
every execution gate remain closed.

## 2. Frozen six control surfaces

| Surface | SHA-256 |
|---|---|
| canonical Stage `p1-stage-spec.md` | `32831bbdbc11192b76ac8c801631bd2484a3f005aa69376f0818feef0c34f5d9` |
| canonical total Plan `p1-plan.md` | `c23df83d00e78062272bb44440436d0db063be8bfaa1109104a6a60fc152f816` |
| A2 leaf `plan.md` | `c2194d029fde7848b5f901af5e2577ae8049a3ce2d0b7c051a0d6cd62af593f0` |
| A2 `blocked.md` | `f94a3d80e359e323dd348aaa1637542b9f2a77b46bb19fd3a7dc1bbb171e6f71` |
| P1 Stage control index | `d6dfd53218efafd595d675ea8a5977b4c304e30f90c2b2915899df8c61044140` |
| P1 Plan control index | `da69563d80be37da5aff7415eeef90863420608c529bcb389ad40c4b0c29dc60` |

All six R26 bodies are byte-identical from
`本段是六个控制面的同一份 current override` through the terminal sentence
`不得由本段或standing Goal自行扩权。`, inclusive: 112 newline-terminated
lines, 9,068 bytes, SHA-256
`18f3fc1244b90c87c12626e19b2f10fe5a57e5381c83f5f9d0ee4badd4757c1e`.
Including the one Markdown blank line immediately before that body gives 113
lines, 9,069 bytes, SHA-256
`ffe65481f9062ca06f47d616fe25120f35410275230025f77af07e693578b8af`.

The controlling locations are canonical Stage `28.13`, canonical total Plan's
R26 final contract, A2 leaf `17`, `blocked.md` `35`, P1 Stage index `4.3`, and
P1 Plan index `5.3`. All headers and current/index statements identify the R26
candidate, fresh driver, exact 206-entry manifest, and this freeze as present and
frozen while Review26 remains absent/pending.

## 3. Frozen R26 driver and causal correction

`r26-begin.sh` is a regular non-symlink file with:

- SHA-256 `937a8cb4e737480f5cf44409d9dedbcdd581f627c46726957352a7b56f5c296d`;
- 5,128 lines and 260,840 bytes;
- successful system Bash syntax validation;
- no product/test/App/Package/permanent-script delta.

The causal guard is at the start of `r26_err_trap`: it captures the real status
and `BASH_COMMAND`, then, before any root log, failure handler, or cleanup, checks
`BASH_SUBSHELL`. A child removes its inherited `ERR` trap and exits with the
original status; only `BASH_SUBSHELL == 0` may run root-owned fail-fast and
containment. There is no `EXIT` trap, no global ERR disablement, no `|| true`
fallback, and no change to caller classifications or fail-closed status handling.

The final pre-BEGIN static gate proves guard order, absence of an `EXIT` trap,
exact nested-capture inventory of 15 `/bin/ps`, two `/usr/bin/pgrep`, and three
`/usr/sbin/lsof` command substitutions, and exactly two calls to the microprobe
function. The exact isolated system-Bash microprobes pass all eight cases:

1. legacy expected-nonzero shape produces two child cleanups;
2. exact-name absent preserves rc 1 and empty payload with zero child cleanup;
3. exact-name present preserves rc 0 and the expected payload;
4. no-child preserves rc 1 and empty payload with zero child cleanup;
5. transient `ps` preserves the retry classification with zero child cleanup;
6. transient `lsof` preserves the safe-startup subset with zero child cleanup;
7. rc 2 remains indeterminate/fail-closed with zero child cleanup;
8. raw uncaught `x="$(false)"` reaches the root and triggers exactly one root
   fail-fast.

The immutable source baselines remain:

| Path | SHA-256 |
|---|---|
| `Sources/AgentLoopCore/Loop/AgentLoop.swift` | `c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275` |
| `Sources/AgentLoopTestSuite/AgentLoopTests.swift` | `37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967` |
| R20-final stripped TestSuite | `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26` |
| `scripts/verify-p1-migrations-sqlite-matrix.sh` | `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c` |

## 4. Immutable R25 anchors, evidence, and rejection

| Anchor | SHA-256 |
|---|---|
| `plan-freeze-r25.md` | `8e6d97aca80591f544b40a8b645c01f1c5624f0f120d5ac12cedf37b94ffbeca` |
| `reviews/25-p1-plan-review.md` | `65b738e9c977e97ec6acdfbadad938d43ff97213c42e3b56297e67998dec237e` |
| `r25-begin.sh` | `1eee61d199c5bb1c5b0149989f17508e9a75eacfbc2bac3b1a2f0063f0ab68bb` |
| `r25-entry.sha256` | `462be6ff554b3d38bea76ac8351a77f780b575a1a9aeae4a461e42dd303655ba` |

The ten actual R25 runtime files remain immutable regular non-symlink evidence:

| Runtime artifact | Bytes | SHA-256 |
|---|---:|---|
| `r25-targeted-tests.log` | 4,718 | `538cf3ff68d95318ab7da9dc7a685648f4c7651668ca0c6fcf4dc35c8a48e532` |
| `r25-verify.log` | 96,109 | `9a0d772ac0f36cf56b2340c741d237dfbc2a4a6a9ecd4314bb5b95319f7b8b5f` |
| `r25-build.log` | 2,043 | `cc50f7f484bb397052dae2be64307361e99255fd27169648cb4ac36aa75dd703` |
| `r25-migration-matrix.log` | 44,079 | `7c0e55705520fe79281e7a38b409177515f00fedc89eb8c8bf68fc0f4f74dca9` |
| `evidence/r25-clean-boundary.log` | 14,444 | `2d1dabc7872b31b7d330700c0979857563af84491ff39391b3bf9279ff50c0d4` |
| `evidence/r25-bundle-provenance.log` | 2,661 | `5bdfdad577d4f9c0c029463c59cf442b83122939f76e59c435e89371e682e3d5` |
| `evidence/r25-source-gates.log` | 2,998 | `8d995eeb44fbccd42d9f83a0b64088d35f326ac8dd0051198327320ca2f0466f` |
| `evidence/r25-hash-manifest.log` | 6,009 | `bba9e1ffd51e2f8fb066d00226fc18f9e4f66b9c32f1917129522b471706564a` |
| `evidence/r25-preview-bootstrap.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r25-preview-cold-start.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

They prove the unique authoritative Swift/tee status `0/0`, terminal 652/652,
seven suites with zero failures, same-log 46/46, debug build, fresh signed bundle,
guard/strip, target-exact Core and TestSuite release builds, four-object symbol
gates, SQLite 3.51/3.52 matrix restoration, source/privacy/final-hash gates, and
pre-preview 192/192. They also prove three rejection blocks, no UI challenge,
no screenshot/report, and no END. Partial green evidence cannot substitute for an
R26 clean rerun, Review02, or acceptance.

## 5. R25 post-read-probe contamination and fixed two-bit universe

After rejection, an independent evidence audit opened the R25 WAL-mode state DB
through a read-only SQLite URI. It did not modify repository, bundle, normal data,
or a user root, but it may have updated `-shm`; no before hash/mtime exists. The
R25 state root is therefore permanently classified
`POST_REJECTION_READ_PROBE_CONTAMINATED`.

R26 may observe only the two exact root path entries, in fixed order:

1. `/private/tmp/agentloop-r25-state.fs7Cz2`
2. `/private/tmp/agentloop-r25-bundle.Ozi6d3`

The baseline is exactly `11`. Each A/B capture uses Python `os.lstat` on only
those two names and accepts only a real directory (`1`) or exact absence (`0`).
Each complete comparison permits equality or 1-to-0 erosion. A 0-to-1 transition,
alternate type, symlink, malformed output, partial capture, or indeterminate OS
error rejects. FIRST, LATEST, and accepted-B commit only after the full comparison
passes. R26 never enters, enumerates, hashes, opens, or cleans either R25 root or
any descendant and never treats their contents or hashes as original terminal
evidence or R26 runtime input. This coarse check does not claim to detect a
same-type inode replacement.

## 6. Frozen 206-entry manifest

`r26-entry.sha256` is a regular non-symlink, absolute-path, lowercase SHA-256,
two-space manifest with:

- 206 sorted unique paths;
- SHA-256 `f9d697f35227e6db7df1e8e1b87c4969a184b0a7f65a3d6c70f7c8bfe5d7a22d`;
- path-set SHA-256 `a9e143f5090f1e49cebc274fccde81e52571317d59696122d970b3e4dcf98949`;
- strict current verification `206/206`;
- exact equation `R25 full 192-path set + 14 new paths`;
- R25 historical partition `186 unchanged + six expected control-surface mismatches`.

The 14 additions are the fresh R26 driver; immutable R25 manifest, freeze, and
Review25; and the ten actual R25 runtime files listed in section 4. R25 driver is
already in the inherited 192 paths and is not duplicated. All 14 additions were
absent from the R25 path set and are regular non-symlink files.

The manifest excludes itself, this freeze, Review26, both future fresh roots,
all invocation-owned hidden stages, and these 12 future R26 runtime/report paths:

1. `r26-targeted-tests.log`
2. `r26-verify.log`
3. `r26-build.log`
4. `r26-migration-matrix.log`
5. `evidence/r26-clean-boundary.log`
6. `evidence/r26-bundle-provenance.log`
7. `evidence/r26-source-gates.log`
8. `evidence/r26-hash-manifest.log`
9. `evidence/r26-preview-bootstrap.log`
10. `evidence/r26-preview-cold-start.log`
11. `evidence/r26-preview-smoke.png`
12. `impl-report-r26.md`

At freeze publication, the manifest and this freeze are present regular
non-symlink files but intentionally excluded from the manifest path set; Review26,
all 12 runtime/report paths, both fresh roots, and hidden stages remain absent.
Entry, every mutation boundary, matrix restoration, and END require 206/206. The
only permitted mutation window is exactly 205 unchanged plus one owned
matrix-script mismatch, followed by exact restoration. O_EXCL, no-pre-delete,
three independent ownership flags, fail-once containment, and no-clobber
publication remain mandatory.

## 7. Review26 and automatic caller contract

The independent reviewer may write only
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/26-p1-plan-review.md`.
That report must contain exactly one
`Verdict: APPROVED — 0 P0 / 0 P1` and exactly one 12-key block:

```text
R26_MACHINE_BLOCK_BEGIN
authority_mode=standing_goal_automatic_after_review26
standing_goal_authority_verified=true
reviewer_independence_attested=true
reviewer_write_scope=review26_only
user_hash_echo_required=false
review_verdict=APPROVED_0_P0_0_P1
freeze_sha=<current plan-freeze-r26 SHA-256>
driver_sha=937a8cb4e737480f5cf44409d9dedbcdd581f627c46726957352a7b56f5c296d
manifest_sha=f9d697f35227e6db7df1e8e1b87c4969a184b0a7f65a3d6c70f7c8bfe5d7a22d
branch=codex/personal-ai-ranch-p0
head=02334ec8d21533be81d93d39191bc7d9b9c24f7f
manifest_count=206
R26_MACHINE_BLOCK_END
```

Review26 computes and binds this freeze's final SHA. This freeze deliberately
does not self-embed its own hash, and neither the six surfaces nor the manifest
embed the manifest's or freeze's self-identity.

After exact Review26 approval and a final check that no newer user turn revoked
the standing Goal, the root agent computes Review26's SHA and invokes the frozen
driver automatically. No user hash echo is required. The caller is exactly:

```text
/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C LANG=C TMPDIR=/private/tmp GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null /bin/bash --noprofile --norc /Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r26-begin.sh <current Review26 SHA-256>
```

The same Bash process must run BEGIN, the unique unfiltered full test with
immediate two-element `PIPESTATUS`, same-log 46/46, debug build and fresh signed
bundle, guard/strip, target-exact release builds, four-object gates, 205+1 matrix
mutation and restoration, source/privacy gates, same-bundle B01–B06/C01–C09 UI
flow, staged screenshot/report, and tiny commit-wins END. Caller continuation,
retry, handoff, root/binary substitution, or patch-on-failure is forbidden.

## 8. Completion gate and red lines

Only an exact R26 END plus all technical evidence may open a new independent
Review02. Only Review02 with zero P0/P1 may open independent A2 acceptance. A3
and every later slice remain closed until A2 is accepted and their own reviewed
plans and entry gates exist.

Commit, push, merge, release, destructive or normal-data operations, payment,
public communication, external operations, and real-user actions remain
unauthorized. Any new architecture, scope, dependency, test gate, semantic, or
evidence gap requires a new bounded planning revision and independent review.
