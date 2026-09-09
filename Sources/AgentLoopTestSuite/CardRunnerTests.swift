import Darwin
import Testing
import Foundation
@testable import AgentLoopCore

@Test func runnerDrivesCompletionThroughBoardSinkAndReportsUsage()
    async throws
{
    let workspace = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
        at: workspace,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: workspace) }
    try "内容".write(
        to: workspace.appendingPathComponent("out.md"),
        atomically: true,
        encoding: .utf8
    )
    let handoffInput: JSONValue = [
        "outcome": "ok",
        "summary": "s",
        "artifacts": [["relativePath": "out.md", "kind": "markdown", "label": "产出"]],
        "verification": [["method": "重读", "passed": true, "note": "ok"]],
        "risks": [],
    ]
    let mock = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "t1", name: "complete_card", input: handoffInput)],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 100, outputTokens: 50)
        ),
        TurnResult(
            content: [.toolUse(id: "t2", name: "complete_card", input: handoffInput)],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 100, outputTokens: 50)
        ),
    ])
    let runner = CardRunner(
        provider: mock,
        capabilityToolsResolver: { _, _ in [] },
        maxTurns: 10,
        retryDelays: []
    )
    let request = try cardRunnerTestRequest()
    let terminal = CardRunnerTestTerminalRecorder()
    let board = CardRunnerTestBoardRecorder()
    let progress = CardRunnerTestProgressRecorder()
    let events = try await cardRunnerTestExecute(
        runner,
        workspaceURL: workspace,
        request: request,
        terminal: terminal,
        board: board,
        progress: progress
    )
    let secondEvents = try await cardRunnerTestExecute(
        runner,
        workspaceURL: workspace,
        request: request,
        terminal: terminal,
        board: board,
        progress: progress
    )

    #expect(events.first == .accepted)
    #expect(secondEvents.first == .accepted)
    #expect(events.contains(.toolActivity(name: "complete_card")))
    #expect(events.contains(.usage(EngineUsageV1(
        inputTokens: 100,
        outputTokens: 50,
        cacheReadTokens: 0,
        costMicros: 0
    ))))
    #expect(await terminal.snapshot().isEmpty)
    #expect(await progress.snapshot().isEmpty)
    let intents = await board.snapshot()
    #expect(intents.count == 2)
    guard case let .completed(handoff) = try #require(intents.first) else {
        Issue.record("complete_card must terminate through the Board sink")
        return
    }
    #expect(handoff.outcome == "ok")
    #expect(handoff.summary == "s")
    #expect(handoff.artifacts == [
        HandoffPayload.ArtifactDecl(
            relativePath: "out.md",
            kind: "markdown",
            label: "产出"
        )
    ])
    #expect(handoff.verification == [
        HandoffPayload.Verification(
            method: "重读",
            passed: true,
            note: "ok"
        )
    ])
    #expect(intents.dropFirst().first == .completed(handoff: handoff))
}

@Test func runnerConsumerCancellationSubmitsCanceledIntent() async throws {
    actor LifecycleProbe {
        private struct Waiter {
            let event: EngineAdapterCancellationLifecycleEventV1
            let expectedCount: Int
            let continuation: CheckedContinuation<Void, Never>
        }

        private var events: [EngineAdapterCancellationLifecycleEventV1] = []
        private var waiters: [Waiter] = []

        func record(_ event: EngineAdapterCancellationLifecycleEventV1) {
            events.append(event)
            let ready = waiters.filter { waiter in
                events.filter { $0 == waiter.event }.count
                    >= waiter.expectedCount
            }
            waiters.removeAll { waiter in
                ready.contains { $0.event == waiter.event
                    && $0.expectedCount == waiter.expectedCount }
            }
            ready.forEach { $0.continuation.resume() }
        }

        func wait(
            for event: EngineAdapterCancellationLifecycleEventV1,
            count expectedCount: Int
        ) async {
            if events.filter({ $0 == event }).count >= expectedCount { return }
            await withCheckedContinuation { continuation in
                waiters.append(Waiter(
                    event: event,
                    expectedCount: expectedCount,
                    continuation: continuation
                ))
            }
        }
    }

    actor CountingCancellationProvider: LLMProvider {
        private struct Waiter {
            let expectedCount: Int
            let continuation: CheckedContinuation<Void, Never>
        }

        private var starts = 0
        private var terminations = 0
        private var startWaiters: [Waiter] = []
        private var terminationWaiters: [Waiter] = []

        nonisolated func streamTurn(
            system: String,
            history: [APIMessage],
            tools: [ToolDef],
            toolChoice: ToolChoice,
            maxTokens: Int
        ) -> AsyncThrowingStream<ProviderEvent, Error> {
            AsyncThrowingStream { continuation in
                let task = Task {
                    await self.markStarted()
                    do {
                        try await Task.sleep(for: .seconds(3_600))
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in
                    task.cancel()
                    Task { await self.markTerminated() }
                }
            }
        }

        func waitUntilStarted(_ expectedCount: Int) async {
            await wait(
                expectedCount,
                snapshot: { starts },
                append: { startWaiters.append($0) }
            )
        }

        func waitUntilTerminated(_ expectedCount: Int) async {
            await wait(
                expectedCount,
                snapshot: { terminations },
                append: { terminationWaiters.append($0) }
            )
        }

        func terminationCount() -> Int { terminations }

        private func markStarted() {
            starts += 1
            resumeReady(starts, waiters: &startWaiters)
        }

        private func markTerminated() {
            terminations += 1
            resumeReady(terminations, waiters: &terminationWaiters)
        }

        private func wait(
            _ expectedCount: Int,
            snapshot: () -> Int,
            append: (Waiter) -> Void
        ) async {
            if snapshot() >= expectedCount { return }
            await withCheckedContinuation { continuation in
                append(Waiter(
                    expectedCount: expectedCount,
                    continuation: continuation
                ))
            }
        }

        private func resumeReady(
            _ count: Int,
            waiters: inout [Waiter]
        ) {
            let ready = waiters.filter { $0.expectedCount <= count }
            waiters.removeAll { $0.expectedCount <= count }
            ready.forEach { $0.continuation.resume() }
        }
    }

    let workspace = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
        at: workspace,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: workspace) }
    let provider = CountingCancellationProvider()
    let runnerLifecycle = LifecycleProbe()
    let runner = CardRunner(
        provider: provider,
        capabilityToolsResolver: { _, _ in [] },
        cancellationLifecycleObserver: { event in
            Task { await runnerLifecycle.record(event) }
        }
    )
    let terminal = CardRunnerTestTerminalRecorder()
    let board = CardRunnerTestBoardRecorder()
    let progress = CardRunnerTestProgressRecorder()
    let request = try cardRunnerTestRequest()
    let profile = RuntimeProfileRecord(
        id: request.profileId,
        kind: .openAIAPI,
        name: "round3 CardRunner ModelLoop seam",
        baseURL: nil,
        credentialAccount: nil,
        isDefault: false,
        createdAt: Date(timeIntervalSince1970: 4_000_000)
    )
    let adapterLifecycle = LifecycleProbe()
    let adapter = ModelLoopEngineAdapter(
        profile: profile,
        descriptor: p1f1d071Descriptor(),
        driver: runner,
        context: try cardRunnerTestContext(),
        workspace: try p1f1d071Workspace(
            workspace,
            campId: request.campId,
            squadId: "00000000-0000-4000-8000-000000000082"
        ),
        boundCapabilityTools: cardRunnerTestBoundCapabilityTools(),
        terminalSink: terminal,
        boardTerminalSink: board,
        progressSink: progress,
        cancellationLifecycleObserver: { event in
            Task { await adapterLifecycle.record(event) }
        }
    )

    func consume() async -> String {
        do {
            for try await _ in adapter.execute(request: request) {}
            return "success"
        } catch is CancellationError {
            return "success"
        } catch is EngineDispatchConflictErrorV1 {
            return "registry_conflict"
        } catch {
            Issue.record("unexpected CardRunner→ModelLoop error: \(error)")
            return "unexpected_failure"
        }
    }

    let consumerTask = Task { await consume() }
    await provider.waitUntilStarted(1)
    consumerTask.cancel()
    await runnerLifecycle.wait(
        for: .cancellationOwnerSettled,
        count: 1
    )
    await adapterLifecycle.wait(
        for: .cancellationOwnerSettled,
        count: 1
    )
    await provider.waitUntilTerminated(1)
    try await adapter.cancel(executionId: request.executionId)
    #expect(await consumerTask.value == "success")
    #expect(await provider.terminationCount() == 1)

    let reuseConsumer = Task { await consume() }
    await provider.waitUntilStarted(2)
    try await adapter.cancel(executionId: request.executionId)
    await provider.waitUntilTerminated(2)
    #expect(await reuseConsumer.value == "success")
    #expect(await provider.terminationCount() == 2)
    #expect(await terminal.snapshot().isEmpty)
    #expect(await board.snapshot().isEmpty)
    #expect(await progress.snapshot().isEmpty)
}

