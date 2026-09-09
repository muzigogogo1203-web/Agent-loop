# R27 Plan Freeze — Compound-If Status Capture and Clean A2 Re-verification

> Date: 2026-08-10
>
> Branch: `codex/personal-ai-ranch-p0`
>
> HEAD: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> Scope: planning/control plane only. This publication did not call the R27
> driver or run BEGIN, tests, builds, matrix, source/privacy gates, bundle work,
> preview, Review02, acceptance, or later-slice work.

## 1. Frozen current route

R26 remains an immutable executed predecessor. Its plan review passed and its
execution passed the unique full 652/652, same-log 46/46, all mechanical gates,
and bootstrap B01–B06. It then permanently ended `REJECTED_CONTAMINATED` at
`quit_wait_job_table_indeterminate_bootstrap_0`; cold preview, screenshot,
implementation report, and END did not occur.

R27 closes only the demonstrated Bash 3.2 compound-`if` status-capture root
cause and adds bounded safe-enum diagnostics. Product, test, App, Package,
schema, migration, public/package API, dependency graph, and permanent-script
bytes remain unchanged. Review27 is the only next gate; caller/BEGIN and all
execution gates remain closed until it approves this exact freeze, driver, and
manifest.

## 2. Frozen six control surfaces

| Surface | SHA-256 |
|---|---|
| canonical Stage `p1-stage-spec.md` | `ccbd624d93c88ead946b25a36490fc42dbfe6e62a9365e82b27a26e621d775bf` |
| canonical total Plan `p1-plan.md` | `1417843e48cedc56b3b26f660163249eea13aa1aa2b6b4f749e816813c2ea7b4` |
| A2 leaf `plan.md` | `afcfa84025af588b0251ca47123d2f37a7509bace10f4b3bf0ac132b109417aa` |
| A2 `blocked.md` | `94316fb12a4519711b1728983491d25dd803aeecf120c7c7daa6c6e31f6efb8b` |
| P1 Stage control index | `930b9176d5bb166ff2ecb76445287b1c1752d155e2e4f880ea5ab1332e662956` |
| P1 Plan control index | `9671f2dba06255f127c9ec14b43130def791f3352583f7c4d341f54808085da6` |

The EOF R27 body in all six surfaces is byte-identical from
`本段是六个 current control surfaces 的 byte-identical override。` through
the final newline: 96 newline-terminated lines, 8,047 bytes, SHA-256
`aa14b169a809ee3acb379ec44f712f126ab993408df2050d55ea299881ed5a8c`.
Headers and current/index statements uniformly identify the six surfaces,
fresh driver, exact 220-entry manifest, and this freeze as present/frozen while
Review27 and all runtime outputs remain absent/pending.

## 3. Frozen R27 driver and root-cause closure

`r27-begin.sh` is a regular non-symlink file with:

- SHA-256 `770d0a413b449e4ea14db4bd8f7dc880f134c20a013b3ef76f684ba3e0f7432d`;
- 5,585 lines and 285,910 bytes;
- successful system Bash syntax validation;
- two independent static audits with zero P0/P1/P2 findings.

The production helper has exactly 13 call sites and all 13 capture its rc as
the first executable statement of an explicit `else`. The five causal sites
are uniquely marked and present. There are zero post-`fi` or same-line reads of
`$?`. Return classifications remain 0/1/2; rc 1 is stable absence and rc 2 is
indeterminate/fail-closed.

The helper's three diagnostics store only safe enums: previous/latest state
from `UNOBSERVED/RUNNING/STOPPED/ABSENT/TRANSITION`, and returned rc from
`UNSET/0/1/2`. No jobs, ps, lsof, pathname, command, or user payload is retained.
The exact stable-absence diagnostic is `ABSENT:ABSENT:1`.

Both final pre-BEGIN rounds run, in order, the inherited ERR-subshell static
gate and eight Bash 3.2 probes, then the new compound-if static gate and four
Bash 3.2 probes. In-memory validation passed:

- inherited ERR guard ordering/inventory and all eight probes;
- 13 calls / 13 immediate else captures;
- all five causal-site markers;
- rc 0 capture;
- rc 1 plus `ABSENT:ABSENT:1` diagnostics;
- rc 2 diagnostics and fail-closed classification;
- legacy no-else reproduction mapping a real rc 2 to compound-if rc 0.

