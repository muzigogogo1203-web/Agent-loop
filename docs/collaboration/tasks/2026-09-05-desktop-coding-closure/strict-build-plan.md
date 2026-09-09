# Strict Build Cleanup Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development for this bounded task; parent owns all builds/tests and independent review. No commits.

**Goal:** Remove the 13 confirmed strict-build diagnostics without changing runtime behavior.

**Architecture:** Update only deprecated fixed-buffer string construction and redundant language syntax. Preserve first-NUL truncation, signed byte bit patterns and lossy UTF-8 repair, along with all existing path/identity validation.

**Tech Stack:** Swift 6, Foundation, existing macOS package.

**Spec:** This directory's `spec.md`; compiler-red evidence is the unchanged-source baseline `../2026-09-05-product-takeover-baseline/build.log`.

## Global Constraints

- Four production files only; no database schema, dependencies, public API, timeout, scheduling, tests or user data changes.
- Preserve unrelated dirty changes; parent has validated the 303-file baseline manifest before this task.
- No new helper or abstraction for this syntax-only cleanup. Existing behavior tests cover the owning authority paths; do not add a test that merely restates Swift standard-library mechanics.
- Parent is the only build/test owner. Worker self-reviews the scoped diff and runs formatting checks only; parent runs strict build and focused regressions before acceptance.

### Task 1: Remove compiler diagnostics with equivalent syntax

Files:

- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`: the 10 diagnosed locations only.
- `Sources/AgentLoopCore/Loop/BoardServerBridgeMain.swift`: diagnosed array conversion only.
- `Sources/AgentLoopCore/Loop/CliEngineAdapter.swift`: diagnosed array conversion only.
- `Sources/AgentLoopCore/Work/PlanningProviderResolver.swift`: diagnosed nonthrowing `try` only.

Edits (line numbers refer to the frozen pre-change source):

1. `Orchestrator.swift:1381`: remove `await` before synchronous actor-isolated `self.finishPrimary` in its already-inherited actor task.
2. Array conversions at Orchestrator lines 4246, 4326, 5169, 5894, 6752, 6871, 6878, 6960; BoardServerBridgeMain line 213; CliEngineAdapter line 1888: replace `String(cString: buffer)` with the following expression, substituting the existing local buffer identifier:

```swift
String(
    decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
    as: UTF8.self
)
```

`dropLast()` is not equivalent for zero-filled fixed buffers. Do not alter pointer-based `String(cString:)` calls (e.g. `strerror`), which are not the diagnosed deprecated overload.

3. `Orchestrator.swift:7044`: use `let bootDescriptor` if the actual scope has no inout/mutation, preserving error/close handling.
4. `PlanningProviderResolver.swift:417`: remove `try` around the nonthrowing expression only; keep surrounding throwing operations intact.

- [ ] Capture four pre-change source copies under this task's `strict-build-before/` (parent).
- [ ] Apply the 13 changes, self-review exact diff and `git diff --check` (worker).
- [ ] Run strict build. If more diagnostics were previously hidden, report exact new locations and extend this same mechanical task only after parent review; no guessed cleanup (parent).
- [ ] Run focused authority/CLI conformance regression covering these paths, then include this revision in the final default full-suite gate (parent).
- [ ] Independent reviewer checks source diff, compiler output and semantic preservation. Full runtime baseline remains red until its separate fix is verified.