@Test func cancelDuringArmedTimeoutSubmitsCanceledIntent() async throws {
    actor LifecycleProbe {
        private struct Waiter {
            let event: EngineAdapterCancellationLifecycleEventV1
            let expectedCount: Int
            let continuation: CheckedContinuation<Void, Never>
        }

        private var events: [EngineAdapterCancellationLifecycleEventV1] = []
        private var waiters: [Waiter] = []

        func record(_ event: EngineAdapterCancellationLifecycleEventV1) {
            events.append(event)
            let ready = waiters.filter { waiter in
                events.filter { $0 == waiter.event }.count
                    >= waiter.expectedCount
            }
            waiters.removeAll { waiter in
                ready.contains { $0.event == waiter.event
                    && $0.expectedCount == waiter.expectedCount }
            }
            ready.forEach { $0.continuation.resume() }
        }

        func count(_ event: EngineAdapterCancellationLifecycleEventV1) -> Int {
            events.filter { $0 == event }.count
        }

        func wait(
            for event: EngineAdapterCancellationLifecycleEventV1,
            count expectedCount: Int
        ) async {
            if events.filter({ $0 == event }).count >= expectedCount { return }
            await withCheckedContinuation { continuation in
                waiters.append(Waiter(
                    event: event,
                    expectedCount: expectedCount,
                    continuation: continuation
                ))
            }
        }
    }

    final class ClaimBarrier: @unchecked Sendable {
        private let condition = NSCondition()
        private var armed = false
        private var entered = false
        private var released = false
        private var enteredWaiters: [CheckedContinuation<Void, Never>] = []

        func arm() {
            condition.lock()
            precondition(!armed && !entered, "duplicate CardRunner claim arm")
            armed = true
            condition.unlock()
        }

        func enterIfArmed() {
            condition.lock()
            guard armed else {
                condition.unlock()
                return
            }
            armed = false
            entered = true
            let waiters = enteredWaiters
            enteredWaiters.removeAll()
            condition.unlock()
            waiters.forEach { $0.resume() }
            condition.lock()
            while !released { condition.wait() }
            condition.unlock()
        }

        func waitUntilEntered() async {
            await withCheckedContinuation { continuation in
                condition.lock()
                if entered {
                    condition.unlock()
                    continuation.resume()
                } else {
                    enteredWaiters.append(continuation)
                    condition.unlock()
                }
            }
        }

        func release() {
            condition.lock()
            precondition(entered && !released, "invalid CardRunner claim release")
            released = true
            condition.broadcast()
            condition.unlock()
        }
    }

    actor CleanupFailingProvider: LLMProvider, LLMProviderRunDrivingV1 {
        private typealias Continuation = AsyncThrowingStream<
            ProviderEvent,
            Error
        >.Continuation

        private var startedCount = 0
        private var startedWaiters:
            [Int: [CheckedContinuation<Void, Never>]] = [:]
        private var cleanupAttempts: [Int: Int] = [:]
        private var cleanupWaiters:
            [Int: [CheckedContinuation<Void, Never>]] = [:]
        private var cleanupReleaseWaiters:
            [Int: [CheckedContinuation<Void, Never>]] = [:]
        private var releasedCleanups: Set<Int> = []
        private var continuations: [Int: Continuation] = [:]
        private var externallyFinished: Set<Int> = []

        nonisolated func streamTurn(
            system: String,
            history: [APIMessage],
            tools: [ToolDef],
            toolChoice: ToolChoice,
            maxTokens: Int
        ) -> AsyncThrowingStream<ProviderEvent, Error> {
            startTurn(
                system: system,
                history: history,
                tools: tools,
                toolChoice: toolChoice,
                maxTokens: maxTokens
            ).events
        }

        package nonisolated func startTurn(
            system: String,
            history: [APIMessage],
            tools: [ToolDef],
            toolChoice: ToolChoice,
            maxTokens: Int
        ) -> LLMProviderTurnRunV1 {
            makeLLMProviderTurnRunV1 { continuation in
                let generation = await self.markStarted(continuation)
                do {
                    while !Task.isCancelled {
                        try await Task.sleep(for: .seconds(3600))
                    }
                } catch {
                    if await self.consumeExternalFinish(generation) {
                        return
                    }
                    await self.waitForCleanupRelease(generation)
                    throw EngineDispatchConflictErrorV1()
                }
            }
        }

        func waitUntilStarted(_ expectedCount: Int) async {
            if startedCount >= expectedCount { return }
            await withCheckedContinuation {
                startedWaiters[expectedCount, default: []].append($0)
            }
        }

        func waitUntilCleanupStarted(_ generation: Int) async {
            if cleanupAttempts[generation, default: 0] > 0 { return }
            await withCheckedContinuation {
                cleanupWaiters[generation, default: []].append($0)
            }
        }

        func releaseCleanup(_ generation: Int) {
            releasedCleanups.insert(generation)
            let current = cleanupReleaseWaiters.removeValue(
                forKey: generation
            ) ?? []
            current.forEach { $0.resume() }
        }

        func cleanupSnapshot() -> [Int] {
            [
                cleanupAttempts[1, default: 0],
                cleanupAttempts[2, default: 0],
            ]
        }

        func cleanupCount(_ generation: Int) -> Int {
            cleanupAttempts[generation, default: 0]
        }

        func finishWithCancellation(_ generation: Int) throws {
            guard let continuation = continuations[generation] else {
                throw EngineDispatchConflictErrorV1()
            }
            externallyFinished.insert(generation)
            continuation.finish(throwing: CancellationError())
        }

        private func markStarted(_ continuation: Continuation) -> Int {
            startedCount += 1
            let generation = startedCount
            continuations[generation] = continuation
            let readyKeys = startedWaiters.keys.filter { $0 <= startedCount }
            for key in readyKeys {
                let current = startedWaiters.removeValue(forKey: key) ?? []
                current.forEach { $0.resume() }
            }
            return generation
        }

        private func consumeExternalFinish(_ generation: Int) -> Bool {
            externallyFinished.remove(generation) != nil
        }

        private func waitForCleanupRelease(_ generation: Int) async {
            cleanupAttempts[generation, default: 0] += 1
            let current = cleanupWaiters.removeValue(
                forKey: generation
            ) ?? []
            current.forEach { $0.resume() }
            if releasedCleanups.contains(generation) { return }
            await withCheckedContinuation {
                cleanupReleaseWaiters[generation, default: []].append($0)
            }
        }
    }

    let workspace = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
        at: workspace,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: workspace) }
    let provider = CleanupFailingProvider()
    let claimBarrier = ClaimBarrier()
    let runnerLifecycle = LifecycleProbe()
    let runner = CardRunner(
        provider: provider,
        capabilityToolsResolver: { _, _ in [] },
        turnTimeout: .seconds(3_600),
        cancellationLifecycleObserver: { event in
            if event == .claimLookup { claimBarrier.enterIfArmed() }
            Task { await runnerLifecycle.record(event) }
        }
    )
    let terminal = CardRunnerTestTerminalRecorder()
    let board = CardRunnerTestBoardRecorder()
    let progress = CardRunnerTestProgressRecorder()
    let request = try cardRunnerTestRequest()
    let profile = RuntimeProfileRecord(
        id: request.profileId,
        kind: .openAIAPI,
        name: "round3 generation-bound CardRunner seam",
        baseURL: nil,
        credentialAccount: nil,
        isDefault: false,
        createdAt: Date(timeIntervalSince1970: 4_000_000)
    )
    let context = try cardRunnerTestContext()
    let resolvedWorkspace = try p1f1d071Workspace(
        workspace,
        campId: request.campId,
        squadId: "00000000-0000-4000-8000-000000000082"
    )
    let adapterLifecycle = LifecycleProbe()
    let adapter = ModelLoopEngineAdapter(
        profile: profile,
        descriptor: p1f1d071Descriptor(),
        driver: runner,
        context: context,
        workspace: resolvedWorkspace,
        boundCapabilityTools: cardRunnerTestBoundCapabilityTools(),
        terminalSink: terminal,
        boardTerminalSink: board,
        progressSink: progress,
        cancellationLifecycleObserver: { event in
            Task { await adapterLifecycle.record(event) }
        }
    )

    func claimResult(_ claim: EngineAdapterCancellationClaimV1) async -> String {
        do {
            try await claim.wait()
            return "success"
        } catch is EngineDispatchConflictErrorV1 {
            return "cleanup_failure"
        } catch is CancellationError {
            return "success"
        } catch {
            return "unexpected_failure"
        }
    }

    func operationResult(
        _ operation: @escaping @Sendable () async throws -> Void
    ) async -> String {
        do {
            try await operation()
            return "success"
        } catch is EngineDispatchConflictErrorV1 {
            return "cleanup_failure"
        } catch is CancellationError {
            return "success"
        } catch {
            return "unexpected_failure"
        }
    }

    func adapterConsumerResult() async -> String {
        await operationResult {
            for try await _ in adapter.execute(request: request) {}
        }
    }

    func runnerConsumerResult() async -> String {
        await operationResult {
            for try await _ in runner.execute(
                request: request,
                context: context,
                workspaceURL: resolvedWorkspace.url,
                terminalSink: terminal,
                boardTerminalSink: board,
                progressSink: progress
            ) {}
        }
    }

    let firstConsumer = Task { await adapterConsumerResult() }
    await provider.waitUntilStarted(1)
    firstConsumer.cancel()
    await provider.waitUntilCleanupStarted(1)
    #expect(await provider.cleanupCount(1) == 1)
    await provider.releaseCleanup(1)
    await runnerLifecycle.wait(
        for: .cancellationOwnerSettled,
        count: 1
    )
    await adapterLifecycle.wait(
        for: .cancellationOwnerSettled,
        count: 1
    )
    let firstCancelOutcome = await operationResult {
        try await adapter.cancel(executionId: request.executionId)
    }
    #expect(firstCancelOutcome == "cleanup_failure")
    #expect(await provider.cleanupCount(1) == 1)
    _ = await firstConsumer.value

    let secondConsumer = Task { await adapterConsumerResult() }
    await provider.waitUntilStarted(2)
    let secondCancel = Task {
        await operationResult {
            try await adapter.cancel(executionId: request.executionId)
        }
    }
    await provider.waitUntilCleanupStarted(2)
    await provider.releaseCleanup(2)
    let secondCancelOutcome = await secondCancel.value
    let secondConsumerOutcome = await secondConsumer.value
    #expect(secondCancelOutcome == "cleanup_failure")
    #expect(secondConsumerOutcome == "cleanup_failure")
    #expect(await provider.cleanupCount(2) == 1)

    let atomicConsumer = Task { await runnerConsumerResult() }
    await provider.waitUntilStarted(3)
    let priorOutcomeCount = await runnerLifecycle.count(
        .generationOutcomePublished
    )
    claimBarrier.arm()
    let atomicClaimTask = Task {
        try await runner.claimCancellation(executionId: request.executionId)
    }
    await claimBarrier.waitUntilEntered()
    try await provider.finishWithCancellation(3)
    await runnerLifecycle.wait(
        for: .generationOutcomePublished,
        count: priorOutcomeCount + 1
    )
    claimBarrier.release()
    let atomicClaim = try await atomicClaimTask.value
    #expect(await claimResult(atomicClaim) == "success")
    #expect(await atomicConsumer.value == "success")
    #expect(
        await runnerConsumerResult() == "cleanup_failure"
    )
    runner.acknowledgeCancellation(atomicClaim)

    let reuseConsumer = Task { await runnerConsumerResult() }
    await provider.waitUntilStarted(4)
    let reuseClaim = try await runner.claimCancellation(
        executionId: request.executionId
    )
    await provider.waitUntilCleanupStarted(4)
    await provider.releaseCleanup(4)
    let reuseClaimOutcome = await claimResult(reuseClaim)
    #expect(reuseClaimOutcome == "cleanup_failure")
    runner.acknowledgeCancellation(reuseClaim)
    let reuseConsumerOutcome = await reuseConsumer.value
    #expect(reuseConsumerOutcome == "cleanup_failure")
    #expect(await provider.cleanupCount(4) == 1)

    #expect(await provider.cleanupSnapshot() == [1, 1])
    #expect(await terminal.snapshot().isEmpty)
    #expect(await board.snapshot().isEmpty)
    #expect(await progress.snapshot().isEmpty)
}

@Test func runnerTransportErrorSubmitsSafeFailedIntent() async throws {
    let workspace = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
        at: workspace,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: workspace) }
    let mock = MockProvider(script: [])
    let runner = CardRunner(
        provider: mock,
        capabilityToolsResolver: { _, _ in [] },
        retryDelays: [.milliseconds(1), .milliseconds(1)]
    )
    let terminal = CardRunnerTestTerminalRecorder()
    let board = CardRunnerTestBoardRecorder()
    let progress = CardRunnerTestProgressRecorder()
    let events = try await cardRunnerTestExecute(
        runner,
        workspaceURL: workspace,
        terminal: terminal,
        board: board,
        progress: progress
    )

    #expect(events.first == .accepted)
    #expect(await terminal.snapshot() == [.failed(
        code: "engine_provider_error",
        detail: "ModelLoop execution failed."
    )])
    #expect(await board.snapshot().isEmpty)
}

@Test func runnerRoutesLoopSelfBlockThroughTerminalSink() async throws {
    let workspace = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
        at: workspace,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: workspace) }
    let mock = MockProvider(script: [
        TurnResult(content: [.text("done?")], stopReason: .endTurn),
        TurnResult(content: [.text("still done")], stopReason: .endTurn),
    ])
    let runner = CardRunner(
        provider: mock,
        capabilityToolsResolver: { _, _ in [] },
        maxTurns: 10,
        retryDelays: []
    )
    let terminal = CardRunnerTestTerminalRecorder()
    let board = CardRunnerTestBoardRecorder()
    let progress = CardRunnerTestProgressRecorder()
    _ = try await cardRunnerTestExecute(
        runner,
        workspaceURL: workspace,
        terminal: terminal,
        board: board,
        progress: progress
    )

    let intents = await terminal.snapshot()
    #expect(intents.count == 1)
    guard case let .blocked(subtype, reason, detail) =
        try #require(intents.first)
    else {
        Issue.record("loop self-block must terminate through terminal sink")
        return
    }
    #expect(subtype == .ordinary)
    #expect(reason == "no_terminator")
    #expect(detail.contains("complete_card / block_card"))
    #expect(await board.snapshot().isEmpty)
}

private actor RunnerHangingProvider: LLMProvider {
    private var started = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    nonisolated func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await self.markStarted()
                do {
                    while !Task.isCancelled {
                        try await Task.sleep(for: .seconds(3600))
                    }
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func markStarted() {
        started = true
        let current = waiters
        waiters.removeAll()
        for waiter in current {
            waiter.resume()
        }
    }
}

// MARK: - 工具白名单（M6-D4）

@Test func whitelistStripsDisallowedToolFromRunner() async throws {
    // 白名单只允许 read_file：write_file 不进提示词工具区、调用被拒、文件不落盘
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let workspace = base.appendingPathComponent("ws")
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }
    let mock = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "t1", name: "write_file",
                               input: ["path": "x.md", "content": "hi"])],
            stopReason: .toolUse
        ),
        TurnResult(
            content: [.toolUse(id: "t2", name: "complete_card", input: [
                "outcome": "o", "summary": "s",
                "noArtifactReason": "无写文件权限，结论在摘要里",
                "verification": [["method": "自查", "passed": true, "note": "ok"]],
                "risks": [],
            ])],
            stopReason: .toolUse
        ),
    ])
    let access = ToolAccess.parse(toolsJson: #"{"v":2,"allow":["read_file"]}"#)
    let runner = CardRunner(
        provider: mock,
        capabilityToolsResolver: { _, resolvedWorkspace in
            guard access.allows("read_file") else { return [] }
            return [ExternalTool(
                def: .readFile,
                handler: FileToolHandler(
                    tools: FileTools(workspaceRoot: resolvedWorkspace),
                    op: .read
                )
            )]
        },
        retryDelays: []
    )
    let terminal = CardRunnerTestTerminalRecorder()
    let board = CardRunnerTestBoardRecorder()
    let progress = CardRunnerTestProgressRecorder()
    _ = try await cardRunnerTestExecute(
        runner,
        workspaceURL: workspace,
        terminal: terminal,
        board: board,
        progress: progress
    )

    #expect(!FileManager.default.fileExists(atPath: workspace.appendingPathComponent("x.md").path))
    let firstTurnTools = Set(
        await mock.recordedTools.first?.map(\.name) ?? []
    )
    #expect(firstTurnTools == ToolAccess.boardToolNames.union(["read_file"]))
    #expect(await terminal.snapshot().isEmpty)
    #expect(await board.snapshot().count == 1)
}

