# P1-A2 Independent Implementation Review 02 — R28 clean execution

> Date: 2026-08-10 (R28 completed 2026-08-11 UTC)
>
> Reviewer: responsibility-separated implementation reviewer
>
> Verdict: **APPROVED — 0 P0 / 0 P1 / 1 non-blocking P2**

## 1. Independence, scope, and authority boundary

This reviewer did not author the R28 six control surfaces, freeze, Review28,
driver, manifest, source delta, runtime logs, bundle, preview, screenshot, or
implementation report, and did not participate in the R28 execution or UI
interaction. The only repository write made by this review is this file at the
exact path required by the accepted leaf plan:

`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/reviews/02-p1-a2-review.md`.

The review was read-only apart from that file. It did not rerun tests, builds,
the migration matrix, the driver, or UI; it did not enter or enumerate any
preserved predecessor or R28 temp root. It did not modify product, test, App,
Package, schema, migration, script, control-surface, runtime-evidence, report,
or acceptance bytes.

The reviewed worktree is on branch `codex/personal-ai-ranch-p0` at HEAD
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`. This Review is not A2 acceptance
and does not itself authorize A3, commit, push, merge, release, data operations,
external actions, or real-user actions.

## 2. Frozen authority and current identities

The six accepted control surfaces remain byte-identical to the R28 freeze:

| Control surface | Current SHA-256 |
|---|---|
| P0 `p1-stage-spec.md` | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| P0 `p1-plan.md` | `dfec20e698d73ef533c8539292e61508873239933a203f8a9050829669d94948` |
| A2 leaf `plan.md` | `9fdda7f4b8c6d8ce6cf7fcf3e9db2c7bac345f905ea8ea0fe29adf3294087671` |
| A2 `blocked.md` | `6f37b6e2586927ee3146dbfb0141b4156c3797ac817eba9b47fd3873f40c2a0f` |
| P1 Stage index | `d988f24af8cfd64a0e725751d389dbd3127c2c3b99d3bc925207705488848e09` |
| P1 Plan index | `a6ae00c3be8eba8316e918264b6057400b9348ceaecf755fa0122855adfbedc9` |

Their final 116 newline-terminated lines are each 8,817 bytes with SHA-256
`f7245b4202c9dd3c62e7febde3c99ee6ab2b37b7215fdc3ee0f9fdb7b3252183`.
The pre-execution status text at the top of those frozen inputs remains
historical planning state by design; Review28 and the immutable runtime
evidence are the later state transitions and the frozen inputs were not
rewritten after execution.

The R28 authority artifacts also remain exact regular non-symlink files:

| Artifact | Current identity |
|---|---|
| `plan-freeze-r28.md` | `902f0ceebd2a998cff724cdf0343440dc6f017733659614001ef11d3c28cc14f` |
| `28-p1-plan-review.md` | `5c1b926c8a34596ea8c4a739c52657910d67ca932fed2fe75d813f7f53e31e09`; `APPROVED — 0 P0 / 0 P1` |
| `r28-begin.sh` | `2f84ff2167faed7a1d677003f36d57548896d4a323ffe9980926fa8f8b0745c7`; 5,970 lines; mode 0755 |
| `r28-entry.sha256` | `9d5fbeb6556a293dddb67fed80ea7983a920f4952c3f5f7ed11a5fb56e945dfc`; 235 entries |

Review28 contains the required standing-goal authority, independence,
review-only write scope, no-user-hash-echo, branch, HEAD, and manifest-count
fields. The frozen driver has one executable unfiltered `swift run RunTests`
command; its second textual mention is report metadata, not another command.
The driver does not write `ShellToolTests.swift`; the sole source delta was
applied in the reviewed pre-BEGIN window.

## 3. Current bytes, scope, and manifest

The only R28 implementation delta is the exact line

```swift
    _ = await LoginShellEnvironment.shared.environment()
