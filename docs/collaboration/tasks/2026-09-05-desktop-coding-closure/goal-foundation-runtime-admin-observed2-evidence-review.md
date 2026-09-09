# Observed2 independent evidence, integrity and privacy review

Date: 2026-09-08. Reviewed observation: 2026-09-07. Reviewer did not implement or execute the diagnostic.

**Verdict: the identified CLI347 text stack is usable as bounded diagnostic evidence; overall capture privacy/scope acceptance is WITHHELD. Runtime remains RED and A1/A2 acceptance is not granted.** The subsequently authorized exact-file deletion is verified separately; it does not retroactively validate the extra capture.

## Scope and frozen inputs

I read the repository instructions, the complete original capture plan, attempt2 plan and independent entry review, then checked the fixed helper/launcher behavior against actual retained evidence. The applicable gate is attempt2 plan Task 2, particularly lines 34–37, together with original capture-plan lines 17–24. The entry review approved one execution, explicitly reserving actual scope/content acceptance.

- Authoritative checkout: `/Users/muzi/Agent-loop`, branch `codex/desktop-coding-closure-20260905`, HEAD `02334ec8d21533be81d93d39191bc7d9b9c24f7f`, unchanged at review end.
- TD: `/Users/muzi/Agent-loop/docs/collaboration/tasks/2026-09-05-desktop-coding-closure`.
- RD: `/private/var/folders/_9/2080h8b50s94v1ympg0mm8pr0000gn/T/agentloop-admin-goal-foundation-runtime-admin-observed2-20260907-34931-1glsvj9`, resolved from the retained observed2 location. Its 17 named files were explicitly included; no traversal into other diagnostic buffers was used.
- CD: `/private/var/folders/_9/2080h8b50s94v1ympg0mm8pr0000gn/T/agentloop-exact-diagnostic-cleanup-20260908-20260908-21449-1eyaaan`, the later deletion's explicitly identified four evidence files.
- Independent checksum verification covered 43 unique files before/after review. All matched; aggregate SHA-256 over sorted canonical `SHA  absolute-path\n` records: `ed0b83bf22ba400061c3433449ccee4085f5a8da7857aeea448ea215fbe10597`.
- Both original source manifests and an independently reconstructed current 305-file manifest are `a462d6b57546a019564499a9ce8a485de7053f4ae3a0fd3d54d870678474e97f`; no input hash or file-set drift was found.
- Root's concurrently edited result/checkpoint/progress/blocked/implementation reports were excluded from frozen inputs. Later cleanup evidence was frozen on arrival and rechecked separately.
- The unexpected `.buf` file was never read, decoded, copied or content-hashed by this reviewer. Its path is intentionally absent from the checksum inventory.

## Findings

### P1 — the tool wrote an unreviewed buffer outside the agreed evidence boundary

Evidence: `RD/sample-stderr.log:3–4`; `TD/goal-foundation-runtime-admin-observed2-extra-file-metadata.json:3–13`; fixed argv at `TD/goal-foundation-runtime-admin-capture.c:319–322`.

The retained stderr explicitly reports a stackshot written to `/var/tmp/spindump-stuck-stackshot.2026-09-07-01:11:53.35445.buf`, despite the approved `-noFile -noBinary` command. Metadata records a regular root:wheel file, mode 0644 (decimal 420), 2,639,968 bytes, inode 345640665, modification time 2026-09-07 01:11:53.697060619 +0800. This is a material departure from the capture's expected file boundary.

The single-target stack subsection in the text report and the `-onlyTarget` argv do not establish the scope of this automatic buffer. Its contents and process scope remain unknown. There is no evidence to assert either that unrelated process content was captured or that it was absent. Neither exit 0 nor byte-complete text transport clears this finding. No secrets/content leakage is asserted without evidence.

Disposition: withhold overall privacy/scope acceptance and any reuse of this sampling path. Root subsequently received explicit user authorization, “允许，仅删除这个文件,” and completed the bounded deletion described below. The retention issue is closed for this exact path; the historical capture-scope uncertainty remains.

### P2 — “one target stack” must not be described as “every report byte is target-only”

Evidence: `RD/sample-stdout.log:23–43`, `:87–334`, `:339–455`.

