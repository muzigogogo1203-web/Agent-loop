# Bounded child-startup sample

One diagnostic pair run, not a repeated full gate: `AGENTLOOP_RUNTIME_DIAGNOSTICS=1 swift run RunTests --filter cliProcessBackendCancellation`, parent 35242, 2026-09-06 02:16:13–02:16:17. `runtime-cli-child-probe.log` records 2 tests / 2.217 s / exit 0, build 0.23 s. All nine previously frozen source hashes still match. No source change or manual process signal was made.

The sampler selected only fresh direct children of that actual parent whose observed command contained the exact c-346/c-372 staged executable path. `runtime-cli-child-probe-samples/identity.log` retains PID/PPID/PGID/start/state/command. Exactly two one-second samples were taken, once each; no retry until failure or success.

- 346: PID/PGID 35315, recorder 2CE94736-F2CD-478B-A944-47FDFB0553A2, Core 9F85782B-3B3F-4B99-990C-FDA05C800BDD.
- 372: PID/PGID 35316, recorder A65E58C7-3170-411E-AEE5-7058EDA4582F, Core 4321CFB6-036A-4AE1-98FE-A12E9F354869.

Both samples began at 02:16:15.286, after captured successful fixture SIGCONT at about 02:16:15.163. Each reports 797 observations entirely at `_dyld_start + 0`, a 96 KiB physical footprint and no available binary-image description. This captures startup before the shell command's normal stack appears; it does not identify the kernel wait, page-fault reason, scheduling policy or cause of the earlier full-run failures.

First stdout bytes appear later: 372 at 02:16:16.682, 346 at 02:16:17.103. Both reach their unchanged readiness checks, then perform their specified cancellation and checked cleanup with zero resource-observation failures. The retained OSLog has 151 lifecycle events plus metadata. Sampling can perturb timing, and this successful probe must not erase the full-run readiness failures or justify changing deadlines, child wrappers or production readers.

Raw samples remain at `/tmp/agentloop-cli-child-samples.HTDVJG` and are copied verbatim into this task directory. Raw run/output metadata are `/tmp/agentloop-cli-child-probe.1LdujC` and `/tmp/agentloop-cli-child-probe-process.CFr1oz`; full event capture is `runtime-cli-child-probe-events.ndjson`.

After this probe, a resource snapshot showed VM pressure 2, swap used 18302.88 MiB and only 1.2 GiB available disk. No further Swift builds or runtime repetitions are planned until the external resource constraint is relieved. This is a safety/verification blocker, not an assertion that all four full-run issues are environmental.
