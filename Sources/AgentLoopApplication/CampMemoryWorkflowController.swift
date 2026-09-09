import Foundation
import AgentLoopCore

package struct CampMemoryWorkflowController: Sendable {
    private let memoryStore: MemoryRecordStore
    private let residencyStore: CowResidencyStore

    package init(
        memoryStore: MemoryRecordStore,
        residencyStore: CowResidencyStore
    ) {
        self.memoryStore = memoryStore
        self.residencyStore = residencyStore
    }

    package static func live(database: AppDatabase) -> Self {
        Self(
            memoryStore: MemoryRecordStore(database: database),
            residencyStore: CowResidencyStore(database: database)
        )
    }

    package func record(
        _ draft: MemoryRecordDraftV1,
        authorizedCowId: String?,
        expectedCampLifecycleVersion: Int?,
        at: Date
    ) throws -> MemoryRecordVersionV1 {
        try memoryStore.record(
            draft,
            authorizedCowId: authorizedCowId,
            expectedCampLifecycleVersion: expectedCampLifecycleVersion,
            at: at
        )
    }

    package func authorizedMemory(
        cowId: String,
        campId: String,
        bridges: [CampBridgeReadV1],
        at: Date
    ) throws -> [MemoryRecordVersionV1] {
        try residencyStore.authorizedMemory(
            cowId: cowId,
            campId: campId,
            bridges: bridges,
            at: at
        )
    }
}
