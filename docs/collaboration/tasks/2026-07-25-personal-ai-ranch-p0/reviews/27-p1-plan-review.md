# P1-A2 R27 Compound-If Status-Capture Plan Review

Verdict: APPROVED — 0 P0 / 0 P1

> Date: 2026-08-10
>
> Review object: R27 final six control surfaces, fresh driver, 220-entry
> manifest, final freeze, immutable R26 evidence, and the two closed R26
> execution-audit findings

## 1. Scope and reviewer independence

This reviewer did not author or revise the R27 six control surfaces,
`r27-begin.sh`, `r27-entry.sha256`, or `plan-freeze-r27.md`. The Review27 path
was absent when this final review began. The only repository write made by this
reviewer is this file.

The review was read-only apart from this report. It did not invoke the R27
driver or BEGIN and did not run tests, builds, the migration matrix, source or
privacy gates, bundle work, UI preview, Review02, acceptance, or later-slice
work. It did not access, enter, enumerate, hash, open, clean, or re-observe any
temporary root. It did not modify product, test, App, Package, schema,
migration, permanent-script, control-surface, driver, manifest, freeze, or
predecessor-evidence bytes.

## 2. Frozen identities and synchronized surfaces

The reviewed snapshot is branch `codex/personal-ai-ranch-p0`, HEAD
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`.

| Artifact | SHA-256 | Result |
|---|---|---|
| R27 freeze | `6d45ecf515861c9aa022ebeea994fc309350e4f33fb7425d01a700777425dd41` | exact; regular non-symlink |
| R27 driver | `770d0a413b449e4ea14db4bd8f7dc880f134c20a013b3ef76f684ba3e0f7432d` | exact; regular non-symlink; 5,585 lines; 285,910 bytes; Bash syntax PASS |
| R27 manifest | `178af4f5f5fa30fd4a070125b8eafbfc0268fc74ad9703293e5dca124a37262e` | exact; regular non-symlink; strict 220/220 PASS |
| canonical Stage | `ccbd624d93c88ead946b25a36490fc42dbfe6e62a9365e82b27a26e621d775bf` | exact |
| canonical total Plan | `1417843e48cedc56b3b26f660163249eea13aa1aa2b6b4f749e816813c2ea7b4` | exact |
| A2 leaf Plan | `afcfa84025af588b0251ca47123d2f37a7509bace10f4b3bf0ac132b109417aa` | exact |
| A2 blocked/control history | `94316fb12a4519711b1728983491d25dd803aeecf120c7c7daa6c6e31f6efb8b` | exact |
| P1 Stage control index | `930b9176d5bb166ff2ecb76445287b1c1752d155e2e4f880ea5ab1332e662956` | exact |
| P1 Plan control index | `9671f2dba06255f127c9ec14b43130def791f3352583f7c4d341f54808085da6` | exact |

All six EOF R27 bodies are byte-identical: 96 newline-terminated lines, 8,047
bytes, SHA-256
`aa14b169a809ee3acb379ec44f712f126ab993408df2050d55ea299881ed5a8c`.
Their headers and current/index statements consistently identify R26 as
permanently rejected, the R27 six surfaces/driver/manifest/freeze as frozen,
Review27 as pending, and every execution gate as closed until approval.

## 3. Manifest and immutable R26 evidence

The manifest has exactly 220 lowercase SHA-256 plus two-space plus absolute
repository-path records. Paths are sorted and unique, the path-set SHA-256 is
`c4ae51003778ade8c24d193a926f879c94bba8c3e281376ca9c431c3454e53d6`,
and strict current verification is 220/220. Its set is exactly the full R26
206-path set plus fourteen additions. The old-set partition is exactly 200
unchanged plus the six expected current-control-surface mismatches; there are
no missing old paths or unexpected additions.

The fourteen additions are the fresh R27 driver; the immutable R26 manifest,
freeze, and Review26; and the ten R26 runtime artifacts. All have their frozen
type, SHA-256, and byte size. R26 evidence independently reconfirms the unique
BEGIN, captured Swift/tee 0/0, full 652/652 in seven suites, same-log 46/46,
build/release/object/matrix/source/privacy gates, pre-preview 206/206, and
exactly one B01–B06 challenge/result pair per step. It also reconfirms the
unique `quit_wait_job_table_indeterminate_bootstrap_0` rejection, zero-byte
cold log, absent screenshot/report, and no END. No AgentLoop or AgentLoopApp
process was present during this review.

The manifest excludes itself, the R27 freeze, this review, and all twelve R27
runtime/report paths. Those twelve paths and this review were absent at review
entry. No temporary-root or hidden-stage observation was performed by this
reviewer.

## 4. Root-cause and observability closure

The R26 failure is correctly reduced to Bash 3.2 compound-`if` status
semantics: reading `$?` after an `if` without an executed branch loses the
helper's nonzero status and produces the observed zero. The R27 production
driver has exactly thirteen calls to `r27_preview_active_job_exact`; every call
has an explicit `else` whose first executable statement captures `$?`. There
are exactly thirteen such captures, exactly five uniquely marked causal-site
repairs, and no post-`fi` or same-line post-`fi` capture.

The helper's 0/1/2 classification is preserved. Its bounded diagnostics retain
only the enumerated previous/latest states
`UNOBSERVED/RUNNING/STOPPED/ABSENT/TRANSITION` and returned rc
`UNSET/0/1/2`. Stable absence is locked to the real two-snapshot contract
`ABSENT:ABSENT:1`; raw jobs, ps, lsof, path, command, and user payload are not
persisted. Normal quit evidence records the safe rc/state pair, and rejection
evidence records the latest safe diagnostics. This closes both the status-loss
P0 completion cause and the R26 evidence audit's P1 observability gap without
changing retry, signal, kill, wait, cached-reap, containment, or fail-closed
semantics.

Both pre-BEGIN rounds place the inherited ERR-subshell static gate and eight
Bash 3.2 probes before the compound-if static gate and four probes. The static
contracts bind the exact call/capture inventory, five causal markers, stable
absence sequence, safe diagnostic assignments, rc 0/1/2 behavior, and the
legacy no-else reproduction. Both rounds occur before the exclusive boundary
creation; there is no EXIT trap or fallback that converts an indeterminate
status into success.

## 5. Gate result

No P0 or P1 finding remains. This approval opens only the exact frozen R27
automatic caller after the root agent confirms the standing Goal has not been
revoked and rechecks the bound identities. It does not attest an R27 execution,
END, Review02, acceptance, A3, commit, push, merge, release, data operation,
payment, public communication, external operation, or real-user action.

R27_MACHINE_BLOCK_BEGIN
authority_mode=standing_goal_automatic_after_review27
standing_goal_authority_verified=true
reviewer_independence_attested=true
reviewer_write_scope=review27_only
user_hash_echo_required=false
review_verdict=APPROVED_0_P0_0_P1
freeze_sha=6d45ecf515861c9aa022ebeea994fc309350e4f33fb7425d01a700777425dd41
driver_sha=770d0a413b449e4ea14db4bd8f7dc880f134c20a013b3ef76f684ba3e0f7432d
manifest_sha=178af4f5f5fa30fd4a070125b8eafbfc0268fc74ad9703293e5dca124a37262e
branch=codex/personal-ai-ranch-p0
head=02334ec8d21533be81d93d39191bc7d9b9c24f7f
manifest_count=220
R27_MACHINE_BLOCK_END