@Test func malformedWhitelistExposesOnlyBoardToolsFromRunner() async throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let workspace = base.appendingPathComponent("ws")
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }
    let mock = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "t1", name: "complete_card", input: [
                "outcome": "o", "summary": "s",
                "noArtifactReason": "无文件产物",
                "verification": [["method": "自查", "passed": true, "note": "ok"]],
                "risks": [],
            ])],
            stopReason: .toolUse
        ),
    ])
    let access = ToolAccess.parse(toolsJson: "malformed")
    let external = ExternalTool(
        def: ToolDef(
            name: "mcp__test__read",
            description: "test",
            inputSchema: ["type": "object"]
        ),
        handler: ClosureToolHandler { _ in .result("ok") }
    )

    #expect(access.parseFailed)
    let runner = CardRunner(
        provider: mock,
        capabilityToolsResolver: { _, _ in
            access.parseFailed ? [] : [external]
        },
        retryDelays: []
    )
    let terminal = CardRunnerTestTerminalRecorder()
    let board = CardRunnerTestBoardRecorder()
    let progress = CardRunnerTestProgressRecorder()
    _ = try await cardRunnerTestExecute(
        runner,
        workspaceURL: workspace,
        terminal: terminal,
        board: board,
        progress: progress
    )

    let firstTurnTools = Set(await mock.recordedTools.first?.map(\.name) ?? [])
    #expect(firstTurnTools == ToolAccess.boardToolNames)
    #expect(await terminal.snapshot().isEmpty)
    #expect(await board.snapshot().count == 1)
}

private struct P1F1D071DatabaseProjection: Equatable {
    let cardJSON: String
    let missionJSON: String
    let runsJSON: String
    let proposalsJSON: String
    let domainEventsJSON: String
    let legacyEventsJSON: String
}

private func p1f1d071CanonicalJSON<Value: Encodable>(
    _ value: Value
) throws -> String {
    String(decoding: try CanonicalJSONV1.encode(value), as: UTF8.self)
}

private func p1f1d071Projection(
    database: AppDatabase,
    cardId: String
) throws -> P1F1D071DatabaseProjection {
    let card = try #require(try database.card(id: cardId))
    let mission = try #require(try database.mission(id: card.missionId))
    let proposals = try database.pool.read { db in
        try EngineTerminalProposalRecord.fetchAll(
            db,
            sql: "SELECT * FROM engine_terminal_proposal ORDER BY id"
        )
    }
    let domainEvents = try database.pool.read { db in
        try DomainEventRecordV1.fetchAll(
            db,
            sql: "SELECT * FROM domain_event ORDER BY id"
        )
    }
    return P1F1D071DatabaseProjection(
        cardJSON: try p1f1d071CanonicalJSON(card),
        missionJSON: try p1f1d071CanonicalJSON(mission),
        runsJSON: try p1f1d071CanonicalJSON(
            database.runs(cardId: cardId)
        ),
        proposalsJSON: try p1f1d071CanonicalJSON(proposals),
        domainEventsJSON: try p1f1d071CanonicalJSON(domainEvents),
        legacyEventsJSON: try p1f1d071CanonicalJSON(
            database.events(cardId: cardId)
        )
    )
}

private func p1f1d071AssertDBFreeSource(
    _ relativePath: String
) throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: repositoryRoot.appendingPathComponent(relativePath),
        encoding: .utf8
    )
    for forbidden in [
        "AppDatabase", "startRun(", "finishRun(", "completeCard(",
        "blockCard(", "transitionMission(",
    ] {
        #expect(
            !source.contains(forbidden),
            "\(relativePath) retains forbidden mutation authority: \(forbidden)"
        )
    }
}

actor P1F1D071TerminalRecorder: EngineTerminalSink {
    private var intents: [EngineTerminalIntentV1] = []

    func submit(_ intent: EngineTerminalIntentV1) async throws {
        intents.append(intent)
    }

    func snapshot() -> [EngineTerminalIntentV1] { intents }
}

actor P1F1D071BoardRecorder: EngineBoardTerminalSink {
    private var intents: [EngineBoardTerminalIntentV1] = []
    private let onSubmit: (@Sendable () async throws -> Void)?

    init(
        onSubmit: (@Sendable () async throws -> Void)? = nil
    ) {
        self.onSubmit = onSubmit
    }

    func submit(_ intent: EngineBoardTerminalIntentV1) async throws {
        if let onSubmit {
            try await onSubmit()
        }
        intents.append(intent)
    }

    func snapshot() -> [EngineBoardTerminalIntentV1] { intents }
}

actor P1F1D071ProgressRecorder: EngineProgressSink {
    private var payloads: [EngineExecutionEventPayloadV1] = []

    func submit(_ payload: EngineExecutionEventPayloadV1) async throws {
        payloads.append(payload)
    }

    func snapshot() -> [EngineExecutionEventPayloadV1] { payloads }
}

private struct P1F1D071DriverSnapshot: Sendable {
    let request: EngineExecutionRequest
    let contextHash: String
    let workspaceURL: URL
    let terminalSinkMatched: Bool
    let boardSinkMatched: Bool
    let progressSinkMatched: Bool
}

