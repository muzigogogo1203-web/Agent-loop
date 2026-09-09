import Foundation
import AgentLoopCore

package struct CowResidencyWorkflowController: Sendable {
    private let store: CowResidencyStore

    package init(store: CowResidencyStore) {
        self.store = store
    }

    package static func live(database: AppDatabase) -> Self {
        Self(store: CowResidencyStore(database: database))
    }

    package func request(
        _ command: RequestCampResidencyCommandV1
    ) throws -> CampResidencySnapshotV1 {
        try store.request(command)
    }

    package func transition(
        _ command: ChangeCampResidencyCommandV1
    ) throws -> CampResidencySnapshotV1 {
        try store.transition(command)
    }

    package func createBridge(
        _ command: CreateCampBridgeCommandV1
    ) throws -> CampBridgeSnapshotV1 {
        try store.createBridge(command)
    }

    package func revokeBridge(
        _ command: RevokeCampBridgeCommandV1
    ) throws -> CampBridgeSnapshotV1 {
        try store.revokeBridge(command)
    }

    package func residentCows(
        campId: String
    ) throws -> [CowIdentitySnapshotV1] {
        try store.residentCows(campId: campId)
    }
}
