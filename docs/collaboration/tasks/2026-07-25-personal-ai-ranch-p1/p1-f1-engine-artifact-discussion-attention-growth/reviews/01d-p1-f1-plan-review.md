# P1-F1 F1D Revision 5 Plan Review 01d

Date: 2026-08-27

## Verdict

**CHANGES REQUIRED — 0 P0 / 4 P1**

This is a responsibility-isolated, plan-only review of F1D Revision 5. It did
not modify the plan, allowlist, product, tests, prior reviews, or evidence, and
it did not run a build, test, migration, package, or application. The review is
bounded to whether 062–080 can obtain a valid runtime red and then be
implemented without inventing an API, ownership, identity, transport, or
security decision. It does not reopen F1A–F1C or enter F1E/F1F/F2/P2.

## Frozen inputs and independent checks

| Input/check | Observed result |
|---|---|
| Revision 5 plan | SHA-256 `5e4df5127368239704732f1bb7f9083a1584876c4dba83ebdb7d598afed1acf8` |
| effective allowlist | 99 unique, byte-sorted, LF-terminated paths; SHA-256 `cf97d4ccab655e37ae1c967b88dafa152b89f8f6e6365857ee0a9d2cae30e9aa` |
| entry manifest / focused manifest | `024dfaab32ff6688258439b0f57e0d37148005f4ac3f8a40854eb24bfd7fd58a` / `03f69e8455d7d7b9c7a75f2489dd7499cf1611b5299542c84042d70b33615968` |
| live machine boundary before this review | dirty `661`, allowlisted present `72`, outside `589`; outside manifest v1 `792b4de01590c9a291f0bb49092057e3fb87678d485ae29d7ba21254846f7a88` |
| absent-at-freeze paths | `ModelLoopEngineAdapter.swift`, `CliEngineAdapter.swift`, and `ExecutionEngineConformanceTests.swift` are absent |
| current relevant pre-images | all eleven hashes in plan lines 2128–2138 independently match live bytes |
| F1C final Review02 | current SHA-256 `821b177cf50f8f0c249824eecd8fdd1c1c7db54cbe6a48bdaa664abc923c95b5`; final bounded F1C verdict is 0 P0 / 0 P1 |

The three descriptor rows, required-capability selection direction, kernel-only
terminal authority, no-F2 boundary, exact 062–080 manifest identities, and
scope/pre-image facts are otherwise suitable inputs for a bounded successor.

## Findings

### P1-1 — The compile-only exception does not freeze the declarations or the 19 runtime-red calls

Revision 5 freezes only `EngineAdapterCapabilityV1` and its unavailable error,
then permits any declarations “needed to compile 062–080” and refers to “every
scaffold operation” without enumerating either set (plan lines 2140–2169).
However, the tests must compile against several currently nonexistent final
types—at least the registry selection, coordinator transport, router, terminal
intent, context/workspace resolvers, adapters, CLI parser/help/process seams,
and sanitizer. Their file owner, stored fields, initializer, method signature,
throwing shape, and compile-only body are not frozen. There is also no
identity-to-operation table stating which exact call each of 062–080 makes and
which one unavailable capability must be observed first.

Consequently the implementer must design the test-facing API before the red,
or can obtain a compile/discovery red instead of the required 19/19 typed
runtime red. The two scaffold symbols alone do not close the ordering gap.

Minimum plan-only correction:

1. enumerate every declaration temporarily needed to compile 062–080, with its
   exact file, access level, stored fields, initializer, method signature,
   return type, and no-side-effect unavailable body;
2. map each identity 062–080 to the first scaffold call and exact
   `EngineAdapterCapabilityV1` case it must assert, including the cold
   `AsyncThrowingStream` rule;
3. state the exact post-red deletion/source gate for every temporary
   declaration, not only the two shared error symbols.

### P1-2 — Registry, coordinator, router, intent, and artifact-manifest production contracts still require architecture decisions

The registry's return type `EngineAdapterSelectionV1` has no defined fields or
initializer, and the ordered factory has no exact initializer, duplicate-kind
rule, factory signature, unsupported error, or help-snapshot injection point
(lines 2176–2204). The CLI descriptor is simultaneously described as publishing
only `supported|unsupported` and as conditional on a help snapshot, without
freezing who probes, when it probes, or how a flag maps to one capability.

The coordinator exposes an undefined `transport` parameter and no initializer
or dependency/clock/factory surface (lines 2211–2218). The router has no exact
input methods, terminal-state query, output/throwing contract, or typed
duplicate-terminal error. `EngineTerminalIntentV1` is prose rather than an
exact enum: associated values, validation, stable reason/detail values, and the
terminal idempotency-key derivation are absent (lines 2222–2245). Likewise
`ArtifactStager.buildManifest(workspaceRoot:handoff:)` has no exact throwing
signature, return type, normalization/error taxonomy, or placement relative to
the existing instance Store dependencies (lines 2247–2255). The live Store
still has the one-argument descriptor resolver, the live sink accepts a full
proposal and returns a record result, and the live Stager only has
`prepare/recoverPreparation/cleanOrphanedStaging`; these are real API decisions,
not mechanical fill-in.

Minimum plan-only correction: assign each new type to one allowlisted file and
freeze the complete registry/selection, descriptor-help input, coordinator
transport/dependencies, router, intent, sink, terminal-key, usage accumulator,
and manifest-builder declarations. Include the exact conversion from one
router terminal to `EngineTerminalProposalContentV1` and the exact handling of
every existing recovery directive. No new path or dependency is needed.

### P1-3 — Context, workspace, and predecessor-session identities are not byte-complete