The immutable source baselines remain:

| Path | SHA-256 |
|---|---|
| `Sources/AgentLoopCore/Loop/AgentLoop.swift` | `c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275` |
| `Sources/AgentLoopTestSuite/AgentLoopTests.swift` | `37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967` |
| `scripts/verify-p1-migrations-sqlite-matrix.sh` | `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c` |

## 4. Immutable R26 anchors and runtime evidence

| Anchor | SHA-256 |
|---|---|
| `plan-freeze-r26.md` | `0306f000961e6ed7b129307475495cb3a798df2adb833a9da830e5ddc70ef7cb` |
| `reviews/26-p1-plan-review.md` | `8d9cc6b3acaeda72204b1a71f209996344215b61747b8c516d7afbf067880ba9` |
| `r26-begin.sh` | `937a8cb4e737480f5cf44409d9dedbcdd581f627c46726957352a7b56f5c296d` |
| `r26-entry.sha256` | `f9d697f35227e6db7df1e8e1b87c4969a184b0a7f65a3d6c70f7c8bfe5d7a22d` |

The ten actual R26 runtime files are immutable regular non-symlink evidence:

| Runtime artifact | Bytes | SHA-256 |
|---|---:|---|
| `evidence/r26-clean-boundary.log` | 14,381 | `814ad7bfc50dfa6e5de65b10f470c8dee3bdbfed3ee2532776ad7011658b2280` |
| `evidence/r26-hash-manifest.log` | 6,063 | `7041b3fc36c6fcc5a0686d9deb95cb4c6738425579f62b904dfbcd83aebf3198` |
| `r26-verify.log` | 96,130 | `212a205b2baaf8d052513f148199ea8679ab625d0d607255e58a2d6807b61ea8` |
| `r26-targeted-tests.log` | 4,718 | `24b321736976667737b38eefcd79c11ecfc90322b9a495e63d7f6fcf52436fea` |
| `r26-build.log` | 729 | `068e012ddb71725eac797c2b76f56972a403048ff0fed5010a7d14ad0ffc6fc6` |
| `r26-migration-matrix.log` | 44,058 | `124b28b317581ea19b7647dfa084ebc7e3c3394fe02c9a40fd80d2de20006932` |
| `evidence/r26-bundle-provenance.log` | 2,661 | `c5604214b12c265fe0100a500491a08eeff7ab95d543b753d2ee433ad459d906` |
| `evidence/r26-source-gates.log` | 2,998 | `58c90e5840c6c14d529ecb53f1b6ada95d2707a4b99d4c18fedee1c253767b76` |
| `evidence/r26-preview-bootstrap.log` | 6,557 | `d10ee7940284ccb289ba48a40284e3c539f421054e39718b02d7a94499b53733` |
| `evidence/r26-preview-cold-start.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

They prove BEGIN, the captured Swift/tee 0/0 full 652/652, seven suites, same-log
46/46, launch/build/release/object/matrix/source/privacy gates, pre-preview
206/206, and same-bundle B01–B06. They also prove the unique quit-wait rejection,
no cold C01–C09, no screenshot/report, and no END. Final containment reaped the
exact child; no AgentLoop or AgentLoopApp process remained.

## 5. Fixed R26 two-root lifecycle universe

The only R26 root entries are, in fixed order:

1. `/private/tmp/agentloop-r26-state.JlHsbi`
2. `/private/tmp/agentloop-r26-bundle.mCj70H`

During this freeze publication, each exact path received one and only one
`os.lstat` root-entry shape check in that order. The observed baseline was exact
`11`: two real, non-symlink directories. No descendant was entered, enumerated,
hashed, opened, or cleaned, and no parent directory or glob was scanned for R26.

The frozen driver uses complete ordered A/B captures of only these two root
entries. It allows equality or 1-to-0 erosion and rejects 0-to-1, symlink, wrong
type, malformed, partial, or indeterminate capture. FIRST/LATEST/accepted-B are
committed only after the full comparison passes. This does not claim detection
of same-type inode replacement and never treats R26 root contents as R27 input.

## 6. Frozen 220-entry manifest

`r27-entry.sha256` is a regular non-symlink absolute-path, lowercase SHA-256,
two-space manifest with:

- 220 sorted unique paths;
- SHA-256 `178af4f5f5fa30fd4a070125b8eafbfc0268fc74ad9703293e5dca124a37262e`;
- path-set SHA-256 `c4ae51003778ade8c24d193a926f879c94bba8c3e281376ca9c431c3454e53d6`;
- strict current verification `220/220`;
- exact equation `R26 full 206-path set + 14 new paths`;
- old R26 partition `200 unchanged + six expected control-surface mismatches`.

The 14 additions are the fresh R27 driver; immutable R26 manifest, freeze, and
Review26; and the ten R26 runtime files in section 4. R26 driver already belongs
to the inherited 206 paths and is not duplicated. All 14 additions were absent
from the R26 path set and are regular non-symlink files.

The manifest excludes itself, this freeze, Review27, both fresh R27 roots, all
invocation-owned hidden stages, and these 12 future runtime/report paths:

1. `r27-targeted-tests.log`
2. `r27-verify.log`
3. `r27-build.log`
4. `r27-migration-matrix.log`
5. `evidence/r27-clean-boundary.log`
6. `evidence/r27-bundle-provenance.log`
7. `evidence/r27-source-gates.log`
8. `evidence/r27-hash-manifest.log`
9. `evidence/r27-preview-bootstrap.log`
10. `evidence/r27-preview-cold-start.log`
11. `evidence/r27-preview-smoke.png`
12. `impl-report-r27.md`

At publication, the manifest and freeze are present but intentionally excluded
from the manifest path set. Review27, all 12 runtime/report paths, both fresh
roots, and hidden stages remain absent. Normal, restore, and END verification is
220/220. The sole matrix mutation window is exactly 219 unchanged plus one owned
matrix-script mismatch, followed by exact restoration. O_EXCL, no-pre-delete,
ownership, no-clobber publication, and fail-once containment remain mandatory.

## 7. Review27 and automatic caller contract

The independent reviewer may write only
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/27-p1-plan-review.md`.
It must contain exactly one `Verdict: APPROVED — 0 P0 / 0 P1` and one machine
block with these 12 key/value lines between unique sentinels:

