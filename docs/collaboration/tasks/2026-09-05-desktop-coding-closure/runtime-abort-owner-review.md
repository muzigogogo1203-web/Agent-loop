# Abort owner lifetime: bounded source and RED/GREEN evidence

2026-09-09. Root records responsibilities-separated `forward_progress_review` decisions. This unit is process-free; it does not clear the real abort465 integration or desktop acceptance gate.

## Plan and source entry

The canonical `runtime-abort-containment-plan.md` was independently approved for Task 1 gate/client/guard/owner preparation and Task 2 unconditional cleanup. Concrete identity and containment remain Task 3. A fourth actual started-reader case was independently added before staging. Legitimate first-abort and cancellation-registration races are checked as explicit typed outcomes, not arbitrary failures.

Fresh entry `runtime-abort-owner-entry.json`, 10:15:52 +08: source 309 manifest `33da3befb75aa9a9a2e25d64ead9984748712f56d419d5b785e715e852e167f9`; sole allowed EEC preimage `dd0a9a6c6df7831996f3b8cbe452fe10cd381c2a6624150f94d0d98327031cad`. Root verified both at application. Applied patch `544af0160be932c68e9e54598a9a65836bfa2223e6a4ef334f36daf23055a3f8`, yielding EEC `d70337ab70ade70c007baf676d818f2b62a70ff2bd394a064651194731cf58d0`. Exact preimage-relative diff `df036ceac184d0158fa35ff2525b1784e745e8f75ea0d8a56beccf2d1439ceda` independently approved before any workload.

Source review checked positive guard start, monotonic deadline, unlocked external actions, abort wakeups for native and async waiters, checked descriptor lifetime, one-shot epilogue, and unconditional no-child rescue before all assertions. Original controlled-wait/provenance test bodies are frozen. The real old abort block only receives two exhaustive `.aborted` switch branches; it is not moved, duplicated or wired yet. No production source, timing budget, signal order or wait-status decision changes.

## RED

Raw base: `/var/folders/_9/2080h8b50s94v1ympg0mm8pr0000gn/T/agentloop-abort-owner-20260909-20260909-65719-3iq67q`.

- `red-build1`: PID 68551, 10:27:11–10:27:42 +08, exit 0, 30.781777 s wall / Swift 27.48 s. Complete log `72116c2fc6fb5db39f44b43e565e42f898ec725cd9c7bb85c3da496b409403fa`; existing CLT/linker and two pre-existing EEC warnings retained. Ordinary build, not strict App.
- `red-focused1`: PID 68914, 10:28:00–10:28:03, exit 1, 2.735581 s wall. Canonical four-test filter: 4 tests / 1 suite / 0.128 s / exactly 4 issues, each solely the absent owner epilogue assertion. Before each failure its positive summary proves gate wakeup, waiter/guard joins, checked applicable shutdown/close, and exact body/result requirements. The fourth reader returned successful EOF. Complete log `c45cfd36c92e48590162d06eb82084bd514cca0f47102c1be2845e6183736fd4`.
- Both runs kept source 309 manifest `c38436744e684e01b250e5d38197a581f68246225f5554949b618f51ccb2a803`; focused RunTests `2ec263ab9cfaa0828eff3eb48716da39b6e5c1f35490a1652b544b2faba3f5e7` and C helper `4d1fca7ceae6e026141917ad884569335e29251be96c4937dab8aded6defe0d2` unchanged. Root awaited exact owned PIDs and read complete outputs.

Independent reviewer verified hashes, joins, resource summaries and exact intended failures, then authorized only Task 2's unconditional owner epilogue.

## GREEN and independent acceptance

Only the owner decision changed: captured body Result determines `bodySucceeded`, then the owner always awaits its one-shot epilogue. EEC `40209eb1af8e23e5100ce337370613fca9525bf0145850d1b8fc137e05bc7175`; entry-relative delta `c55c777fb77038edf11675d7107aa1d780179bf42a3c8125785df9c5dd3239ad`. Reverse substitution reconstructs the entire accepted RED source, so all four tests, resource helpers and other bytes stayed frozen. Independent exact source review preceded the following workloads.

- `green-build1`: PID 69369, 10:30:40–10:31:06 +08, exit 0, 25.856374 s wall / Swift 25.38 s. Complete log `e09fd5c195faafb994e0476538e76f9f309a1de54fd9b94fc8c86787952d8b27`; pre-existing warnings unchanged.
- `green-focused1`: PID 69509, 10:31:39–10:31:43, exit 0, 3.200010 s wall. Identical four-test filter passed: 4 tests / 1 suite / 0.045 s, all original resource oracles and owner claims. Complete log `38c2fa594566692a8333cb4a23c37b1e87a82717e0cff366872999ce56a466fb`.
- `green-regression1`: PID 69564, 10:32:02–10:32:03, exit 0, 0.733007 s wall. Existing controlled-wait and cleanup-provenance regressions passed: 2 tests / 1 suite / 0.153 s. Strict self-exec child 69574 returned raw status 0, exact evidence and bytes/EOF, no rescue and no read errors. Provenance retained the exact no-child authority failure. Complete log `c87f13ebeb71691ae0df0eebcab5eac830bc252252674b38e3e67ce698f36532`.
- All three runs kept source 309 manifest `01f8015fae38219c62a4cbdd94351f904fce98a7b6dde8f40962178dad02b8db`. Tests used unchanged RunTests `e9ef00ed951379f88acf09e5a2c2f1a2eb3f580e289b1617692c5e60715b99cc` and C helper `4d1fca7ceae6e026141917ad884569335e29251be96c4937dab8aded6defe0d2`. Root joined exact PIDs and read every complete log; `git diff --check` passed.

Responsibilities-separated `forward_progress_review` accepted Tasks 1–2 for bounded spec, source quality and RED→GREEN evidence. Durable archive `runtime-abort-owner-evidence/` contains 26 verified files, manifest `92f0189c046ad85c3f246f6d8eb84b4424c0be8aa4aaac1c62ffd2c010c1dcf6`. No real abort465, integration/full or App acceptance is implied.

## Next bounded entry

Task 3 patch preparation only was approved after GREEN. Fresh `runtime-abort-contained-entry.json` captured 10:33:14 +08 at the same 309 manifest and EEC pin. The one-test split, identity ownership and containment-before-assertion invariants are fixed. No source application or real process execution follows until exact review.

Root's future diagnostic wrapper `.superpowers/sdd/runtime-abort-containment-plan/capture-abort.rb`, SHA `d208bfb9fbde1cb2ca4e5b5ba4cf44845142211a6a5daffb627de96a8496796c`, has preparation review only. It binds accepted build/CWD/source/runner/helper/UUID, protects the spawned-child join, persists joined status before post-inspection, and separately records scoped OSLog collection. One selected test, complete output, exact PID/time/Mach-O UUID and valid nonempty export still require actual post-run admission. No privileged sampling or historical PID operation is used.
