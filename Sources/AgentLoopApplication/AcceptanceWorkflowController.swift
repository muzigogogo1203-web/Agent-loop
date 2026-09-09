import Foundation
import AgentLoopCore

package enum AcceptanceWorkflowResultV1: Sendable, Equatable {
    case committed(AcceptanceCommitSnapshotV1)
    case notCommitted(AcceptanceWorkflowFailureV1)

    package var mayNavigate: Bool {
        if case .committed = self { return true }
        return false
    }
}

package struct AcceptanceWorkflowFailureV1: Sendable, Equatable {
    package let traceId: String
    package let errorType: String
    package let message: String

    package init(traceId: String, errorType: String, message: String) {
        self.traceId = traceId
        self.errorType = errorType
        self.message = message
    }
}

package struct AcceptanceWorkflowController: Sendable {
    private let readOutcome: @Sendable (String) throws -> OutcomeSnapshotV1?
    private let commit: @Sendable (AcceptOutcomeCommandV1) throws
        -> AcceptanceCommitSnapshotV1

    package init(
        readOutcome: @escaping @Sendable (String) throws
            -> OutcomeSnapshotV1?,
        commit: @escaping @Sendable (AcceptOutcomeCommandV1) throws
            -> AcceptanceCommitSnapshotV1
    ) {
        self.readOutcome = readOutcome
        self.commit = commit
    }

    package static func live(store: OutcomeStore) -> Self {
        Self(
            readOutcome: { try store.outcome(id: $0) },
            commit: { try store.acceptOutcome($0) }
        )
    }

    package func accept(
        _ command: AcceptOutcomeCommandV1
    ) -> AcceptanceWorkflowResultV1 {
        do {
            guard let current = try readOutcome(command.outcome.id),
                  current.currentRef == command.outcome,
                  current.aggregateVersion
                    == command.expectedOutcomeAggregateVersion
            else {
                throw OutcomeReferenceMismatchError()
            }
            return .committed(try commit(command))
        } catch {
            return .notCommitted(AcceptanceWorkflowFailureV1(
                traceId: command.envelope.correlationId,
                errorType: String(reflecting: type(of: error)),
                message: "Acceptance did not commit [trace: \(command.envelope.correlationId)]"
            ))
        }
    }
}

package struct ArtifactViewSessionV1: Sendable, Equatable {
    private var viewedArtifactIDs: Set<String> = []

    package init() {}

    package mutating func recordReveal(artifactId: String) throws {
        try CanonicalContractCodingV1.validateNonempty(artifactId)
        viewedArtifactIDs.insert(artifactId)
    }

    package func hasViewed(artifactId: String) -> Bool {
        viewedArtifactIDs.contains(artifactId)
    }
}

package enum LegacyKnowledgeTruthV1: String, Sendable, Equatable {
    case notConnected
}

package struct LegacyReturnTruthV1: Sendable, Equatable {
    package let usedKnowledge: LegacyKnowledgeTruthV1
    package let writtenBackKnowledge: LegacyKnowledgeTruthV1

    package init() {
        usedKnowledge = .notConnected
        writtenBackKnowledge = .notConnected
    }
}