```text
R27_MACHINE_BLOCK_BEGIN
authority_mode=standing_goal_automatic_after_review27
standing_goal_authority_verified=true
reviewer_independence_attested=true
reviewer_write_scope=review27_only
user_hash_echo_required=false
review_verdict=APPROVED_0_P0_0_P1
freeze_sha=<current plan-freeze-r27 SHA-256>
driver_sha=770d0a413b449e4ea14db4bd8f7dc880f134c20a013b3ef76f684ba3e0f7432d
manifest_sha=178af4f5f5fa30fd4a070125b8eafbfc0268fc74ad9703293e5dca124a37262e
branch=codex/personal-ai-ranch-p0
head=02334ec8d21533be81d93d39191bc7d9b9c24f7f
manifest_count=220
R27_MACHINE_BLOCK_END
```

Review27 computes and binds this freeze's final SHA. The freeze does not embed
its own hash; the manifest excludes itself and the freeze, avoiding cycles.

After exact Review27 approval and confirmation that no newer user turn revoked
the standing Goal, the root agent computes the review SHA and invokes the frozen
driver automatically without a user hash echo:

```text
/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C LANG=C TMPDIR=/private/tmp GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null /bin/bash --noprofile --norc /Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r27-begin.sh <current Review27 SHA-256>
```

The same Bash process must run BEGIN, the unique unfiltered full test and
immediate two-element `PIPESTATUS`, same-log/build/release/object/matrix/source/
privacy gates, B01–B06/C01–C09, staged screenshot/report, and tiny commit-wins
END. No retry, handoff, caller continuation, root/object replacement, evidence
reuse, or patch-on-failure is allowed.

## 8. Completion gate and red lines

Only exact R27 END plus every technical gate may open independent Review02. Only
Review02 with zero P0/P1 may open A2 acceptance. A3 and later slices remain
closed until A2 is accepted and their own reviewed plans and entry gates exist.

Commit, push, merge, release, destructive or normal-data operations, payment,
public communication, external operations, and real-user actions remain
unauthorized. Any new architecture, scope, dependency, test gate, semantic, or
evidence gap requires a new bounded planning revision and independent review.
