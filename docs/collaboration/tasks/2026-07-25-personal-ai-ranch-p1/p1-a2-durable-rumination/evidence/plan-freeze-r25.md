# R25 Plan Freeze — Numeric Diagnostics and Clean A2 Re-verification

> Date: 2026-08-10
>
> Branch: `codex/personal-ai-ranch-p0`
>
> HEAD: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> Scope: planning/control plane only. This freeze did not call the R25 driver and
> did not run BEGIN, tests, builds, the migration matrix, source/privacy gates,
> bundle assembly/signing, preview, Review02, acceptance, or later-slice work.

## 1. Frozen current route

R24 remains an immutable executed predecessor. Its plan review passed, but the
execution permanently ended `REJECTED_CONTAMINATED` at
`phase=guard_shape_and_strip`, `reason=core_guard_shape_1:1::0:1:1`, exit 70.
R24 did not reach END.

R25 closes only the demonstrated Bash/awk diagnostic-rendering false negative.
It changes no product, test, App, package, schema, migration, API, or permanent
script bytes. Review25 is the only next gate. Before Review25 approves this exact
freeze, driver, and manifest, caller/BEGIN and every execution gate remain closed.

## 2. Frozen six control surfaces

| Surface | SHA-256 |
|---|---|
| canonical Stage `p1-stage-spec.md` | `1144ba615251f55bfe4e19a75b51949fb40578f03061f3b3b85abe55d16fa6e7` |
| canonical total Plan `p1-plan.md` | `3f49cd0e0c15216dde94dc1ec760e17349401e87e8091ff801b322b772080dbc` |
| A2 leaf `plan.md` | `efea0df0384cad16e374a7d8fd9de7848ebb0ea6a8c0c89964e2b6cc78461fdd` |
| A2 `blocked.md` | `de207674738425db358f5bdb0e245b02e26e06eb7df99845095fa9fe925bfdeb` |
| P1 Stage control index | `8d96ed8fe893db88008e0e12156172e62386346a3d0f914d2b3938a58370069f` |
| P1 Plan control index | `218b89806024c6c54b1eb5fb94c64ceb0eb55da68f7cdd33e094a91f9f91f2c6` |

All six R25 sections are byte-identical when extracted immediately after their
R25 heading through the terminal sentence
`不得由本段或standing Goal自行扩权。`, inclusive. The exact extraction includes
one leading Markdown blank-line byte and the terminal newline: 103 newline-terminated
lines, 8,154 bytes, SHA-256
`2f23d0a32c25140018a0bcb16ba733bf2c63af2377b927b60a8bcb88c24b6e0f`.
Removing only that asserted leading blank line yields the equivalent semantic-body
identity: 102 lines, 8,153 bytes, SHA-256
`4ec596810398184465fdc4023bfde8322d8b15112f4fd863191bb1a89e98b567`.

The controlling locations are canonical Stage `28.12`, canonical total Plan's
R25 final section, A2 leaf `16`, `blocked.md` `34`, P1 Stage index `4.2`, and
P1 Plan index `5.2`. Earlier R24 text is historical and cannot open R25 execution.

## 3. Frozen R25 driver and unchanged source baseline

`r25-begin.sh` is a regular non-symlink file with:

- SHA-256 `1eee61d199c5bb1c5b0149989f17508e9a75eacfbc2bac3b1a2f0063f0ab68bb`;
- 4,751 lines and 241,713 bytes;
- successful system Bash 3.2 syntax validation;
- numeric rendering as the only causal gate correction; all other differences are
  fresh R25 identity, immutable-predecessor, lifecycle, and evidence bindings that
  preserve the inherited product/test/gate semantics.

The immutable source baselines are:

| Path | SHA-256 |
|---|---|
| `Sources/AgentLoopCore/Loop/AgentLoop.swift` | `c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275` |
| `Sources/AgentLoopTestSuite/AgentLoopTests.swift` | `37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967` |
| R20-final stripped TestSuite | `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26` |
| `scripts/verify-p1-migrations-sqlite-matrix.sh` | `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c` |

The Core and TestSuite guard parsers each have one pure helper, reused by
preflight, final pre-BEGIN, and the active guard gate. Expected outputs are exact
`1:1:0:0:1:1` and `3:3:6:0:0:1`. R25 adds numeric `+ 0` rendering only to
the two six-field guard diagnostics, the seven top-level same-log counters, and
the two matrix count/line diagnostics. Predicates, tokens, commands, tests, and
failure behavior remain unchanged.