The answered-request hash object does not say whether `optionsJson` and
`answerJson` are canonical JSON values or JSON strings, how nil is encoded, or
which canonical Date representation is used for `answeredAt` (lines
2269–2278). `EngineContextTransportResolverV1` has no exact request/result,
initializer/dependencies, ref-to-row table, or production mapping for the other
prompt-changing inputs already rendered by `ContextPacket`—camp/companion
notes, upstream handoffs, instructions, and resources (lines 2280–2284).
“Existing typed ref/hash” is not an executable contract.

The workspace object similarly leaves path normalization, nil bookmark
encoding, bookmark hashing, resolved scoped-access lifetime, and resolver
request/result unspecified (lines 2286–2293). Finally, production continuation
is said to pass an exact predecessor execution ID, but Revision 5 defines no
replacement request field/type or Store API for the current direct
`sessionSelection`, and no deterministic predecessor eligibility/query rule
(lines 2295–2302). An implementer therefore must invent bytes that directly
affect `contextHash`, `workspaceHash`, `sessionScopeHash`, recovery, and identity
080.

Minimum plan-only correction: freeze canonical Codable DTOs/golden bytes for
answered requests and workspace identity; enumerate every production prompt
ref source and its reload/hash rule; define resolver inputs/results and scoped
access release ownership; and replace product `sessionSelection` with an exact
predecessor-execution field plus deterministic Store lookup/eligibility and
zero-write mismatch behavior.

### P1-4 — The CLI conformance contract contains placeholders where exact commands, parsing, cancellation, and secret-safe evidence are required

Lines 2324–2352 still use `<approved -c key=value config pairs>`, “the same
workspace/sandbox/model/config”, “exact model/workspace flags”, “known text,
usage, and result events”, “all required flags”, “a bounded existing timeout”,
and “fixed reason text plus a safe trace ID”. These phrases do not enumerate:

- first/resume argument arrays and order for both CLIs, all allowed Codex
  config keys/values, the source of model `M`, Claude workspace/model behavior,
  and the exact Contract prompt placement;
- the exact help commands/snapshot schema, flag-to-capability table, probe
  caching/injection, and typed unsupported error;
- every accepted JSONL/stream-json event shape and exact keys, checked numeric
  conversion, session/result binding, and unknown-event policy;
- process-group creation, TERM grace, KILL/wait/drain deadlines, exit proof,
  cancellation-vs-terminal race, and temp-config cleanup ordering;
- the trace ID source/validation, fixed safe detail strings/reason codes, and
  whether the trace is execution-stable across replay/recovery.

The live command builder currently uses `KernelDefaults` model values and a
broad recursive parser, so tests 072–075 cannot infer a single intended final
contract from existing code. These omissions are also security-relevant to
identity 070 and cannot be delegated to fixture authors.

Minimum plan-only correction: replace every placeholder above with literal
ordered argument templates, exact DTO/event/help tables, injected process/probe
interfaces and bounded durations, and exact safe error/trace formatting. Keep
real login/network forbidden and preserve the current allowlist.

## Count and gate

- P0: 0
- P1: 4

Review01d does not open any scaffold, test, product, build, or App write. A
single bounded Revision 5 successor may close only these four groups, recompute
the plan/allowlist/boundary hashes, and receive a fresh responsibility-isolated
plan review. F1D implementation remains closed until that review reports
`APPROVED — 0 P0 / 0 P1`.

## Bounded successor review — Revision 5a

### Verdict

**CHANGES REQUIRED — 0 P0 / 1 P1**

This is the one bounded successor review authorized by Review01d. It reviewed
only the four original P1 closure groups and the subsequent mechanical
cross-reference/clock corrections. It did not reopen F1A–F1C, expand into
F1E/F2, modify any plan/allowlist/product/test byte, or run a build, test,
migration, package, process, or application.

### Frozen inputs and closure checks

| Input/check | Observed result |
|---|---|
| Revision 5a plan | SHA-256 `c517ba3116a05267c2d416ddc08f1a6e8d02aa3ee560b80029487b78719cf859` |
| effective allowlist | 99 lines; SHA-256 `cf97d4ccab655e37ae1c967b88dafa152b89f8f6e6365857ee0a9d2cae30e9aa` |
| immutable Review01d prefix | first 9,453 bytes retain SHA-256 `61cb7cd6771100da11090db2526cba4f3ac1e84fe10fb9ba916ab7c11b2340bb` |
| live machine boundary before append | dirty `662`, allowlisted present `73`, outside `589`; outside manifest v1 `792b4de01590c9a291f0bb49092057e3fb87678d485ae29d7ba21254846f7a88` |
| mechanical corrections | context and workspace declarations point to §18.3; CLI/process declarations point to §18.4; coordinator freezes `clock: @Sendable () -> Date` |

The 062–080 first-call table now fixes 19 identities and 19 unavailable cases,
and the registry/context/workspace/CLI prose is substantially more exact. One
load-bearing terminal-transport contradiction remains.

### P1-5 — The frozen terminal intent cannot carry two CLI failure subtypes required by the sanitizer contract

§18.1 closes `EngineTerminalIntentV1` to completed, ordinary blocked,
needs-human-input, failed, and canceled. §18.2 then fixes every
`.blocked(reasonCode,detail)` to subtype `.ordinary`; the only separate router
entry point is `routeProtocolFailure`, which always creates
`.engineProtocolError`. `CliEngineAdapter`, however, is given only
`EngineTerminalSink.submit(_ intent:)`, not the router.

