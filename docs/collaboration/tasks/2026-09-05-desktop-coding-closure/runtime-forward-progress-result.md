# Blocking-operation repair result — 2026-09-08

Production blocking-reaper execution is repaired with real RED/GREEN evidence and independent code review. Full runtime and product acceptance remain open. Current branch codex/runtime-forward-progress-20260908; HEAD02334ec8d21533be81d93d39191bc7d9b9c24f7f, no commits.

## Actual change and cause

The CLI reaper formerly performed blocking waitpid directly in Task.detached. A retained task now awaits a checked continuation whose named utility Thread executes the same waitpid body. Exact-child ownership, EINTR/status handling, diagnostic events and cancellation/join semantics remain unchanged. The bridge's real-pipe regression runs in one isolated strict-pool child, never a globally serialized suite. This follows the forward-progress constraint described in [Apple's Swift concurrency session](https://developer.apple.com/videos/play/wwdc2021/10254/).

RED child51677 completed a cancelled operation, real byte165 read/write, controller/sibling joins and both closes without error, failing solely because external rescue was needed. GREEN child54289 completed the identical test without rescue. Frozen test SHA976d95b79421f76dacc18e151966d18cd6c460f194d65c9bebdecf6ed08c74a6. This proves the production bridge's executor availability, not that this bug caused every old runtime failure or that deadlines are universally met.

## Verification

| Check | Result |
|---|---|
| Baseline build | exit0,69.97reported seconds |
| Focused RED | exit1,one expected child rescue assertion; parent1.139seconds |
| Corrected build | exit0,70.60reported seconds |
| Same focused GREEN | exit0,one test0.164seconds; child0.007seconds |
| Ordinary full swift run RunTests | exit1,1131tests/33suites/45.325seconds,8parentissues in6tests |
| Successor registration build | exit0,36.95reported seconds |
| A3 source boundary after registration | exit0,one test0.038seconds |

Full failures: A3 exact successor omission(2 issues, subsequently repaired/focused GREEN); CLI152 held-pipe watchdog; CLI372 checked-cancel readiness; CLI346 escalation readiness; CLI347 deliberate-failure fixture readiness plus missing KILL(2 issues);065 cold readiness. Intentional negative child failures from075 and Board leak proof were contained by passing parents and are not extra failures. Three previous HALT tests passed this workload; their existing oracle limits remain.

Independent final reviewer found no additional material production/test issues; it required exact two-file successor registration. Task3 added only that dated set, presence/disjointness checks and narrow exclusion. Original manifest SHA3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e,206/102 counts and prior assertions remain unchanged. Final Task3 delta caac0400484410f629134abf70af85050b110807e6b7df48ca100e3e99c541ae independently approved. No blind full rerun followed.

Build warnings remain in unchanged legacy tests and CLT configuration/linker; output is not pristine. No new warning identified in the four-path delta. Current307-input manifest be3f2e3ac48fb5397ddeb80474793d90aa84534ed32e2c9da08c6c1dd14d1f3b. Current RunTests binary d17325121a8daa701490042e5ff934b45ff7ce622fff14d6adf90ce7aa82a8a1. Each run's complete output/status/source/binary identities are retained in runtime-forward-progress-evidence/ and original raw directory from runtime-forward-progress-entry.json.

## Remaining work and scope

Next bounded plan runtime-native-cli-fixture-plan.md removes source-proved generated-script, user-login-environment and unacknowledged self-expiring-holder dependencies in mechanics fixtures without weakening real cleanup or permissions. Source registration is resolved; residual runtime failure is not. Pre-registration cancellation/completion timeout concerns recorded in runtime-repair-cli-cause.md are not claimed fixed by this unit. No App install/launch, real camp data, Provider, administrator operation, sampling, commit/push or release occurred.
