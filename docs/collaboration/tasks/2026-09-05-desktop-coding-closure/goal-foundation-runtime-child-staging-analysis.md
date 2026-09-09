# CLI child staging and startup: read-only findings

Scope: current construction of CLI fixtures 346/347/372 and 065, comparison with other local shell fixtures, and retained actual-child samples. No source modifications, probes, tests, compiler runs, process signals, or xattr/security changes were performed. This is not a root-cause finding or a passing gate.

## What is actually staged

**The affected fixtures do not copy or re-sign the `/bin/sh` Mach-O executable. They create a new script that invokes the existing system shell.**

| Fixture | Construction and actual launch | Relevant differences |
| --- | --- | --- |
| CLI 346/347/372 | `CliBackendTests.swift:917–945`: new `staged-UUID/executable`; atomically write `#!/bin/sh\nexec /bin/sh "$@"\n`; chmod 0500; lstat and SHA256 the script. `:977` launches that staged script, not `sourcePath`. | 346/347 argv first installs an ignore-TERM trap, then prints ready; 372 prints ready then execs `/bin/sleep 30` (`:486`, `:611`, `:549`). |
| CLI 152/213 | Same `CliMechanicsHarness.request` and exact `/bin/sh` branch (`:273`, `:341`). | Different scripts/assertions: inherited pipe/parent exit and final line without newline. Staging is not unique to the failing readiness tests. |
| 065 | `ExecutionEngineConformanceTests.swift:646–661`: fresh `/tmp/al65-…/controlled-shell`, identical two-line wrapper, atomic write, chmod 0500, lstat/hash. Request command is the wrapper (`:753`). | Cold argv installs trap then creates a ready file, not a stdout frame (`:8471–8477`, also `:8667`). Initial cold-ready evidence is independent of the CLI stdout consumer. |
| Other 075 shell cases | `CliBackendTests.swift:2841–2872` atomically writes each supplied shebang script, chmod 0500, captures actual script stat/hash; examples at `:4586`, `:4721`, `:4746`, `:4759`, `:4783`, `:4798`. | Most execute their script body directly under the shebang interpreter rather than the extra `exec /bin/sh "$@"` wrapper. Help-probe backend also requests START_SUSPENDED (`CliEngineAdapter.swift:1504–1512`) then SIGCONT (`:1563`). Not an identical readiness test. |
| CardRunner shell fixtures | `CardRunnerTests.swift:2167–2184`, `:2949–2957`, `:3033–3051`: fresh shebang scripts, atomic write and chmod 0500. | Different bodies and assertions; their inspector also uses negative-group signal targets (`:1317–1322`). |

The `copyItem` at `CliBackendTests.swift:932–935` belongs only to the **non-`/bin/sh`** branch. It is not executed by 346/347/372/152/213. Each affected fixture does create a fresh script filesystem object, and records its actual device/inode; that does not mean it changes the system `/bin/sh` inode or Mach-O code signature. The wrapper bytes are identical between these cases, while path/inode authority is specific to each created fixture.

No construction path above runs codesign, strips/adds xattrs, or re-signs the system executable. No retained xattr inventory establishes which attributes the filesystem actually assigned; absence of explicit xattr manipulation must not be reported as a measured empty-xattr state.

## App validation versus OS execution

CLI uses `CliMechanicsSignatureRevalidator` (`CliBackendTests.swift:785–835`); 065 uses `P1F1D065SignatureRevalidator` (`ExecutionEngineConformanceTests.swift:393–448`). Both validate canonical fixture authority, require exact expected authority, and record order; the latter can inject the prescribed failure. These are not calls to the live code-signature verifier. The authority's designated requirement/team/CDHash fields are fixture metadata, not newly generated signatures on the script.

The real backend still checks the staged file's bytes/device/inode (`CliProcessBackend.swift:1721–1755`) using its descriptor-based identity read (`:1757` onward). Live production's separate signature revalidator calls `revalidateStagedCodeSignature` (`:14–28`), but these fixtures inject the test revalidators instead. In observed1, all launch validation and spawn/resume stages completed promptly, so an app-side prelaunch signature check is not where the measured multi-second interval lies.

The actual spawn flags include SETPGROUP and START_SUSPENDED (`CliProcessBackend.swift:925–938`), and the kernel is asked to execute a shebang script. The retained samples independently show the resulting image as `/bin/sh`. If the wrapper progresses, its explicit `exec /bin/sh "$@"` then replaces that shell image before the test command runs. Thus these fixtures involve interpreter startup and an additional exec boundary; they do not directly run the final `-c` body in a copied native shell image.