§18.4 requires sanitized parser/help failures to persist as blocked
`.engineProtocolError` and launch/cleanup/exit uncertainty as blocked
`.externalEffectUnknown`. Neither subtype can traverse the frozen adapter→sink
surface: `.blocked` is forced to `.ordinary`, and there is no intent or router
operation for `.externalEffectUnknown`. The same section says only that the
sanitizer takes “this reason enum”, but freezes neither that enum nor
`failure(reason:executionId:)`'s return type; `prefix16` also does not decide
whether the trace is 16 hex characters or 16 bytes/32 hex characters. Thus
identity 070 does not have a decision-complete compile/runtime-red declaration,
and final CLI failures cannot satisfy the required durable subtype without an
unplanned API/security decision.

Minimum plan-only correction: freeze one exact DB-free failure path end to end:
the sanitizer reason enum/cases, initializer and `failure` return type; an
intent/sink/router representation that preserves `.ordinary`,
`.engineProtocolError`, and `.externalEffectUnknown` exactly (with Board limited
to `.ordinary`); the exact proposal mapping for each; and trace truncation in
bytes or hex characters. Add that exact callable surface to identity 070's
compile-only declaration and post-red replacement list. No new path,
allowlist, dependency, product scope, or test identity is needed.

### Successor count and gate

- P0: 0
- P1: 1

F1D scaffold/test/product implementation remains closed. A bounded plan-only
correction may address only P1-5 and then receive a responsibility-isolated
successor verdict; no build/test/App run is authorized by this review.

## Scoped successor review — Revision 5b

### Verdict

**CHANGES REQUIRED — 0 P0 / 1 P1**

This review is confined to whether Revision 5b closes P1-5. It did not reopen
any other Review01d finding, inspect F1E/F2 behavior, modify plan/allowlist/
product/test bytes, or run a build, test, migration, process, package, or App.

### Frozen inputs and verified closures

| Input/check | Observed result |
|---|---|
| Revision 5b plan | SHA-256 `2d2d367b0577c01a3c2f5710abe30866aac43e621e9220fd8090d799d52fe185` |
| pre-§19 plan prefix | first 150,817 bytes retain SHA-256 `c517ba3116a05267c2d416ddc08f1a6e8d02aa3ee560b80029487b78719cf859`; §19 is 8,612 bytes / 183 lines |
| effective allowlist | 99 lines; SHA-256 `cf97d4ccab655e37ae1c967b88dafa152b89f8f6e6365857ee0a9d2cae30e9aa` |
| immutable review prefix | first 13,057 bytes retain SHA-256 `5eb9f3b57a06887ed87b9a78f0bded35b748e53503cf3d975557d5d732f20093`; original 9,453-byte base prefix remains `61cb7cd6771100da11090db2526cba4f3ac1e84fe10fb9ba916ab7c11b2340bb` |
| live machine boundary before append | dirty `662`, allowlisted present `73`, outside `589`; outside manifest v1 `792b4de01590c9a291f0bb49092057e3fb87678d485ae29d7ba21254846f7a88` |

Revision 5b does freeze the exact sanitizer reason/result/signature and identity
070 unavailable body, the three blocked intent subtypes and exhaustive durable
proposal mapping, all five safe reason mappings, and a 16-character lowercase
ASCII-hex trace with no raw diagnostic input. Those portions are implementable
against the existing `EngineTerminalSubtypeV1` receipt taxonomy.

### P1-5 remains open — The coordinator-owned Board sink has no frozen injection path

§19.2 says CLI and ModelLoop adapters receive **only**
`EngineTerminalSink`, while BoardTools, BoardToolServer, and
BoardServerBridgeMain receive **only** the new `EngineBoardTerminalSink`; it
also assigns the Board conversion to a coordinator-owned sink. But the still-
controlling §18.1 `EngineAdapterRuntimeV1`, both adapter stored-field lists,
and `ModelLoopExecutionDrivingV1.execute` carry only `EngineTerminalSink` plus
`EngineProgressSink`. No Board sink field, constructor/factory argument, dual-
conforming concrete sink, or conversion owner is exposed to the transports
that construct those Board objects.

Consequently the subtype split itself is sound, but production cannot pass the
coordinator-owned Board sink to the three Board owners without inventing a new
runtime/adapter/driver API or an unchecked existential cast. This blocks the
required adapter-vs-Board authority wiring and the final 077/078 path.

Minimum plan-only correction: freeze exactly one typed handoff from coordinator
to every Board construction site—either an explicit
`boardTerminalSink: any EngineBoardTerminalSink` runtime/adapter/driver field
and initializer parameter, or one named coordinator sink type that is declared
to conform to both protocols and is passed through an exact typed surface.
Enumerate the affected existing constructors and compile-only bodies; preserve
Board's type-level inability to create protocol/external-unknown subtypes. This
needs no new path, identity, dependency, or F1E/F2 behavior.

### Revision 5b count and gate

- P0: 0
- P1: 1

F1D implementation remains closed pending this single scoped transport
correction and a 0 P0 / 0 P1 responsibility-isolated successor verdict.

## Final bounded successor review — Revisions 5c and 5d

### Verdict

**CHANGES REQUIRED — 0 P0 / 1 P1**

This review is limited to the two recorded load-bearing closures: the typed
Board-sink handoff and the shared completed-manifest resolver. It did not reopen
F1A–F1C or any earlier finding, expand into F1E/F2, modify plan/allowlist/
product/test bytes, or run a build, test, migration, process, package, or App.

### Frozen inputs and verified closures

