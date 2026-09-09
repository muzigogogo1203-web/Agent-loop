# P1-A4 Responsibility-Isolated Plan Re-review01A

> Date: 2026-08-10
>
> Reviewer: fresh responsibility-isolated A4 plan re-reviewer
>
> Verdict: **APPROVED — 0 P0 / 0 P1 / 0 P2**

## 1. Independence and review boundary

This reviewer did not author Candidate 01 or Revision 01 and has not
participated in A4 implementation. The review was read-only except for this
exact report. It did not run tests, builds, migrations, the SQLite matrix,
preview, bundle, or UI, and it did not modify canonical Stage/Plan, the leaf,
Revision 01, control indexes, product, test, Package, runner, script, evidence,
or prior review/acceptance bytes.

The review read `AGENTS.md`, the collaboration protocol, canonical P1 Stage
§6.6/§18.2, canonical P1 Plan §3.5/§10/§11, complete Candidate 01, immutable
Review01, complete current Revision 01, and the necessary live code/test/matrix
boundaries in the exact 13-file allowlist. The local GRDB source was inspected
only to verify that the frozen custom `DatabaseDateDecodingStrategy` and
`DatabaseValue.storage` API shape exists. Static source/manifest/anchor checks
were diagnostic only and did not cross an execution gate.

## 2. Review01 closure

All five Review01 P1 findings are decision-complete:

1. **P1-01 disposition/effects:** the four-cell started/failed ×
   inserted/replayed matrix is exact. `commitScheduledMission` is database-only;
   `wakeScheduledPlanning` is the sole conditional tick/Kernel-event/kick owner;
   guide broadcast and `onScheduleFired` are inserted-only, independent
   post-commit effects. Replayed results cannot duplicate user-visible writes or
   rewrite ledger truth.
2. **P1-02 slot/date totality:** only Gregorian/POSIX with a reconstructable
   exact time-zone identifier is accepted; registration captures and passes the
   same complete planned context; run-now/startup capture before their first
   await. Finite range, `-0.0`, component absence, exact instant bits, the former
   millisecond-overflow fixture, and both epoch boundaries have deterministic
   outcomes. New Date columns use numeric-only decoding with exact Int64→Double
   and Date-bit round-trip checks, so corruption cannot be silently rounded.
3. **P1-03 failures:** terminal business/provider outcomes have an exact
   precedence, concrete typed conditions, stable codes, fixed safe Chinese
   messages, and exact mutation shape. The profile fence is limited to the
   explicitly named provider-identity fields. Database, canonical, numeric,
   unknown runtime/resolver, and unenumerated errors remain rollback/fail-fast.
4. **P1-04 evidence partition:** immutable A3 evidence remains byte-identical;
   the transformed A3 sentinel removes only the exact A4 intersections. The new
   206-row complement manifest freezes every non-A4 Source/script/Package byte,
   validates the exact 13-path complement, uses NUL pathname transport, rejects
   LF/CR and symlinks fail-closed, and binds the independently derived Stage,
   §18.1, and §18.2 anchors without weakening inherited diagnostics.
5. **P1-05 preview:** two cold launches through the unmodified real preview
   script now follow all tests/build/matrix/source gates. Each uses a distinct
   fresh explicit state root and requires checkout-executable identity, one
   process, zero normal-root access, bounded liveness, graceful termination,
   and safe evidence.

Review01 P2-01 is also closed as a conscious A4 limit: fire/cursor history is
durable, while catchup prompt disposition is explicitly session-only. A crash
does not spin or duplicate a fire, and no unreviewed table/column claims durable
prompt consumption.

## 3. Additional risk closure

The separately identified replay/hash/template/date/duplicate/catchup risks
are closed without expanding the 13-file boundary:

- Replay identity excludes provider outcome and incoming trace, includes exact
  selected/unavailable runtime nullability, and is independently reconstructed
  and hashed by the Store. Same key/same identity returns the first graph before
  provider/profile work; any key/hash/original mismatch conflicts with zero
  writes.
- Template rebinding is no longer ambiguous: the payload records original and
  effective template IDs, the writer fences capture-to-write drift, a new replay
  uses the writer-current effective template, and the original fire remains
  immutable provenance.
- Original duplicate lookup precedes current business/profile/provider drift,
  validates the complete stored graph, and requires two identical concurrent
  callers to resolve as exactly one inserted plus one replayed result.
- Exact numeric storage, normalized instant bits, raw-UTF8 cursor tie-breaking,
  checked cursor version increment, and concrete corruption errors remove the
  prior Date/ordering implementation choice.
- Startup commits at most the latest missed original, advances the cursor for
  both terminal states, and only an explicit fresh replay key can retry it.

The current code boundary is sufficient: the existing Coordinator →
Orchestrator → Supervisor → AppDatabase structure can host the two-phase
preflight and one nested fileprivate schedule ledger; `ScheduleMath` owns the
semantic slot/cursor calculation; `MissionScheduler` owns only capture and
post-commit App effects; the three test files plus existing runner/script cover
the exact schema, transaction, legacy, source, and dual-SQLite gates. No new
target, dependency, public API, App test seam, F2 trigger, or fourteenth source
file is required.

## 4. Verification and next gate

The reviewed route retains exactly the ten canonical tests, the 657 accepted
baseline, and the exact 667/667-in-7-suites completion count. It requires the
failure-first log, individually selected canonical and affected legacy tests,
real v12-durable predecessor migration, dual SQLite 3.51/3.52 literal and GRDB
lanes, debug/release Core/TestSuite/App builds, fail-closed source partition,
one fresh unfiltered authoritative `swift run RunTests`, two isolated previews,
implementation review, and independent acceptance.

**APPROVED — 0 P0 / 0 P1 / 0 P2.**

This verdict opens only the A4 entry-manifest and failure-first test-edit gate,
followed by implementation inside the exact 13-file allowlist if those gates
pass. It does not accept A4, open P1-B, authorize a hash echo, or authorize
commit, push, merge, release, normal/destructive data access, external action,
or real-user operation.