```

immediately before `let clock = ContinuousClock()` inside
`shellTimeoutTerminatesProcess()`. The current test file SHA-256 is
`37b9e97c567cc599b98899fe1ca6c1deb9383b2889d52c2c42d3236dd2535a29`.
The line occurs exactly once; removing only that newline-terminated line in a
read-only stream reconstructs the frozen entry SHA-256
`c4c75d66540c2cc0760f0edaef0650a93e2e589a45a5d8b932ab3b2bdc091350`.
The existing 5-second assertion, 300 ms command timeout, `sleep 30`, error and
captured-output checks, and registry-cleanup assertion remain present.

The two product witnesses remain unchanged:

- `ShellTool.swift`: `e5980b4fb7d756656a7271ea646a54d49355c7a64f683245c6689254d76f2faf`;
- `ShellProcessRegistry.swift`: `260896d845d031e5cf46865303cfd00e944fa1c212278482c0d9a29d1001e6d1`.

An independent current-manifest pass found 234 exact matches, one mismatch,
zero missing paths, and zero symlinks. The sole mismatch is the authorized
`ShellToolTests.swift` entry-to-final transition. All 235 absolute paths are
bytewise sorted and unique regular files. The matrix script is restored to its
entry SHA-256 `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`.
`git diff --check` is clean.

The execution-time status log included an untracked tool-local
`.claude/settings.local.json` that is currently absent. It is outside the
235-entry manifest and every R28 product/test/script/control/runtime path; its
absence changes neither the authorized 234+1 partition nor the reviewed A2
bytes. No unexplained R28-scoped drift is present.

## 4. Technical completion evidence

### 4.1 Authoritative test and exact subset

`r28-verify.log` is a complete unfiltered `swift run RunTests` output with
SHA-256 `ea2e1f140c4e2db5f52d7d309ce4b7446a1c1abe8aa45577368c431e442e757d`.
Independent parsing of the raw log found:

- exactly 652 unique test starts and 652 unique matching passes;
- zero test, suite, or run failure markers;
- exactly seven suite starts and seven suite passes;
- one terminal summary, `652 tests in 7 suites passed`, as the final non-empty
  line;
- `shellTimeoutTerminatesProcess` discovered once, passed once, failed zero
  times, in 4.108 seconds.

`r28-targeted-tests.log` is a mechanically derived same-log audit bound to that
raw log. Its 46 required names are unique, and every name has exactly one start
and one pass in the raw full-run log. It is not a filtered retry and does not
substitute for the full run.

The legacy canonical `verify.log` remains byte-identical at
`354c0165ad261d7ec7a47b1cd2e7fe83db81fbf5ac10ce9ff0fce40ed0ccd861`
and retains the earlier 652/652 R13 technical run. It is historical evidence,
not the R28 authoritative output.

### 4.2 Build, release configuration, and object gates

`r28-build.log` records successful:

- debug `swift build --product AgentLoopApp`;
- exact release `--target AgentLoopCore`;
- exact release `--target AgentLoopTestSuite`.

The release Core object remained stable across the TestSuite target build.
`r28-source-gates.log` records the exact release/debug object paths and proves
the Core `idleClockForTesting` token is absent from release and present in
debug, while all eleven TestSuite seam tokens are absent from release and
present in debug. The only emitted build diagnostics are two existing
`weakServer` weak-mutability warnings and the recorded driver-flag warning;
none is an error or an A2 gate failure.

### 4.3 SQLite matrix, source, privacy, and final hashes

`r28-migration-matrix.log` contains two real lanes:

- SQLite 3.51.0 and SQLite 3.52.0;
- fresh, v7, v8-coding-ranch, v9-evercamp, v10-runtime-profiles,
  v11-cli-kinds, and v12-durable replay/FK/integrity/DDL/append-only gates;
- v12 snapshot and double replay;
- real-GRDB and literal lanes;
- expected negative append-only, CHECK, and missing-table sentinels retained
  as visible errors;
- two lane-level `matrix.result=pass` records and one terminal
  `p1_migration_matrix.result=pass`.

The owned matrix rewrite window was exactly 233 unchanged + the authorized
shell-test mismatch + one matrix-script mismatch. Mandatory restoration
returned the script to its entry bytes before later gates and END.

The source/privacy log records all ten same-log source-contract tests as exact
passes, A1b sentinels, A2 seam guards, literal hashes, the privacy scan, and
`git diff --check` as PASS. Current runtime hashes match the final hash log.
The legacy `impl-report.md` and `verify.log` remain unchanged historical R13
artifacts; the current R28 report is the separately named
`impl-report-r28.md`, SHA-256
`704a3a0bf1d32647989c7c3c4146ee88e3f83d6c0013353bee874bb0550974aa`.

### 4.4 Bundle and isolated preview

The provenance log closes source/build/bundle/executable identity through an
ad-hoc signed App with invocation-unique bundle identifier. It records exact
source/generated/copied resource equality, unsigned executable equality,
Info.plist environment, signature validation, post-sign executable identity,
and a zero-process LAUNCH_READY state.

The bootstrap log contains exactly B01–B06, with one matching PASS result and
nonce for every challenge. The cold-start log contains exactly C01–C09 with
the same property. The two lifecycles use distinct direct-child PIDs, the same
signed bundle and isolated state root, and each ends with child/job-table/global
process absence. The synthetic fixture passes foreign-key and integrity checks.

The cold screenshot evidence is a true 900×732 PNG, 134,228 bytes, SHA-256
`be6496b7351392940fc64f506190e3ec67df609af4845997c7f040c67feb17ab`.
Independent visual inspection shows `隔离恢复验证`, completed `保存原文`, and current
`正在恢复`; it does not display extracting, organizing, or confirmation as the
current phase. Screenshot and report staging paths are absent after their
no-clobber publication.

The preview evidence records zero observed normal-root opens, exact isolated
owned processes, no observed replacement process, no provider dispatch, and
clean exit. The claim is correctly limited to observed intervals; neither the
logs nor report assert an atomic proof over unobserved intervals. The
invocation-unique preference-domain onboarding write is disclosed and is not a
normal-data claim. `AgentLoop` and `AgentLoopApp` exact process names are absent
at review time.

### 4.5 Boundary and terminal END

`r28-clean-boundary.log` has one BEGIN, one BEGIN attestation, one authoritative
full-test attestation, LAUNCH_READY, matrix PASS/restoration, remaining
source/privacy/final-hash PASS, same-bundle preview PASS, and exactly one final
`status=END` / `result=PASS`. The final two lines are that END result. It has no
R28 `status=REJECTED_CONTAMINATED`, no same-boundary retry, one test-only delta,
and zero product/App/Package/permanent-script deltas. The final report and
screenshot hashes in the boundary match current files.

## 5. Historical chain is preserved, not washed green

Review01 remains immutable at
`5b6a171515404a644abcd05e3afc3840cb1dd4d84d7993f74af48de0692b4dd5`
with `CHANGES REQUIRED — 0 P0 / 1 P1`. The R13 installed-App incident still
records opens of the normal lock/DB/SHM/WAL and mutation remains UNKNOWN. The
later isolated retry does not erase that incident.

All later predecessor classifications remain immutable. In particular:

- R15 remains `REJECTED_CONTAMINATED` before later gates;
- R16 did not consume BEGIN, while R17 and R18 were not executed;
- R19 remains rejected after authoritative full 651/652;
- R20 remains rejected at the release Core build after its earlier partial
  technical successes;
- R23–R27 remain their recorded rejected boundaries and are not substituted
  into R28.

R27 specifically remains permanently `REJECTED_CONTAMINATED`: its ten runtime
files have the frozen sizes/hashes, its authoritative log remains 651/652 with
the sole 5.13908825-second measurement-boundary issue, later gates and END are
absent, and `impl-report-r27.md` plus `r27-preview-smoke.png` remain absent.
Neither R28 nor this review entered, enumerated, rewrote, cleaned, or reused the
two R27 roots. R28 is the later independent clean boundary; it does not convert
any predecessor into green evidence or claim that all A2 history had zero
normal-data access.

## 6. A2 completion and acceptance decision

The exact A2 completion gates are satisfied by current R28 evidence:

- the 41 durable-rumination names plus five deterministic-clock names are
  exact same-log green inside a single authoritative 652/652 run;
- the start/adoption/retry/cancel/terminal, captured-runtime/resolver,
  single-Supervisor/FIFO/lifecycle, legacy-repair, provider/usage/failure,
  phase/projection/mutation-fence, and lock-before-DB-open contracts retain
  their named dynamic and source gates;
- release/debug seam direction, debug App build, exact release targets, SQLite
  3.51/3.52 matrix, source/privacy, manifest/scope, bundle provenance, isolated
  preview, screenshot, process containment, and terminal END all pass;
- R-02 is closed for this slice by durable work ownership, adoption,
  terminal/retry/cancel behavior, recovering projection, and the corresponding
  exact tests; no empty/default-success fallback is used to hide failure;
- no unresolved P0/P1, red test, unknown failure, R28-scoped drift, or
  permission expansion remains.

Therefore this Review02 opens the independent A2 acceptance owner. It does not
write or pre-judge `acceptance.md`. Acceptance must still explicitly preserve
the R13 normal-data incident and UNKNOWN mutation, every rejected/not-executed
predecessor including R27, and the fact that only the R28 boundary supplies the
accepted clean execution evidence. Acceptance must also verify zero authority
expansion. A3 and all later slices remain closed until that separate acceptance
is `ACCEPTED`.

## 7. Findings

### P0

0.

### P1

0.

### P2-01 — Login-shell environment capture is cached but not single-flight

`LoginShellEnvironment.environment()` checks a lock-protected cache, performs
an async capture after a cache miss, then stores the result. Concurrent cold
callers can therefore perform duplicate login-shell captures before either
stores the cache. R28 correctly repairs only the test measurement boundary and
does not add an API, injection seam, timeout change, or product fallback.

This is a non-blocking performance/observability follow-up explicitly excluded
from R28 by the frozen plan. It does not invalidate the ShellTool command
deadline, the authoritative green run, A2 durable-rumination behavior, or the
clean execution boundary. If pursued, it requires its own bounded plan and
review rather than expansion of this slice.

## 8. Verdict and next gate

**APPROVED — 0 P0 / 0 P1 / 1 non-blocking P2.**

A2 may proceed to its independent acceptance owner. A2 is not yet Accepted,
and A3 remains closed pending that acceptance.