The complete text contains host hardware/state and locale metadata, a kernel-extension inventory, and a WindowServer frame-rate appendix in addition to the one target process stack. These sections are observable report content, even though there is only one `Process:` stack section. Restrict causal claims to the target stack at lines 52–84 and the separately admitted process evidence. Do not claim that the entire report contains only temporary-test information, or infer the automatic buffer's scope from this text. No rewrite, deletion or sanitization of the retained original text was performed.

P0: none established. No other material integrity failure was found in this scoped review.

## What the evidence establishes

### Entry, identity and command

`TD/goal-foundation-runtime-admin-launch2-process.jsonl:1–4` preserves the exact observed2 invocation, pre/post pins, source count and actual outer status. It pins the approved entry review SHA `7369e519ef0f8a5a648c49692f90a229a6c13a0b27ee8907ea07f86427aacf67`; the unchanged C/helper, corrected Ruby/AppleScript, observer, RunTests and spindump match the recorded before/after values. The retained source and fixed `execve` call support one exact command:

`/usr/sbin/spindump 35430 1 100 -onlyTarget -timeline -timelimit 10 -noFile -noBinary`

There is no fresh sampling invocation in this review. Raw transport contains exactly one capture start, one spindump start, one spindump result and one helper result. The fixed observed2 location remains consumed; a generic “继续” cannot authorize another authentication/workload/sample.

| Role | PID / birth generation | Identity evidence |
| --- | --- | --- |
| Ordinary collector | 34931 / 1788714629.604216 | UID 501, PPID/PGID 34926, `/usr/bin/ruby`; `RD/identity.log:1` |
| osascript | 34939 / 1788714629.759095 | UID 501, PPID 34931, PGID 34926; identical before/readiness identities at `RD/identity.log:2,4` |
| Selector | 34972 / 1788714636.161205 | UID 501, direct PPID 34939, PGID 34926, fixed helper image; `RD/identity.log:3`, `RD/process.log:7` |
| Workload / RunTests | 34975 / 1788714636.236924 | UID 501, PPID 34931, PGID 34926; initially swift, subsequently pinned RunTests image checked by observer/selector/capture; `RD/process.log:10`, `RD/selector.ndjson:3` |
| Fixed spindump target | 35430 / 1788714703.497530 | UID/RUID 501, PPID 34975, PGID 35430, `/bin/sh`, CLI347 `c-347-201D/workspace`; `RD/observer.log:648`, `RD/apple.log:1` |
| Owned spindump | 35445 / 1788714704.063607 | UID/RUID 0, PPID 35442, PGID 27522, `pin_valid=1`; `RD/apple.log:2` |

The selector's two valid quiet samples are 390.341 ms apart, with stationary counters and zero stdout pipe bytes (`RD/selector.ndjson:1–2`). The final capture guard records target age 565,931 μs, below the 2-second bound. The target's generation matches between native observer, numeric selector ticket and privileged capture start. The complete text identifies sh PID 35430, UID 501, parent PID 34975 and one thread. The report's extra `unique pid 334190` is not substituted for a libproc birth-generation check. The acknowledged final PID-check-to-kernel-use race is not claimed to be atomic.

Authentication was requested at 01:10:29.758406 +0800, validated readiness at 01:10:36.232259, and workload start at 01:10:36.234975 (`RD/process.log:6–8`). The actual selector is the direct osascript child, so observed1's shell-bridge failure did not recur.

### Byte integrity, timing and cleanup

I independently parsed every nonempty JSON frame and strictly decoded all 20 base64 stream frames. The reconstructed channels exactly equal the retained files:

| Channel | Bytes | SHA-256 |
| --- | ---: | --- |
| stdout | 61,875 | `b6540ae83a78af53ba4a399d3b4461d685fbc5751ca0a16b6d5fc3b2ec8f51ce` |
| stderr | 328 | `cc89a6fabcca9aad3721d19c4a916b0554319472b5caf6d38127254bcb56e94b` |

The capture contains 164 tool-wait events and no tool-signal or cleanup-incomplete event. `RD/apple.log:186–190` records waitpid returning the exact owned spindump PID, exit 0, signal 0, `io_ok=1`, `bytes_complete=1`, `deadline_expired=0`, and helper exit 0. Approximately 14.545 seconds elapsed from spindump-start record to result (14.547 seconds from capture-start record), inside the 15-second helper bound. The stderr phrase “over a minute” is the tool's diagnostic message, not an independently established elapsed duration.