private final class P1F1D071ModelDriver:
    ModelLoopExecutionDrivingV1, @unchecked Sendable
{
    private let lock = NSLock()
    private let expectedTerminal: P1F1D071TerminalRecorder
    private let expectedBoard: P1F1D071BoardRecorder
    private let expectedProgress: P1F1D071ProgressRecorder
    private var stored: P1F1D071DriverSnapshot?

    init(
        terminal: P1F1D071TerminalRecorder,
        board: P1F1D071BoardRecorder,
        progress: P1F1D071ProgressRecorder
    ) {
        expectedTerminal = terminal
        expectedBoard = board
        expectedProgress = progress
    }

    func execute(
        request: EngineExecutionRequest,
        context: EngineResolvedContextTransportV1,
        workspaceURL: URL,
        terminalSink: any EngineTerminalSink,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink
    ) -> AsyncThrowingStream<EngineExecutionEventPayloadV1, Error> {
        let snapshot = P1F1D071DriverSnapshot(
            request: request,
            contextHash: context.hash,
            workspaceURL: workspaceURL,
            terminalSinkMatched:
                (terminalSink as? P1F1D071TerminalRecorder)
                    === expectedTerminal,
            boardSinkMatched:
                (boardTerminalSink as? P1F1D071BoardRecorder)
                    === expectedBoard,
            progressSinkMatched:
                (progressSink as? P1F1D071ProgressRecorder)
                    === expectedProgress
        )
        lock.lock()
        stored = snapshot
        lock.unlock()
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await progressSink.submit(
                        .progress(message: "model-loop-driver-started")
                    )
                    try await boardTerminalSink.submit(
                        .completed(
                            handoff: HandoffPayload(
                                outcome: "implemented",
                                summary: "DB-free ModelLoop proposal",
                                artifacts: [],
                                noArtifactReason: "No file in adapter seam.",
                                verification: [],
                                risks: []
                            )
                        )
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func cancel(executionId: String) async throws {}

    var snapshot: P1F1D071DriverSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

private struct P1F1D071ProviderResolveCall: Sendable, Equatable {
    let profile: RuntimeProfileRecord
    let companionId: String
    let model: String
    let policy: CompanionModelPolicy
}

private final class P1F1D071FactoryLedger: @unchecked Sendable {
    private let lock = NSLock()
    private var providerResolveStorage: [P1F1D071ProviderResolveCall] = []
    private var counts: [String: Int] = [:]

    func record(_ name: String) {
        lock.withLock { counts[name, default: 0] += 1 }
    }

    func recordProviderResolve(_ call: P1F1D071ProviderResolveCall) {
        lock.withLock { providerResolveStorage.append(call) }
    }

    func count(_ name: String) -> Int {
        lock.withLock { counts[name, default: 0] }
    }

    var providerResolveCalls: [P1F1D071ProviderResolveCall] {
        lock.withLock { providerResolveStorage }
    }
}

private final class P1F1D079AuthorityLedger: @unchecked Sendable {
    private let lock = NSLock()
    private var authorities: [CliExecutableAuthorityV1] = []
    private var counts: [String: Int] = [:]

    func append(_ authority: CliExecutableAuthorityV1) {
        lock.withLock { authorities.append(authority) }
    }

    func record(_ name: String) {
        lock.withLock { counts[name, default: 0] += 1 }
    }

    var receivedAuthorities: [CliExecutableAuthorityV1] {
        lock.withLock { authorities }
    }

    func count(_ name: String) -> Int {
        lock.withLock { counts[name, default: 0] }
    }
}

private enum P1F1D079SignatureCall: Sendable, Equatable {
    case cli
    case boardBridge
}

private enum P1F1D079SignatureFixtureError: Error, Sendable, Equatable {
    case injected(P1F1D079SignatureCall)
}

private final class P1F1D079SignatureRevalidator:
    CliProcessCodeSignatureRevalidatingV1, @unchecked Sendable
{
    private let expectedCLI: CliExecutableAuthorityV1
    private let expectedBoardBridge: EngineBoardBridgeExecutableAuthorityV1
    private let injectedFailure: P1F1D079SignatureCall?
    private let lock = NSLock()
    private var calls: [P1F1D079SignatureCall] = []

    init(
        expectedCLI: CliExecutableAuthorityV1,
        expectedBoardBridge: EngineBoardBridgeExecutableAuthorityV1,
        injectedFailure: P1F1D079SignatureCall? = nil
    ) {
        self.expectedCLI = expectedCLI
        self.expectedBoardBridge = expectedBoardBridge
        self.injectedFailure = injectedFailure
    }

    func revalidateCLI(
        _ authority: CliExecutableAuthorityV1
    ) throws {
        try authority.validateCanonical()
        guard authority == expectedCLI else {
            throw EngineContextValidationErrorV1()
        }
        try record(.cli, expectedPrefix: [])
    }

    func revalidateBoardBridge(
        _ authority: EngineBoardBridgeExecutableAuthorityV1
    ) throws {
        try authority.validateCanonical()
        guard authority == expectedBoardBridge else {
            throw EngineContextValidationErrorV1()
        }
        try record(.boardBridge, expectedPrefix: [.cli])
    }

    func snapshot() -> [P1F1D079SignatureCall] {
        lock.withLock { calls }
    }

    private func record(
        _ call: P1F1D079SignatureCall,
        expectedPrefix: [P1F1D079SignatureCall]
    ) throws {
        try lock.withLock {
            guard calls == expectedPrefix else {
                throw EngineContextValidationErrorV1()
            }
            calls.append(call)
        }
        if injectedFailure == call {
            throw P1F1D079SignatureFixtureError.injected(call)
        }
    }
}

private final class P1F1D079ProcessInspector:
    EngineRuntimeProcessInspectingV1, @unchecked Sendable
{
    private let lock = NSLock()
    private let authority: CliExecutableAuthorityV1
    private var signalsStorage: [(Int32, Int32)] = []
    private var snapshotCallCount = 0
    private var existingGroupChecks = 0
    private var missingGroupChecks = 0

    init(authority: CliExecutableAuthorityV1) {
        self.authority = authority
    }

    func snapshots() throws -> [EngineRuntimeProcessSnapshotV1] {
        lock.withLock { snapshotCallCount += 1 }
        var pids = [pid_t](repeating: 0, count: 512)
        let count = pids.withUnsafeMutableBytes { bytes in
            proc_listchildpids(
                getpid(),
                bytes.baseAddress,
                Int32(bytes.count)
            )
        }
        guard count >= 0, Int(count) <= pids.count else {
            throw EngineContextValidationErrorV1()
        }
        return pids.prefix(Int(count)).compactMap { pid in
            guard pid > 0 else { return nil }
            let pgid = getpgid(pid)
            guard pgid > 0 else { return nil }
            return EngineRuntimeProcessSnapshotV1(
                pid: pid,
                processGroupId: pgid,
                uid: getuid(),
                startSeconds: 1,
                startMicroseconds: 0,
                executablePath: authority.stagedPath,
                executableDevice: authority.stagedDevice,
                executableInode: authority.stagedInode,
                executableHash: authority.executableHash,
                designatedRequirement: authority.designatedRequirement,
                cdHash: authority.cdHash
            )
        }
    }

    func send(signal: Int32, processGroupId: Int32) throws {
        lock.withLock {
            signalsStorage.append((signal, processGroupId))
        }
        guard Darwin.kill(-processGroupId, signal) == 0 || errno == ESRCH else {
            throw EngineContextValidationErrorV1()
        }
    }

    func processGroupExists(_ processGroupId: Int32) throws -> Bool {
        if Darwin.kill(-processGroupId, 0) == 0 {
            lock.withLock { existingGroupChecks += 1 }
            return true
        }
        if errno == ESRCH {
            lock.withLock { missingGroupChecks += 1 }
            return false
        }
        if errno == EPERM {
            lock.withLock { existingGroupChecks += 1 }
            return true
        }
        throw EngineContextValidationErrorV1()
    }

    var signals: [(Int32, Int32)] { lock.withLock { signalsStorage } }
    var snapshotsObserved: Int { lock.withLock { snapshotCallCount } }
    var observedExistingGroup: Bool {
        lock.withLock { existingGroupChecks > 0 }
    }
    var observedExactESRCH: Bool {
        lock.withLock { missingGroupChecks > 0 }
    }
}

private func p1f1d079Backend(
    registry: ShellProcessRegistry,
    processInspector: P1F1D079ProcessInspector,
    revalidator: any CliProcessCodeSignatureRevalidatingV1
) throws -> CliProcessBackend {
    try CliProcessBackend(
        registry: registry,
        processInspector: processInspector,
        codeSignatureRevalidator: revalidator
    )
}

private func p1f1d079SignatureGateRequest(
    executionId: String,
    executableAuthority: CliExecutableAuthorityV1,
    bridgeAuthority: EngineBoardBridgeExecutableAuthorityV1,
    workspaceURL: URL,
    directoryAuthority: EngineBoardSocketDirectoryAuthorityV1,
    cleanupAuthority: CliCleanupFileAuthorityV1,
    cardId: String,
    board: any EngineBoardTerminalSink,
    progress: any EngineProgressSink
) throws -> CliProcessLaunchRequestV1 {
    let socketURL = try BoardToolServer.makeSocketURL(
        directoryAuthority: directoryAuthority,
        executionId: executionId
    )
    return try CliProcessLaunchRequestV1(
        executionId: executionId,
        spec: CliCommandSpec(
            command: executableAuthority.stagedPath,
            arguments: [],
            environment: [:],
            stdinBytes: Data("p1f1d 079 signature gate".utf8),
            cleanupAuthorities: [cleanupAuthority]
        ),
        cliExecutableAuthority: executableAuthority,
        workspaceURL: workspaceURL,
        boundCapabilityTools: EngineBoundCapabilityToolsV1(
            logicalDefinitions: [
                .completeCard, .blockCard, .addProgressNote, .askUser,
            ],
            capabilityTools: []
        ),
        bridgeExecutableAuthority: bridgeAuthority,
        boardSocketDirectoryAuthority: directoryAuthority,
        boardSocketBasename: socketURL.lastPathComponent,
        boardToken: String(repeating: "9", count: 64),
        boardCardId: cardId,
        boardTerminalSink: board,
        progressSink: progress
    )
}

private enum P1F1D079DrainOutcome: Sendable {
    case backendFailure(CliProcessBackendError)
    case unexpectedFailure(String)
    case completedWithoutFailure
    case deadline
}

private enum P1F1D079ClosedStdioFixtureError: Error, Equatable {
    case invalidExecutable
    case fileActions(Int32)
    case spawn(Int32)
    case wait
    case status(Int32)
    case close(Int32)
    case evidence
    case residue
}

private func p1f1d079CStringVector(
    _ strings: [String]
) throws -> [UnsafeMutablePointer<CChar>?] {
    var result: [UnsafeMutablePointer<CChar>?] = []
    for string in strings {
        guard !string.utf8.contains(0), let pointer = strdup(string) else {
            result.forEach { if let pointer = $0 { free(pointer) } }
            throw P1F1D079ClosedStdioFixtureError.invalidExecutable
        }
        result.append(pointer)
    }
    result.append(nil)
    return result
}

private func p1f1d079FreeCStringVector(
    _ strings: [UnsafeMutablePointer<CChar>?]
) {
    strings.forEach { if let pointer = $0 { free(pointer) } }
}

private func p1f1d079RunClosedStdioSubprocess(
    base: URL,
    evidence: URL
) throws {
    let executable = URL(
        fileURLWithPath: CommandLine.arguments[0],
        relativeTo: URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
    ).standardizedFileURL.path
    guard executable.hasPrefix("/"),
          FileManager.default.isExecutableFile(atPath: executable)
    else {
        throw P1F1D079ClosedStdioFixtureError.invalidExecutable
    }

    var actions: posix_spawn_file_actions_t?
    var code = posix_spawn_file_actions_init(&actions)
    guard code == 0 else {
        throw P1F1D079ClosedStdioFixtureError.fileActions(code)
    }
    defer { posix_spawn_file_actions_destroy(&actions) }
    for (descriptor, flags) in [
        (STDIN_FILENO, O_RDONLY),
        (STDOUT_FILENO, O_WRONLY),
        (STDERR_FILENO, O_WRONLY),
    ] {
        code = "/dev/null".withCString { path in
            posix_spawn_file_actions_addopen(
                &actions,
                descriptor,
                path,
                flags,
                0
            )
        }
        guard code == 0 else {
            throw P1F1D079ClosedStdioFixtureError.fileActions(code)
        }
    }

    var arguments = try p1f1d079CStringVector([
        "/usr/bin/env",
        "AGENTLOOP_R9C_CLOSED_STDIO=backend",
        "AGENTLOOP_R9C_FIXTURE_BASE=\(base.path)",
        "AGENTLOOP_R9C_FIXTURE_EVIDENCE=\(evidence.path)",
        executable,
        "--filter",
        "p1f1_079.*",
    ])
    defer { p1f1d079FreeCStringVector(arguments) }
    var pid: pid_t = 0
    code = "/usr/bin/env".withCString { path in
        arguments.withUnsafeMutableBufferPointer { buffer in
            posix_spawn(
                &pid,
                path,
                &actions,
                nil,
                buffer.baseAddress,
                environ
            )
        }
    }
    guard code == 0 else {
        throw P1F1D079ClosedStdioFixtureError.spawn(code)
    }
    var status: Int32 = 0
    while waitpid(pid, &status, 0) < 0 {
        if errno == EINTR { continue }
        throw P1F1D079ClosedStdioFixtureError.wait
    }
    guard status == 0 else {
        throw P1F1D079ClosedStdioFixtureError.status(status)
    }
    guard try String(contentsOf: evidence, encoding: .utf8)
            == "closed-stdio-backend-ok\n"
    else {
        throw P1F1D079ClosedStdioFixtureError.evidence
    }
    guard !FileManager.default.fileExists(atPath: base.path) else {
        throw P1F1D079ClosedStdioFixtureError.residue
    }
}

private func p1f1d079CloseFixtureStandardDescriptors() throws {
    for descriptor in [STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO] {
        if Darwin.close(descriptor) != 0, errno != EBADF {
            throw P1F1D079ClosedStdioFixtureError.close(descriptor)
        }
    }
}

private func p1f1d079CollectWithDeadline(
    _ stream: AsyncThrowingStream<CliProcessFrameV1, Error>
) async -> P1F1D079DrainOutcome {
    await withTaskGroup(of: P1F1D079DrainOutcome.self) { group in
        group.addTask {
            do {
                for try await _ in stream {}
                return .completedWithoutFailure
            } catch let error as CliProcessBackendError {
                return .backendFailure(error)
            } catch {
                return .unexpectedFailure(String(describing: error))
            }
        }
        group.addTask {
            do {
                try await Task.sleep(for: .seconds(3))
                return .deadline
            } catch {
                return .deadline
            }
        }
        let first = await group.next() ?? .deadline
        group.cancelAll()
        return first
    }
}

private struct P1F1D079DeferredDriver: CliProcessDrivingV1 {
    let ledger: P1F1D079AuthorityLedger
    var supportsProcessGroupCancellation: Bool { true }

    func launch(
        _ request: CliProcessLaunchRequestV1
    ) -> AsyncThrowingStream<CliProcessFrameV1, Error> {
        ledger.record("driver-launch")
        return AsyncThrowingStream { $0.finish() }
    }

    func cancel(executionId: String) async throws -> CliProcessExitEvidenceV1 {
        ledger.record("driver-cancel")
        return CliProcessExitEvidenceV1(
            pid: 79,
            processGroupID: 79,
            status: 0,
            termSent: true,
            killSent: false,
            stdoutEOF: true,
            stderrEOF: true,
            childReaped: true
        )
    }
}

private func p1f1d079ExecutableAuthority(
    at executable: URL,
    kind: RuntimeProfileKind = .cliCodex,
    generation: Character = "a"
) throws -> CliExecutableAuthorityV1 {
    var info = stat()
    guard executable.path.withCString({ Darwin.lstat($0, &info) }) == 0 else {
        throw EngineContextValidationErrorV1()
    }
    return try CliExecutableAuthorityV1(
        kind: kind,
        command: kind == .cliCodex ? "codex" : "claude",
        commandSourcePath: kind == .cliCodex
            ? "/fixtures/@openai/codex/bin/codex.js"
            : "/fixtures/@anthropic-ai/claude-code/cli.js",
        commandSourceHash: String(repeating: generation, count: 64),
        resolvedExecutablePath: executable.path,
        stagedPath: executable.path,
        executableHash: CanonicalJSONV1.sha256Hex(
            try Data(contentsOf: executable)
        ),
        designatedRequirement: kind == .cliCodex
            ? "anchor apple generic and identifier codex and certificate leaf[subject.OU] = 2DC432GLL2"
            : "anchor apple generic and identifier claude and certificate leaf[subject.OU] = Q6L2SF6YDW",
        teamIdentifier: kind == .cliCodex ? "2DC432GLL2" : "Q6L2SF6YDW",
        cdHash: String(repeating: generation, count: 40),
        stagedDevice: UInt64(info.st_dev),
        stagedInode: UInt64(info.st_ino)
    )
}

private func p1f1d079BridgeAuthority(
    at executable: URL
) throws -> EngineBoardBridgeExecutableAuthorityV1 {
    var info = stat()
    guard executable.path.withCString({ Darwin.lstat($0, &info) }) == 0 else {
        throw EngineContextValidationErrorV1()
    }
    return try EngineBoardBridgeExecutableAuthorityV1(
        sourcePath: executable.path,
        stagedPath: executable.path,
        executableHash: CanonicalJSONV1.sha256Hex(
            try Data(contentsOf: executable)
        ),
        designatedRequirement: "anchor apple generic and identifier com.muzi.agentloop.board-bridge",
        teamIdentifier: "2DC432GLL2",
        cdHash: String(repeating: "b", count: 40),
        stagedDevice: UInt64(info.st_dev),
        stagedInode: UInt64(info.st_ino)
    )
}

private func p1f1d071Context() throws -> EngineResolvedContextTransportV1 {
    try EngineResolvedContextTransportV1(
        envelope: p1f1CanonicalEnvelope(),
        packet: p1f1ContextPacket(),
        canonicalEnvelopeJSON: p1f1ContextGolden,
        hash: p1f1ContextGoldenHash
    )
}

private func p1f1d071Workspace(
    _ url: URL,
    campId: String,
    squadId: String
) throws -> EngineResolvedWorkspaceV1 {
    let identity = try EngineWorkspaceIdentityV1(
        campId: campId,
        squadId: squadId,
        workspacePath: url.standardizedFileURL.path,
        bookmarkHash: nil
    )
    return try EngineResolvedWorkspaceV1(
        identity: identity,
        url: url.standardizedFileURL,
        release: {}
    )
}

private func p1f1d071Descriptor() -> ExecutionEngineDescriptor {
    ExecutionEngineDescriptor(
        adapterId: "agentloop.model-loop",
        adapterVersion: "1",
        profileKind: .openAIAPI,
        streamingProgress: .supported,
        boardTerminal: .supported,
        toolBridge: .supported,
        cancellation: .supported,
        sessionResume: .unsupported,
        usageMetering: .supported,
        workspaceRead: .supported,
        workspaceWrite: .supported,
        network: .supported,
        replayClassResolver: { _ in .nonReplayable }
    )
}

private func p1f1d071Request(
    campId: String,
    cardId: String,
    runId: String,
    squadId: String
) throws -> EngineExecutionRequest {
    let profileId = "40000000-0000-4000-8000-000000000071"
    let contract = try OutcomeContractRef(
        id: p1f1EngineContractID,
        version: 7,
        hash: p1f1EngineHashA
    )
    let descriptor = p1f1d071Descriptor()
    let scope = try EngineSessionScopeV1.derived(
        campId: campId,
        profileId: profileId,
        descriptor: descriptor,
        engineKind: descriptor.adapterId,
        model: "model-loop-test",
        workspaceHash: p1f1EngineWorkspaceHash,
        contract: contract
    )
    let scopeBytes = try CanonicalJSONV1.encode(scope)
    return try EngineExecutionRequest.makeCanonical(
        executionId: "00000000-0000-4000-8000-000000000071",
        idempotencyKey: "p1f1d-071-model-loop",
        campId: campId,
        campLifecycleVersion: 1,
        runId: runId,
        cardId: cardId,
        contract: contract,
        adapterId: "agentloop.model-loop",
        adapterVersion: "1",
        profileId: profileId,
        engineKind: descriptor.adapterId,
        model: "model-loop-test",
        replayClass: .nonReplayable,
        contextJson: p1f1ContextGolden,
        contextHash: p1f1ContextGoldenHash,
        sessionScopeJson: String(decoding: scopeBytes, as: UTF8.self),
        sessionScopeHash: CanonicalJSONV1.sha256Hex(scopeBytes),
        requiredCapabilities: [
            .boardTerminal, .cancellation, .network, .streamingProgress,
            .toolBridge, .usageMetering, .workspaceRead,
        ],
        approvalGrantIds: [],
        budget: EngineExecutionBudgetV1(
            tokenLimit: 1_000,
            costMicrosLimit: 0,
            wallClockSeconds: 0
        ),
        workspace: EngineWorkspaceRefV1(
            reference: "squad-workspace.v1:\(squadId)",
            hash: p1f1EngineWorkspaceHash
        ),
        sessionRef: nil
    )
}

typealias CardRunnerTestTerminalRecorder = P1F1D071TerminalRecorder
typealias CardRunnerTestBoardRecorder = P1F1D071BoardRecorder
typealias CardRunnerTestProgressRecorder = P1F1D071ProgressRecorder

func cardRunnerTestBoundCapabilityTools()
    -> EngineBoundCapabilityToolsV1
{
    EngineBoundCapabilityToolsV1(
        logicalDefinitions: [
            .completeCard, .blockCard, .addProgressNote, .askUser,
        ],
        capabilityTools: []
    )
}

func cardRunnerTestContext() throws
    -> EngineResolvedContextTransportV1
{
    try p1f1d071Context()
}

func cardRunnerTestRequest(
    campId: String = p1f1EngineCampID,
    cardId: String = p1f1EngineCardID,
    runId: String = "10000000-0000-4000-8000-000000000071",
    squadId: String = "00000000-0000-4000-8000-000000000082"
) throws -> EngineExecutionRequest {
    try p1f1d071Request(
        campId: campId,
        cardId: cardId,
        runId: runId,
        squadId: squadId
    )
}

func cardRunnerTestExecute(
    _ runner: CardRunner,
    workspaceURL: URL,
    request: EngineExecutionRequest? = nil,
    terminal: CardRunnerTestTerminalRecorder,
    board: CardRunnerTestBoardRecorder,
    progress: CardRunnerTestProgressRecorder
) async throws -> [EngineExecutionEventPayloadV1] {
    let resolvedRequest: EngineExecutionRequest
    if let request {
        resolvedRequest = request
    } else {
        resolvedRequest = try cardRunnerTestRequest()
    }
    var events: [EngineExecutionEventPayloadV1] = []
    for try await event in runner.execute(
        request: resolvedRequest,
        context: try cardRunnerTestContext(),
        workspaceURL: workspaceURL,
        terminalSink: terminal,
        boardTerminalSink: board,
        progressSink: progress
    ) {
        events.append(event)
    }
    return events
}

@Test func p1f1_071ModelLoopAdapterCannotMutateRunCard() async throws {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("p1f1d-071-\(UUID().uuidString)")
    let workspaceURL = base.appendingPathComponent("workspace")
    try FileManager.default.createDirectory(
        at: workspaceURL,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: base) }
    let database = try AppDatabase(
        path: base.appendingPathComponent("projection.sqlite").path
    )
    let ids = try database.createSingleCardMission(
        campName: "c",
        squadName: "s",
        goal: "g",
        cardTitle: "authoritative adapter card",
        cardDescription: "the request and projection share this exact Card",
        expectedOutput: "same projection",
        assigneeId: nil,
        maxTurns: 3,
        workspacePath: workspaceURL.path
    )
    let before = try p1f1d071Projection(
        database: database,
        cardId: ids.cardId
    )
    let squad = try #require(try database.squad(forCard: ids.cardId))
    let terminal = P1F1D071TerminalRecorder()
    let board = P1F1D071BoardRecorder()
    let progress = P1F1D071ProgressRecorder()
    let driver = P1F1D071ModelDriver(
        terminal: terminal,
        board: board,
        progress: progress
    )
    let profile = RuntimeProfileRecord(
        id: "40000000-0000-4000-8000-000000000071",
        kind: .openAIAPI,
        name: "P1-F1D model loop",
        baseURL: nil,
        credentialAccount: nil,
        isDefault: false,
        createdAt: Date(timeIntervalSince1970: 0)
    )
    let context = try p1f1d071Context()
    let workspace = try p1f1d071Workspace(
        workspaceURL,
        campId: squad.campId,
        squadId: squad.id
    )
    let request = try p1f1d071Request(
        campId: squad.campId,
        cardId: ids.cardId,
        runId: "10000000-0000-4000-8000-000000000071",
        squadId: squad.id
    )
    let factoryLedger = P1F1D071FactoryLedger()
    let logicalDefinitions: [ToolDef] = [
        .completeCard, .blockCard, .addProgressNote, .askUser,
    ]
    let contextRequest = try EngineContextResolveRequestV1(
        campId: squad.campId,
        cardId: ids.cardId,
        companionId: "50000000-0000-4000-8000-000000000071",
        contextJson: p1f1ContextGolden,
        contextHash: p1f1ContextGoldenHash
    )
    let modelBindings = logicalDefinitions.map {
        EngineContextToolBindingV1(
            logicalName: $0.name,
            providerVisibleName: $0.name
        )
    }
    let modelVariant = EnginePreparedContextVariantV1(
        request: contextRequest,
        resolved: context,
        namespace: .modelLoop,
        toolBindings: modelBindings
    )
    let cliVariant = EnginePreparedContextVariantV1(
        request: contextRequest,
        resolved: context,
        namespace: .ranchMCP,
        toolBindings: modelBindings.map {
            EngineContextToolBindingV1(
                logicalName: $0.logicalName,
                providerVisibleName: "mcp__ranchboard__\($0.logicalName)"
            )
        }
    )
    let preparedContext = EnginePreparedContextV1(
        modelLoop: modelVariant,
        cli: cliVariant,
        profile: profile,
        contract: request.contract,
        companionId: "50000000-0000-4000-8000-000000000071",
        companionModel: request.model,
        companionModelPolicy: .pinned,
        autonomy: .standard,
        cardMaxTurns: 3,
        cardTokenBudget: request.budget.tokenLimit,
        capabilityTools: EngineCapabilityToolPlanV1(
            logicalDefinitions: logicalDefinitions,
            modelLoopDefinitions: logicalDefinitions,
            cliDefinitions: logicalDefinitions.map {
                ToolDef(
                    name: "mcp__ranchboard__\($0.name)",
                    description: $0.description,
                    inputSchema: $0.inputSchema
                )
            },
            requiresWorkspaceWrite: false,
            makeCapabilityTools: { receivedWorkspace in
                #expect(receivedWorkspace == workspace.url)
                factoryLedger.record("tool-maker")
                return EngineBoundCapabilityToolsV1(
                    logicalDefinitions: logicalDefinitions,
                    capabilityTools: []
                )
            }
        )
    )
    let workspaceClaim = EnginePreparedWorkspaceClaimV1(
        request: try EngineWorkspaceResolveRequestV1(
            cardId: ids.cardId,
            campId: squad.campId,
            expectedWorkspace: request.workspace
        ),
        workspace: request.workspace
    )
    let seed = EngineExecutionTransportSeedV1(
        context: preparedContext,
        workspace: workspaceClaim,
        baseRequiredCapabilities: [
            .boardTerminal, .cancellation, .network, .streamingProgress,
            .toolBridge, .usageMetering, .workspaceRead,
        ],
        bridgeExecutableAuthority: nil,
        boardSocketDirectoryAuthority: nil,
        validateCodexManagedPolicy: { _ in
            factoryLedger.record("codex-validator")
        },
        validateClaudeManagedPolicy: { _ in
            factoryLedger.record("claude-validator")
        },
        claudeConfigDirectory: base,
        cliExecutableDirectory: base,
        resolveInitialModelLoopProvider: {
            receivedProfile,
            receivedCompanion,
            receivedModel,
            receivedPolicy in
            factoryLedger.recordProviderResolve(
                P1F1D071ProviderResolveCall(
                    profile: receivedProfile,
                    companionId: receivedCompanion,
                    model: receivedModel,
                    policy: receivedPolicy
                )
            )
            return try EngineModelLoopProviderAuthorityV1(
                profileId: receivedProfile.id,
                effectiveModel: request.model,
                makeProvider: {
                    factoryLedger.record("provider-maker")
                    return MockProvider(script: [])
                }
            )
        },
        resolveRecoveryModelLoopProvider: { _, _, _ in
            factoryLedger.record("recovery-provider-resolver")
            throw EngineContextValidationErrorV1()
        },
        makeCliProcessDriver: {
            factoryLedger.record("cli-driver")
            throw EngineContextValidationErrorV1()
        }
    )
    let factories = EngineAdapterFactoryV1.builtInFactories(
        makeModelLoopAdapter: { _, _ in
            factoryLedger.record("model-adapter")
            throw EngineContextValidationErrorV1()
        },
        makeCodexAdapter: { _, _ in
            factoryLedger.record("codex-adapter")
            throw EngineContextValidationErrorV1()
        },
        makeClaudeAdapter: { _, _ in
            factoryLedger.record("claude-adapter")
            throw EngineContextValidationErrorV1()
        }
    )
    let selection = try EngineAdapterRegistryV1(
        factories: factories,
        helpSnapshots: [:]
    ).resolve(
        profile: profile,
        requiredCapabilities: seed.baseRequiredCapabilities
    )
    let prepared = try selection.prepareRequest(seed)
    #expect(
        factoryLedger.providerResolveCalls == [
            P1F1D071ProviderResolveCall(
                profile: profile,
                companionId: preparedContext.companionId,
                model: preparedContext.companionModel,
                policy: .pinned
            ),
        ]
    )
    #expect(factoryLedger.count("provider-maker") == 0)
    #expect(factoryLedger.count("cli-driver") == 0)
    #expect(factoryLedger.count("tool-maker") == 0)
    #expect(factoryLedger.count("codex-validator") == 0)
    #expect(factoryLedger.count("claude-validator") == 0)
    #expect(prepared.model == request.model)
    #expect(prepared.engineKind == selection.descriptor.adapterId)
    let transport = try prepared.makeTransport(request, context, workspace)
    #expect(transport.modelLoopDriver != nil)
    #expect(transport.cliProcessDriver == nil)
    #expect(transport.cliConfiguration == nil)
    #expect(
        transport.boundCapabilityTools.logicalDefinitions
            == logicalDefinitions
    )
    #expect(transport.boundCapabilityTools.capabilityTools.isEmpty)
    #expect(factoryLedger.count("provider-maker") == 1)
    #expect(factoryLedger.count("tool-maker") == 1)
    #expect(factoryLedger.count("cli-driver") == 0)
    #expect(factoryLedger.count("model-adapter") == 0)
    #expect(factoryLedger.count("codex-adapter") == 0)
    #expect(factoryLedger.count("claude-adapter") == 0)
    let adapter = ModelLoopEngineAdapter(
        profile: profile,
        descriptor: p1f1d071Descriptor(),
        driver: driver,
        context: context,
        workspace: workspace,
        boundCapabilityTools: transport.boundCapabilityTools,
        terminalSink: terminal,
        boardTerminalSink: board,
        progressSink: progress
    )
    var iterator = adapter.execute(request: request).makeAsyncIterator()
    var events: [EngineExecutionEventPayloadV1] = []
    if let event = try await iterator.next() { events.append(event) }
    while let event = try await iterator.next() { events.append(event) }

    let driverSnapshot = try #require(driver.snapshot)
    #expect(driverSnapshot.request == request)
    #expect(driverSnapshot.contextHash == context.hash)
    #expect(driverSnapshot.workspaceURL == workspaceURL.standardizedFileURL)
    #expect(driverSnapshot.terminalSinkMatched)
    #expect(driverSnapshot.boardSinkMatched)
    #expect(driverSnapshot.progressSinkMatched)
    #expect(
        adapter.boundCapabilityTools.logicalDefinitions
            == transport.boundCapabilityTools.logicalDefinitions
    )
    #expect(
        adapter.boundCapabilityTools.capabilityTools.count
            == transport.boundCapabilityTools.capabilityTools.count
    )
    #expect(await terminal.snapshot().isEmpty)
    #expect(
        await progress.snapshot()
            == [.progress(message: "model-loop-driver-started")]
    )
    let boardIntents = await board.snapshot()
    #expect(boardIntents.count == 1)
    guard case let .completed(handoff) = try #require(boardIntents.first) else {
        Issue.record("ModelLoop may terminate only through its Board sink")
        return
    }
    #expect(handoff.outcome == "implemented")
    #expect(events.isEmpty)
    try p1f1d071AssertDBFreeSource(
        "Sources/AgentLoopCore/Loop/ModelLoopEngineAdapter.swift"
    )
    try p1f1d071AssertDBFreeSource(
        "Sources/AgentLoopCore/Loop/CardRunner.swift"
    )
    #expect(
        try p1f1d071Projection(database: database, cardId: ids.cardId)
            == before
    )
}