## 4. Immutable R24 anchors and actual runtime evidence

| Anchor | SHA-256 |
|---|---|
| `plan-freeze-r24.md` | `f22a7ffd954ddf6d9b2d804a5f3be58807373c388634b9200d260f1a8eb66746` |
| `reviews/24-p1-plan-review.md` | `a9ef2cab24afa65290f563b85ac03022b958d39253c025017d1c91b689926c0e` |
| `r24-begin.sh` | `1b224f442d1fdea856433d12141e5ea9f74190a380e554e4ec94872ba0b8655f` |
| `r24-entry.sha256` | `55a6c2e8a657166de8b983cd0edfb2a7b1ae1943dc291819c0c2ea417338a80c` |

The ten actual R24 runtime files are immutable regular non-symlink evidence:

| Runtime artifact | Bytes | SHA-256 |
|---|---:|---|
| `r24-targeted-tests.log` | 4,717 | `b1565785c8eafc04e088503273c33bfad740d7285574aecf98596593559d571e` |
| `r24-verify.log` | 96,130 | `1f2cfaa1b42d821404ce8f449445f29f1fa3d9cf745967883e89ff185c85f084` |
| `r24-build.log` | 451 | `ad11175a810a70ae005aa30e51b441c210c0988abc6437516ae6c9638b251319` |
| `r24-migration-matrix.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r24-source-gates.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r24-bundle-provenance.log` | 2,661 | `20a4f2764e97024eaa17da100925af7c870d092bfb5177279ceb05dfcfe80b8a` |
| `evidence/r24-clean-boundary.log` | 6,523 | `c3066bbce88a22a0ac7dfa860a6991a07adc90122a0be551d820681f671880fb` |
| `evidence/r24-hash-manifest.log` | 2,901 | `7ff8f616c269f0450ca30e22d7fc03f5a527982bf301e111f9254acaf391b088` |
| `evidence/r24-preview-bootstrap.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `evidence/r24-preview-cold-start.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

They prove the unique authoritative Swift/tee status `0/0`, terminal 652/652,
seven suites with zero failures, same-log 46/46, debug build, fresh signed bundle,
and `LAUNCH_READY`, followed by the permanent guard-shape rejection. Matrix
mutation/restore, source gate, preview, report publication, and END did not run.
`impl-report-r24.md` and `evidence/r24-preview-smoke.png` remain absent.

## 5. Frozen R24 39-bit lifecycle

The historical roots are:

- state: `/private/tmp/agentloop-r24-state.Qko2Y3`;
- bundle: `/private/tmp/agentloop-r24-bundle.OPfuVv`;
- app: `/private/tmp/agentloop-r24-bundle.OPfuVv/AgentLoop.app`.

The universe is exactly 39 bits: state root, bundle parent, App, and the App's
36 descendants (six directories and 30 regular files). Its planning baseline is
`111111111111111111111111111111111111111`. The present state root is exact empty.
The present bundle/App tree has exact type and contents with:

| Identity | SHA-256 / value |
|---|---|
| 36-node aggregate | `1871d346bed8b7978f7456e2893218a97cad7b8dc643c84bba9cd87cb81c8b5e` |
| signed executable | `0d01c0ee8b658cf68c5463ef70cc68756a69630a5986cf620ad3870097021b05` |
| `Info.plist` | `53bb6470fc12b39a5f48ac6d261415acff96cfbc57ffbf4721d3e351d2123277` |
| `_CodeSignature/CodeResources` | `4e903bc32534480c4fa8a17490e49c496e655f1827eafbed280d09fc0eb90ae4` |
| CDHash | `17bd20ada27ef9e69d0de007b49c53d01ddf48a6` |

Every R25 observation must drain a complete A/B capture and permit only equality
or 1-to-0 from BASELINE/LATEST through A and B. FIRST, LATEST, and accepted-B are
committed together only after every comparison passes. A 0-to-1 transition,
alternate identity, bad type/hash, malformed or indeterminate capture, extra node,
or substitution rejects permanently. R25 never mutates or cleans these historical
roots. This observation does not provide a filesystem transaction or lock and does
not prove inode, hardlink, xattr, resource-fork stability, or eliminate TOCTOU.

## 6. Frozen 192-entry manifest

`r25-entry.sha256` is a regular non-symlink, absolute-path, lowercase SHA-256,
two-space manifest with:

- 192 sorted unique paths;
- SHA-256 `462be6ff554b3d38bea76ac8351a77f780b575a1a9aeae4a461e42dd303655ba`;
- path-set SHA-256 `528ff3455bf4d3e97388ce0dca88ea6edcc1de073657ae48d1fbca649abbb03b`;
- strict current verification `192/192`;
- exact equation `R24 full 178-path set + 14 new paths`;
- R24 historical partition `172 unchanged + six expected control-surface mismatches`;
- R23 historical partition `156 unchanged + AgentLoopTests.swift + six control surfaces`.

The 14 additions are R25 driver; immutable R24 manifest, freeze, and Review24;
and the ten R24 runtime files listed in section 4. All 14 are absent from the R24
path set and are regular non-symlink files.

The manifest excludes itself, this freeze, Review25, and these 12 future R25
runtime artifacts:

1. `r25-targeted-tests.log`
2. `r25-verify.log`
3. `r25-build.log`
4. `r25-migration-matrix.log`
5. `evidence/r25-clean-boundary.log`
6. `evidence/r25-bundle-provenance.log`
7. `evidence/r25-source-gates.log`
8. `evidence/r25-hash-manifest.log`
9. `evidence/r25-preview-bootstrap.log`
10. `evidence/r25-preview-cold-start.log`
11. `evidence/r25-preview-smoke.png`
12. `impl-report-r25.md`

At freeze publication, the manifest and this freeze are present regular non-symlink
files but intentionally excluded from the manifest path set; Review25 and all 12
future runtime artifacts remain absent. Both future fresh roots and every
invocation-owned hidden stage are also excluded and absent. Entry, each mutation
boundary, matrix restoration, and END require 192/192. The only permitted mutation
window is exactly 191 unchanged plus one owned matrix-script mismatch, followed by
mandatory exact restoration. O_EXCL, no-pre-delete, three independent ownership
flags, fail-once containment, and no-clobber publication remain mandatory.

## 7. Review25 and automatic caller contract

The independent reviewer may write only
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/25-p1-plan-review.md`.
That report must contain exactly one
`Verdict: APPROVED — 0 P0 / 0 P1` and exactly one 12-line block:

```text
R25_MACHINE_BLOCK_BEGIN
authority_mode=standing_goal_automatic_after_review25
standing_goal_authority_verified=true
reviewer_independence_attested=true
reviewer_write_scope=review25_only
user_hash_echo_required=false
review_verdict=APPROVED_0_P0_0_P1
freeze_sha=<current plan-freeze-r25 SHA-256>
driver_sha=1eee61d199c5bb1c5b0149989f17508e9a75eacfbc2bac3b1a2f0063f0ab68bb
manifest_sha=462be6ff554b3d38bea76ac8351a77f780b575a1a9aeae4a461e42dd303655ba
branch=codex/personal-ai-ranch-p0
head=02334ec8d21533be81d93d39191bc7d9b9c24f7f
manifest_count=192
R25_MACHINE_BLOCK_END
```

Here “12-line block” means the 12 key/value lines between the unique begin/end
sentinels. Review25 computes and binds this freeze's final SHA; the freeze does not
self-embed it.

After an exact Review25 approval and a final check that the standing Goal has not
been revoked by a newer user instruction, the root agent computes Review25's SHA
and invokes the frozen driver automatically. No user hash echo is required. The
caller is exactly:

```text
/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C LANG=C TMPDIR=/private/tmp GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null /bin/bash --noprofile --norc /Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r25-begin.sh <current Review25 SHA-256>
```

The same Bash process must run BEGIN, the only unfiltered
`swift run RunTests | tee` with immediate two-element `PIPESTATUS` capture,
same-log 46/46, debug build and fresh signed bundle, guard/strip, target-exact
release builds, four-object symbol gates, matrix mutation/restoration,
source/privacy gates, exact bootstrap and cold UI flows, staged report, and END.
No caller continuation, second full test, retry, handoff, root/binary substitution,
or patch-on-failure is allowed.

## 8. Completion gate and red lines

Only an exact R25 END plus all technical evidence may open a new independent
Review02. Only Review02 with zero P0/P1 may open independent A2 acceptance. A3 and
all later slices remain closed until A2 is accepted and their own reviewed plans
and entry gates exist.

Commit, push, merge, release, destructive or normal-data operations, payment,
public communication, external operations, and real-user actions remain
unauthorized. Any new architecture, scope, dependency, test gate, semantic, or
evidence gap requires a new bounded planning revision and independent review.
