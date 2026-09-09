# P1-E Compatibility Plan Review — Review01g

> Date: 2026-08-27  
> Reviewer: independent Codex subagent  
> Process disclosure: the user explicitly directed the implementation owner to
> proceed without Claude. This review was performed by a responsibility-isolated
> Codex subagent. The reviewer did not author Revision 07 and did not modify any
> product, test, plan, allowlist, or prior-evidence byte. The only repository
> write in this pass is this review artifact.  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. Reviewed inputs and independent recomputation

I reviewed `AGENTS.md`, the collaboration protocol, Revision 06, Review01f,
Revision 07, its 128-line executable allowlist, the preserved default-parallel
red, the frozen Revision-07 diagnostic, the four implementation-sensitive
pre-images, and all five protected bytes named by Revision 07. I did not run a
build, the authoritative/full suite, or any chance-green retry.

The frozen inputs are byte-exact:

```text
revision_06_sha256=6894971b1a39bc004ffde1f71bc2954843b5b4eccc88dbeffc383aa30722b0f9
review_01f_sha256=952228e9c714f33016bef7ec3f0e4f01a8bcaecd869435366a61a01344e225e5
revision_07_sha256=1a7bf9e4fb83816baab1551984d390c0e595f12e0d163040387de0ff48fbbebc
revision_07_red_sha256=8ab32c3445412823bf0f4ccf117c79f3b7d5ed464a4da43cebdf81dd66640f7d
revision_07_diagnostic_sha256=162dd725a87b3ce0b12dc715f8c08ff16fe3f386310798a1bb56453384543b6b
```

The red contains exactly four issues in 992 tests / 24 suites after 60.079
seconds, with `command_code=1` and `tee_code=0`: the shutdown wall-clock
assertion, real-time cooldown observation, Board framing receive timeout, and
process-global descriptor delta. The current P1-E 90-test suite is green in
that run; this is not treated as full acceptance.

The allowlist is LF-terminated, nonempty, and unique. Removing exactly the one
new test path and six Revision-07 task artifacts reconstructs the 121-line
Revision-06 allowlist byte-for-byte:

```text
revision_07_allowlist_lines=128
revision_07_allowlist_nonempty_unique=128
revision_07_allowlist_sha256=2929ab1de17cb24574790842b0661354707ef36373482a2ea6a855baf005c067
reconstructed_revision_06_lines=121
reconstructed_revision_06_sha256=390534f89cb2f4826403ee1507976f9b0dd6047aa17c0c32acea87ff6b256d46
```

Replaying the base plan's NUL-safe `u64be(path-byte-count) + path +
u32be(lstat-mode) + type/content` serializer immediately before creating this
review gave:

```text
dirty_total=615
allowlisted_present_count=120
outside_count=495
outside_manifest_v1=917cf6611f701b4c0186fa5359b6432076a1f5a658ddbd8d5aed2d61c857da1e
```

Creating this allowlisted review may advance only the first two counters to
616 and 121. The outside count/hash must remain exact.

The implementation pre-images match Revision 07:

| File | SHA-256 |
|---|---|
| `Orchestrator.swift` | `4dcfa183d6a7e85d31651d7dded45a5adb624a4cda01677c010c7727efc1e087` |
| `HaltAndCooldownTests.swift` | `339d8ddf8c1bc0514590a813f3ebab671885c5b5ed2b6dfe231b3e5810a13b6a` |
| `DurablePlanningTests.swift` | `c05d633ff65e7f7edf25c35bbbf8ab2a18bd23c35887e7eba6c070011f8c07d5` |
| `BoardServerTests.swift` | `ea974b23b544fd353772935440f38f07916f406befccc0bfe245d3b30c6e1dda` |

The protected hashes also match:

| File | SHA-256 |
|---|---|
| `DurableWorkSupervisor.swift` | `e4efbd3679549cb3db6d87aa7a1272c7b200ba5ac35781a2d626b7e1b75beaae` |
| `BoardToolServer.swift` | `ab681c9982c537e0f6777f85e3d482c022c0d10182f9335efe0d7902364044ea` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Package.swift` | `0a4b9d3c4eba1a06bda535e69c54c3a5186dcaf148bcb489f1667b4c069cba48` |