| Input/check | Observed result |
|---|---|
| Revision 5c+5d plan | SHA-256 `d4663965c8f3cede5ab5678928e437335c6532b4c209bf23d3e6acc74e225c82` |
| pre-§21 / pre-§20 prefixes | first 171,564 bytes retain SHA-256 `a5c2ec0665413eb64e65b9fb1ceb62a8fd3391e03bdf34e7ad5bd8c97422f093`; first 159,430 bytes retain `2d2d367b0577c01a3c2f5710abe30866aac43e621e9220fd8090d799d52fe185` |
| effective allowlist | 99 lines; SHA-256 `cf97d4ccab655e37ae1c967b88dafa152b89f8f6e6365857ee0a9d2cae30e9aa` |
| immutable review prefixes | first 16,445 bytes retain `98d78bee63cc9c30cd31407ca4af616ff37bd0170868d1ea7fbc3bb0dae70c64`; first 13,057 retain `5eb9f3b57a06887ed87b9a78f0bded35b748e53503cf3d975557d5d732f20093`; original 9,453 retain `61cb7cd6771100da11090db2526cba4f3ac1e84fe10fb9ba916ab7c11b2340bb` |
| live machine boundary before append | dirty `662`, allowlisted present `73`, outside `589`; outside manifest v1 `792b4de01590c9a291f0bb49092057e3fb87678d485ae29d7ba21254846f7a88` |

Revision 5c correctly carries distinct general/Board/progress sinks through the
runtime and ModelLoop path, keeps the child bridge socket-only, and preserves
077/078's first `.terminalIntent` red. Revision 5d correctly supplies one shared
coordinator manifest resolver to both terminal sinks, resolves only completed
before routing, commits only the winning routed terminal, and leaves failed
resolution open with zero routed event/commit/prepare/write. One CLI parent-
server construction gap remains in the 5c handoff.

### P1-5 remains open — The CLI launch request cannot construct the exact parent Board server

§20.2 freezes `CliProcessLaunchRequestV1` with execution ID, command spec,
workspace URL, Board sink, and progress sink. §20.3 then requires
`CliProcessBackend` to construct `BoardToolServer(socketURL:token:cardId:...)`
before child launch, but supplies no typed `socketURL`, `token`, or `cardId` in
that request. It says only to extract the card ID from
`request.spec.environment`; the controlling §18.4 builders instead place the
socket/token/card values inside Codex `-c` MCP config or Claude's 0600 MCP JSON,
and do not freeze a top-level environment copy or any reverse parser.

The backend therefore cannot build the parent server with the same values
already embedded for the child without inventing provider-specific argv/config
scraping, regenerating mismatched credentials, or exposing the Board secret in
the whole CLI process environment. The typed Board sink reaches the process
request, but not a constructible authenticated parent server, so the 078
production path is not decision-complete.

Minimum plan-only correction: add exact non-child control fields
`socketURL`, `token`, and canonical `cardId` (or one exact typed value containing
them) to `CliProcessLaunchRequestV1` and its initializer; require
`CliEngineAdapter` to pass the identical values used by the command builder;
and require `CliProcessBackend` to pass those fields directly to
`BoardToolServer`. Forbid argv/MCP-file/environment scraping, regeneration, and
top-level child-environment duplication. Preserve identity 079's first
`.processLaunch` red and 077/078's existing `.terminalIntent` red. No new path,
identity, dependency, schema, or F1E/F2 behavior is needed.

### Revision 5c+5d count and gate

- P0: 0
- P1: 1

The manifest-resolver closure is approved within this bounded review. F1D
implementation remains closed only on the CLI parent-server control handoff and
a subsequent 0 P0 / 0 P1 responsibility-isolated verdict.

## Final scoped successor review — Revision 5e

### Verdict

**CHANGES REQUIRED — 0 P0 / 1 P1**

This review is confined to the one remaining CLI parent-server control handoff.
It preserved the already-approved sanitizer, typed-sink, and manifest-resolver
closures, did not reopen any other finding or F1A–F1C/F1E/F2 scope, modified no
plan/allowlist/product/test byte, and ran no build, test, migration, process,
package, or App.

### Frozen inputs and preserved closures

| Input/check | Observed result |
|---|---|
| Revision 5e plan | SHA-256 `f41ed0e041b0c48ec4b613101919506d633d356be2d92bd36efe98cab5a82030` |
| pre-§22 prefix | first 176,740 bytes retain SHA-256 `d4663965c8f3cede5ab5678928e437335c6532b4c209bf23d3e6acc74e225c82` |
| effective allowlist | 99 lines; SHA-256 `cf97d4ccab655e37ae1c967b88dafa152b89f8f6e6365857ee0a9d2cae30e9aa` |
| immutable review prefix | first 20,427 bytes retain SHA-256 `e9eb4875905c70ed20453bdb389c622fba9f7c09ad613e8822571a3c96252c30` |
| live machine boundary before append | dirty `662`, allowlisted present `73`, outside `589`; outside manifest v1 `792b4de01590c9a291f0bb49092057e3fb87678d485ae29d7ba21254846f7a88` |

Revision 5e otherwise closes the recorded handoff: exact typed socket/token/Card
fields, one-local same-source builder/request flow, direct parent-server
construction, provider-scoped child config only, zero top-level environment or
reverse parsing/regeneration, same socket/token cleanup, and unchanged
072/073/074/078/079 first-failure order. The sanitizer, general-vs-Board sink
isolation, terminal-once router, and shared manifest resolver remain preserved.

### P1-5 remains open — `boardCardId` requires mutually incompatible canonical casing

§22.1 requires `boardCardId == UUID(uuidString:
boardCardId)?.uuidString.lowercased()`. §22.2 simultaneously requires that
value to be passed directly, without transform, from authoritative
`EngineExecutionRequest.cardId`. The live frozen request constructor validates
that Card ID with `CanonicalContractCodingV1.validateCanonicalUUID`, whose
contract is `UUID(uuidString: value)?.uuidString == value`; Store UUID factories
likewise use `UUID().uuidString`. That repository-canonical representation is
uppercase, so a valid request Card ID cannot satisfy the new lowercase equality.

