# P1-A2 Independent Acceptance — Durable Rumination

> Final status: **ACCEPTED**
>
> Date: 2026-08-10 local / 2026-08-11 UTC
>
> Acceptance owner: fresh, responsibility-isolated independent acceptance owner
>
> Branch: `codex/personal-ai-ranch-p0`
>
> HEAD: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. Responsibility isolation and review boundary

This acceptance owner did not participate in A2 planning, implementation,
test implementation, runtime-evidence generation, R28 execution, Review28, or
Review02. The owner's earlier work was limited to a read-only map of the gate
after A2. The only repository write made by this acceptance invocation is this
`acceptance.md`.

The accepted Stage, total Plan, A2 leaf, `blocked.md`, P1 indexes, product code,
tests, Package files, scripts, freezes, reviews, runtime logs, report, and
screenshot remained read-only. This owner did not rerun tests, builds, the
SQLite matrix, the execution driver, or UI; did not enter or enumerate any
preserved temporary root; and did not modify, clean, complete, or reuse any
predecessor artifact or root. The R28 screenshot was visually inspected as an
existing immutable file.

## 2. Frozen authority and current-byte verification

The six accepted control surfaces remain byte-identical to the R28 freeze:

| Control surface | Current SHA-256 |
|---|---|
| P0 `p1-stage-spec.md` | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| P0 `p1-plan.md` | `dfec20e698d73ef533c8539292e61508873239933a203f8a9050829669d94948` |
| A2 leaf `plan.md` | `9fdda7f4b8c6d8ce6cf7fcf3e9db2c7bac345f905ea8ea0fe29adf3294087671` |
| A2 `blocked.md` | `6f37b6e2586927ee3146dbfb0141b4156c3797ac817eba9b47fd3873f40c2a0f` |
| P1 Stage index | `d988f24af8cfd64a0e725751d389dbd3127c2c3b99d3bc925207705488848e09` |
| P1 Plan index | `a6ae00c3be8eba8316e918264b6057400b9348ceaecf755fa0122855adfbedc9` |

The controlling R28 artifacts also remain exact:

| Artifact | Current identity / verdict |
|---|---|
| `plan-freeze-r28.md` | `902f0ceebd2a998cff724cdf0343440dc6f017733659614001ef11d3c28cc14f` |
| `28-p1-plan-review.md` | `5c1b926c8a34596ea8c4a739c52657910d67ca932fed2fe75d813f7f53e31e09`; `APPROVED — 0 P0 / 0 P1` |
| `r28-begin.sh` | `2f84ff2167faed7a1d677003f36d57548896d4a323ffe9980926fa8f8b0745c7` |
| `r28-entry.sha256` | `9d5fbeb6556a293dddb67fed80ea7983a920f4952c3f5f7ed11a5fb56e945dfc`; 235 entries |
| `impl-report-r28.md` | `704a3a0bf1d32647989c7c3c4146ee88e3f83d6c0013353bee874bb0550974aa`; PASS |
| `reviews/02-p1-a2-review.md` | `4efc3075d86cf7e96fad4873af403f3bf226fcdeb29fe4bd385feff4d710126d`; `APPROVED — 0 P0 / 0 P1 / 1 non-blocking P2` |

An independent current-manifest pass found exactly 234 unchanged files, one
authorized mismatch, zero unexpected mismatches, zero missing files, and zero
symlinks. The sole mismatch is the frozen one-line
`ShellToolTests.swift` entry-to-final transition. The line occurs exactly once
and removing only that line in a read-only stream reconstructs the entry hash.
The two product witnesses, `ShellTool.swift` and `ShellProcessRegistry.swift`,
remain at their frozen hashes. No unexplained A2-scoped byte drift remains.

## 3. Completion-gate decision

The immutable R28 evidence and independent Review02 satisfy every accepted A2
completion gate:

- the authoritative unfiltered `swift run RunTests` log has exactly 652 unique
  starts, 652 unique matching passes, seven suite starts and passes, no failure
  marker, and terminal `652 tests in 7 suites passed`;
- all 46 required A2 names are unique and each has exactly one start and one
  pass in that same full-run log; no filtered retry substitutes for it;
- `shellTimeoutTerminatesProcess` is discovered once and passes once inside the
  five-second assertion boundary;
- debug AgentLoopApp, exact release AgentLoopCore target, exact release
  AgentLoopTestSuite target, and release/debug object-symbol direction pass;
- SQLite 3.51.0 and 3.52.0 fresh/replay/FK/integrity/DDL/append-only lanes pass,
  and the owned matrix rewrite is restored to its exact entry bytes;
- source-contract, privacy, A1b sentinel, final-hash, and `git diff --check`
  gates pass;
- bundle source/build/copy/sign/executable provenance closes at LAUNCH_READY;
- isolated bootstrap B01–B06 and cold-start C01–C09 pass using the same signed
  bundle and isolated state root, the synthetic fixture passes FK/integrity,
  the screenshot shows the required recovering state, and both owned process
  lifecycles end contained;