The report sampling interval is 01:11:44.098–01:11:45.099 +0800, ten samples at 100 ms. All ten samples show the target thread in `AppleSystemPolicy::procNotifyExecComplete → evaluateScript → waitForEvaluation → ASPEvaluationManager::waitOnEvaluation → lck_mtx_sleep` (`RD/sample-stdout.log:67–79`). This establishes that generation's waiting location during that interval. It does not establish why the policy evaluation was slow, how long the full wait lasted, a universal cause of earlier failures, or a product fix.

The target's post-capture libproc check returns ESRCH, with `post_available=0, post_same=0` (`RD/apple.log:187–188`). That is honest unavailability after exit, not a verified matching live post-generation. Same-run evidence independently records target progress, a 6-byte stdout-pipe observation, parent waitpid returning 35430, and reaping: `RD/observer.log:1118–1123,1147–1149`; `RD/events-admitted.ndjson:1358–1359,1396`.

The native observer covers exactly the admitted fixture generations 346/35431, 347/35430 and 372/35424, with 26/23/22 valid samples respectively. It ends with `missing_targets=0`, `no_valid_samples=0` and status 0; this does not claim continuous coverage. Its broader nonprivileged metadata scope is the unchanged original observer scope, not additional privileged stack captures. All 2,062 admitted OSLog events independently match parent PID 34975, UID 501, pinned RunTests image, subsystem/category and the invocation interval. The OSLog query itself is restricted to that PID/subsystem/category (`RD/process.log:17–19`).

No diagnostic `tool_signal` or `osascript_signal` occurred. This does not mean no signal occurred in the workload: parent OSLog records the product's ordinary SIGCONT for target 35430 at lines 1083/1089. These are distinct from diagnostic process-control authority. osascript, observer and OSLog exit 0; selector absence is explicitly observed with ESRCH (`RD/process.log:13–20`, `RD/identity.log:6`). The later retained post-identity checks show all ten named process PIDs absent at 01:14:46, supplementing rather than replacing same-run wait/reap evidence.

### Test outcome and causal boundary

The actual default workload remains **exit 1, no terminating signal**: 1,130 tests in 33 suites, 92.866 seconds, five parent issues (`RD/test.log:2548`; `RD/process.log:11–12,21–22`). The outer collector preserves exit 1 (`TD/goal-foundation-runtime-admin-launch2-process.jsonl:3`). Diagnostic transport success does not override it.

The five parent issues are two assertions in `rateLimitTriggersGlobalCooldownThenRecovers`, one each in `emergencyStopCancelsRunningBeforeWaitingForPlanner` and `emergencyStopHaltsDispatchAndResumeContinues`, and the held-pipe watchdog/cleanup error in `cliProcessBackendFinishesWithinGraceWhenGrandchildHoldsPipe` (`RD/test.log:1501,1626,1645,1724,2284`). Nested child-test results are not added to the parent count.

Crucially, sampled CLI347 is `cliProcessBackendFixtureFailureStillJoinsRealCleanup`, which passed after 67.105 seconds; fixture cleanup explicitly maps it to PID 35430 and reports zero resource failures (`RD/test.log:2331–2333`). CLI346 is `cliProcessBackendCancellationEscalatesAfterGrace`, separately passed at lines 2338–2340. This successful CLI347 occurrence cannot by itself prove the cause of an earlier CLI347 ready failure or the five other parent issues. Root-cause and runtime-green gates remain unmet.

## Later exact-file deletion

This is a separate, newly authorized deletion-only action on 2026-09-08, not reuse of the consumed diagnostic authorization. I inspected its retained request and actual results without running the command or touching the target file.

`TD/goal-foundation-runtime-admin-observed2-extra-file-cleanup-location.json:2–8` retains a fixed inline Ruby command that requires administrator UID, resolves the parent to root:wheel mode-01777 `/private/var/tmp`, validates a regular non-symlink root:wheel mode-0644 target with exact device/inode/size/mtime, and performs one exact `File.unlink`. It contains no content-reading, decoding, copying or hashing call, no glob and no recursive deletion. It confirms ENOENT afterward.

`CD/stdout.log:1` reports `count=1`, matched inode 345640665 and size 2,639,968; stderr is empty. `TD/goal-foundation-runtime-admin-observed2-extra-file-cleanup-result.json:2–11` records osascript PID 21454 exit 0, no signal, and a separate post-check with `present=false, ENOENT` at 22:05:49 +0800. The old metadata file correctly remains historical evidence of the earlier preserved state. Deletion does not prove the former buffer's scope or remove the P1 history.