As written, `CliProcessLaunchRequestV1.init` rejects the exact authoritative
Card ID that the adapter is required to forward. The command input, launch
request, and parent server therefore cannot be constructed from one identical
Card-ID local, blocking the 078/079 production path despite the otherwise
correct typed handoff.

Minimum plan-only correction: validate `boardCardId` with the existing
repository-canonical UUID rule (`UUID(uuidString: boardCardId)?.uuidString ==
boardCardId`, or the existing validator) and preserve those exact bytes through
command input, launch request, nested provider config, parent server, and socket
frames. Do not lowercase, regenerate, or add a second identity. No new path,
identity, dependency, schema, or F1E/F2 behavior is needed.

### Revision 5e count and gate

- P0: 0
- P1: 1

F1D implementation remains closed only on this canonical Card-ID validation
correction and a subsequent 0 P0 / 0 P1 responsibility-isolated verdict.

## Fix-round 5 final scoped review — Revision 5f

### Verdict

**APPROVED — 0 P0 / 0 P1**

This is the final mechanical review of the sole remaining Revision 5e finding.
It reviewed only §23's canonical Card-ID correction, preserved every previously
approved sanitizer/sink/manifest/secret/red-order closure, modified no prior
review, plan, allowlist, product, or test byte, and ran no build, test,
migration, process, package, or App.

### Frozen inputs and independent checks

| Input/check | Observed result |
|---|---|
| Revision 5f plan | SHA-256 `cba526c908d72c92abc81fa641085f77109a921ef16cb1a211e12434f8c12a9b` |
| pre-§23 prefix | first 184,574 bytes retain SHA-256 `f41ed0e041b0c48ec4b613101919506d633d356be2d92bd36efe98cab5a82030` |
| effective allowlist | 99 lines; SHA-256 `cf97d4ccab655e37ae1c967b88dafa152b89f8f6e6365857ee0a9d2cae30e9aa` |
| immutable review prefix | first 23,713 bytes retain SHA-256 `dca7c71ac31446e9748e8c0d4b15f6064220d786a3a846985ecb2d290079e6be` |
| live machine boundary before append | dirty `662`, allowlisted present `73`, outside `589`; outside manifest v1 `792b4de01590c9a291f0bb49092057e3fb87678d485ae29d7ba21254846f7a88` |

§23 mechanically closes the finding. `CliProcessLaunchRequestV1.init` calls
the existing `CanonicalContractCodingV1.validateCanonicalUUID`; its predicate
is the same repository authority, `UUID(uuidString: value)?.uuidString ==
value`. The authoritative uppercase `UUID().uuidString` bytes are bound once
from `request.cardId` and remain byte-identical through command input, launch
request, provider-scoped config, parent Board server, and child hello/Card
comparison. Lowercase or any other noncanonical casing is rejected before I/O,
and every case transform, normalization, parse, or regeneration is forbidden.

This is implementable against the live canonical validator and removes the
only contradiction identified in Revision 5e without changing any path,
identity, dependency, schema, or F1E/F2 boundary.

### Final count and gate

- P0: 0
- P1: 0

The bounded Revision 5–5f F1D plan chain and unchanged 99-line allowlist are
approved for the plan gate. Scaffold/test/product implementation may now follow
the frozen ordering and evidence requirements; this review itself authorizes
no build/test/App claim or external action.

## Responsibility-isolated successor review — Revision 6

### Verdict

**APPROVED — 0 P0 / 0 P1**

This review is confined to Revision 6's F1D runtime-authority correction and
its explicit conflicts with Revisions 5–5f. It checked only §24, the controlling
5–5f clauses, the 062–080 focused identities, the effective allowlist, and the
live signatures needed to establish implementability. It did not reopen or
review F1A–F1C, enter F1E/F2/P2, modify plan/product/test bytes, or run a build,
test, migration, process, package, or App.

### Frozen inputs and independent checks

| Input/check | Observed result |
|---|---|
| immutable pre-Revision-6 plan prefix | first 185,834 bytes retain SHA-256 `cba526c908d72c92abc81fa641085f77109a921ef16cb1a211e12434f8c12a9b` |
| Revision 6 plan | 205,269 bytes; SHA-256 `604526003684189eeecda8ecc291734154dc3d6948b16243f1c840657e146486` |
| effective allowlist | 103 unique, byte-sorted, LF-terminated paths; SHA-256 `9184ba618c4d21f1a96eeecd7e533285793dba1e72a145d39dfd9cdd4ea9a2cb` |
| focused manifest | unchanged SHA-256 `03f69e8455d7d7b9c7a75f2489dd7499cf1611b5299542c84042d70b33615968`; identities 062–080 remain the same 19 names/files |
| immutable Review01d history before this append | first 26,028 bytes retain SHA-256 `d97160d3985a7875d0a81ff430357526e80834ca662c6eb778c0ee77d525bc46` |
| live machine boundary before append | dirty `669`, allowlisted present `83`, outside `586`; outside manifest v1 `6581154ebc21bbec06c718173e3cbb7bb76b57bf8a079772d9ed29a934d5c49e` |
| allowlist expansion | exactly `AskUserTests.swift`, `McpTests.swift`, `ShellToolTests.swift`, and `WebSearchTests.swift`; no fifth path |

### Closure checks

- The adapter stream is payload-only and terminal payload is explicitly a
  protocol failure. One router now owns sequence, terminal state, and checked
  cumulative usage; the new routed Store transaction verifies identity,
  sequence, monotonic cumulative usage, and converts it to a durable delta.
  The legacy F1B delta surface remains isolated rather than becoming a second
  F1D sequence owner.
- The throwing registry, exact three-factory production catalog, captured
  descriptor, and runtime driver/configuration matrix close descriptor and
  dispatch authority. CLI command/help/config equality, per-invocation Claude
  parser factory, and exact first/resume session binding remove the former
  placeholder or global-configuration choices.