- the R28 boundary contains one BEGIN and one terminal
  `status=END` / `result=PASS`, with one authorized test-only delta and zero
  product, App, Package, or permanent-script delta;
- Review02 independently rechecked the current bytes and evidence and returned
  **0 P0 / 0 P1**. Its cached-login-shell single-flight observation is P2,
  explicitly outside R28 scope, and is not accepted here as implemented.

R-02 is therefore **CLOSED for P1-A2**: durable rumination now has durable work
ownership, adoption, retry, cancel and terminal behavior, recovering
projection, and the exact dynamic/source evidence required by the accepted
Stage and Plan. No empty result, default success, swallowed error, or
unreviewed fallback is used to close the risk.

## 4. Historical incident and predecessor disclosure

Acceptance of R28 does not wash earlier attempts green.

The R13 implementation/completion invocation remains
`REJECTED_CONTAMINATED`. During its first preview, a Computer Use display-name
lookup launched installed `/Applications/AgentLoop.app` PID 74836, which opened
the normal `.agentloop.lock`, database, SHM, and WAL. There is no pre-incident
normal-database content hash, so whether normal data mutated remains
**UNKNOWN**. Review01 remains immutable at
`5b6a171515404a644abcd05e3afc3840cb1dd4d84d7993f74af48de0692b4dd5`
with `CHANGES REQUIRED — 0 P0 / 1 P1`. No later isolated success changes these
facts.

The complete R15–R27 disposition is preserved:

| Attempt | Immutable disposition |
|---|---|
| R15 | `REJECTED_CONTAMINATED` at BEGIN attestation false-negative; no later technical gates or preview ran. |
| R16 | `PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED`; zero runtime/repository writes and no execution gate ran. |
| R17 | Review17 required changes; the candidate was not executed and no R17 runtime artifact/root was created. |
| R18 / R18-A | Review18 required changes for lossy newline pathname transport; no execution gate or runtime artifact/root was created. |
| R19 | `REJECTED_CONTAMINATED` after the sole authoritative full run ended 651/652; later gates and END did not run. |
| R20 | `REJECTED_CONTAMINATED` at release Core build after partial 652/652, same-log 46/46, debug build and LAUNCH_READY success; later gates and END did not run. |
| R21 | `PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED — ZERO WRITE`; no R21 boundary, runtime artifact, root, or source guard was created. |
| R22 | Review22 required changes; it was not executed and created no runtime artifact/root or source delta. |
| R23 | `REJECTED_CONTAMINATED`; the process printed terminal 652/652, but the zsh carrier did not capture Swift/tee statuses, so 46/46 and all later gates/END were absent. |
| R24 | `REJECTED_CONTAMINATED` at the guard-shape parser after captured 652/652, same-log 46/46, debug build and LAUNCH_READY; later gates, preview and END were absent. |
| R25 | `REJECTED_CONTAMINATED` during bootstrap preview because inherited Bash `ERR` handling escaped the command-substitution child; no UI challenge, screenshot, report, or END occurred. |
| R26 | `REJECTED_CONTAMINATED` after B01–B06 because a compound-`if` status capture misclassified stable process absence; cold C01–C09, screenshot, report and END were absent. |
| R27 | `REJECTED_CONTAMINATED` after the sole authoritative full run ended 651/652 at the shell-timeout measurement boundary; later gates and END were absent. |

R14 also remains a planning review that required changes and was never
executed. All predecessor evidence, absence facts, and recorded classifications
remain historical evidence; none is substituted into R28 or reclassified by
this acceptance.

## 5. Exact scope of normal-data and isolation claims

The accepted clean-execution claim applies **only to the observed intervals of
the R28 boundary**. Within those intervals, evidence records exact isolated
owned direct-child processes, an observed normal-root open count of zero, no
observed replacement process, no provider dispatch, and clean owned-process
exit. It does not prove an atomic filesystem transaction, continuous coverage
of unobserved intervals, absolute absence of TOCTOU, or that all A2 history had
zero normal-data access.

The R28 invocation-unique preference-domain onboarding write is explicitly
disclosed and is not represented as a normal-data write. The R13 normal-root
incident and its **UNKNOWN mutation state** remain the controlling disclosure
for A2 history.

## 6. Acceptance and next gate

**ACCEPTED.** P1-A2 Durable Rumination is complete, and R-02 is closed for this
slice.

This acceptance opens **only the P1-A3 entry gate** under the already accepted
Stage and Plan. It does not pre-accept A3, authorize an A3 implementation
outside its reviewed leaf/allowlist, or open A4–P6. It grants no commit, push,
merge, release, destructive or normal-data operation, payment, public
communication, external action, or real-user operation. Any A3 ambiguity,
scope mismatch, or unmet entry condition must return to bounded planning and
responsibility-isolated review.
