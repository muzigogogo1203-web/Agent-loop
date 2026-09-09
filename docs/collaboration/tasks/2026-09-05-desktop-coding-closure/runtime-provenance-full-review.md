# Current default full runtime gate — independent evidence review

2026-09-06. **Current default full runtime gate: GREEN.** The retained unfiltered run completed **1092 tests in 31 suites, 57.278 s, exit 0**. All parent tests passed; the two raw issue records are fully enclosed intentional negative child tests with verified failing statuses and passing parent assertions. The runtime prerequisite for the already reviewed A1 foundation slice is satisfied on these frozen sources. This does not mean A1 is implemented or accepted, the desktop product flow is complete, or the App has been packaged, launched, or accepted by the user.

Read the complete 2463-line authoritative stdout/stderr log in bounded chunks, its entire process record (all source checks plus metadata), resources, entry decision, source manifests, child evidence blocks, and relevant approved A1 entry documents. Parsed lifecycle provenance without taking over the separate halt timing analysis. Subsequently read the complete separately supplied strict App build log and process record. No source edits, compiler/test runs, process manipulation, OSLog queries, App/database operations, or subagents were performed. This report is the sole file write.

## Frozen run and artifact provenance

- Exact parent PID **61158**, **2026-09-06 05:16:44–05:17:42 PDT**; process record identifies default `swift run RunTests` with no filter, job-count override, or suite-serialization argument. Entry record specifies `AGENTLOOP_RUNTIME_DIAGNOSTICS=1`; the retained lifecycle stream confirms diagnostics were active.
- RunTests build completed in **0.14 s**; recorded executable SHA-256 is identical before/after: `e5382f90258f9d538613246872bcea1100798ef5e96a4eb26906e78e663a31b0`.
- Independently hashed `runtime-provenance-full.log`: **`7705c0199a5f126605e500c8df2d65c1c0c6e5ce5ae505852bbb85fde48262a9`**. It contains 2463 lines and is byte-for-byte identical to current `verify.log`.
- `runtime-provenance-full-all-source.sha256` contains **301** source/script/package entries; `runtime-cli-provenance-source.sha256` contains **12** targeted entries. Independent verification found no current mismatches in either manifest. Both halves of the full process record contain **313** OK checks with exactly the combined manifest's path multiplicities. This includes reviewed production `08f56a49c3293d246d4d57e2bfc600ecc5e9461002940916b0c7acf6a1e8719e` and unchanged covering test `f7089c930283b0277721f3642a31491fef458006a5b20266b7119f5422c681f3`.
- Resource evidence retains approximately **29.0 → 27.1 GiB** available, VM pressure **1**, and swap used **3911.75 MiB** before/after, with intermediate samples also well above the 6 GiB stop threshold. This supports completion under the recorded operating conditions, not a causal explanation for old failures.

The old `runtime-combined-full.log` remains intact and ends **1091 tests / 31 suites / 63.440 s / 4 issues**. Its independently computed hash is `8ebd486da4fd1366eff835e99ffcbb5a4de77d74fd68ae8d7e04d79cc07fca75`. It is a historical failed run; this current gate is established by new reviewed sources and new complete evidence, not reinterpretation of that old run.

## Every raw child issue is accounted for

All five BEGIN/PHASE EVIDENCE/END blocks were fully read and parsed, with matching PID/mode/raw status and **`read-errors=[]`** at every END:

| Child PID | Mode | Raw status | Evidence / interpretation |
| ---: | --- | ---: | --- |
| 61172 | expected-failure | 256 | Deliberate `deliberateChildFailure`; exactly one child issue; parent `p1f1d075FDChildFailureReachesParent` passes. |
| 61208 | drain | 0 | Child test passes; phase evidence `live-drain`, `surviving-run`, `surviving-abort`; outer CLI help-capability test passes. |
| 61256 | blocked-handler | 0 | Baseline 4 / final 4 / delta 0 over 20 iterations; child and outer blocked-handler test pass. |
| 61273 | accept-loop | 0 | Baseline 4 / final 4 / delta 0 over 100 iterations; child and outer accept-loop test pass. |
| 61306 | blocked-handler-leak-proof | 256 | Deliberate delta 32 (4 → 36), correctly fails the `< 10` assertion; parent `boardFDIsolatedLeakStillFailsParent` passes. |

Independent block-aware parsing found exactly **two** raw `recorded an issue` lines, both inside the above expected negative blocks; zero parent issue lines and zero parent failed lines remain outside the blocks. It also counted exactly **1092 parent test pass lines and 31 parent suite pass lines**, matching the final parent summary. The successful gate is not inferred by discarding arbitrary failures: each excluded child issue has an explicit negative-test purpose, observed nonzero raw status, complete captured output, and a passing parent test.