- `predecessorExecutionId` is now part of the canonical request bytes, coding,
  rehydration, hash, and replay comparison. The retained direct F1B seam is
  mutually exclusive and forbidden to product callers, so two predecessor
  executions cannot collapse merely because they share a session.
- Context assembly/reload is uniformly async and rebuilds the full closed ref
  set from real rows and dependency-loader tool definitions. The checked
  millisecond truncation rule, independent source-byte hashes, and shared
  canonical execution fixture close the prior timestamp, empty-ref, raw-path,
  noncanonical-ID, and echoed-context false-green paths.
- Coordinator recovery receives a fresh typed transport for each authoritative
  directive, while the active-execution registry owns the one live cancel
  closure and fails unknown/nonlive cancellation. Runtime selection,
  descriptor, context/workspace, driver/config, dispatch, cleanup, and
  recovery therefore have one explicit authority path.
- CLI process ownership is mechanics-only with advertised process-group
  cancellation, pre-registration cancel intent, exact TERM/KILL/drain/reap
  evidence, checked Board shutdown/unlink/config cleanup, and a throwing
  `BoardToolServer.stop()`. CardRunner is DB-free, takes an authorized tool
  resolver, rejects Board-name replacement, and delegates terminal authority
  only through the frozen sinks; the four added compatibility tests cover the
  remaining legacy assembly call sites without retaining a DB/backend
  overload.
- External-effect-unknown keeps the sanitized
  `engine_external_effect_unknown` reason, permits any otherwise-valid safe
  reason in the committed receipt, forces urgent attention and exactly two
  domain events, and retains the older recovery reason bytes. Proposal,
  receipt, event count, result hash, and replay disagreement remains an atomic
  rollback.
- The pre-red corrections are harness-only and preserve the exact §18.1
  first-call/unavailable mapping: throwing registry initializers, one matching
  driver, canonical full fixtures, normalized timestamps, explicit recovery
  replay class, missing `await`/`return`, and payload-stream fake types cannot
  themselves satisfy a red. The gate remains 19 discovered / 19 started / 19
  failed with no identity or first failure changed.

Revision 6's overrides are narrow and explicit; the nonconflicting Revision
5–5f sanitizer, sink, manifest, Board control, Card-ID, security, ordering, and
boundary clauses remain controlling. I found no new architecture decision,
signature contradiction, extra path, schema/migration/dependency change, or
scope escape required to implement the plan.

### Successor count and gate

- P0: 0
- P1: 0

The exact Revision 5–6 F1D plan chain and 103-line allowlist are approved for
the Revision 6 plan gate. The immutable exact-19 runtime red and then the
frozen implementation order may proceed. This verdict is not a build, focused
green, full-suite, App, package, release, or external-action claim.

## Responsibility-isolated successor review — Revision 7

### Verdict

**APPROVED — 0 P0 / 0 P1**

This review is confined to §25's transient recovery-session authority and its
explicit interaction with the controlling Revision-6 runtime/recovery clauses.
It checked the live Store/runtime/CLI/coordinator signatures, identities 067
and 076, the immutable Review01d history, the effective allowlist/focused
manifest, and the outside boundary. It did not reopen any prior approved
closure, enter F1E/F2/P2, modify plan/product/test bytes, or run Swift, a build,
a process fixture, a migration, a package, or the App.

### Frozen inputs and independent checks

| Input/check | Observed result |
|---|---|
| immutable pre-Revision-7 plan prefix | first 205,269 bytes retain SHA-256 `604526003684189eeecda8ecc291734154dc3d6948b16243f1c840657e146486` |
| Revision 7 plan | 219,330 bytes; SHA-256 `b66293455f50bae1b9c9ad4888d53b6411a9c2be3bf879df6147a3e9b29b5cec` |
| effective allowlist | 103 unique, byte-sorted, LF-terminated paths; SHA-256 `9184ba618c4d21f1a96eeecd7e533285793dba1e72a145d39dfd9cdd4ea9a2cb` |
| focused manifest | 100 identities; unchanged SHA-256 `03f69e8455d7d7b9c7a75f2489dd7499cf1611b5299542c84042d70b33615968`; 062–080 remain the same 19 names/files |
| immutable Review01d history before this append | first 31,511 bytes retain SHA-256 `72691d0b93e5961db3c78573f8c463ab06181026ad0d103dedc8b030ea9d22da` |
| live machine boundary before append | dirty `670`, allowlisted present `84`, outside `586`; outside manifest v1 `6581154ebc21bbec06c718173e3cbb7bb76b57bf8a079772d9ed29a934d5c49e` |

### Closure checks

- The read-only Store resolver has complete inputs and one authority path. It
  validates the four caller values before a single read transaction, rehydrates
  the unchanged canonical request, requires the exact running/session-bound
  execution and exact active session, and checks Camp, profile, adapter/version,
  workspace, scope JSON/hash, session ID, external ID, and any canonical
  `sessionRef`. Its existing capability-aware descriptor authority receives
  sorted unique persisted requirements plus `.sessionResume`; only an exact
  resume-supported CLI descriptor can return. Drift creates no Store write,
  adapter, process, filesystem, or network action, and typed descriptor/
  selection versus session-scope failures remain separated.
- `resolvedSessionRef` is one transient optional field in
  `EngineAdapterRuntimeV1` and one copied field in `CliEngineAdapter`. Every
  normal and non-resume recovery construction passes literal nil; ModelLoop
  rejects nonnil; the execution transport, process request/drivers, request,
  context/workspace, receipt, Board, and logs remain unchanged. Required
  initializer arguments and the no-overload/default gate prevent a hidden
  fallback authority.
