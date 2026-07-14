import Foundation
import GRDB

extension AppDatabase {
    private static let globalKernelControlId = "global"

    /// Returns the durable dispatch gate. A missing or corrupt singleton is an
    /// explicit database failure and must never be interpreted as running.
    public func dispatchMode() throws -> DispatchMode {
        try pool.read { db in
            guard let control = try KernelControlRecord.fetchOne(
                db,
                key: Self.globalKernelControlId
            ) else {
                throw RecordNotFoundError(
                    table: KernelControlRecord.databaseTableName,
                    id: Self.globalKernelControlId
                )
            }
            return control.dispatchMode
        }
    }

    /// Atomically moves the global dispatch gate and appends its audit event.
    /// Repeating an already-completed edge is idempotent and writes nothing.
    @discardableResult
    public func transitionDispatchMode(
        from expected: DispatchMode,
        to desired: DispatchMode
    ) throws -> Bool {
        try pool.write { db in
            guard var control = try KernelControlRecord.fetchOne(
                db,
                key: Self.globalKernelControlId
            ) else {
                throw RecordNotFoundError(
                    table: KernelControlRecord.databaseTableName,
                    id: Self.globalKernelControlId
                )
            }

            if control.dispatchMode == desired {
                return false
            }
            guard control.dispatchMode == expected else {
                throw StaleKernelControlStateError(
                    expected: expected,
                    actual: control.dispatchMode
                )
            }

            control.dispatchMode = desired
            control.updatedAt = Date()
            try control.update(db)

            let eventKind: String
            switch desired {
            case .running:
                eventKind = EventKind.campResumed
            case .halted:
                eventKind = EventKind.campHalted
            }
            try Self.appendEvent(
                db,
                missionId: nil,
                cardId: nil,
                runId: nil,
                kind: eventKind,
                payload: .object([:])
            )
            return true
        }
    }
}