Both immutable historical manifests remain exact at 206 unique entries. Their
intersections and successor arithmetic independently recompute as:

```text
A4_manifest_sha256=6c59ed6d2e411ee2859f16833567471142b59958fabbc56f0f3f78a3602abc71
A4_raw_P1E_intersection=39
A4_unaffected_entries=206-46-3-19-11=127
A3_manifest_sha256=3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e
A3_raw_P1E_intersection=41
A3_live_enumerated_entries=206-7-43-3-19-11=123
HaltAndCooldownTests_present_in_both=true
```

## 2. Conforming roots

The shutdown correction is causal and test-real: it preserves the genuinely
uncooperative synchronous provider and the exact uncooperative work identity,
observes the injected 25ms deadline, proves shutdown cannot finish before the
deadline is released, and removes only an executor-load-dependent wall-clock
upper bound. `DurableWorkSupervisor.swift` correctly remains protected.

The cooldown seam is feasible without a public API change. `Orchestrator` has
exactly two designated package initializer paths; a defaulted package-only
`@Sendable () -> ContinuousClock.Instant` can be stored and initialized by
both, while the public initializer delegates with the live clock. The existing
test can select the non-rumination package path with
`externalOperationWorkflow: nil`, freeze time through the complete 429 path,
and advance exactly 400ms. Both existing real-time reads are named, and no
duration or product outcome changes.

The descriptor correction replaces a non-causal process-global count with
synchronous observations around this client's real `socket` and
`Darwin.close` calls. Ordered open/close pairs, identical descriptor identity,
zero close results, twenty typed failed constructions, and a separately live
unrelated pipe make the proof independent of concurrent process descriptors.
The tests-first `+2` pipe red directly demonstrates the old measurement flaw.

## 3. Finding

### P1 — the framing correction isolates only the handler queue, but the observed hello wait is still gated by a protected shared accept queue

Revision 07 §4.4 creates and readies a dedicated `handlerQueue`, then passes it
through `makeBoardHarness(handlerQueue:)`. That queue is not the first
scheduler boundary for a socket connection. In the exact protected
`BoardToolServer.swift` pre-image, `start()` always submits `acceptLoop` to
`DispatchQueue.global(qos: .utility)`; only after `accept()` succeeds does
`acceptLoop` submit `handle(connection:)` to the injected handler queue.

The diagnostic sample cited by Revision 07 is still present with its exact
frozen SHA-256
`7c4f1f696482e2cb944e7bea228289c385d7c8d82fe0f8e628b57ba5fdef7a1a`.
It records the client blocked in the initial `hello -> readLine` for 557 of 586
framing-test samples. The server-side sample contains only 34 samples in
`start -> acceptLoop` and 33 in the later handler path (27 already inside the
tool-call path and six reading the connection). Thus the dominant observed
wait precedes the point at which a dedicated handler queue can provide a
deterministic guarantee. A synchronous empty barrier on that handler queue
does not establish that the separately queued global-utility accept loop has
started or accepted this connection.

This is not a request to increase the five-second timeout, serialize the full
suite, or retry the full gate. The bounded correction must control both
scheduler boundaries while preserving production defaults—for example, an
explicit accept-queue injection seam defaulted to the current utility queue,
with separate ready dedicated accept and handler queues in this one functional
test—or present equivalent causal evidence that the accept loop is ready
before the client receive deadline begins. The revised plan must update the
Board product pre-image/protection boundary, allowlist/scope gates if needed,
tests-first proof, build/preview requirement, and exact red lines accordingly.

Without that change, the proposed implementation can leave the documented
root active and cannot deterministically clear the exact default-parallel gate.

## 4. Verdict

**NEEDS CHANGES — 0 P0 / 1 P1.**

No source or test implementation is authorized by Review01g.
