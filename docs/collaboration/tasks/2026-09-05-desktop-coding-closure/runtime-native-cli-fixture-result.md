# Native CLI fixture repair — in progress, 2026-09-09

Current status: dependency-free C fixture implemented, independently reviewed, and focused11tests passed; default full remains RED with exactly3readiness failures. No full or App acceptance. Earlier blocking-reaper correction has independent real RED/GREEN evidence in runtime-forward-progress-result.md. Current work repairs controlled test construction without changing production cancellation semantics.

## Retained evidence before the C amendment

- Initial six-file native implementation build1 failed at two compile sites (sigaction name resolution and async Boolean autoclosure). No test ran; full output retained. Standard imported API typecheck succeeded; compile and checked-cleanup corrections independently reviewed.
- build2: exit0,52.068seconds; source manifest7b49e2ff4181435ea184da7b223342bfbdfa835bc135fd593fff1b081e5e9e32 unchanged. RunTests SHA920146618e45e1b8d419dee705f704f317fd57283144d70b109aa980c32ad4fb. Complete compiler output includes existing warnings; this was not a strict build.
- focused1: exit1,11tests/1suite/25.641seconds,5issues in4parents. CLI346/372 readiness, CLI347 readiness plus missingKILL,065 pre-registration terminal assertion. Passing: CLI152 acknowledged held-pipe,213 final unterminated line,548/549 environment dependency, cold065forced-error cleanup, A3 exact source boundary, blocking-operation forward progress. Resource cleanup observations for152/346/372/347 and both cold065 paths report no failures. No full retry followed this RED.
- Its three-second readiness clock includes async preparation/spawn/startup. CLI347 status143 establishes that its SIG_IGN had not successfully taken effect at TERM; no particular loader instruction, OS service or universal cause is established. The monolithic95MB staged RunTests fixture's Testing/app/runtime dependencies are source/artifact-proved overhead unrelated to these mechanics. Removing them is a discriminating implementation change, not grounds to alter deadlines.
- The065 assertion discarded child frames and collapsed all unexpected terminals into false, then short-circuited its resource comparison. Its old message does not prove cleanup was published early. The amendment exposes actual result and tests each invariant separately.
- Isolated SwiftPM construction proof: exit0,24.524seconds; automatically built C executable50304bytes/libSystemonly. Swift Driver linked only its own object and printed its marker. This permits ordinary RunTests dependency construction without fallback scripts or runtime compilation.

## C amendment verification

Strict C syntax check passed with no diagnostics. Ordinary `swift build --product RunTests` automatically built the fixture; exit0/39.858seconds. C executable39048bytes, SHA4d1fca7ceae6e026141917ad884569335e29251be96c4937dab8aded6defe0d2, links onlylibSystem; actual RunTests link excludes Cmain. Full source and integration review approved, including final exact pins, restored historical runner and206/102 accounting. Current309inputmanifest ea0160bd12c977a93fb645cb042af90f4d575efe7507d2a12c0a94fbadee18d1.

c-focused1:11tests/1suite/20.297seconds/exit0. CLI346/152/213/372/347 and injected environment paths all pass; both065pass, actualresourcecleanupchecked. Default full c-full1:1133tests/33suites/46.077seconds/exit1, exactly3parentissues CLI346/372/347 readiness. Allreportedresourcechecks pass,347nowrequiresKILL,065andthreehistoricalHALTtests pass. Intentional childfailure075 is contained by its passing parent and is not another parent issue. Source and both binaries unchanged in bothruns; defaultfull is not replaced by focusedGREEN.

Further source analysis identifies shared-executor contention paths but does not prove their causal involvement. Existing selfexec helper isolation is unsafe for these new separate-group descendants onoutertimeout and is not implemented. The independently approved single capture in runtime-cli-three-boundary-plan.md has completed; no second capture is authorized by that plan.

## Independently admitted scheduling-boundary evidence

boundary1 ran the exact pinned RunTests directly with child-only lifecycle logging: PID87977, 2026-09-09 01:07:40.026955+08 to 01:08:29.329537+08, 49.302721 wall seconds. Actual diagnostic outcome:1133tests/33suites/49.059seconds/exit1, five issues in four parents (346 readiness,372 readiness,347 readiness plus missingKILL, emergencyStopCancelsRunningBeforeWaitingForPlanner). This is not the ordinary c-full1 result and not acceptance. Complete log SHA24fc0954f866c2ebe932a50cbbbd5ee76634433b91b477a2e5aab743e21b2b6a; unchanged309-input source manifest and both binaries.

Read-only exact-PID/image/subsystem/category/time OSLog capture succeeded, SHA13d584a8ac084ceefaa3b01388aaf7653a9244fff47476344aa2db0c37014cdd, 2562 events and matching statistics. Independent forward_progress_review verified capture integrity, unique recorder/execution/PID/backend joins and all required stage occurrences from raw evidence. Backend diagnostic UUID is random, joined by the positive spawned PID, never assumed to equal execution UUID.

| Fixture | backend run entry after readiness wait start | configured readiness budget |
|---|---:|---:|
|346|4.676600875s|3s|
|372|9.211682375s|3s|
|347|6.197963s|3s|

Each readiness deadline had expired before backend preparation began in this invocation. This proves pre-entry scheduling delay, not which worker/test blocked, executor saturation, a named OS service, or a universal root cause. Environment acquisition and child startup are downstream of this already-expired budget. cliStdinFinished is only a finalizer join marker. There is no basis for an additional stdin/fixture patch, priority change, timeout increase or isolation success claim.

The reviewer identified that the original analysis script's capture admission did not automatically enforce unique queued/started/ready-end stages. Root added exact-owner uniqueness checks and reanalyzed only the retained bytes into boundary1.analysis-reviewed.json; no workload rerun. Actual stages were already unique in the admitted capture. Next bounded work is source investigation and a discriminating regression around an identified blocking path before scheduling/placement/budget changes.

All complete logs/statuses, before/after manifests, source preimages and code review deltas remain under the directory in runtime-native-cli-fixture-entry.json. Final repair/gates remain pending; durable evidence location is recorded in runtime-native-cli-evidence-manifest.json when copied.

## Scope and limitations

Preserve live environment default, reserved-key scrubbing, real staged bytes/hash/dev/inode, signature-call order, process-group/FD ownership, held-descendant acknowledgment, cancellation/join and unchanged deadlines. Controlled CLI fixtures receive private environments and registries; opt-in actual CLI408 is unchanged. Preserve historical206/102 boundaries and frozen manifest, register only exact current successors. No App installation/launch, real-camp operation, paid Provider, secrets, administrator tool, sampling, commit/push or release is part of this unit. Earlier pre-registration cancellation and structured timeout-race concerns are not declared fixed by fixture replacement.
