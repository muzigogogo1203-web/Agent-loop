# Independent local candidate packaging plan review

Date: 2026-09-05. Reviewer: responsibilities-separated Codex agent.

## Decision

Approved for implementation within the two-script boundary. No blocking plan findings. This approval covers the plan only, not script correctness after editing, successful packaging, signature validity, UI acceptance, or release authority.

Reviewed plan SHA-256: `199dceb7b1781387951121e23b6f69677a83bfe3743eb9d629f38eaa9263fa8f`.

## Evidence from the actual implementation

Read the complete current `scripts/run-app.sh` and `scripts/package-app.sh`, and the helper-resolution path in `Sources/AgentLoopApp/AppStore.swift:869`.

- `AppStore` supplies `Bundle.main/Contents/Helpers/AgentLoopBoardBridge` to `EngineExecutionEnvironmentV1`; the proposed bundled-helper correction matches the actual lookup, without inventing an external helper fallback.
- Development currently copies only the main executable and resources, deletes `.build/AgentLoop.app`, and signs only the outer bundle. Its two cold-launch guards and preview/state-directory arguments are present and must survive the implementation.
- Packaging currently builds both products and signs the helper before the outer App. It validates identifiers and ad-hoc signature attributes, verifies strict signatures, and compares the CodeResources helper CDHash and exact ad-hoc CDHash requirement to the signed helper. Those are appropriate concrete checks to retain and apply to development packaging.
- Packaging currently removes the whole `dist` directory, uses fixed output paths, accepts `$2` without checking value presence, performs the ad-hoc/notary incompatibility check after Swift builds, and invokes `hdiutil create -ov`. The plan addresses those specific behaviors.

Reviewed script hashes: development `5b34e5e98a0e91b4087e20525c3aba81e7955475865d2af70e6ae65736e7997b`; packaging `733dd7a06d91939b49509d91ce5ab263b8536e176b7a5b1a88e3b699e78e4142`.

## Assessment

The output policy is adequate for preserving existing artifacts: reject existing leaves including dangling symlinks, resolve the physical parent, atomically claim an absent leaf using plain `mkdir`, and use `mktemp -d` for defaults. Every artifact belongs under that newly claimed directory; failure leaves its exact path available for diagnosis. The absence checks must apply before building, and a failed leaf claim must propagate as an error. No reuse or recursive cleanup is authorized.

Argument validation includes missing/empty values and following-flag rejection, and signing/notary incompatibility is moved before Swift invocation. The planned negative-path fixtures directly exercise the relevant input failures. These checks do not substitute for actual package and signature validation.

Explicit builds for both products, an executable helper at the AppStore path, nested-first signing, strict verification, and comparison against the outer bundle's actual helper seal provide the required identity evidence. `--deep` verification is distinct from signing; the plan correctly forbids using it to sign nested code.

The plan is proportional: it edits two packaging scripts and preserves runtime source, bundle identities, version behavior, resources, state isolation, and cold-launch guards. Parent invocation with `SIGN_ID=-` and empty `NOTARY_PROFILE` keeps this work local. Retaining the existing optional Developer ID/notarization code path does not authorize invoking it during this task. Existing App/dist output is expressly preserved. Runtime process ownership stays with the parent.

## Verification status

This review performed only file reads and SHA-256 inspection, and wrote only this report. No builds, tests, app/process operations, user-data operations, script/source edits, or package/output changes occurred. Post-edit scoped review, syntax/argument validation, actual nested signature proof, isolated UI/resource acceptance, and source/artifact identity evidence remain pending the parent as specified in the plan.