@Test func p1f1_079CardRunnerAndCLIBackendCannotStartOrFinishRun()
    async throws
{
    let environment = ProcessInfo.processInfo.environment
    let closedStdioFixture =
        environment["AGENTLOOP_R9C_CLOSED_STDIO"] == "backend"
    let base: URL
    if closedStdioFixture {
        guard let path = environment["AGENTLOOP_R9C_FIXTURE_BASE"] else {
            throw P1F1D079ClosedStdioFixtureError.evidence
        }
        base = URL(fileURLWithPath: path, isDirectory: true)
    } else {
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent("p1f1d-079-\(UUID().uuidString)")
    }
    let workspaceURL = base.appendingPathComponent("workspace")
    let socketDirectory = URL(fileURLWithPath: "/tmp")
        .appendingPathComponent("al79-\(UUID().uuidString.prefix(8))")
    try FileManager.default.createDirectory(
        at: workspaceURL,
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: socketDirectory,
        withIntermediateDirectories: true
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: socketDirectory.path
    )
    defer {
        try? FileManager.default.removeItem(at: base)
        try? FileManager.default.removeItem(at: socketDirectory)
    }
    if !closedStdioFixture {
        try p1f1d079RunClosedStdioSubprocess(
            base: base.appendingPathComponent("closed-stdio-backend-work"),
            evidence: base.appendingPathComponent(
                "closed-stdio-backend.evidence"
            )
        )
    }
    let database = try AppDatabase(
        path: base.appendingPathComponent("projection.sqlite").path
    )
    let ids = try database.createSingleCardMission(
        campName: "c",
        squadName: "s",
        goal: "g",
        cardTitle: "process isolation",
        cardDescription: "typed process launch cannot mutate this card",
        expectedOutput: "unchanged database",
        assigneeId: nil,
        maxTurns: 3,
        workspacePath: workspaceURL.path
    )
    let legacyRunId = "70000000-0000-4000-8000-000000000079"
    try database.startRun(cardId: ids.cardId, runId: legacyRunId)
    let before = try p1f1d071Projection(
        database: database,
        cardId: ids.cardId
    )

    let scriptURL = base.appendingPathComponent("fake-cli")
    let script = """
    #!/bin/sh
    i=0
    while [ "$i" -lt 8192 ]; do
      printf '%s' '0123456789abcdef'
      i=$((i + 1))
    done
    printf '\n'
    cat >/dev/null
    printf '%s\\n' 'p1f1-079-stdout'
    printf '%s\\n' 'p1f1-079-stderr' >&2
    exit 0
    """
    try script.write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o500],
        ofItemAtPath: scriptURL.path
    )
    let executableAuthority = try p1f1d079ExecutableAuthority(at: scriptURL)
    let bridgeAuthority = try p1f1d079BridgeAuthority(at: scriptURL)
    let directoryDescriptor = socketDirectory.path.withCString {
        Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
    }
    guard directoryDescriptor >= 0 else {
        throw EngineContextValidationErrorV1()
    }
    var directoryInfo = stat()
    guard Darwin.fstat(directoryDescriptor, &directoryInfo) == 0 else {
        _ = Darwin.close(directoryDescriptor)
        throw EngineContextValidationErrorV1()
    }
    let socketDirectoryAuthority = try EngineBoardSocketDirectoryAuthorityV1(
        directoryURL: try p1f1CanonicalDirectoryURL(directoryDescriptor),
        ownedDescriptor: directoryDescriptor,
        device: UInt64(directoryInfo.st_dev),
        inode: UInt64(directoryInfo.st_ino),
        uid: UInt32(directoryInfo.st_uid),
        mode: UInt16(directoryInfo.st_mode & mode_t(0o777)),
        ownerIdentityHash: String(repeating: "7", count: 64),
        bootId: "79000000-0000-4000-8000-000000000079"
    )
    defer { try? socketDirectoryAuthority.close() }
    let cleanupURL = base.appendingPathComponent("provider-config.json")
    try "{}".write(to: cleanupURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: cleanupURL.path
    )
    let cleanupAuthority = try CliCleanupFileAuthorityV1.captureExisting(
        cleanupURL
    )
    let factoryLedger = P1F1D079AuthorityLedger()
    let profile = RuntimeProfileRecord(
        id: "40000000-0000-4000-8000-000000000079",
        kind: .cliCodex,
        name: "P1-F1D selected generation A",
        baseURL: nil,
        credentialAccount: nil,
        isDefault: false,
        createdAt: Date(timeIntervalSince1970: 0)
    )
    let helpSnapshot = try CliHelpSnapshotV1(
        executableAuthority: executableAuthority,
        versionLine: "codex-cli 0.144.5",
        rootExitStatus: 0,
        rootStdoutHash: String(repeating: "1", count: 64),
        firstExitStatus: 0,
        firstStdoutHash: String(repeating: "2", count: 64),
        resumeExitStatus: 0,
        resumeStdoutHash: String(repeating: "3", count: 64),
        rootFlags: ["-C", "-a", "-m", "-s"],
        firstFlags: [
            "--ignore-rules", "--ignore-user-config", "--json",
            "--skip-git-repo-check", "--strict-config", "-c",
        ],
        resumeFlags: [
            "--ignore-rules", "--ignore-user-config", "--json",
            "--skip-git-repo-check", "--strict-config", "-c",
        ],
        subcommands: ["resume"]
    )
    let squad = try #require(try database.squad(forCard: ids.cardId))
    let resolvedContext = try p1f1d071Context()
    let resolvedWorkspace = try p1f1d071Workspace(
        workspaceURL,
        campId: squad.campId,
        squadId: squad.id
    )
    let logicalDefinitions: [ToolDef] = [
        .completeCard, .blockCard, .addProgressNote, .askUser,
    ]
    let contextRequest = try EngineContextResolveRequestV1(
        campId: squad.campId,
        cardId: ids.cardId,
        companionId: "50000000-0000-4000-8000-000000000079",
        contextJson: p1f1ContextGolden,
        contextHash: p1f1ContextGoldenHash
    )
    let logicalBindings = logicalDefinitions.map {
        EngineContextToolBindingV1(
            logicalName: $0.name,
            providerVisibleName: $0.name
        )
    }
    let preparedContext = EnginePreparedContextV1(
        modelLoop: EnginePreparedContextVariantV1(
            request: contextRequest,
            resolved: resolvedContext,
            namespace: .modelLoop,
            toolBindings: logicalBindings
        ),
        cli: EnginePreparedContextVariantV1(
            request: contextRequest,
            resolved: resolvedContext,
            namespace: .ranchMCP,
            toolBindings: logicalBindings.map {
                EngineContextToolBindingV1(
                    logicalName: $0.logicalName,
                    providerVisibleName:
                        "mcp__ranchboard__\($0.logicalName)"
                )
            }
        ),
        profile: profile,
        contract: try OutcomeContractRef(
            id: p1f1EngineContractID,
            version: 7,
            hash: p1f1EngineHashA
        ),
        companionId: "50000000-0000-4000-8000-000000000079",
        companionModel: "cli-default",
        companionModelPolicy: .inherit,
        autonomy: .standard,
        cardMaxTurns: 3,
        cardTokenBudget: 1_000,
        capabilityTools: EngineCapabilityToolPlanV1(
            logicalDefinitions: logicalDefinitions,
            modelLoopDefinitions: logicalDefinitions,
            cliDefinitions: logicalDefinitions.map {
                ToolDef(
                    name: "mcp__ranchboard__\($0.name)",
                    description: $0.description,
                    inputSchema: $0.inputSchema
                )
            },
            requiresWorkspaceWrite: false,
            makeCapabilityTools: { receivedWorkspace in
                #expect(receivedWorkspace == resolvedWorkspace.url)
                factoryLedger.record("tool-maker")
                return EngineBoundCapabilityToolsV1(
                    logicalDefinitions: logicalDefinitions,
                    capabilityTools: []
                )
            }
        )
    )
    let workspaceRef = EngineWorkspaceRefV1(
        reference: "squad-workspace.v1:\(squad.id)",
        hash: p1f1EngineWorkspaceHash
    )
    let transportSeed = EngineExecutionTransportSeedV1(
        context: preparedContext,
        workspace: EnginePreparedWorkspaceClaimV1(
            request: try EngineWorkspaceResolveRequestV1(
                cardId: ids.cardId,
                campId: squad.campId,
                expectedWorkspace: workspaceRef
            ),
            workspace: workspaceRef
        ),
        baseRequiredCapabilities: [
            .boardTerminal, .cancellation, .network, .streamingProgress,
            .toolBridge, .usageMetering, .workspaceRead,
        ],
        bridgeExecutableAuthority: bridgeAuthority,
        boardSocketDirectoryAuthority: socketDirectoryAuthority,
        validateCodexManagedPolicy: { authority in
            factoryLedger.append(authority)
        },
        validateClaudeManagedPolicy: { _ in
            factoryLedger.record("claude-validator")
        },
        claudeConfigDirectory: base,
        cliExecutableDirectory: base,
        resolveInitialModelLoopProvider: { _, _, _, _ in
            factoryLedger.record("provider-resolver")
            throw EngineContextValidationErrorV1()
        },
        resolveRecoveryModelLoopProvider: { _, _, _ in
            factoryLedger.record("recovery-provider-resolver")
            throw EngineContextValidationErrorV1()
        },
        makeCliProcessDriver: {
            factoryLedger.record("cli-driver-maker")
            return P1F1D079DeferredDriver(ledger: factoryLedger)
        }
    )
    let descriptor = ExecutionEngineDescriptor(
        adapterId: "agentloop.cli.codex",
        adapterVersion: "1",
        profileKind: .cliCodex,
        streamingProgress: .supported,
        boardTerminal: .supported,
        toolBridge: .supported,
        cancellation: .supported,
        sessionResume: .supported,
        usageMetering: .supported,
        workspaceRead: .supported,
        workspaceWrite: .supported,
        network: .supported,
        replayClassResolver: { _ in .nonReplayable }
    )
    let contract = preparedContext.contract
    let scope = try EngineSessionScopeV1.derived(
        campId: squad.campId,
        profileId: profile.id,
        descriptor: descriptor,
        engineKind: descriptor.adapterId,
        model: "gpt-5.5",
        workspaceHash: p1f1EngineWorkspaceHash,
        contract: contract
    )
    let scopeBytes = try CanonicalJSONV1.encode(scope)
    let engineRequest = try EngineExecutionRequest.makeCanonical(
        executionId: "00000000-0000-4000-8000-000000000079",
        idempotencyKey: "p1f1d-079-cli-generation-a",
        campId: squad.campId,
        campLifecycleVersion: 1,
        runId: legacyRunId,
        cardId: ids.cardId,
        contract: contract,
        adapterId: descriptor.adapterId,
        adapterVersion: descriptor.adapterVersion,
        profileId: profile.id,
        engineKind: descriptor.adapterId,
        model: "gpt-5.5",
        replayClass: .nonReplayable,
        contextJson: p1f1ContextGolden,
        contextHash: p1f1ContextGoldenHash,
        sessionScopeJson: String(decoding: scopeBytes, as: UTF8.self),
        sessionScopeHash: CanonicalJSONV1.sha256Hex(scopeBytes),
        requiredCapabilities: transportSeed.baseRequiredCapabilities,
        approvalGrantIds: [],
        budget: EngineExecutionBudgetV1(
            tokenLimit: 1_000,
            costMicrosLimit: 0,
            wallClockSeconds: 0
        ),
        workspace: workspaceRef,
        sessionRef: nil
    )
    let registry = try EngineAdapterRegistryV1(
        factories: EngineAdapterFactoryV1.builtInFactories(
            makeModelLoopAdapter: { _, _ in
                throw EngineContextValidationErrorV1()
            },
            makeCodexAdapter: { _, _ in
                throw EngineContextValidationErrorV1()
            },
            makeClaudeAdapter: { _, _ in
                throw EngineContextValidationErrorV1()
            }
        ),
        helpSnapshots: [.cliCodex: helpSnapshot]
    )
    let selection = try registry.resolve(
        profile: profile,
        requiredCapabilities: transportSeed.baseRequiredCapabilities
    )
    let prepared = try selection.prepareRequest(transportSeed)
    #expect(factoryLedger.count("provider-resolver") == 0)
    #expect(factoryLedger.count("cli-driver-maker") == 0)
    #expect(factoryLedger.receivedAuthorities.isEmpty)
    let selectedTransport = try prepared.makeTransport(
        engineRequest,
        resolvedContext,
        resolvedWorkspace
    )
    #expect(factoryLedger.count("cli-driver-maker") == 1)
    #expect(factoryLedger.count("provider-resolver") == 0)
    #expect(factoryLedger.count("tool-maker") == 1)
    #expect(factoryLedger.receivedAuthorities == [executableAuthority])
    #expect(
        selectedTransport.cliConfiguration?.cliExecutableAuthority
            == executableAuthority
    )
    #expect(
        selectedTransport.cliConfiguration?.command
            == executableAuthority.stagedPath
    )
    #expect(
        selectedTransport.boundCapabilityTools.logicalDefinitions
            == logicalDefinitions
    )
    #expect(selectedTransport.boundCapabilityTools.capabilityTools.isEmpty)
    #expect(selectedTransport.modelLoopDriver == nil)
    let recoveredTransport = try selection.makeRecoveryTransport(
        engineRequest,
        resolvedContext,
        resolvedWorkspace,
        transportSeed
    )
    #expect(factoryLedger.count("cli-driver-maker") == 2)
    #expect(factoryLedger.count("provider-resolver") == 0)
    #expect(factoryLedger.count("recovery-provider-resolver") == 0)
    #expect(factoryLedger.count("tool-maker") == 2)
    #expect(
        factoryLedger.receivedAuthorities
            == [executableAuthority, executableAuthority]
    )
    #expect(
        recoveredTransport.cliConfiguration?.cliExecutableAuthority
            == executableAuthority
    )
    #expect(
        recoveredTransport.boundCapabilityTools.logicalDefinitions
            == selectedTransport.boundCapabilityTools.logicalDefinitions
    )
    #expect(factoryLedger.count("claude-validator") == 0)
    let carrierInput = try CliEngineCommandInputV1(
        command: executableAuthority.stagedPath,
        cliExecutableAuthority: executableAuthority,
        workspaceURL: resolvedWorkspace.url,
        sandbox: "read-only",
        model: engineRequest.model,
        reasoningEffort: "xhigh",
        prompt: "generation A exact carrier",
        bridgeExecutableAuthority: bridgeAuthority,
        boardSocketURL: try BoardToolServer.makeSocketURL(
            directoryAuthority: socketDirectoryAuthority,
            executionId: engineRequest.executionId
        ),
        boardToken: String(repeating: "d", count: 64),
        boardCardId: engineRequest.cardId,
        toolNames: [
            "add_progress_note", "ask_user", "block_card",
            "complete_card",
        ],
        claudeConfigURL: base.appendingPathComponent("unused.json"),
        session: .first(ranchUUID: engineRequest.executionId)
    )
    #expect(carrierInput.cliExecutableAuthority == executableAuthority)
    let carrierSpec = try CliEngineCommandBuilderV1().buildCodex(
        carrierInput
    )
    #expect(carrierSpec.command == executableAuthority.stagedPath)
    #expect(carrierSpec.stdinBytes == Data("generation A exact carrier".utf8))

    let claudeAuthority = try p1f1d079ExecutableAuthority(
        at: scriptURL,
        kind: .cliClaude,
        generation: "d"
    )
    let claudeProfile = RuntimeProfileRecord(
        id: "41000000-0000-4000-8000-000000000079",
        kind: .cliClaude,
        name: "P1-F1D Claude selected generation A",
        baseURL: nil,
        credentialAccount: nil,
        isDefault: false,
        createdAt: Date(timeIntervalSince1970: 0)
    )
    let claudeHelpFlags = [
        "--add-dir", "--allowedTools", "--disable-slash-commands",
        "--input-format", "--mcp-config", "--model", "--no-chrome",
        "--output-format", "--permission-mode", "--resume",
        "--session-id", "--setting-sources", "--strict-mcp-config",
        "--tools", "--verbose", "-p",
    ].sorted()
    let claudeHelp = try CliHelpSnapshotV1(
        executableAuthority: claudeAuthority,
        versionLine: "2.1.81 (Claude Code)",
        rootExitStatus: 0,
        rootStdoutHash: String(repeating: "4", count: 64),
        firstExitStatus: 0,
        firstStdoutHash: String(repeating: "5", count: 64),
        resumeExitStatus: 0,
        resumeStdoutHash: String(repeating: "6", count: 64),
        rootFlags: [],
        firstFlags: claudeHelpFlags,
        resumeFlags: claudeHelpFlags,
        subcommands: []
    )
    let claudeLedger = P1F1D079AuthorityLedger()
    let claudeContext = EnginePreparedContextV1(
        modelLoop: preparedContext.modelLoop,
        cli: preparedContext.cli,
        profile: claudeProfile,
        contract: preparedContext.contract,
        companionId: preparedContext.companionId,
        companionModel: preparedContext.companionModel,
        companionModelPolicy: preparedContext.companionModelPolicy,
        autonomy: preparedContext.autonomy,
        cardMaxTurns: preparedContext.cardMaxTurns,
        cardTokenBudget: preparedContext.cardTokenBudget,
        capabilityTools: EngineCapabilityToolPlanV1(
            logicalDefinitions: logicalDefinitions,
            modelLoopDefinitions: logicalDefinitions,
            cliDefinitions: logicalDefinitions.map {
                ToolDef(
                    name: "mcp__ranchboard__\($0.name)",
                    description: $0.description,
                    inputSchema: $0.inputSchema
                )
            },
            requiresWorkspaceWrite: false,
            makeCapabilityTools: { receivedWorkspace in
                #expect(receivedWorkspace == resolvedWorkspace.url)
                claudeLedger.record("tool-maker")
                return EngineBoundCapabilityToolsV1(
                    logicalDefinitions: logicalDefinitions,
                    capabilityTools: []
                )
            }
        )
    )
    let claudeSeed = EngineExecutionTransportSeedV1(
        context: claudeContext,
        workspace: transportSeed.workspace,
        baseRequiredCapabilities: transportSeed.baseRequiredCapabilities,
        bridgeExecutableAuthority: bridgeAuthority,
        boardSocketDirectoryAuthority: socketDirectoryAuthority,
        validateCodexManagedPolicy: { _ in
            claudeLedger.record("codex-validator")
        },
        validateClaudeManagedPolicy: { authority in
            claudeLedger.append(authority)
        },
        claudeConfigDirectory: base,
        cliExecutableDirectory: base,
        resolveInitialModelLoopProvider: { _, _, _, _ in
            claudeLedger.record("provider-resolver")
            throw EngineContextValidationErrorV1()
        },
        resolveRecoveryModelLoopProvider: { _, _, _ in
            claudeLedger.record("recovery-provider-resolver")
            throw EngineContextValidationErrorV1()
        },
        makeCliProcessDriver: {
            claudeLedger.record("cli-driver-maker")
            return P1F1D079DeferredDriver(ledger: claudeLedger)
        }
    )
    let claudeRegistry = try EngineAdapterRegistryV1(
        factories: EngineAdapterFactoryV1.builtInFactories(
            makeModelLoopAdapter: { _, _ in
                throw EngineContextValidationErrorV1()
            },
            makeCodexAdapter: { _, _ in
                throw EngineContextValidationErrorV1()
            },
            makeClaudeAdapter: { _, _ in
                throw EngineContextValidationErrorV1()
            }
        ),
        helpSnapshots: [.cliClaude: claudeHelp]
    )
    let claudeSelection = try claudeRegistry.resolve(
        profile: claudeProfile,
        requiredCapabilities: claudeSeed.baseRequiredCapabilities
    )
    let claudePrepared = try claudeSelection.prepareRequest(claudeSeed)
    let claudeModel = KernelDefaults.claudeCliModel
        ?? KernelDefaults.defaultGuideModel
    let claudeScope = try EngineSessionScopeV1.derived(
        campId: squad.campId,
        profileId: claudeProfile.id,
        descriptor: claudeSelection.descriptor,
        engineKind: claudeSelection.descriptor.adapterId,
        model: claudeModel,
        workspaceHash: p1f1EngineWorkspaceHash,
        contract: contract
    )
    let claudeScopeBytes = try CanonicalJSONV1.encode(claudeScope)
    let claudeRequest = try EngineExecutionRequest.makeCanonical(
        executionId: "01000000-0000-4000-8000-000000000079",
        idempotencyKey: "p1f1d-079-claude-generation-a",
        campId: squad.campId,
        campLifecycleVersion: 1,
        runId: legacyRunId,
        cardId: ids.cardId,
        contract: contract,
        adapterId: claudeSelection.descriptor.adapterId,
        adapterVersion: claudeSelection.descriptor.adapterVersion,
        profileId: claudeProfile.id,
        engineKind: claudeSelection.descriptor.adapterId,
        model: claudeModel,
        replayClass: .nonReplayable,
        contextJson: p1f1ContextGolden,
        contextHash: p1f1ContextGoldenHash,
        sessionScopeJson: String(decoding: claudeScopeBytes, as: UTF8.self),
        sessionScopeHash: CanonicalJSONV1.sha256Hex(claudeScopeBytes),
        requiredCapabilities: claudeSeed.baseRequiredCapabilities,
        approvalGrantIds: [],
        budget: EngineExecutionBudgetV1(
            tokenLimit: 1_000,
            costMicrosLimit: 0,
            wallClockSeconds: 0
        ),
        workspace: workspaceRef,
        sessionRef: nil
    )
    let claudeNormal = try claudePrepared.makeTransport(
        claudeRequest,
        resolvedContext,
        resolvedWorkspace
    )
    let claudeRecovery = try claudeSelection.makeRecoveryTransport(
        claudeRequest,
        resolvedContext,
        resolvedWorkspace,
        claudeSeed
    )
    #expect(claudeLedger.count("codex-validator") == 0)
    #expect(claudeLedger.count("provider-resolver") == 0)
    #expect(claudeLedger.count("recovery-provider-resolver") == 0)
    #expect(claudeLedger.count("tool-maker") == 2)
    #expect(claudeLedger.count("cli-driver-maker") == 2)
    #expect(
        claudeLedger.receivedAuthorities
            == [claudeAuthority, claudeAuthority]
    )
    #expect(
        claudeNormal.cliConfiguration?.cliExecutableAuthority
            == claudeAuthority
    )
    #expect(
        claudeRecovery.cliConfiguration?.cliExecutableAuthority
            == claudeAuthority
    )

    let generationB = try CliExecutableAuthorityV1(
        kind: .cliCodex,
        command: "codex",
        commandSourcePath: executableAuthority.commandSourcePath,
        commandSourceHash: String(repeating: "f", count: 64),
        resolvedExecutablePath: executableAuthority.resolvedExecutablePath,
        stagedPath: executableAuthority.stagedPath + ".generation-b",
        executableHash: executableAuthority.executableHash,
        designatedRequirement: executableAuthority.designatedRequirement,
        teamIdentifier: executableAuthority.teamIdentifier,
        cdHash: executableAuthority.cdHash,
        stagedDevice: executableAuthority.stagedDevice,
        stagedInode: executableAuthority.stagedInode
    )
    do {
        _ = try CliEngineRuntimeConfigurationV1(
            command: executableAuthority.stagedPath,
            cliExecutableAuthority: generationB,
            sandbox: "read-only",
            reasoningEffort: "xhigh",
            bridgeExecutableAuthority: bridgeAuthority,
            boardSocketDirectoryAuthority: socketDirectoryAuthority,
            claudeConfigDirectory: base,
            ranchSessionId: engineRequest.executionId
        )
        Issue.record("generation B must not enter generation A command chain")
    } catch is EngineContextValidationErrorV1 {}

    let board = P1F1D071BoardRecorder()
    let progress = P1F1D071ProgressRecorder()
    let processInspector = P1F1D079ProcessInspector(
        authority: executableAuthority
    )

    let productionCleanupURL = base.appendingPathComponent(
        "production-signature-cleanup.json"
    )
    try "{}".write(
        to: productionCleanupURL,
        atomically: true,
        encoding: .utf8
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: productionCleanupURL.path
    )
    let productionCleanupAuthority = try CliCleanupFileAuthorityV1
        .captureExisting(productionCleanupURL)
    let productionExecution = "60000000-0000-4000-8000-000000000079"
    let productionRequest = try p1f1d079SignatureGateRequest(
        executionId: productionExecution,
        executableAuthority: executableAuthority,
        bridgeAuthority: bridgeAuthority,
        workspaceURL: workspaceURL,
        directoryAuthority: socketDirectoryAuthority,
        cleanupAuthority: productionCleanupAuthority,
        cardId: ids.cardId,
        board: board,
        progress: progress
    )
    let productionSocket = try BoardToolServer.makeSocketURL(
        directoryAuthority: socketDirectoryAuthority,
        executionId: productionExecution
    )
    let productionRegistry = ShellProcessRegistry()
    let productionBackend = try CliProcessBackend(
        registry: productionRegistry,
        processInspector: processInspector
    )
    do {
        for try await _ in productionBackend.launch(productionRequest) {}
        Issue.record("production signature gate accepted unsigned 079 fixture")
    } catch is EngineContextValidationErrorV1 {}
    #expect(!FileManager.default.fileExists(atPath: productionCleanupURL.path))
    #expect(!FileManager.default.fileExists(atPath: productionSocket.path))
    #expect(productionRegistry.activeCount == 0)
    #expect(processInspector.snapshotsObserved == 0)
    #expect(processInspector.signals.isEmpty)
    #expect(!processInspector.observedExistingGroup)
    #expect(!processInspector.observedExactESRCH)
    #expect(await board.snapshot().isEmpty)
    #expect(await progress.snapshot().isEmpty)

    let rejectedCleanupURL = base.appendingPathComponent(
        "injected-signature-cleanup.json"
    )
    try "{}".write(
        to: rejectedCleanupURL,
        atomically: true,
        encoding: .utf8
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: rejectedCleanupURL.path
    )
    let rejectedCleanupAuthority = try CliCleanupFileAuthorityV1
        .captureExisting(rejectedCleanupURL)
    let rejectedExecution = "61000000-0000-4000-8000-000000000079"
    let rejectedRequest = try p1f1d079SignatureGateRequest(
        executionId: rejectedExecution,
        executableAuthority: executableAuthority,
        bridgeAuthority: bridgeAuthority,
        workspaceURL: workspaceURL,
        directoryAuthority: socketDirectoryAuthority,
        cleanupAuthority: rejectedCleanupAuthority,
        cardId: ids.cardId,
        board: board,
        progress: progress
    )
    let rejectedSocket = try BoardToolServer.makeSocketURL(
        directoryAuthority: socketDirectoryAuthority,
        executionId: rejectedExecution
    )
    let rejectedRegistry = ShellProcessRegistry()
    let rejectedRevalidator = P1F1D079SignatureRevalidator(
        expectedCLI: executableAuthority,
        expectedBoardBridge: bridgeAuthority,
        injectedFailure: .cli
    )
    let rejectedBackend = try p1f1d079Backend(
        registry: rejectedRegistry,
        processInspector: processInspector,
        revalidator: rejectedRevalidator
    )
    do {
        for try await _ in rejectedBackend.launch(rejectedRequest) {}
        Issue.record("throwing signature gate launched controlled 079 fixture")
    } catch let error as P1F1D079SignatureFixtureError {
        #expect(error == .injected(.cli))
    }
    #expect(rejectedRevalidator.snapshot() == [.cli])
    #expect(!FileManager.default.fileExists(atPath: rejectedCleanupURL.path))
    #expect(!FileManager.default.fileExists(atPath: rejectedSocket.path))
    #expect(rejectedRegistry.activeCount == 0)
    #expect(processInspector.snapshotsObserved == 0)
    #expect(processInspector.signals.isEmpty)
    #expect(!processInspector.observedExistingGroup)
    #expect(!processInspector.observedExactESRCH)
    #expect(await board.snapshot().isEmpty)
    #expect(await progress.snapshot().isEmpty)

    let processRegistry = ShellProcessRegistry()
    let processRevalidator = P1F1D079SignatureRevalidator(
        expectedCLI: executableAuthority,
        expectedBoardBridge: bridgeAuthority
    )
    let backend = try p1f1d079Backend(
        registry: processRegistry,
        processInspector: processInspector,
        revalidator: processRevalidator
    )
    let socketURL = try BoardToolServer.makeSocketURL(
        directoryAuthority: socketDirectoryAuthority,
        executionId: engineRequest.executionId
    )
    let stdin = Data(repeating: UInt8(ascii: "x"), count: 512 * 1_024)
    let request = try CliProcessLaunchRequestV1(
        executionId: engineRequest.executionId,
        spec: CliCommandSpec(
            command: scriptURL.path,
            arguments: [],
            environment: [:],
            stdinBytes: stdin,
            cleanupAuthorities: [cleanupAuthority]
        ),
        cliExecutableAuthority: executableAuthority,
        workspaceURL: workspaceURL,
        boundCapabilityTools: EngineBoundCapabilityToolsV1(
            logicalDefinitions: logicalDefinitions,
            capabilityTools: []
        ),
        bridgeExecutableAuthority: bridgeAuthority,
        boardSocketDirectoryAuthority: socketDirectoryAuthority,
        boardSocketBasename: socketURL.lastPathComponent,
        boardToken: String(repeating: "d", count: 64),
        boardCardId: ids.cardId,
        boardTerminalSink: board,
        progressSink: progress
    )
    if closedStdioFixture {
        _ = await LoginShellEnvironment.shared.environment()
        try p1f1d079CloseFixtureStandardDescriptors()
    }
    var iterator = backend.launch(request).makeAsyncIterator()
    var frames: [CliProcessFrameV1] = []
    if let frame = try await iterator.next() { frames.append(frame) }
    while let frame = try await iterator.next() { frames.append(frame) }

    #expect(frames.contains(.stdoutLine("p1f1-079-stdout")))
    #expect(
        frames.contains { frame in
            guard case let .stderr(data) = frame else { return false }
            return String(decoding: data, as: UTF8.self)
                .contains("p1f1-079-stderr")
        }
    )
    #expect(frames.contains(.exited(0)))
    #expect(await board.snapshot().isEmpty)
    #expect(await progress.snapshot().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: cleanupURL.path))
    #expect(!FileManager.default.fileExists(atPath: socketURL.path))
    #expect(processRegistry.activeCount == 0)
    #expect(processInspector.observedExactESRCH)
    #expect(processRevalidator.snapshot() == [.cli, .boardBridge])
    #expect(request.cliExecutableAuthority == executableAuthority)
    #expect(request.spec.stdinBytes == stdin)
    if closedStdioFixture {
        for descriptor in [STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO] {
            let result = fcntl(descriptor, F_GETFD)
            let failure = errno
            #expect(result == -1)
            #expect(failure == EBADF)
        }
        guard let evidencePath =
                environment["AGENTLOOP_R9C_FIXTURE_EVIDENCE"]
        else {
            throw P1F1D079ClosedStdioFixtureError.evidence
        }
        try "closed-stdio-backend-ok\n".write(
            to: URL(fileURLWithPath: evidencePath),
            atomically: true,
            encoding: .utf8
        )
        return
    }

    do {
        _ = try CliProcessLaunchRequestV1(
            executionId: "10000000-0000-4000-8000-000000000079",
            spec: CliCommandSpec(
                command: scriptURL.path,
                arguments: [],
                stdinBytes: Data(repeating: 1, count: 4_194_305)
            ),
            cliExecutableAuthority: executableAuthority,
            workspaceURL: workspaceURL,
            boundCapabilityTools: EngineBoundCapabilityToolsV1(
                logicalDefinitions: logicalDefinitions,
                capabilityTools: []
            ),
            bridgeExecutableAuthority: bridgeAuthority,
            boardSocketDirectoryAuthority: socketDirectoryAuthority,
            boardSocketBasename: "s-1111111111111111.sock",
            boardToken: String(repeating: "d", count: 64),
            boardCardId: ids.cardId,
            boardTerminalSink: board,
            progressSink: progress
        )
        Issue.record("oversized one-shot stdin must fail before spawn")
    } catch is EngineContextValidationErrorV1 {}

    let immediateURL = base.appendingPathComponent("immediate-exit-cli")
    try "#!/bin/sh\nexit 0\n".write(
        to: immediateURL,
        atomically: true,
        encoding: .utf8
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o500],
        ofItemAtPath: immediateURL.path
    )
    let immediateAuthority = try p1f1d079ExecutableAuthority(
        at: immediateURL,
        generation: "e"
    )
    let immediateInspector = P1F1D079ProcessInspector(
        authority: immediateAuthority
    )
    let immediateRegistry = ShellProcessRegistry()
    let immediateRevalidator = P1F1D079SignatureRevalidator(
        expectedCLI: immediateAuthority,
        expectedBoardBridge: bridgeAuthority
    )
    let immediateBackend = try CliProcessBackend(
        registry: immediateRegistry,
        processInspector: immediateInspector,
        codeSignatureRevalidator: immediateRevalidator
    )
    let immediateCleanup = base.appendingPathComponent(
        "immediate-config.json"
    )
    try "{}".write(
        to: immediateCleanup,
        atomically: true,
        encoding: .utf8
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: immediateCleanup.path
    )
    let immediateCleanupAuthority = try CliCleanupFileAuthorityV1
        .captureExisting(immediateCleanup)
    let immediateExecution = "20000000-0000-4000-8000-000000000079"
    let immediateSocket = try BoardToolServer.makeSocketURL(
        directoryAuthority: socketDirectoryAuthority,
        executionId: immediateExecution
    )
    let immediateRequest = try CliProcessLaunchRequestV1(
        executionId: immediateExecution,
        spec: CliCommandSpec(
            command: immediateURL.path,
            arguments: [],
            stdinBytes: Data(repeating: 2, count: 4_194_304),
            cleanupAuthorities: [immediateCleanupAuthority]
        ),
        cliExecutableAuthority: immediateAuthority,
        workspaceURL: workspaceURL,
        boundCapabilityTools: EngineBoundCapabilityToolsV1(
            logicalDefinitions: logicalDefinitions,
            capabilityTools: []
        ),
        bridgeExecutableAuthority: bridgeAuthority,
        boardSocketDirectoryAuthority: socketDirectoryAuthority,
        boardSocketBasename: immediateSocket.lastPathComponent,
        boardToken: String(repeating: "e", count: 64),
        boardCardId: ids.cardId,
        boardTerminalSink: board,
        progressSink: progress
    )
    var sawCheckedEPIPE = false
    do {
        for try await _ in immediateBackend.launch(immediateRequest) {}
    } catch {
        sawCheckedEPIPE = true
    }
    #expect(sawCheckedEPIPE)
    #expect(!FileManager.default.fileExists(atPath: immediateCleanup.path))
    #expect(!FileManager.default.fileExists(atPath: immediateSocket.path))
    #expect(immediateRegistry.activeCount == 0)
    #expect(immediateInspector.observedExactESRCH)
    #expect(immediateRevalidator.snapshot() == [.cli, .boardBridge])

    let descendantURL = base.appendingPathComponent(
        "continuous-descendant-cli"
    )
    let descendantScript = """
    #!/bin/sh
    dd bs=1 count=1 >/dev/null 2>/dev/null
    (
      trap '' TERM PIPE
      while :; do printf '%s' '0123456789abcdef'; done
    ) &
    exit 0
    """
    try descendantScript.write(
        to: descendantURL,
        atomically: true,
        encoding: .utf8
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o500],
        ofItemAtPath: descendantURL.path
    )
    let descendantAuthority = try p1f1d079ExecutableAuthority(
        at: descendantURL,
        generation: "c"
    )
    let descendantInspector = P1F1D079ProcessInspector(
        authority: descendantAuthority
    )
    let descendantRegistry = ShellProcessRegistry()
    let descendantRevalidator = P1F1D079SignatureRevalidator(
        expectedCLI: descendantAuthority,
        expectedBoardBridge: bridgeAuthority
    )
    let descendantBackend = try CliProcessBackend(
        terminationGrace: .milliseconds(30),
        killGrace: .milliseconds(200),
        pipeDrainGrace: .milliseconds(30),
        registry: descendantRegistry,
        processInspector: descendantInspector,
        codeSignatureRevalidator: descendantRevalidator
    )
    let descendantCleanup = base.appendingPathComponent(
        "continuous-descendant-config.json"
    )
    try "{}".write(
        to: descendantCleanup,
        atomically: true,
        encoding: .utf8
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: descendantCleanup.path
    )
    let descendantCleanupAuthority = try CliCleanupFileAuthorityV1
        .captureExisting(descendantCleanup)
    let descendantExecution = "30000000-0000-4000-8000-000000000079"
    let descendantSocket = try BoardToolServer.makeSocketURL(
        directoryAuthority: socketDirectoryAuthority,
        executionId: descendantExecution
    )
    let descendantRequest = try CliProcessLaunchRequestV1(
        executionId: descendantExecution,
        spec: CliCommandSpec(
            command: descendantURL.path,
            arguments: [],
            stdinBytes: Data("x".utf8),
            cleanupAuthorities: [descendantCleanupAuthority]
        ),
        cliExecutableAuthority: descendantAuthority,
        workspaceURL: workspaceURL,
        boundCapabilityTools: EngineBoundCapabilityToolsV1(
            logicalDefinitions: logicalDefinitions,
            capabilityTools: []
        ),
        bridgeExecutableAuthority: bridgeAuthority,
        boardSocketDirectoryAuthority: socketDirectoryAuthority,
        boardSocketBasename: descendantSocket.lastPathComponent,
        boardToken: String(repeating: "c", count: 64),
        boardCardId: ids.cardId,
        boardTerminalSink: board,
        progressSink: progress
    )
    let descendantOutcome = await p1f1d079CollectWithDeadline(
        descendantBackend.launch(descendantRequest)
    )
    switch descendantOutcome {
    case .backendFailure(.pipeDrainIncomplete):
        break
    case .backendFailure(let error):
        Issue.record("wrong continuous-drain failure: \(error)")
    case .unexpectedFailure(let error):
        Issue.record("untyped continuous-drain failure: \(error)")
    case .completedWithoutFailure:
        Issue.record("continuous descendant must expose bounded drain failure")
    case .deadline:
        Issue.record("continuous descendant exceeded the bounded cleanup deadline")
    }
    #expect(descendantRegistry.activeCount == 0)
    #expect(descendantInspector.observedExistingGroup)
    #expect(descendantInspector.observedExactESRCH)
    #expect(descendantInspector.signals.contains { $0.0 == SIGTERM })
    #expect(descendantInspector.signals.contains { $0.0 == SIGKILL })
    #expect(descendantRevalidator.snapshot() == [.cli, .boardBridge])
    #expect(
        !FileManager.default.fileExists(atPath: descendantCleanup.path)
    )
    #expect(!FileManager.default.fileExists(atPath: descendantSocket.path))

    let replacementURL = base.appendingPathComponent(
        "replacement-config.json"
    )
    try "{\"generation\":\"a\"}".write(
        to: replacementURL,
        atomically: true,
        encoding: .utf8
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: replacementURL.path
    )
    let replacementAuthority = try CliCleanupFileAuthorityV1
        .captureExisting(replacementURL)
    try FileManager.default.removeItem(at: replacementURL)
    try "{\"generation\":\"b\"}".write(
        to: replacementURL,
        atomically: true,
        encoding: .utf8
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: replacementURL.path
    )
    do {
        try replacementAuthority.removeExpectedFile()
        Issue.record("cleanup authority must not unlink a replacement file")
    } catch let error as CliCleanupFileErrorV1 {
        #expect(error == .identityMismatch)
    } catch {
        Issue.record("wrong cleanup authority failure type: \(error)")
    }
    #expect(FileManager.default.fileExists(atPath: replacementURL.path))

    let backendSource = try String(
        contentsOfFile:
            "Sources/AgentLoopCore/Loop/CliProcessBackend.swift",
        encoding: .utf8
    )
    #expect(backendSource.contains("errno == EINTR"))
    #expect(backendSource.contains("F_SETNOSIGPIPE"))
    #expect(!backendSource.contains("signal(SIGPIPE"))
    #expect(!backendSource.contains("posix_spawnp("))
    #expect(!backendSource.contains("addinherit_np"))
    try p1f1d071AssertDBFreeSource(
        "Sources/AgentLoopCore/Loop/CliProcessBackend.swift"
    )
    try p1f1d071AssertDBFreeSource(
        "Sources/AgentLoopCore/Loop/CardRunner.swift"
    )
    #expect(
        try p1f1d071Projection(database: database, cardId: ids.cardId)
            == before
    )
}