## Accepted evidence, unmet gates and safe follow-up

Accepted: reviewed-entry continuity, unchanged source305/pins, corrected selector ancestry, one identified privileged target-stack capture, exact transport bytes/statuses, bounded tool reap, same-run target joins, preserved RED outcome, and separately authorized deletion of the exact extra file.

Withheld: overall capture privacy/scope acceptance; an all-report-bytes-target-only assertion; an atomic post-generation assertion; historical/universal root-cause closure; runtime GREEN, A1/A2/App/package acceptance.

Remaining work may use the already retained target stack, parent OSLog and source for bounded causal analysis and accurate checkpoint updates. Any proposal to reuse spindump needs a new concrete review of automatic buffers and report metadata, plus new explicit sampling authority; the existing command's `-noFile` behavior cannot be assumed sufficient. Deletion authority is consumed and does not authorize content access, another authentication/workload/sample, security-setting changes or other cleanup. No additional live action is required to finish this evidence review.

Reviewer actions were limited to read-only repository/evidence inspection, checksum verification and this report. No diagnostic helper, product test, compilation, authentication, sample, test-process control, Provider/camp-data action, product edit or git mutation was performed by this reviewer.

## Frozen checksum inventory

All rows below matched before/after. TD/RD/CD are the absolute directories defined above. The unexpected buffer itself is excluded.

