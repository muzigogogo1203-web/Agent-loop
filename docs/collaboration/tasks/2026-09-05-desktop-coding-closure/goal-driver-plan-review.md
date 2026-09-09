# A2 goal driver plan — independent review

2026-09-06. Responsibilities-separated, read-only plan review; the reviewer did not author the plan or implement its proposed source changes.

**Verdict: approved within the stated Core-only planning scope. 0 P0 / 0 P1 / 0 P2 actionable findings.** Approval covers all 385 lines of `goal-driver-plan.md` at SHA-256 `7eed55faf2fde3a87460c5914977faa948607a581b58d6edf7ae02f31f81966d`, including its enumerated Provider logging and exact source-inventory addenda. It does not approve implementation, clear a runtime gate, or establish application acceptance.

## Review basis and findings

Read the complete driver plan and preparation report against task `spec.md`, the complete current `goal-flow-plan.md`, `goal-foundation-plan.md`, and the provider-aware policy review. Inspected the relevant current worker, domain, resolver, transport, durable-store and source-inventory implementations. The historical seam amendment's OAuth exclusion is not adopted.

- **Wire and provider boundary:** the private request DTO accounts for the actual 13 request fields and persisted history; strict response reconstruction invokes the real 14-field throwing understanding initializer. `InputContractValidationV1.requireExactKeys` uses arbitrary string coding keys, so the proposed extra-key rejection is feasible. Local response sizes are reasonable bounded validation choices and do not assert remote generation limits.
- **One reservation per generation:** the concrete request-body builders and synchronous `startTurn` methods exist. The strict synchronous resolver accepts a separate factory; zero internal retries, nil OAuth refresher, resolved Anthropic auth and a session redirect delegate fit the existing interfaces. The plan preserves OAuth provider-managed output and requires actual request-byte and no-replay evidence. It explicitly stops the redirect-test boundary if its fixture cannot prove the production behavior.
- **Ownership and accounting:** desktop eligibility surrounds the existing exact DB-taking claim in one write, including the missing desktop/global-dispatch/consent/attempt checks. Claim, reservation and continuation rollback are specified together. Terminal evidence precedes domain publication; unknown/unproven usage cannot create automatic free retries. Context changes cannot reinterpret original capture bytes or past attempt modes. The two-real-work, fourth-attempt-success fixture can reach eight reservations while respecting the existing maximum-four failure branch.
- **Terminal and lifecycle fences:** the current worker provider closure is nonthrowing and terminal domain methods are synchronous. The proposed throwing initializer plus desktop-only terminal-commit callback therefore supplies the necessary new seams without changing historical domain command ownership. The callback must cover parser and coach success and failure terminal paths, as required by M3/M5. Actor launch/commit ordering, retained producer/consumer/deadline tasks, canceled-caller joins, and separate primary/cleanup errors are specified; stream completion alone is not accepted as producer completion.
- **Recovery and wakes:** the present expired-control adoption implementation has a factorable one-row transactional body. The proposed exact owner/version/lease checks, atomic attempt-journal reconciliation, live-lease future wake, renewed-expiry re-read, and cancel/join before adopting a locally registered producer address the concrete existing seams. Recovery does not authorize remote dispatch or invent zero usage.
- **Exact scope:** the four new A2 source paths are explicit and distinct from A1's four paths. The four proposed Provider edits are already members of the existing exact five-file `r9fProviderCompletionHandleFiles` set; MockProvider is not added to this change. The plan preserves the frozen manifest, historical counts/hashes and existing successor sets. No new domain-contract, resolver, Package, RunTests, AppStore or Orchestrator edit is implied by this approval.

The local size limits, `workerAttemptsExhausted` wait presentation, throwing worker seam, synchronous terminal callback, closed diagnostic formatter and exact A2 successor set are approved ordinary technical choices for this plan. No additional user product decision is required by this review.

## Gates retained

A1 is not implemented/reviewed. A2 must consume its actual reviewed interfaces and refresh preimages at entry; material drift requires scoped review. The parent's runtime gate remains red. The reported host resource block (approximately 4.6 GiB available and pressure level 2) was not remeasured or cleared here. No build, test, app, network, Provider, key access, process signal, commit or additional agent was run by this review.

A3 still must bind the real AppStore bootstrap, halt, shutdown and runtime/consent mutation paths to the driver gate/cancel/join ordering. This Core-only approval does not establish an application-wide halt fence. A2 implementation requires its real DB/transport/producer tests and independent implementation review; authoritative unfiltered tests, strict App build and later isolated application acceptance remain separate gates.

## Input identity and preservation

Confirmed unchanged approved dependency hashes:

```text
a6166c3fb5b9622450a20d614c01dd5ea87dfbdf79ded48656c353e925a5d5c5  goal-flow-plan.md
c2f0a874bdaf4bfcd1a4d31f8a31c88199d51fd1a92f0b35274a945fe893b4fc  goal-foundation-plan.md
5412316a2d651e07d7be9a0cfecc2b88eb158faace7c9ac4ef7032dd2e4f0882  goal-output-policy-plan-review.md
7eed55faf2fde3a87460c5914977faa948607a581b58d6edf7ae02f31f81966d  goal-driver-plan.md
```

Only this review artifact was written. Pre-existing dirty changes were preserved. A before/after artifact-write hash comparison covers the six reviewed task documents and thirteen inspected source files; no tested behavior or full-tree byte audit is claimed.
