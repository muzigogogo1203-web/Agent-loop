import Foundation
import os

package enum FailurePersistence: Sendable, Equatable {
    case stored
    case unavailable(reason: FailurePersistenceUnavailability)
}

package enum FailurePersistenceUnavailability:
    String, Sendable, Equatable
{
    case failureRecordWriteFailed = "failure_record_write_failed"
}

package struct FailureLogEntry: Sendable, Equatable {
    package let traceId: String
    package let operation: FailureOperation
    package let scope: FailureScope
    package let errorCode: FailureCode
    package let persistence: FailurePersistence

    package init(
        traceId: String,
        operation: FailureOperation,
        scope: FailureScope,
        errorCode: FailureCode,
        persistence: FailurePersistence
    ) {
        self.traceId = traceId
        self.operation = operation
        self.scope = scope
        self.errorCode = errorCode
        self.persistence = persistence
    }
}

package protocol FailureRecordWriting: Sendable {
    func persistFailureRecord(_ record: FailureRecord) throws
}

package protocol FailureLogSink: Sendable {
    func write(_ entry: FailureLogEntry)
}

package struct SystemFailureLogSink: FailureLogSink, Sendable {
    package static let shared = SystemFailureLogSink()
    private static let logger = Logger(
        subsystem: "com.muzi.agentloop",
        category: "failure"
    )

    package func write(_ entry: FailureLogEntry) {
        let persistence: String
        switch entry.persistence {
        case .stored:
            persistence = "stored"
        case .unavailable(let reason):
            persistence = reason.rawValue
        }
        Self.logger.error(
            "failure trace=\(entry.traceId, privacy: .public) operation=\(entry.operation.rawValue, privacy: .public) code=\(entry.errorCode.rawValue, privacy: .public) persistence=\(persistence, privacy: .public)"
        )
    }
}

public struct FailureReporter: Sendable {
    private let writer: any FailureRecordWriting
    private let logSink: any FailureLogSink

    public init(database: AppDatabase) {
        writer = database
        logSink = SystemFailureLogSink.shared
    }

    package init(
        writer: any FailureRecordWriting,
        logSink: any FailureLogSink
    ) {
        self.writer = writer
        self.logSink = logSink
    }

    public func capture(
        _ error: any Error,
        trace: OperationTrace
    ) -> UserVisibleFailure {
        let prepared = prepare(error, trace: trace)
        let persistence = persistPrepared(prepared)
        return complete(prepared, persistence: persistence)
    }

    package func prepare(
        _ error: any Error,
        trace: OperationTrace
    ) -> PreparedFailure {
        FailureRecordFactory.prepared(
            classification: FailureClassifier.classify(error, trace: trace),
            trace: trace,
            now: Date()
        )
    }

    package func persistPrepared(
        _ prepared: PreparedFailure
    ) -> FailurePersistence {
        do {
            try writer.persistFailureRecord(prepared.record)
            return .stored
        } catch {
            return .unavailable(reason: .failureRecordWriteFailed)
        }
    }

    package func complete(
        _ prepared: PreparedFailure,
        persistence: FailurePersistence
    ) -> UserVisibleFailure {
        logSink.write(
            FailureLogEntry(
                traceId: prepared.record.id,
                operation: prepared.record.operation,
                scope: prepared.record.scope,
                errorCode: prepared.record.errorCode,
                persistence: persistence
            )
        )
        return prepared.visible
    }
}

package enum ApplicationBootstrapStage:
    String, Error, Sendable, Equatable
{
    case previewUserDefaults
    case stateDirectory
    case databaseOpen
}

package struct ApplicationBootstrapFailureBoundary: Sendable {
    private let traceFactory: OperationTraceFactory
    private let logSink: any FailureLogSink

    package init(
        traceFactory: OperationTraceFactory,
        logSink: any FailureLogSink
    ) {
        self.traceFactory = traceFactory
        self.logSink = logSink
    }

    package func makeTrace() -> OperationTrace {
        traceFactory.generated(
            operation: .applicationBootstrap,
            scope: .fixed(.application)
        )
    }

    package func capture(
        stage: ApplicationBootstrapStage,
        trace: OperationTrace
    ) -> UserVisibleFailure {
        precondition(trace.operation == .applicationBootstrap)
        precondition(trace.scope.campId == nil)
        precondition(trace.scope.type == .application)
        precondition(trace.scope.id == "application")
        let code: FailureCode
        switch stage {
        case .previewUserDefaults, .stateDirectory:
            code = .unexpectedFailure
        case .databaseOpen:
            code = .databaseReadFailed
        }
        let visible = FailureRecordFactory.bootstrapVisible(
            stage: stage,
            trace: trace
        )
        logSink.write(
            FailureLogEntry(
                traceId: trace.traceId,
                operation: trace.operation,
                scope: trace.scope,
                errorCode: code,
                persistence: .unavailable(
                    reason: .failureRecordWriteFailed
                )
            )
        )
        return visible
    }

    package func terminate(
        stage: ApplicationBootstrapStage,
        trace: OperationTrace
    ) -> Never {
        let failure = capture(stage: stage, trace: trace)
        preconditionFailure(failure.message)
    }
}

package struct ApplicationPostDatabaseBootstrapBoundary: Sendable {
    private let reporter: FailureReporter

    package init(reporter: FailureReporter) {
        self.reporter = reporter
    }

    // P1-B-SEAM applicationPostDatabaseBootstrap
    package func ensureCodingRanchBootstrap(
        trace: OperationTrace,
        _ body: @Sendable () throws -> CodingRanchBootstrapResult
    ) -> OperationCommitOutcome<CodingRanchBootstrapResult> {
        let result = Result { try body() }
        switch result {
        case .success(let value):
            return .committed(value)
        case .failure(let error):
            return .notCommitted(reporter.capture(error, trace: trace))
        }
    }
}
