# Independent package script implementation review

Date: 2026-09-05. Reviewer: responsibilities-separated Codex agent.

## Decision

Approved for the bounded implementation with one nonblocking observability finding below. No blocking findings in output preservation, helper packaging/signature logic, or the preserved runtime contract. Actual package and UI acceptance remain pending parent verification.

## Finding

- **P3 — Render filesystem paths literally.** `scripts/run-app.sh:95,197` and `scripts/package-app.sh:110,299-301` print output paths with zsh `print`/`echo` without raw mode. A valid requested directory containing literal backslash escape sequences can therefore be displayed differently from its actual path, weakening the plan's exact-path diagnostic contract. The filesystem operations themselves are quoted and target the proper directory. Use `print -r --` for path-bearing stdout and `print -r -u2 --` for path-bearing errors. This was identified statically; no script execution was performed. Ordinary paths used by the parent are unaffected.

## Reviewed inputs and identity

Read the implementation report `.superpowers/sdd/package-plan/task-1-report.md`, the previously reviewed plan and plan review, and both complete current scripts. Independently generated and examined both full diffs against `package-before/scripts/`, rather than relying on report claims or the saved diff alone.

| Script | Preimage SHA-256 | Reviewed implementation SHA-256 |
| --- | --- | --- |
| `scripts/run-app.sh` | `5b34e5e98a0e91b4087e20525c3aba81e7955475865d2af70e6ae65736e7997b` | `3540c7f1222ea8dca3c6d8f3d4c30a42f33ce0839e3d78f7a49ebcca83a59174` |
| `scripts/package-app.sh` | `733dd7a06d91939b49509d91ce5ab263b8536e176b7a5b1a88e3b699e78e4142` | `605092b111dc7601d4ed3116d4c429aa6d2113cf4bc586c6da07aa9381006ad1` |

## Scope and logic conclusions

Both scripts reject missing/empty/following-option values before building. Packaging also rejects missing signing identity and ad-hoc/notary incompatibility before claiming output or building. Requested output rejects existing files, directories and dangling symlinks, requires an existing directory parent, resolves that parent physically, rechecks the resulting leaf, and uses plain `mkdir` so a concurrent creator cannot be reused. Default parents reject symlinks/non-directories and new leaves use `mktemp -d`. Failures leave claimed output intact. Neither script contains the previous recursive deletion.

The development App now resides under its claimed directory and explicitly builds/copies both products. Its helper location matches AppStore's fixed `Contents/Helpers/AgentLoopBoardBridge` lookup. The helper is made executable, signed first using `com.muzi.agentloop.board-bridge`, and the outer App is then signed with the preserved `com.muzi.agentloop.dev` identity. Strict helper/outer verification, ad-hoc attribute checks, nonempty CDHashes, and exact CodeResources helper CDHash/requirement comparisons match the existing package proof. No helper execution, external helper fallback, or `--deep` signing was introduced.

The complete diffs preserve Info.plist identity/URL/resource policy, debug/release build configuration, preview/dark/state arguments, both development cold-launch guards, package version/build-number defaults, icon generation, and the existing package signature checks. Main App, ZIP, and DMG destinations derive from the one newly claimed output directory. ZIP/DMG absence checks reject existing destinations, and `hdiutil -ov` was removed. Existing optional notarization still re-creates its own same-invocation ZIP after stapling; that preserved branch is outside this task's authorized invocation with `SIGN_ID=-` and empty `NOTARY_PROFILE`, and does not touch prior output directories.

Replacing the final `codesign -dv | head` with the already validated captured signature is a narrow observability adjustment, avoiding a new signing command or pipeline failure after successful archive production. No unrelated Swift source or historical inventory was changed by these script diffs.

## Validation boundary

Only file reads, diffs, and hash inspection were performed. This reviewer wrote only this report. No scripts, syntax checks, tests, builds, signing/archive tools, App/process operations, or data/output mutation were executed. Parent syntax and stubbed argument checks are separate pending evidence, and cannot prove actual nested seals. Development/release packaging, source and artifact identities, resource checks, and isolated UI acceptance remain later gates. This report does not claim full task acceptance or authorize release.

## Fix1 follow-up — 2026-09-06

Approved. The P3 literal-path rendering finding is closed by static review. Path-bearing errors now use `print -r -u2 --`; output-directory, development App and package App/ZIP/DMG announcements use `print -r --`. The package's final interpolations also use equivalent explicit variable braces. No new findings.

Compared the latest full diffs with the frozen package preimages and the prior reviewed implementation. Additionally reversed only these raw-print/path-interpolation edits in an in-memory text stream and hashed that stream: both recovered hashes exactly match the previously reviewed script hashes above. This establishes that the follow-up adds only the intended path-rendering edits, without altering output claiming, argument validation, build/signature/resource logic, archives, or launch behavior.

Fix1 reviewed script hashes:

- `scripts/run-app.sh`: `34ff641b68379e1978367cd2c5c9890638c5913627942858767efe56b475428c`.
- `scripts/package-app.sh`: `5e3950b7c50a18c8f8389cdab14eb847caa9d8632c8474cd44b3a7948fc35439`.

No build, test, target-script execution, signing, app, process, or source modification was performed. Parent literal-path red/green evidence and the stubbed argument checks remain separate verification; actual package acceptance is still a later gate.
