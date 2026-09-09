# Local candidate packaging repair

Status: proposed, requires independent review before implementation. Parent owns all builds and app runs. This is a local acceptance candidate, not release authority.

## Evidence and constraints

`AppStore.swift` resolves the bridge exclusively at `Bundle.main/Contents/Helpers/AgentLoopBoardBridge`. Current `scripts/run-app.sh` copies only the main executable and resource bundle and signs only the outer bundle. Its development App therefore does not contain the required helper. `scripts/package-app.sh` does include and seal the helper correctly, but begins by recursively removing all of `dist`, which contains older user artifacts. Neither existing artifact may be overwritten or deleted for this task.

No public release, notarization, upload, Developer ID/Keychain access, production App termination, or real data access. Parent invocation explicitly uses `SIGN_ID=-` and empty `NOTARY_PROFILE`. Preserve the existing package helper signing/identity/seal checks, main identifiers, URLs, version defaults, resource-copy policy and cold-launch guard. Never use `codesign --deep` to sign nested code; sign nested helper first, outer App second, verify both.

### Task 1: Complete helper packaging and preserve output history

Modify only `scripts/run-app.sh` and `scripts/package-app.sh`. Do not change Swift source, app runtime behavior, identities or accepted product contracts.

Both scripts gain optional `--output-dir <path>` with missing/empty argument errors before any build. The requested directory must not already exist, including a dangling symlink; its parent must already be a directory. Normalize via the physical parent plus basename and claim the leaf using plain `mkdir` before any build. A concurrent creator makes the command fail rather than overwrite it. Never delete or reuse existing files. The scripts leave a partially produced directory on failure and print its exact path for diagnosis; they do not silently clean it up.

Without `--output-dir`, use `mktemp -d` to allocate a fresh, identifiable run directory: `.build/AgentLoopDev.XXXXXX` for development and `dist/CodingRanchCandidate.XXXXXX` for packaging. The known `.build` or `dist` parent may be created with `mkdir -p` after verifying it is not a symlink/non-directory. These directories are output containers only, never recursive removal targets. Do not modify the old `.build/AgentLoop.app` or old files directly inside `dist`. All produced App/ZIP/DMG paths use the one selected new output directory, and are printed to stdout so parent can verify and open exactly that result. Preserve existing filename conventions inside that directory. Update script usage/header examples accordingly; do not claim the old fixed path was updated.

Development explicitly builds `--product AgentLoopApp` and `--product AgentLoopBoardBridge` with the existing build flags. Create `Contents/Helpers`, copy the helper, check it executable, sign it with `com.muzi.agentloop.board-bridge` using ad-hoc signing, then sign the outer development App with its existing `com.muzi.agentloop.dev` identity. Verify helper and outer App strictly, verify the outer CodeResources helper CDHash and its exact ad-hoc requirement against the freshly signed helper, using the already working package script checks as the source. Preserve resource placement, preview environment, isolated-state behavior and the second cold-launch guard. Do not execute the helper directly as a smoke test or add shell fallbacks to locate it outside the bundle.

The package script selects/claims output and validates arguments and incompatible signing/notary choices before invoking Swift. Replace its `rm -rf dist` and fixed `dist/` product paths with the selected fresh directory, retaining all existing signing checks and archive creation. Do not use `hdiutil -ov` to override an existing artifact; its new output must be absent. Optional argument values must not accidentally consume a following flag as a value. This task does not alter automatic tag/build-number behavior or invent a semantic release version.

## Parent verification

1. Capture both script preimages and the old App/dist artifact identities before edits. Syntax-check with `zsh -n` and inspect scoped diff. No build during source edits elsewhere.
2. For each script, exercise missing `--output-dir` value, existing regular directory, existing symlink and absent parent using unique temporary fixtures. All must fail before any Swift build/launch and preserve sentinels. Do not run a valid launch command until candidate UI prerequisites are ready. These argument checks are not proof of actual signing.
3. After source/tests/UI gates, execute the development script with a unique isolated state directory and `--preview --output-dir` an exact absent path. Capture full stdout/stderr, exact App PID/path, cold-launch behavior, nested helper signature, outer CodeResources and resource bundle. Use process identity before stopping only that owned preview process; no broad `pkill`.
4. Build the local release candidate into an exact absent output directory. Capture source manifest (including dirty and newly created Sources, package scripts, Package.swift and Package.resolved), its aggregate hash, helper/main executable hashes, resource manifest, Info.plist, codesign checks and App/ZIP/DMG hashes beside the candidate evidence in the task directory. The manifest's hash is the source identity; unchanged HEAD alone is insufficient. Do not insert it into an already signed App.
5. Verify the actual package contains the helper and resources and that nested seals match. Perform isolated App UI/clean-machine resource checks from the exact candidate; restoring temporarily moved build resources is mandatory on every exit. Archive existence or process survival is not UI/functional acceptance. Keep fixtures and real-provider/user acceptance distinct.
6. Record output layout in the final acceptance instructions and current task `impl-report.md`. The legacy skill's fixed `.build/AgentLoop.app` example is historical after this change; resolve the App path from this invocation's output instead. Do not run its broad process-kill example.

No source inventory successor is needed: this task adds no Swift source. Existing historical frozen source lists must remain unchanged.
