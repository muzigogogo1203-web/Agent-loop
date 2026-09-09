# Independent native fixture entry review — 2026-09-08

Reviewer native_cli_entry_review, not implementer: approved once explicit pre-registration readiness exception is recorded. Root added it to plan and design before allowing edits.

Blocking clarification resolved: ready-file/resume-ready must precede stdin read because ExecutionEngineConformanceTests.swift:562–587 synchronously waits in send(SIGCONT), and CliProcessBackend.swift:1102–1115 creates the writer afterward. Mode remains alive with stdin open. Other modes may drain first.

Six-file scope, unchanged live environment/security, acknowledged same-group stderr holder and narrow failure cleanup, original206/102 plus derived101+one pinned historical successor accepted. Exact065 mode mapping verified. Implementation/evidence review required later; no full or product acceptance.

Reviewer performed no writes or workloads.