| Input/evidence file | Bytes | SHA-256 |
| --- | ---: | --- |
| `/private/tmp/agentloop-admin-final-compile-20260907-20814-ic98bc/admin-capture` | 71136 | `ce85c0c1d709898ef2ff36ce12a9f73d13a440f5d49678dac1ebac64316542f5` |
| `/private/tmp/agentloop-child-observer-20260906-94075-n85bj9/observer` | 53368 | `10461c3041954e75b89a3e7d55d57818cc608935ca82bd313aff8e614ae49365` |
| `RD/apple-stderr.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `RD/apple.log` | 97437 | `533890ef58dfca8733e9552490e9210d4bcb325ea193196e2d3e37470d2534d2` |
| `RD/auth-ready` | 66 | `dcc7d3599a5bcee3fad3f5cb222a3887578659b9641bc102bfae5b848219af2f` |
| `RD/events-admitted.ndjson` | 2114657 | `cb5c21ddbd28706643e56af5b650749b0921abd13f8815d9e3f9f0051a8f5dec` |
| `RD/events-stderr.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `RD/events.log` | 2143553 | `1ca4db56e817665e77e1748227b6eb0ed860599bcf5d3dcae6ccbd2d042fd4f2` |
| `RD/identity.log` | 2202 | `fe7cf61615427932c72fa6987e759f216656a6e48423c8d895c20f754046152e` |
| `RD/observer-stderr.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `RD/observer.log` | 192318 | `fc2fba19c4a64d6ef149cc13a36c18430a9df17b8c1aed2d9b3e0de3b32f47be` |
| `RD/pins.json` | 1293 | `815f9e653f0e998b45ef443cfc5ebf4453f5b15ef6c6ce3279845c2f35fa03fa` |
| `RD/process.log` | 4920 | `7dad5653222ceb738686c5bfe4a2c6900aa57519b06df7bfd56ce0cde9668450` |
| `RD/sample-stderr.log` | 328 | `cc89a6fabcca9aad3721d19c4a916b0554319472b5caf6d38127254bcb56e94b` |
| `RD/sample-stdout.log` | 61875 | `b6540ae83a78af53ba4a399d3b4461d685fbc5751ca0a16b6d5fc3b2ec8f51ce` |
| `RD/selector.ndjson` | 640 | `1a53e722506ff22ba1296bad320cd0eab5ea30fb9a0a4d566ba5d754acfe3d2b` |
| `RD/source-after.sha256` | 36414 | `a462d6b57546a019564499a9ce8a485de7053f4ae3a0fd3d54d870678474e97f` |
| `RD/source.sha256` | 36414 | `a462d6b57546a019564499a9ce8a485de7053f4ae3a0fd3d54d870678474e97f` |
| `RD/test.log` | 199740 | `eab1a8e32ed85991b16661d58eac8c579a582a7a3a15f0410c5c58b48dabf4ea` |
| `CD/request.json` | 3172 | `05daadd271ec95be94de571da2706042f85b76c071d29f14b23eca8be180eb37` |
| `CD/result.json` | 281 | `c24fb481fbdb38f2ee915765b1842c7462cade1eb87c0906b39c1ed8608edce0` |
| `CD/stderr.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `CD/stdout.log` | 158 | `b4bfd925acb345945a815f3f696ed47347cb6a3c3d9acd42276c2c2ff0abbaf5` |
| `/Users/muzi/Agent-loop/.build/arm64-apple-macosx/debug/RunTests` | 94765872 | `5f7c24dd9f76616e11ccd553066e06f4f5683ac11520089bb27758183aea5386` |
| `AGENTS.md` | 5461 | `ef69cb1a148ae60a47c20d46ed95b8ce38c2e5d7ca55e3e3cfa2ec3f7f807f40` |
| `TD/goal-foundation-runtime-admin-attempt2-implementation-review.md` | 6869 | `7369e519ef0f8a5a648c49692f90a229a6c13a0b27ee8907ea07f86427aacf67` |
| `TD/goal-foundation-runtime-admin-attempt2-implementation.diff` | 14418 | `f3e1067dbb0e2fb3b1206f50745ddb1521c7d460fb801ae8500ab5e1700d84ea` |
| `TD/goal-foundation-runtime-admin-attempt2-plan.md` | 6076 | `f70eaa311afa3da889c76a1ac4d5a23c4c0a5e45ae917730c9c170be64548165` |
| `TD/goal-foundation-runtime-admin-capture-plan.md` | 12248 | `0f76aee99ad99de6b6c5522376aa4e1c6926b0ea945d5d8758dd45fb18442e2f` |
| `TD/goal-foundation-runtime-admin-capture-run.rb` | 23029 | `78388665f655783ff0af408f3818b696555496240716874821aa0c7cd9c7d854` |
| `TD/goal-foundation-runtime-admin-capture.applescript` | 2181 | `e71c166d01e19fc0da074dd94aa9279d2743e60af7e773fb32c4a9ffcd7f083d` |
| `TD/goal-foundation-runtime-admin-capture.c` | 22391 | `8d1a9a1a7a3f6be783844cef2590da9d73777a08bf7cfea77d0e3dee5f04fabd` |
| `TD/goal-foundation-runtime-admin-launch2-process.jsonl` | 3583 | `1a5afbb4fa1d9d3990e084dd0b0b86978deacc581deebbc8497051a518d6f66f` |
| `TD/goal-foundation-runtime-admin-launch2-stderr.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `TD/goal-foundation-runtime-admin-launch2-stdout.log` | 216 | `0eddb6898026dd6f4d2495ab96d776ad0fa6ea4f1b397c7a6dd5b88df5625e9b` |
| `TD/goal-foundation-runtime-admin-observed2-extra-file-cleanup-location.json` | 3172 | `05daadd271ec95be94de571da2706042f85b76c071d29f14b23eca8be180eb37` |
| `TD/goal-foundation-runtime-admin-observed2-extra-file-cleanup-result.json` | 281 | `c24fb481fbdb38f2ee915765b1842c7462cade1eb87c0906b39c1ed8608edce0` |
| `TD/goal-foundation-runtime-admin-observed2-extra-file-metadata.json` | 433 | `324cef07ea870505c0d76d9658239fd4159ac38821fdf3f01f91a1e3f3ad7691` |
| `TD/goal-foundation-runtime-admin-observed2-location.json` | 177 | `e4c2c71e60313159f9013c360995c75db854073f13fefe4cd9b885dffa33671d` |
| `TD/goal-foundation-runtime-admin-observed2-post-identity.json` | 3413 | `13fb9082c6f4c3caa4e54ac195d5af0e06068c01b0749c68fe559712a8a7f5b8` |
| `TD/goal-foundation-runtime-child-observer-run.rb` | 9854 | `74f5a90ac5b94c5631bb9b8f1a65584b3583fe0255cf3aedf12ed7b740e69417` |
| `TD/goal-foundation-runtime-child-observer.c` | 31425 | `027c041baca6fa1f34f9ebae77d7da8eec3e5aea583e9bb665ccfda4a9db0bcf` |
| `/usr/sbin/spindump` | 3600352 | `ae75637b77d3262dde83b201893338d8b4fb01b7be11895533267f60d07c7625` |
