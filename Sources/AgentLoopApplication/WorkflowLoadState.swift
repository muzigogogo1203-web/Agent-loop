import Foundation
import AgentLoopCore

package enum WorkflowLoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(UserVisibleFailure)
}

extension WorkflowLoadState: Equatable where Value: Equatable {}

package struct WorkflowRequestGeneration: Sendable, Equatable {
    fileprivate let rawValue: UInt64

    fileprivate init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

package struct WorkflowProjection<Value: Sendable>: Sendable {
    package private(set) var state: WorkflowLoadState<Value>
    package private(set) var lastLoadedValue: Value?
    package private(set) var generation: WorkflowRequestGeneration

    package init() {
        state = .idle
        lastLoadedValue = nil
        generation = WorkflowRequestGeneration(rawValue: 0)
    }

    package init(loaded value: Value) {
        state = .loaded(value)
        lastLoadedValue = value
        generation = WorkflowRequestGeneration(rawValue: 0)
    }

    package init(initial result: SynchronousCaptureResult<Value>) {
        switch result {
        case .value(let value):
            state = .loaded(value)
            lastLoadedValue = value
        case .failed(let failure):
            state = .failed(failure)
            lastLoadedValue = nil
        }
        generation = WorkflowRequestGeneration(rawValue: 0)
    }

#if DEBUG
    package init(testingGenerationValue: UInt64) {
        state = .idle
        lastLoadedValue = nil
        generation = WorkflowRequestGeneration(
            rawValue: testingGenerationValue
        )
    }
#endif

    package mutating func beginRefresh() throws
        -> WorkflowRequestGeneration
    {
        let (next, overflow) = generation.rawValue.addingReportingOverflow(1)
        if overflow {
            throw ProjectionContractError.generationOverflow
        }
        generation = WorkflowRequestGeneration(rawValue: next)
        state = .loading
        return generation
    }

    @discardableResult
    package mutating func applyTerminal(
        _ terminal: WorkflowLoadState<Value>,
        for generation: WorkflowRequestGeneration
    ) throws -> Bool {
        if self.generation != generation {
            return false
        }
        switch terminal {
        case .loaded(let value):
            lastLoadedValue = value
            state = .loaded(value)
        case .failed(let failure):
            state = .failed(failure)
        case .idle, .loading:
            throw ProjectionContractError.invalidTerminal
        }
        return true
    }
}

package enum SynchronousCaptureResult<Value: Sendable>: Sendable {
    case value(Value)
    case failed(UserVisibleFailure)
}

package enum WorkflowReadTerminal<Value: Sendable>: Sendable {
    case loaded(Value)
    case failed(UserVisibleFailure)
}

extension WorkflowReadTerminal: Equatable where Value: Equatable {}

package enum ApplicationStartupGateDecision: Sendable, Equatable {
    case waitingForOther
    case startNow
    case alreadyStarted
}

@MainActor
package struct ApplicationStartupGate {
    package private(set) var runtimeReady = false
    package private(set) var codingRanchReady = false
    package private(set) var didStart = false

    package init() {}

    package init(
        runtime: WorkflowLoadState<RuntimeWorkflowSnapshot>,
        codingRanch: WorkflowLoadState<CodingRanchBootstrapResult>
    ) {
        if case .loaded = runtime {
            runtimeReady = true
        }
        if case .loaded = codingRanch {
            codingRanchReady = true
        }
    }

    package mutating func claimStartIfReady()
        -> ApplicationStartupGateDecision
    {
        if didStart {
            return .alreadyStarted
        }
        guard runtimeReady, codingRanchReady else {
            return .waitingForOther
        }
        didStart = true
        return .startNow
    }

    package mutating func acceptRuntimeLoaded(
        _ snapshot: RuntimeWorkflowSnapshot
    ) -> ApplicationStartupGateDecision {
        _ = snapshot
        runtimeReady = true
        return claimStartIfReady()
    }

    package mutating func acceptCodingRanchLoaded(
        _ result: CodingRanchBootstrapResult
    ) -> ApplicationStartupGateDecision {
        _ = result
        codingRanchReady = true
        return claimStartIfReady()
    }
}

// P1-B-SEAM synchronousWorkflowLoad
package func captureSynchronous<Value: Sendable>(
    reporter: FailureReporter,
    trace: OperationTrace,
    _ body: () throws -> Value
) -> SynchronousCaptureResult<Value> {
    do {
        return .value(try body())
    } catch {
        return .failed(reporter.capture(error, trace: trace))
    }
}

package func captureSynchronousLoad<Value: Sendable>(
    reporter: FailureReporter,
    trace: OperationTrace,
    _ body: () throws -> Value
) -> WorkflowLoadState<Value> {
    switch captureSynchronous(reporter: reporter, trace: trace, body) {
    case .value(let value):
        return .loaded(value)
    case .failed(let failure):
        return .failed(failure)
    }
}

package func captureAsyncLoad<Value: Sendable>(
    reporter: FailureReporter,
    trace: OperationTrace,
    _ body: @Sendable () async throws -> Value
) async -> WorkflowLoadState<Value> {
    await captureAsyncOperation(
        reporter: reporter,
        trace: trace,
        onFailure: { .failed($0) },
        { .loaded(try await body()) }
    )
}

package func captureAsyncOperation<Terminal: Sendable>(
    reporter: FailureReporter,
    trace: OperationTrace,
    onFailure: @escaping @Sendable (UserVisibleFailure) -> Terminal,
    _ body: @Sendable () async throws -> Terminal
) async -> Terminal {
    do {
        return try await body()
    } catch {
        return onFailure(reporter.capture(error, trace: trace))
    }
}

package enum WorkflowStreamCommitDisposition: Sendable, Equatable {
    case notCommitted
    case committed
}

package enum WorkflowStreamTerminal: Sendable, Equatable {
    case finished(commit: WorkflowStreamCommitDisposition)
    case cancelled(commit: WorkflowStreamCommitDisposition)
    case failed(
        UserVisibleFailure,
        commit: WorkflowStreamCommitDisposition
    )
}

package func captureAsyncStream(
    reporter: FailureReporter,
    trace: OperationTrace,
    isOwnedCancellation: @escaping @Sendable () -> Bool,
    open: @escaping @Sendable () throws
        -> (@Sendable () async throws -> Void)
) async -> WorkflowStreamTerminal {
    var commit = WorkflowStreamCommitDisposition.notCommitted
    do {
        let run = try open()
        commit = .committed
        try await run()
        return .finished(commit: commit)
    } catch is CancellationError {
        if isOwnedCancellation() {
            return .cancelled(commit: commit)
        }
        return .failed(
            reporter.capture(CancellationError(), trace: trace),
            commit: commit
        )
    } catch {
        return .failed(
            reporter.capture(error, trace: trace),
            commit: commit
        )
    }
}