- The five-row effective-session table is exhaustive. Canonical-only,
  transient-only, and byte-equal dual sources converge on one value; unequal
  dual sources fail before Task/socket/token/config/launch/provider effects.
  Resume argv, the per-invocation Claude parser, Codex `thread.started`, and all
  resumed `sessionBound` payloads use that exact external ID, while the request
  JSON/hash and durable DTO remain untouched and raw IDs/errors gain no channel.
- Store's already-bound `sessionBound` branch is the required second defense:
  only exact active-session identity and external-ID equality allow the existing
  accepted-event transaction to advance sequence and record the event. It
  cannot rebind, replace, reopen, or update the session, and mismatch rolls back
  before event/receipt/outbox/legacy/projection writes.
- Resume recovery order is decision-complete: exact directive/request, fresh
  transport plus context/workspace reload, registry selection with the added
  resume requirement, the fresh Store resolver, one runtime/adapter, then the
  unchanged request through the existing router/Store path. All other branches
  pass nil. There is no request clone/re-encode, latest-session query, profile
  fallback, first-call retry, second recovery DTO, or session-bearing transport.
- Identity 067 retains its immutable first `.execute` red while its future green
  covers nil-canonical/transient resume, equal and unequal dual sources, exact
  argv/parser evidence, unchanged request identity, and ModelLoop rejection.
  Identity 076 retains its first `.select` red and uses a distinctly test-owned
  idempotency-keyed, resume-supported CLI descriptor for bind/crash/restart;
  post-scan drift covers external/session/request/scope/workspace/profile/
  adapter-version authority with zero factory/process count and no Store write
  beyond the deliberate fixture mutation. No identity or unavailable mapping
  changes.
- The three production built-ins remain `.nonReplayable`, so the pre-existing
  external-effect-unknown precedence is not weakened to manufacture a recovery
  green. Section 25 overrides only the conflicting runtime/session clauses;
  payload-only routing, cancellation, Board/process ownership, sanitizer,
  removal order, and every Revision-6 acceptance/boundary gate remain intact.

### Successor count and gate

- P0: 0
- P1: 0

Revision 7 is approved for its bounded plan gate. Implementation may resume at
the exact §25.6 order before Revision-6 step 7; this verdict is not runtime
green evidence, full acceptance, an App/package claim, or external authority.

## Responsibility-isolated successor review — Revision 8

### Verdict

**CHANGES REQUIRED — 0 P0 / 1 P1**

This review is confined to §26's production composition, ready-event cause,
tool/approval boundary, executable/runtime-directory authority, coordinator
bind/cancel/observer order, and engine-first recovery against the approved
§§17–25 chain. It checked the frozen allowlist, Review01d history, focused
identity manifest, and live signatures needed to establish implementability.
It did not reopen F1A–F1C, enter F1E/F2/P2, modify plan/allowlist/product/test
bytes, or run Swift, a build, a test, a process fixture, a package, or the App.

### Frozen inputs and independent checks

| Input/check | Observed result |
|---|---|
| immutable pre-Revision-8 plan prefix | first 219,330 bytes retain SHA-256 `b66293455f50bae1b9c9ad4888d53b6411a9c2be3bf879df6147a3e9b29b5cec` |
| Revision 8 plan | 330,868 bytes / 6,185 lines; SHA-256 `a3a078cd85050c9d8d87533759319227b0032f13cb149b590bd236838464d0b8` |
| effective allowlist | 109 unique, byte-sorted, LF-terminated paths / 7,808 bytes; SHA-256 `83db82562cd412e32a6920e222e3dfbafab24a63ebc2fa6a6d3b984e01061e53` |
| focused manifest | 100 identities; unchanged SHA-256 `03f69e8455d7d7b9c7a75f2489dd7499cf1611b5299542c84042d70b33615968`; 062–080 retain the same names/files |
| immutable Review01d history before this append | first 36,964 bytes retain SHA-256 `ed9c8a46e46bafca72a73f395e1f51b6968030404c01fa8a03c209b5d0f847c8` |
| live machine boundary before append | dirty `671`, allowlisted present `88`, outside `583`; outside manifest v1 `1a19caaa14031b57885af39af6c8bd55d31ef6fe312d86c92ffdb7ab4dd80690` |
| allowlist expansion | exactly the six §26 paths; `ApplicationWorkflowTests.swift`, `KernelDefaults.swift`, and every other outside path remain excluded |

The ready-event payload/order/idempotency graph, prepared factory/recovery
closures, one-source context/tool bindings, zero engine approval handler,
App environment and three initializer forwarding rules, lazy shared CLI
driver, socket/state-root authorities, bind/start gate, cancellation lifecycle,
post-commit observer, and engine-first recovery/removal gates are otherwise
decision-complete within the listed scope. One executable-authority handoff is
still missing.

### P1-1 — Managed-policy validation cannot receive the selected staged executable authority

Section 26 requires each Codex/Claude managed-policy and account/auth probe to
run with the **same** staged, signed, hash-pinned executable authority used by
the selected help snapshot, both before that factory is registered and again
immediately before its actual launch. It also permits old and new immutable
help/registry generations to coexist while running Tasks retain an older
generation.

The exact `EngineExecutionEnvironmentV1` and
`EngineExecutionTransportSeedV1` declarations instead freeze both validators
as `(@Sendable () throws -> Void)?`. AppStore constructs those no-argument
closures before `EngineExecutionRuntimeV1` identifies, stages, probes, caches,
and selects a CLI authority; copying a closure into the seed does not give it
the selected `CliHelpSnapshotV1.executableAuthority`. None of the exact
transport, runtime configuration, command input, launch request, or backend
surfaces adds that missing argument. Re-resolving PATH, scanning staged
directories, choosing a same-kind generation, or consulting mutable ambient
state would be a second executable authority/side channel and cannot prove
byte equality to the captured selection. The backend's separate no-follow
hash/signature revalidation also does not perform the required managed-policy
and account/auth proof.