## Previously relevant paths pass in the complete run

- **069:** all 21 scenario markers appear; both shared model and CLI joins reach their end markers. The actual line `P1F1D069_RESULT=stubborn-direct value=process_group_still_alive` is present, its unchanged assertion passes, and the full 069 matrix passes in **6.404 s**. This carries the independently reviewed focused repair result into the default full run without loosening its expected category or skipping later scenarios.
- **065 ordinary cleanup:** fixture `4374FA93-52C7-4C09-8AD1-F4CD1B163E83`, execution ending 0065, exact child/group **61305**; test passes in **25.861 s**.
- **065 forced-error cleanup:** fixture `B566586D-4332-4C71-A57E-5E8AFC94F5F8`, execution ending 0865, exact child/group **61328**; `forcedFailure.afterReady` is retained as the intended primary error, and the test passes in **5.621 s**.
- Both 065 fixtures record successful exact-group signals, status 137, stdout/stderr EOF, child reaping, stream join/exit, absent process and group (ESRCH), no remaining waitable child (ECHILD), absent socket (ENOENT), zero active registry count, and `cleanup-certified=true retained-root=none`. Every recorded certificate observation passes.
- **CLI execution 0346:** `cliProcessBackendCancellationEscalatesAfterGrace` passes in **32.788 s**, with cleanup child 61304 and resource-observation failures=0. **CLI execution 0372:** `cliProcessBackendCancellationReturnsCheckedEvidence` passes in **31.952 s**, cleanup child 61303, failures=0. These are this run's identities; prior-run PIDs are not reused.
- **Halt ordering test:** `emergencyStopCancelsRunningBeforeWaitingForPlanner` passes in **22.374 s**, correlated by this run's explicit orchestrator/execution/provider/gate mapping. That whole-test duration includes setup; it is not the cancellation latency. A passing polling-helper result is not proof that cancellation happened strictly within one second, nor that the old 863.437 ms pre-persistence delay's root cause has been repaired. The separate halt analysis owns exact interval interpretation.

The two new REDs remain historical facts: PID 58119's stubborn assertion failed without printing its actual category; PID 58651 localized a typed-cleanup-to-CancellationError mismatch at the shared CLI consumer join. The current successful exact category and joins support the bounded provenance repair. They do not retroactively supply missing observations from historical PID 50925.

## Lifecycle capture provenance

The retained NDJSON parses to **4080 events plus metadata `{count:4080, finished:1}`**. All records use the same RunTests image path and the closed stage/UUID/monotonic-integer/value format; no format failure was found. Recorded timestamps range **05:16:46.239684–05:17:40.054692 PDT**, inside the full-run window.

Events are attributed to parent 61158 (**2057**), drain child 61208 (**34**), blocked-handler child 61256 (**290**), accept-loop child 61273 (**1400**), and negative leak-proof child 61306 (**299**). These are within the parent's exact six-PID capture allowlist comprising the parent and all five child blocks. Expected-failure child 61172 contributes no lifecycle event; this is not a missing runtime result, because its deliberate failure and raw exit are fully captured in stdout/stderr. No unrelated PID appears. Metadata completion and full child-output capture support correlation; they do not assert that OSLog can never drop an individual event. No new invocation IDs or unsafe attribution were invented.

## Separate strict build and A1 readiness

The subsequent, separately retained `runtime-provenance-strict-app.log` also completes successfully: exact PID **61834**, **05:20:39–05:21:17 PDT**, command **`swift build --product AgentLoopApp -Xswiftc -warnings-as-errors`**, **34.83 s**, exit **0**. Its process record has all **301** source checks before and after. This is current strict App compilation evidence, kept distinct from runtime tests and actual App execution. It does not establish resource packaging, nested-helper availability, signature correctness, isolated launch, UI behavior, or user acceptance.

The A1 entry table requires a reviewed plan and green runtime gate. The scoped output-policy review explicitly approved current plan/brief hashes; independently rehashing `goal-flow-plan.md`, `goal-foundation-plan.md`, and the A1 brief matches its three approved values (`a6166c3f…`, `c2f0a874…`, `f476f42d…`). Its outstanding runtime precondition is now satisfied. Root can prepare fresh preimages/ownership and enter that bounded Core-persistence slice under its existing authority. This review does not approve future A1 changes in advance, relax its tests-first/diff-review gates, or permit A2/Provider/real-user actions beyond their own reviewed scope.

**Disposition:** accept this frozen default full run as the current runtime baseline and remove the runtime-red entry blocker. Retain all historical failures and their attribution limits. Product workflow completion, implementation-stage reviews, package and isolated App verification, delivery candidate evidence, and user acceptance remain separate outstanding gates; no commit, merge, push or release is authorized here.
