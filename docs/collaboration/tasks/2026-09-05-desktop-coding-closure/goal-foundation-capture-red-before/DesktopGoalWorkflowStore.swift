import Foundation
import GRDB

// Checkpoint-3 RED scaffold. No persistence or receipt is fabricated by these entry points.
private enum DesktopGoalStoreNotImplemented: Error {
    case checkpoint3
}

package struct DesktopGoalWorkflowStore: Sendable {
    private let database: AppDatabase

    package init(database: AppDatabase) {
        self.database = database
    }

    package func prepareSubmission(_ intent: DesktopGoalCaptureIntentV1) throws -> DesktopGoalCaptureReceiptV1 {
        throw DesktopGoalStoreNotImplemented.checkpoint3
    }

    package func sealCaptureStage(
        operationId: String, expectedVersion: Int, intent: DesktopGoalCaptureIntentV1
    ) throws -> DesktopGoalSealedStageV1 {
        throw DesktopGoalStoreNotImplemented.checkpoint3
    }

    // Shared by the real capture transaction and direct receipt-CAS callers.
    package static func appendCaptureReceipt(
        operationId: String, expectedVersion: Int, receipt: InputCaptureReceiptV1,
        in database: Database
    ) throws -> DesktopGoalStageReceiptV1 {
        throw DesktopGoalStoreNotImplemented.checkpoint3
    }
}
