# Runtime diagnostics source-boundary successor plan

Date: 2026-09-05. Planning only. I read the complete `spec.md`, `runtime-diagnostics-plan.md`, the exact `a3Revision02EntryBoundaryRemainsByteExact` body and its adjacent successor helpers, and the instrumented-run failure. No source, test, historical manifest, build, app, Provider, credential, or data operation occurred. This document is the only file written.

Reviewed spec SHA-256: `58a6563c92e73b4a05dfbb3fe34e3df6c81da4043e7764a91e6ee577a43e1390`. Reviewed runtime-diagnostics plan SHA-256: `1c2be06ef1033f8e799fb3f9a676ffefcf17959c2851de0e1438ad3aa242ae47`.

## Diagnosis and invariant

The full instrumented run is already the red evidence for this narrow update. `runtime-observed.log:179-180` shows only the recursive complement assertions failing: `enumerated.count` is 103 instead of 102 and the exact-array equality contains one additional path, `Sources/AgentLoopCore/Observability/RuntimeLifecycleDiagnostics.swift`. The test reports two issues because count and equality independently expose the same one-path delta. This is consistent with the approved diagnostics plan, which explicitly created that logger source.

The A3 historical authority remains immutable and currently verifies at its original values:

- `revision02-entry-source-manifest.sha256` stays byte-for-byte unchanged with SHA-256 `3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e` and exactly 206 sorted, unique entries.
- `liveEntries` remains the same 102-entry historical complement, and every one of those entries continues through its existing per-file hash check.
- The original A3, A4, P1-B, P1-C, P1-D, P1-E, P1-F1 and R9-F partitions, their counts/intersections, both frozen-entry hashes, and all existing assertions remain unchanged.
- The approved logger is a dated successor source outside that historical manifest. It must be accounted for by exact path, not retroactively added to a historical stage allowlist or manifest.

## Smallest implementation

### Task 1: Admit the approved diagnostic successor

Modify only `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`. Do not modify the logger, any original manifest/allowlist, or any production source for this boundary repair.

### 1. Add one explicit dated successor set

Immediately after the existing `r9fProviderCompletionHandleFiles` declaration, add:

```swift
// The 2026-09-05 desktop Coding closure added one opt-in runtime lifecycle
// logger for the approved bounded diagnosis. Keep it separate from every
// byte-frozen historical P1 allowlist and manifest.
private let desktopCodingClosureRuntimeDiagnosticsSuccessorFiles: Set<String> = [
    "Sources/AgentLoopCore/Observability/RuntimeLifecycleDiagnostics.swift",
]
```

This is deliberately a singleton file allowlist. Do not use an `Observability/` prefix test, directory exclusion, glob, suffix rule, or a generic “new Sources” exemption. Do not add the possible later runtime-repair helper here in advance; if evidence selects a new helper source, that separately reviewed repair receives its own exact successor set and assertions.

### 2. Prove the successor is new, exact, and present

Inside `a3Revision02EntryBoundaryRemainsByteExact`, immediately after the existing R9-F manifest-intersection assertions and before `liveEntries` is built, add:

```swift
#expect(
    desktopCodingClosureRuntimeDiagnosticsSuccessorFiles.count == 1
)
#expect(
    manifestPaths.intersection(
        desktopCodingClosureRuntimeDiagnosticsSuccessorFiles
    ).isEmpty
)
for path in desktopCodingClosureRuntimeDiagnosticsSuccessorFiles {
    try a3RequireRegularNonSymlink(
        root.appendingPathComponent(path)
    )
}
```

The empty intersection prevents reclassifying an original 206-entry manifest path as a new successor. The regular/non-symlink check prevents an allowlisted missing path or symlink from silently passing. Do not freeze the logger into the historical manifest or replace its current reviewed implementation with a copied historical hash.

### 3. Subtract only that singleton from recursive enumeration

In the existing `enumerated` filter, after the two R9-F exact-set exclusions, add one condition:

```swift
&& !desktopCodingClosureRuntimeDiagnosticsSuccessorFiles.contains($0)
```

No change is needed in the `liveEntries` filter because the new assertion proves this successor path is absent from the fixed manifest. Keep both existing final expectations exactly:

```swift
#expect(enumerated.count == 102)
#expect(enumerated == liveEntries.map(\.path))
```

Do not change either expected value to 103, append the logger to `liveEntries`, remove the equality, or weaken it to subset/contains logic. After the exact subtraction, any other unplanned regular file under `Sources` remains in `enumerated`, causing the unchanged count and exact sorted equality to fail. The observed red run itself demonstrates that this detection is active.

## Reviewable file boundary

Authorized implementation file:

1. `Sources/AgentLoopTestSuite/DurablePlanningTests.swift` — one singleton successor constant, three exact successor assertions/checks, and one exact enumeration-filter condition.

Explicitly unchanged:

- `Sources/AgentLoopCore/Observability/RuntimeLifecycleDiagnostics.swift`
- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a3-candidate-transaction/revision02-entry-source-manifest.sha256`
- every historical scope allowlist and manifest
- all other production and test sources

The implementation diff should contain no expected-hash updates, no historical-count changes, no new helper abstraction, and no assertion deletion. The test file is already part of the historical reviewed partitions, so editing the sentinel does not create another unexplained enumerated path; the explicit singleton remains the only newly admitted source path.

## Verification strategy owned by the parent

1. Preserve `runtime-observed.log` as the pre-change red evidence: two issues from one exact unexpected path, with no claim that the overall runtime baseline was green.
2. Review the implementation diff against the one-file/one-path boundary above and run `git diff --check`.
3. Run the exact focused sentinel using the repository runner's established filter form: `swift run RunTests --filter a3Revision02EntryBoundaryRemainsByteExact`. Green requires the original 206-row manifest hash/count, unchanged successor partition counts, exactly 102 live/enumerated paths, equality of the full sorted arrays, all 102 historical hashes, the two frozen entry hashes, and the new singleton presence/non-symlink checks.
4. The parent later runs the required unfiltered `swift run RunTests` as part of the runtime repair gate. This boundary update may remove the two explained sentinel issues; it must not be reported as a green runtime baseline or as resolving the independent process/Board/shell failures in `runtime-observed.log`.
5. If the evidence-selected runtime fix later adds a helper source file, first leave this sentinel red on that exact new path, obtain the separate repair review, then add a separate exact successor set. Do not expand this diagnostics singleton, pre-authorize a directory, or alter the historical manifest.

No new test function is needed. The existing sentinel is the production source-boundary regression: its count plus full equality catches additions, its per-entry hashes catch drift in the unaffected historical complement, and the new singleton checks make this one authorized successor explicit and fail closed if it disappears or becomes a symlink.
