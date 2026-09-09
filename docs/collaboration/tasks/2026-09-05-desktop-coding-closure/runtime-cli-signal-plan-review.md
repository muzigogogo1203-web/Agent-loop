# CLI signal diagnostics — independent parent plan review

Read the full 98-line plan SHA `b53902f981f98443d13dddbc8d64bb01569ae74893b4e63c36ba8f06919d181d`, checked the actual registry and fixture signal/report seams. Approved for exactly its three files, diagnostics only. A per-syscall UUID links source path, signed target, signal, actual result and immediately captured errno without changing snapshot/clear semantics or adding a signal. Joined decoded exit evidence remains explicitly distinct from raw wait status.

Entry sequencing: the plan's listed CliBackendTests.swift hash is its planning snapshot, not the source at the later entry. The currently authorized Board isolation writer owns that file. Wait for its release, preserve its completed changes, then capture a fresh three-file preimage and hash manifest for this signal-only diff. Do not restore the older hash or mix Board implementation into this review. ShellProcessRegistry.swift is already in the exact P1-E historical successor set; no new frozen-manifest exclusion is needed.

No readiness behavior fix is selected. Full observation waits for the Board tests, this source review and the separately bounded halt observability review; no repeated full run now. Retain original deadlines, errors, cancellation-result await count and all dirty changes.