This path can involve ordinary OS executable/interpreter loading and policy checks, but the source and logs do **not** establish a particular security validation request, quarantine decision, cache miss, AMFI/syspolicyd wait, or mandatory revalidation penalty for the fresh script. “A fresh inode necessarily caused security scanning” is not supported.

## What the retained child samples prove

Read in full: `runtime-cli-child-probe-analysis.md`, `runtime-cli-child-probe-samples/identity.log`, `child-35315.sample.txt`, and `child-35316.sample.txt`.

- The sampled PIDs were actual direct children of RunTests 35242: PID/PGID 35315 (346) and 35316 (372), matched to their unique staged paths. Identity command lines were `/bin/sh <staged-wrapper> -c …`, not a copy of `/bin/sh` under the temporary filename. Observed `ps` state text was `SN`; that is not a measured Mach task/thread suspend count.
- Both actual child reports name image path `/bin/sh`, ARM64, 96 KiB footprint, and 797 observations of their main thread exclusively at `_dyld_start + 0`; binary image descriptions are unavailable. These are child stacks, not RunTests/Swift reader stacks.
- The prior bounded sample run ultimately passed both fixtures; stdout arrived later. It is not a sampled failure from observed1. The sample reports' wall-clock offset strings and the analysis display differ; no new causal ordering here is inferred by comparing those wall strings. The prior capture's PID joins and stage records support its own order; observed1 has separate monotonic evidence.

The narrow inference is that at the sampled instants the child's normal shell execution stack had not become visible and its PC repeatedly remained at the loader entry. This makes an explanation confined to **only** a late parent stdout consumer incomplete for that sampled interval: the child itself shows startup nonprogress. It does not establish why the child was there. It could reflect initial suspended/resume state, scheduling/nonexecution, or an early loader/kernel condition; no kernel wait channel, thread run state/suspend count, page-fault attribution, or security service correlation was captured. `_dyld_start + 0` is not proof that dyld was actively spending CPU doing validation, nor that cooperative-reader starvation caused the child PC to stay there.

Conversely, parent cooperative task delays are separately real in observed1 (reader queue→entry about 380/207/51 ms). They may coexist with child-startup delay. After entry, the read loop's individual read/EAGAIN/sleep-wakeup events are uninstrumented, so entry alone cannot exclude reader-service starvation. The retained child sample cannot measure that parent service, and the parent first-byte timestamp cannot measure the child's write timestamp.

## Competing hypotheses and best next measurement

1. **Initial START_SUSPENDED/resume behavior:** current group SIGCONT calls return success, but no child task/thread resume-state observation exists. The same target type also passes in 372 and prior 346; neither universal correctness nor universal failure follows.
2. **Child interpreter/exec startup:** the fresh script and extra exec are real, and the old PC sample places the child before ordinary shell work. Loader/security/OS scheduling causes within that interval remain alternatives, not findings. Do not “fix” this by replacing the wrapper and treating a different executable path as the original test.
3. **Parent reader service or wider scheduling pressure:** delayed reader admission is measured; continued service after entry is not. This can delay first bytes, but alone does not explain a sampled child's loader-entry PC or the separate 065 ready-file observation. A shared resource/scheduling cause could affect both; current evidence does not identify one.

**Best next measurement:** in a separately authorized bounded run with the exact current wrapper and workload, capture the identity-checked owned child's task/thread state (including available run/suspend state and PC/stack) immediately after the *first* successful SIGCONT and once in the no-ready window, correlated to monotonic Core stages. Prefer evidence that can distinguish “still initially suspended” from “running/blocked before shell body”; another undifferentiated `_dyld_start + 0` stack alone would not resolve that distinction. If OS permissions prevent that state read, report the capability gap rather than interpreting absence as resumed.

A predeclared paired initial-SIGCONT leader/group target comparison may then isolate that variable; keep staging, argv, flags, deadline and group TERM/KILL cleanup unchanged and do not add an automatic second resume. If both children are shown resumed/runnable yet no output arrives, the next approved measurement should record bounded numeric parent read outcomes and actual sleep/wakeup gaps, with owned-child loader/kernel wait evidence if available. Security-service correlation is justified only if that observation points there. No unbounded rerun, timeout increase, reader rewrite, xattr removal, signing change or production signal change is justified by this report.