Consequently production and deterministic tests cannot implement the stated
same-authority registration/prelaunch gate from the frozen signatures without
inventing an authority channel. This is security- and recovery-significant:
with two retained generations, a no-argument validator may probe one signed
binary while dispatch launches another.

Minimum plan-only correction:

1. Freeze one validator type (or the two inline fields) as
   `@Sendable (_ executableAuthority: CliExecutableAuthorityV1) throws -> Void`
   in both the environment and seed, preserving their listed initializer
   positions.
2. Before factory registration, invoke the matching validator with exactly
   that successful `CliHelpSnapshotV1.executableAuthority`; require
   `.cliCodex` for Codex and `.cliClaude` for Claude.
3. Capture that same authority in `prepareRequest` and invoke the validator
   with it again in the gated prelaunch closure. Require byte equality to the
   selection immediately before invocation; forbid PATH re-resolution,
   directory scanning, or any ambient authority lookup.
4. Strengthen the existing 071/075/079 managed-policy fixtures to assert the
   received value is byte-equal to the selected snapshot authority at both
   calls. No new path, identity, dependency, schema, migration, or product
   scope is needed.

### Successor count and gate

- P0: 0
- P1: 1

Revision 8 remains closed for implementation. A bounded plan-only successor
may correct only this selected-authority validator handoff, refresh the frozen
hashes/boundary, and receive a new responsibility-isolated verdict. This review
does not authorize scaffold, product/test implementation, build/test/App work,
packaging, release, or external action.

## Responsibility-isolated successor review — Revision 9

### Verdict

**APPROVED — 0 P0 / 0 P1**

This review is confined to §27's correction of Revision 8 P1-1. It checked the
authority-bearing validator signature, partial-registry registration,
normal/recovery gated prelaunch handoff, existing proof identities, frozen
allowlist, immutable Review01d history, and the live owner signatures needed
for implementability. It did not reopen any other §26 closure, enter
F1E/F2/P2, modify plan/allowlist/product/test bytes, or run Swift, a build, a
test, a process fixture, a package, or the App.

### Frozen inputs and independent checks

| Input/check | Observed result |
|---|---|
| immutable pre-Revision-9 plan prefix | first 330,868 bytes retain SHA-256 `a3a078cd85050c9d8d87533759319227b0032f13cb149b590bd236838464d0b8` |
| Revision 9 plan | 337,164 bytes / 6,302 lines; SHA-256 `ab4170c8182dd86442054ed95ef50639e111bac4dd0a852097830e68b16f61e2` |
| effective allowlist | unchanged 109 unique, byte-sorted, LF-terminated paths / 7,808 bytes; SHA-256 `83db82562cd412e32a6920e222e3dfbafab24a63ebc2fa6a6d3b984e01061e53` |
| immutable Review01d history before this append | first 42,396 bytes retain SHA-256 `ca63faeb5f3bba38d869a27c09acbd0e29ee7720c58f332665560c38f4ef3be5` |
| live machine boundary before append | dirty `671`, allowlisted present `88`, outside `583`; outside manifest v1 `1a19caaa14031b57885af39af6c8bd55d31ef6fe312d86c92ffdb7ab4dd80690` |
| Markdown/source hygiene | plan fences remain even at `164`; allowlist remains sorted/unique with terminal LF |

### Finding closure

- `EngineCliManagedPolicyValidateV1` now accepts the exact
  `CliExecutableAuthorityV1`. Both environment and transport seed replace the
  no-argument fields without changing their positions, optionality, or
  provider-specific names; the zero-argument/ambient resolver route is
  explicitly removed.
- Partial-registry construction invokes the matching validator with the exact
  successful help snapshot authority before insertion. Codex and Claude check
  their distinct kinds, use only `stagedPath`, and fail only that factory on
  nil, drift, mismatch, or policy failure, so registration cannot validate a
  different same-kind generation or silently substitute a provider.
- `prepareRequest` binds one selected authority from the captured snapshot.
  Its gated `makeTransport` rechecks byte equality after `.startNow`, invokes
  the validator with that value before driver/Board/config/process effects,
  and passes the same value unchanged through runtime configuration, command
  input, and launch request. The validator cannot replace the authority, and
  the later backend/image checks remain independent defenses.
- Recovery obtains the authority only from the current exact registry
  selection, applies the same kind/equality/validator chain only in a
  Store-validated dispatching branch, and performs zero policy probe for a
  non-dispatch directive. Generation or descriptor drift remains a visible
  failure with no adoption, latest-generation lookup, or fallback.
- Existing identities 071, 075, and 079 now prove both registration and
  prelaunch byte equality, normal versus dispatching-recovery call counts,
  two-generation nonmixing, wrong-kind/nil/throw/drift failures, and unchanged
  authority bytes at all three final carriers. The involved owners and tests
  are already allowlisted; no hidden API, new path, identity, schema,
  migration, dependency, or product decision is required.

Revision 9 therefore supplies exactly the authority channel missing from the
no-argument Revision-8 surface and closes P1-1 without weakening the approved
ready-event, context/tool/approval, App/runtime-directory, cancellation,
observer, or recovery boundaries.

### Successor count and gate

- P0: 0
- P1: 0

The corrected Revision 5–9 F1D plan chain and unchanged 109-line allowlist are
approved for the Revision-9 plan gate. The earlier Revision-8
`CHANGES REQUIRED` verdict remains immutable history. This approval is not
scaffold/product green evidence, full acceptance, an App/package claim,
release authority, or permission for external action.
