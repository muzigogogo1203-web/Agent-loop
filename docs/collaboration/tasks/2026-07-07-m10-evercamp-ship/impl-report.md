# M10 Evercamp Core + Logic Implementation Report

## Scope Implemented

- Core migration `v9-evercamp` with `mission_template` and `schedule`.
- Schedule records, CRUD, template validation, fire-time validation helpers, CAS same-slot fire claim, `schedule_fired` / `schedule_missed` event helpers.
- `ScheduleMath` pure functions for daily/weekly next fire, previous fire, misfire detection, and same-slot dedupe with explicit `Calendar` + `TimeZone`.
- `EventKind.scheduleFired` and `EventKind.scheduleMissed`.
- Guide broadcast convenience via `appendGuideBroadcast(campId:text:)`, no LLM path.
- `MissionScheduler` in App layer using `NSBackgroundActivityScheduler`, startup misfire flag/callback, fire-time validation, CAS dedupe, `Orchestrator.startMission`, `schedule_fired` event, and guide broadcast.
- Scheduled mission notification glue for closeout/failure/budget-exhausted, guarded for non-bundle/bare-binary runs.
- AppDelegate menu-bar residency logic: status item creation, close-window residency behavior via UserDefaults flag, exposed methods/actions, notification click routing.
- AppStore logic methods for saving templates/schedules, schedule enable authorization request, scheduler refresh, and scheduled outcome notification/broadcast.

## Files Changed

- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/EventKind.swift`
- `Sources/AgentLoopCore/Database/KnowledgeStore.swift`
- `Sources/AgentLoopCore/Database/ScheduleStore.swift`
- `Sources/AgentLoopCore/Kernel/ScheduleMath.swift`
- `Sources/AgentLoopApp/AgentLoopApp.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/MissionScheduler.swift`
- `Sources/AgentLoopApp/ScheduledMissionNotifications.swift`
- `Sources/AgentLoopTestSuite/ScheduleTests.swift`
- `docs/collaboration/tasks/2026-07-07-m10-evercamp-ship/verify.log`

## Verification

- `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift build --disable-sandbox --target AgentLoopCore` passed.
- `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift build --disable-sandbox --target AgentLoopTestSuite` passed.
- `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift build --disable-sandbox --product AgentLoopApp` passed.
- Required command run: `CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests`.
  - First run completed in console output with `376` tests and `1` issue.
  - The single issue was `keychainRoundTrip()` throwing `KeychainError(status: -50)`, the known sandbox limitation called out in the task.
  - New schedule tests passed in that run.

## Deviations / Notes

- No SwiftUI schedule/settings UI was implemented; `Views/*.swift` were left untouched per user instruction.
- No Sparkle or packaging script work was implemented; this round was limited to Core + logic layer.
- `verify.log` caveat: the first `tee` run produced the final test summary in console but the tool session did not close cleanly. A second pure-redirection run was attempted to regenerate a complete `verify.log`, but that RunTests process stopped producing output under the sandbox before completion; process inspection/termination was denied by sandbox (`sysctl(KERN_PROC): Operation not permitted`). Current `verify.log` is therefore not a complete final-run log even though the first required command did complete in console with only the known Keychain `-50` issue.
