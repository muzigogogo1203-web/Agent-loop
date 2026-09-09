# A1b isolated preview observation

Date: 2026-07-27  
Final result: PASS

## Accepted Review01 retry

- Command:
  `AGENTLOOP_STATE_DIR=<fresh-absolute-temp-root> scripts/run-app.sh --preview`
- State root:
  `/private/tmp/agentloop-a1b-review01-preview.sy7T0L`
- Process:
  PID `51258`,
  `/Users/muzi/Agent-loop/.build/AgentLoop.app/Contents/MacOS/AgentLoop`
- Required environment:
  `AGENTLOOP_UI_PREVIEW=1` and the exact state root above were present.
- Isolated domain files:
  `.agentloop.lock`, `agentloop.sqlite`, `agentloop.sqlite-wal`, and
  `agentloop.sqlite-shm` were all below the fresh state root. The process had
  zero open files below
  `/Users/muzi/Library/Application Support/AgentLoop`.
- Isolated AppStore preferences:
  current-source inspection plus the passing source/order regression
  `uiPreviewUsesProcessLocalDefaultsBeforeBootstrapAndReload` establish that
  preview creates one `ProcessLocalPreviewUserDefaults` before its first
  defaults access and injects that same locked, process-local store into
  `ProfileScopedDefaults`, fresh-profile bootstrap, resolver, scheduler,
  reload, catalog, persistence, and OAuth state paths. Normal launch still
  selects `.standard`; the accepted live launch supplies the matching preview
  environment and process evidence. The regression is not a runtime probe of
  the normal domain. No normal UserDefaults content was inspected, printed,
  exported, snapshotted, or diffed as part of this evidence.
- Visible state:
  the accessible window title was `Coding 牧场`; the sidebar showed
  `我的营地`, `基础牛，空闲`, and `发起放牛…`. The no-model first-run panel
  visibly explained `还没有连接模型` and allowed material to be saved later;
  no blocking credential, Keychain, or error prompt was present.
- Responsiveness:
  a live process sample showed the main thread waiting in the normal
  `NSApplication` event loop and contained no `SecItemCopyMatching` frame.
- Screenshot:
  `preview-smoke.png` is a true 1190 × 732 RGB PNG with SHA-256
  `90ae69421b6a0be472e5ba22afacb6279b16e2838df75ee13d285e384e3648c8`.
  The Computer Use capture initially returned JPEG bytes; the same captured
  frame was re-encoded and independently verified as PNG before acceptance.
- Exit:
  Computer Use delivered Command-Q to the running preview. PID `51258`
  exited, a shell-only process check found no remaining AgentLoop process, and
  no post-quit UI state call was made.

## Preserved rejected runs and fixes

The original A1b preview failure and retry remain in `../preview.log`:

1. PID `16652` exposed an OAuth Keychain presence lookup blocking the main
   thread in `SecItemCopyMatching`; it was rejected and cleaned up.
2. PID `20227` verified the Keychain short-circuit and the earlier isolated
   state-root behavior, but Review01 later proved that its AppStore bootstrap
   still wrote the normal shared defaults domain.

The first Review01 repair run used fresh root
`/private/tmp/agentloop-a1b-review01-preview.CDsP2O` and preview PID `50856`.
Its AppStore/defaults isolation, UI, screenshot, and Command-Q exit all passed.
It is nevertheless rejected because an attempted post-quit Computer Use state
probe automatically launched a new, non-preview PID `51012`. That process had
neither preview environment variable, was immediately terminated by exact PID,
and no defaults or Keychain content was inspected. Since a normal AppStore
initialization can access its normal preference domain, this automation mistake
is retained as an explicit deviation and is not used as green evidence.

The accepted retry above started only after no AgentLoop process remained. It
used another fresh state root and avoided every post-quit UI probe.

## Evidence boundary

The live checks establish isolated database/artifact/report/lock placement and
the source-backed, process-local AppStore/bootstrap defaults path. The preview
did not click preference-changing UI, inspect normal preference contents, read
credential values, or claim that unrelated pre-existing view-level
`@AppStorage` reads were rewritten by this bounded A1b repair.

Full launch, process, environment, file, format, rejected-run, repair, and exit
evidence is in `../preview.log`.
