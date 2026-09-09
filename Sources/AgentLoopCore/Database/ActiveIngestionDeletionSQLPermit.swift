import Foundation
import GRDB
import GRDBSQLite

package enum ActiveIngestionDeletionSQLPermitErrorV1: Error, Equatable, Sendable {
    case missingSQLiteConnection
    case unknownConnectionRole(code: Int32)
    case duplicateConnectionRegistration
    case sqliteRegistrationFailed(code: Int32)
    case registrationLifecycleMismatch
    case stickyLifecycleFault
    case connectionNotRegistered
    case staleConnectionCell
    case readOnlyConnection
    case transactionRequired
    case transactionForbidden
    case autocommitMismatch
    case generationStillPresent
    case generationMissing
    case generationMismatch
    case cursorMismatch
    case invocationMismatch
    case finishMismatch
}

package enum ActiveIngestionDeletionPermitCursorV1:
    String, Sendable, Equatable
{
    case receipt
    case scope
    case event
    case outbox
    case resultMutation
    case ingestionMutation
    case finish
    case finished
}

package enum ActiveIngestionDeletionPermitInvocationV1:
    String, Sendable, Equatable, Hashable
{
    case deleteResult
    case deleteIngestion
}

package struct ActiveIngestionDeletionPermitExpectedCountsV1:
    Sendable, Equatable
{
    package let deletedResultCount: Int
    package let deletedIngestionCount: Int
    package let updatedIngestionCount: Int
    package let knowledgeSourceLinkCount: Int
    package let actionCandidateCount: Int
    package let nonterminalRuminationWorkCount: Int
    package let openRuminationAttemptCount: Int
    package let nonterminalProviderDispatchCount: Int

    package init(payload: ActiveIngestionDeletionCommandPayloadV1) {
        deletedResultCount = payload.deletedResultCount
        deletedIngestionCount = payload.deletedIngestionCount
        updatedIngestionCount = payload.updatedIngestionCount
        knowledgeSourceLinkCount = payload.knowledgeSourceLinkCount
        actionCandidateCount = payload.actionCandidateCount
        nonterminalRuminationWorkCount = payload.nonterminalRuminationWorkCount
        openRuminationAttemptCount = payload.openRuminationAttemptCount
        nonterminalProviderDispatchCount = payload.nonterminalProviderDispatchCount
    }

    package init(
        deletedResultCount: Int,
        deletedIngestionCount: Int,
        updatedIngestionCount: Int,
        knowledgeSourceLinkCount: Int,
        actionCandidateCount: Int,
        nonterminalRuminationWorkCount: Int,
        openRuminationAttemptCount: Int,
        nonterminalProviderDispatchCount: Int
    ) {
        self.deletedResultCount = deletedResultCount
        self.deletedIngestionCount = deletedIngestionCount
        self.updatedIngestionCount = updatedIngestionCount
        self.knowledgeSourceLinkCount = knowledgeSourceLinkCount
        self.actionCandidateCount = actionCandidateCount
        self.nonterminalRuminationWorkCount = nonterminalRuminationWorkCount
        self.openRuminationAttemptCount = openRuminationAttemptCount
        self.nonterminalProviderDispatchCount = nonterminalProviderDispatchCount
    }
}

package struct ActiveIngestionDeletionSQLGenerationTokenV1:
    Sendable, Equatable
{
    fileprivate let connectionKey: ActiveIngestionDeletionSQLConnectionKeyV1
    fileprivate let generationNonce: UUID
}

private enum ActiveIngestionDeletionSQLValueV1: Sendable, Equatable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)

    init(_ value: DatabaseValue) throws {
        switch value.storage {
        case .null: self = .null
        case .int64(let value): self = .integer(value)
        case .double(let value): self = .real(value)
        case .string(let value): self = .text(value)
        case .blob: throw ActiveIngestionDeletionSQLPermitErrorV1.invocationMismatch
        }
    }
}

private struct ActiveIngestionDeletionSQLGenerationV1: Sendable {
    let nonce: UUID
    let expectedCounts: ActiveIngestionDeletionPermitExpectedCountsV1
    var cursor: ActiveIngestionDeletionPermitCursorV1
    var expectedInvocations:
        [ActiveIngestionDeletionPermitInvocationV1: [ActiveIngestionDeletionSQLValueV1]]
}

package final class ActiveIngestionDeletionSQLPermitCellV1: @unchecked Sendable {
    fileprivate let key: ActiveIngestionDeletionSQLConnectionKeyV1
    fileprivate let role: ActiveIngestionDeletionSQLConnectionRoleV1
    fileprivate var isInvalidated = false
    fileprivate var hasActiveOrFinishedGeneration = false
    fileprivate var generation: ActiveIngestionDeletionSQLGenerationV1?
    fileprivate var lastClearedGenerationNonce: UUID?

    fileprivate init(
        key: ActiveIngestionDeletionSQLConnectionKeyV1,
        role: ActiveIngestionDeletionSQLConnectionRoleV1
    ) {
        self.key = key
        self.role = role
    }
}

package final class ActiveIngestionDeletionSQLPermitRegistryV1: @unchecked Sendable {
    private enum EntryPhase: Sendable {
        case installing
        case installed
    }

    private struct ConnectionEntry: Sendable {
        let key: ActiveIngestionDeletionSQLConnectionKeyV1
        let cellIdentity: ObjectIdentifier
        var phase: EntryPhase
    }

    private final class WeakCell: @unchecked Sendable {
        weak var value: ActiveIngestionDeletionSQLPermitCellV1?

        init(_ value: ActiveIngestionDeletionSQLPermitCellV1) {
            self.value = value
        }
    }

    private enum LifecycleFault: Sendable {
        case duplicateConnectionRegistration
        case registrationReconcileMismatch
        case destroyedConnectionMismatch
    }

    private let lock = NSLock()
    private var entriesByPointer: [UInt: ConnectionEntry] = [:]
    private var weakCellsByKey: [ActiveIngestionDeletionSQLConnectionKeyV1: WeakCell] = [:]
    private var stickyLifecycleFault: LifecycleFault?
    private var installAttempts = 0
    private var rawRegistrationCalls = 0
    private var successfulRegistrations = 0
    private var destroyCalls = 0
    private var contextDeinits = 0
    private var lastConnectionNonceFingerprint = ""
    package init() {}

    package func installConnectionUDF(on db: Database) throws {
        synchronized { installAttempts += 1 }
        guard let pointer = db.sqliteConnection else {
            throw ActiveIngestionDeletionSQLPermitErrorV1.missingSQLiteConnection
        }

        let role: ActiveIngestionDeletionSQLConnectionRoleV1
        switch sqlite3_db_readonly(pointer, "main") {
        case 0:
            role = .writer
        case 1:
            role = .reader
        case let code:
            throw ActiveIngestionDeletionSQLPermitErrorV1.unknownConnectionRole(code: code)
        }

        try installConnectionUDF(
            pointer: pointer,
            role: role,
            invalidFunctionNameForTesting: false
        )
    }

    private func installConnectionUDF(
        pointer: OpaquePointer,
        role: ActiveIngestionDeletionSQLConnectionRoleV1,
        invalidFunctionNameForTesting: Bool
    ) throws {
        let pointerIdentity = ActiveIngestionDeletionSQLConnectionKeyV1
            .pointerIdentity(pointer)
        let key = ActiveIngestionDeletionSQLConnectionKeyV1(
            pointerIdentity: pointerIdentity,
            nonce: UUID()
        )
        let cell = ActiveIngestionDeletionSQLPermitCellV1(key: key, role: role)
        let context = ActiveIngestionDeletionSQLFunctionContextV1(
            registry: self,
            key: key,
            cell: cell
        )

        try synchronized {
            try requireNoStickyFaultLocked()
            guard entriesByPointer[pointerIdentity] == nil else {
                stickyLifecycleFault = .duplicateConnectionRegistration
                throw ActiveIngestionDeletionSQLPermitErrorV1.duplicateConnectionRegistration
            }
            entriesByPointer[pointerIdentity] = ConnectionEntry(
                key: key,
                cellIdentity: ObjectIdentifier(cell),
                phase: .installing
            )
            weakCellsByKey[key] = WeakCell(cell)
        }

        let retainedContext = Unmanaged.passRetained(context).toOpaque()
        synchronized {
            rawRegistrationCalls += 1
            lastConnectionNonceFingerprint = CanonicalJSONV1.sha256Hex(
                Data(key.nonce.uuidString.utf8)
            )
        }
        let functionName = invalidFunctionNameForTesting
            ? String(repeating: "x", count: 256)
            : "agentloop_active_ingestion_deletion_permit_v1"
        let code = sqlite3_create_function_v2(
            pointer,
            functionName,
            -1,
            SQLITE_UTF8,
            retainedContext,
            xFunc,
            nil,
            nil,
            xDestroy
        )

        if code == SQLITE_OK {
            try synchronized {
                try requireNoStickyFaultLocked()
                guard
                    var entry = entriesByPointer[pointerIdentity],
                    entry.key == key,
                    entry.cellIdentity == ObjectIdentifier(cell),
                    entry.phase == .installing,
                    weakCellsByKey[key]?.value === cell,
                    !cell.isInvalidated
                else {
                    stickyLifecycleFault = .registrationReconcileMismatch
                    throw ActiveIngestionDeletionSQLPermitErrorV1.registrationLifecycleMismatch
                }
                entry.phase = .installed
                entriesByPointer[pointerIdentity] = entry
                successfulRegistrations += 1
            }
        } else {
            let teardownWasExact = synchronized {
                entriesByPointer[pointerIdentity] == nil
                    && weakCellsByKey[key] == nil
                    && cell.isInvalidated
                    && stickyLifecycleFault == nil
            }
            guard teardownWasExact else {
                synchronized {
                    stickyLifecycleFault = .registrationReconcileMismatch
                }
                throw ActiveIngestionDeletionSQLPermitErrorV1.registrationLifecycleMismatch
            }
            throw ActiveIngestionDeletionSQLPermitErrorV1.sqliteRegistrationFailed(code: code)
        }
    }

    package func requireWriterCell(
        for db: Database
    ) throws -> ActiveIngestionDeletionSQLPermitCellV1 {
        guard let pointer = db.sqliteConnection else {
            throw ActiveIngestionDeletionSQLPermitErrorV1.missingSQLiteConnection
        }
        let pointerIdentity = ActiveIngestionDeletionSQLConnectionKeyV1.pointerIdentity(pointer)

        return try synchronized {
            try requireNoStickyFaultLocked()
            let cell = try exactInstalledCellLocked(pointerIdentity: pointerIdentity)
            guard cell.role == .writer else {
                throw ActiveIngestionDeletionSQLPermitErrorV1.readOnlyConnection
            }
            guard db.isInsideTransaction else {
                throw ActiveIngestionDeletionSQLPermitErrorV1.transactionRequired
            }
            guard sqlite3_get_autocommit(pointer) == 0 else {
                throw ActiveIngestionDeletionSQLPermitErrorV1.autocommitMismatch
            }
            return cell
        }
    }

    package func assertNoActiveGenerationForResolution(for db: Database) throws {
        guard let pointer = db.sqliteConnection else {
            throw ActiveIngestionDeletionSQLPermitErrorV1.missingSQLiteConnection
        }
        let pointerIdentity = ActiveIngestionDeletionSQLConnectionKeyV1.pointerIdentity(pointer)

        try synchronized {
            try requireNoStickyFaultLocked()
            let cell = try exactInstalledCellLocked(pointerIdentity: pointerIdentity)
            guard cell.role == .writer else {
                throw ActiveIngestionDeletionSQLPermitErrorV1.readOnlyConnection
            }
            guard !db.isInsideTransaction else {
                throw ActiveIngestionDeletionSQLPermitErrorV1.transactionForbidden
            }
            guard sqlite3_get_autocommit(pointer) == 1 else {
                throw ActiveIngestionDeletionSQLPermitErrorV1.autocommitMismatch
            }
            guard !cell.hasActiveOrFinishedGeneration else {
                throw ActiveIngestionDeletionSQLPermitErrorV1.generationStillPresent
            }
        }
    }

    package func beginGeneration(
        on cell: ActiveIngestionDeletionSQLPermitCellV1,
        expectedCounts: ActiveIngestionDeletionPermitExpectedCountsV1
    ) throws -> ActiveIngestionDeletionSQLGenerationTokenV1 {
        try synchronized {
            try requireNoStickyFaultLocked()
            try requireInstalledCellLocked(cell)
            guard cell.generation == nil,
                  !cell.hasActiveOrFinishedGeneration
            else {
                throw ActiveIngestionDeletionSQLPermitErrorV1.generationStillPresent
            }
            let nonce = UUID()
            cell.generation = ActiveIngestionDeletionSQLGenerationV1(
                nonce: nonce,
                expectedCounts: expectedCounts,
                cursor: .receipt,
                expectedInvocations: [:]
            )
            cell.hasActiveOrFinishedGeneration = true
            cell.lastClearedGenerationNonce = nil
            return ActiveIngestionDeletionSQLGenerationTokenV1(
                connectionKey: cell.key,
                generationNonce: nonce
            )
        }
    }

    package func advanceEvidence(
        _ step: ActiveIngestionDeletionPermitCursorV1,
        token: ActiveIngestionDeletionSQLGenerationTokenV1,
        cell: ActiveIngestionDeletionSQLPermitCellV1
    ) throws {
        try synchronized {
            var generation = try requireGenerationLocked(token: token, cell: cell)
            guard generation.cursor == step else {
                throw ActiveIngestionDeletionSQLPermitErrorV1.cursorMismatch
            }
            generation.cursor = switch step {
            case .receipt: .scope
            case .scope: .event
            case .event: .outbox
            case .outbox: .resultMutation
            default: throw ActiveIngestionDeletionSQLPermitErrorV1.cursorMismatch
            }
            cell.generation = generation
        }
    }

    package func registerExpectedInvocation(
        _ values: [DatabaseValue],
        invocation: ActiveIngestionDeletionPermitInvocationV1,
        token: ActiveIngestionDeletionSQLGenerationTokenV1,
        cell: ActiveIngestionDeletionSQLPermitCellV1
    ) throws {
        let normalized = try values.map(ActiveIngestionDeletionSQLValueV1.init)
        try synchronized {
            var generation = try requireGenerationLocked(token: token, cell: cell)
            guard generation.cursor == .resultMutation
                    || generation.cursor == .ingestionMutation,
                  generation.expectedInvocations[invocation] == nil
            else {
                throw ActiveIngestionDeletionSQLPermitErrorV1.cursorMismatch
            }
            generation.expectedInvocations[invocation] = normalized
            cell.generation = generation
        }
    }

    package func consumeStoreMutation(
        _ step: ActiveIngestionDeletionPermitCursorV1,
        token: ActiveIngestionDeletionSQLGenerationTokenV1,
        cell: ActiveIngestionDeletionSQLPermitCellV1
    ) throws {
        try synchronized {
            var generation = try requireGenerationLocked(token: token, cell: cell)
            guard generation.cursor == step else {
                throw ActiveIngestionDeletionSQLPermitErrorV1.cursorMismatch
            }
            switch step {
            case .resultMutation:
                generation.cursor = .ingestionMutation
            case .ingestionMutation:
                generation.cursor = .finish
            default:
                throw ActiveIngestionDeletionSQLPermitErrorV1.cursorMismatch
            }
            cell.generation = generation
        }
    }

    package func finishGeneration(
        token: ActiveIngestionDeletionSQLGenerationTokenV1,
        cell: ActiveIngestionDeletionSQLPermitCellV1,
        observedCounts: ActiveIngestionDeletionPermitExpectedCountsV1
    ) throws {
        try synchronized {
            var generation = try requireGenerationLocked(token: token, cell: cell)
            guard generation.cursor == .finish,
                  generation.expectedCounts == observedCounts
            else {
                throw ActiveIngestionDeletionSQLPermitErrorV1.finishMismatch
            }
            generation.cursor = .finished
            cell.generation = generation
        }
    }

    package func clearGeneration(
        token: ActiveIngestionDeletionSQLGenerationTokenV1,
        cell: ActiveIngestionDeletionSQLPermitCellV1
    ) {
        synchronized {
            guard let generation = cell.generation,
                  cell.key == token.connectionKey,
                  generation.nonce == token.generationNonce
            else {
                stickyLifecycleFault = .registrationReconcileMismatch
                return
            }
            cell.lastClearedGenerationNonce = generation.nonce
            cell.generation = nil
            cell.hasActiveOrFinishedGeneration = false
        }
    }

    package func observeTransactionBoundary(
        token: ActiveIngestionDeletionSQLGenerationTokenV1,
        cell: ActiveIngestionDeletionSQLPermitCellV1
    ) {
        synchronized {
            guard cell.key == token.connectionKey,
                  cell.generation == nil,
                  cell.lastClearedGenerationNonce == token.generationNonce
            else {
                stickyLifecycleFault = .registrationReconcileMismatch
                cell.generation = nil
                cell.hasActiveOrFinishedGeneration = false
                return
            }
            cell.lastClearedGenerationNonce = nil
        }
    }

    fileprivate func acceptsInvocation(
        exactKey: ActiveIngestionDeletionSQLConnectionKeyV1,
        cell: ActiveIngestionDeletionSQLPermitCellV1,
        values: [ActiveIngestionDeletionSQLValueV1]
    ) -> Bool {
        synchronized {
            guard stickyLifecycleFault == nil else { return false }
            guard
                let entry = entriesByPointer[exactKey.pointerIdentity],
                entry.key == exactKey,
                entry.cellIdentity == ObjectIdentifier(cell),
                entry.phase == .installed,
                weakCellsByKey[exactKey]?.value === cell,
                !cell.isInvalidated
            else {
                return false
            }

            guard var generation = cell.generation,
                  cell.hasActiveOrFinishedGeneration,
                  let first = values.first,
                  case .text(let rawStep) = first,
                  let invocation = ActiveIngestionDeletionPermitInvocationV1(
                    rawValue: rawStep
                  ),
                  generation.expectedInvocations[invocation] == values
            else { return false }
            switch invocation {
            case .deleteResult:
                guard generation.cursor == .resultMutation else { return false }
                generation.cursor = .ingestionMutation
            case .deleteIngestion:
                guard generation.cursor == .ingestionMutation else { return false }
                generation.cursor = .finish
            }
            generation.expectedInvocations.removeValue(forKey: invocation)
            cell.generation = generation
            return true
        }
    }

    fileprivate func invalidateDestroyedCell(
        exactKey: ActiveIngestionDeletionSQLConnectionKeyV1,
        cell: ActiveIngestionDeletionSQLPermitCellV1
    ) {
        synchronized {
            destroyCalls += 1
            guard
                weakCellsByKey[exactKey]?.value === cell,
                cell.key == exactKey
            else {
                stickyLifecycleFault = .destroyedConnectionMismatch
                return
            }
            cell.hasActiveOrFinishedGeneration = false
            cell.generation = nil
            cell.lastClearedGenerationNonce = nil
            cell.isInvalidated = true
        }
    }

    fileprivate func removeDestroyedConnection(
        exactKey: ActiveIngestionDeletionSQLConnectionKeyV1,
        cellIdentity: ObjectIdentifier
    ) {
        synchronized {
            guard
                let entry = entriesByPointer[exactKey.pointerIdentity],
                entry.key == exactKey,
                entry.cellIdentity == cellIdentity,
                weakCellsByKey[exactKey]?.value.map(ObjectIdentifier.init) == cellIdentity
            else {
                stickyLifecycleFault = .destroyedConnectionMismatch
                return
            }
            entriesByPointer.removeValue(forKey: exactKey.pointerIdentity)
            weakCellsByKey.removeValue(forKey: exactKey)
        }
    }

    private func exactInstalledCellLocked(
        pointerIdentity: UInt
    ) throws -> ActiveIngestionDeletionSQLPermitCellV1 {
        guard let entry = entriesByPointer[pointerIdentity], entry.phase == .installed else {
            throw ActiveIngestionDeletionSQLPermitErrorV1.connectionNotRegistered
        }
        guard
            let cell = weakCellsByKey[entry.key]?.value,
            ObjectIdentifier(cell) == entry.cellIdentity,
            cell.key == entry.key,
            !cell.isInvalidated
        else {
            throw ActiveIngestionDeletionSQLPermitErrorV1.staleConnectionCell
        }
        return cell
    }

    private func requireInstalledCellLocked(
        _ cell: ActiveIngestionDeletionSQLPermitCellV1
    ) throws {
        let installed = try exactInstalledCellLocked(
            pointerIdentity: cell.key.pointerIdentity
        )
        guard installed === cell else {
            throw ActiveIngestionDeletionSQLPermitErrorV1.staleConnectionCell
        }
    }

    private func requireGenerationLocked(
        token: ActiveIngestionDeletionSQLGenerationTokenV1,
        cell: ActiveIngestionDeletionSQLPermitCellV1
    ) throws -> ActiveIngestionDeletionSQLGenerationV1 {
        try requireNoStickyFaultLocked()
        try requireInstalledCellLocked(cell)
        guard cell.key == token.connectionKey else {
            throw ActiveIngestionDeletionSQLPermitErrorV1.generationMismatch
        }
        guard let generation = cell.generation else {
            throw ActiveIngestionDeletionSQLPermitErrorV1.generationMissing
        }
        guard generation.nonce == token.generationNonce else {
            throw ActiveIngestionDeletionSQLPermitErrorV1.generationMismatch
        }
        return generation
    }

    private func requireNoStickyFaultLocked() throws {
        guard stickyLifecycleFault == nil else {
            throw ActiveIngestionDeletionSQLPermitErrorV1.stickyLifecycleFault
        }
    }

    fileprivate func recordContextDeinit() {
        synchronized { contextDeinits += 1 }
    }

    @discardableResult
    private func synchronized<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}

private struct ActiveIngestionDeletionSQLConnectionKeyV1: Hashable, Sendable {
    let pointerIdentity: UInt
    let nonce: UUID

    static func pointerIdentity(_ pointer: OpaquePointer) -> UInt {
        UInt(bitPattern: Int(bitPattern: pointer))
    }
}

private enum ActiveIngestionDeletionSQLConnectionRoleV1: Sendable {
    case writer
    case reader
}

private final class ActiveIngestionDeletionSQLFunctionContextV1: @unchecked Sendable {
    let registry: ActiveIngestionDeletionSQLPermitRegistryV1
    let key: ActiveIngestionDeletionSQLConnectionKeyV1
    let cell: ActiveIngestionDeletionSQLPermitCellV1

    init(
        registry: ActiveIngestionDeletionSQLPermitRegistryV1,
        key: ActiveIngestionDeletionSQLConnectionKeyV1,
        cell: ActiveIngestionDeletionSQLPermitCellV1
    ) {
        self.registry = registry
        self.key = key
        self.cell = cell
    }

    deinit {
        registry.recordContextDeinit()
    }
}

private let activeIngestionDeletionSQLPermitRejected =
    "agentloop_active_ingestion_deletion_permit_rejected"

private func xFunc(
    _ sqliteContext: OpaquePointer?,
    _ argumentCount: Int32,
    _ arguments: UnsafeMutablePointer<OpaquePointer?>?
) {
    guard
        let sqliteContext,
        let opaqueContext = sqlite3_user_data(sqliteContext),
        let arguments,
        argumentCount == 53 || argumentCount == 63,
        let stepValue = arguments[0],
        sqlite3_value_type(stepValue) == SQLITE_TEXT,
        let stepBytes = sqlite3_value_text(stepValue)
    else {
        sqlite3_result_error(sqliteContext, activeIngestionDeletionSQLPermitRejected, -1)
        return
    }

    let step = String(cString: stepBytes)
    guard
        (argumentCount == 53 && step == "deleteIngestion")
            || (argumentCount == 63 && step == "deleteResult")
    else {
        sqlite3_result_error(sqliteContext, activeIngestionDeletionSQLPermitRejected, -1)
        return
    }

    let context = Unmanaged<ActiveIngestionDeletionSQLFunctionContextV1>
        .fromOpaque(opaqueContext)
        .takeUnretainedValue()
    var values: [ActiveIngestionDeletionSQLValueV1] = []
    values.reserveCapacity(Int(argumentCount))
    for index in 0..<Int(argumentCount) {
        guard let value = arguments[index] else {
            sqlite3_result_error(
                sqliteContext,
                activeIngestionDeletionSQLPermitRejected,
                -1
            )
            return
        }
        switch sqlite3_value_type(value) {
        case SQLITE_NULL:
            values.append(.null)
        case SQLITE_INTEGER:
            values.append(.integer(sqlite3_value_int64(value)))
        case SQLITE_FLOAT:
            values.append(.real(sqlite3_value_double(value)))
        case SQLITE_TEXT:
            guard let bytes = sqlite3_value_text(value) else {
                sqlite3_result_error(
                    sqliteContext,
                    activeIngestionDeletionSQLPermitRejected,
                    -1
                )
                return
            }
            values.append(.text(String(cString: bytes)))
        default:
            sqlite3_result_error(
                sqliteContext,
                activeIngestionDeletionSQLPermitRejected,
                -1
            )
            return
        }
    }
    guard context.registry.acceptsInvocation(
        exactKey: context.key,
        cell: context.cell,
        values: values
    ) else {
        sqlite3_result_error(sqliteContext, activeIngestionDeletionSQLPermitRejected, -1)
        return
    }
    sqlite3_result_int(sqliteContext, 1)
}

private func xDestroy(_ opaqueContext: UnsafeMutableRawPointer?) {
    guard let opaqueContext else { return }
    let context = Unmanaged<ActiveIngestionDeletionSQLFunctionContextV1>
        .fromOpaque(opaqueContext)
        .takeRetainedValue()
    context.registry.invalidateDestroyedCell(exactKey: context.key, cell: context.cell)
    context.registry.removeDestroyedConnection(
        exactKey: context.key,
        cellIdentity: ObjectIdentifier(context.cell)
    )
}

#if DEBUG
package enum ActiveIngestionDeletionSQLPermitLifecycleScenarioV1:
    String, CaseIterable, Sendable, Equatable
{
    case registrationFailure
    case laterPrepareDatabaseSetupThrow
    case directPoolClose
    case duplicatePointerInstall
    case busyCloseThenRetry
    case closeV2ZombieFinalRelease
    case boundedPointerReuse
}

package enum ActiveIngestionDeletionSQLPermitCleanupMismatchV1:
    String, CaseIterable, Sendable, Equatable
{
    case missing
    case wrongKey
    case wrongCell
    case replaced
    case duplicateCleanup
}

package enum ActiveIngestionDeletionSQLCloseResultClassV1:
    String, Sendable, Equatable
{
    case notAttempted
    case success
    case busy
}

package struct ActiveIngestionDeletionSQLPermitLifecycleReportV1:
    Sendable, Equatable
{
    package let scenario: ActiveIngestionDeletionSQLPermitLifecycleScenarioV1
    package let completed: Bool
    package let installAttempts: Int
    package let rawRegistrationCalls: Int
    package let successfulRegistrations: Int
    package let xDestroyCalls: Int
    package let contextDeinits: Int
    package let activeEntries: Int
    package let stickyFaultPresent: Bool
    package let connectionNonceFingerprint: String
    package let firstCloseResultClass:
        ActiveIngestionDeletionSQLCloseResultClassV1
    package let secondCloseResultClass:
        ActiveIngestionDeletionSQLCloseResultClassV1
    package let destroyBeforeFinalRelease: Bool
    package let destroyAfterFinalRelease: Bool
    package let duplicateRejectedBeforeRawCall: Bool
    package let pointerReuseCount: Int
    package let oldContextDestroyedBeforeReuse: Bool
}

package struct ActiveIngestionDeletionSQLPermitCleanupReportV1:
    Sendable, Equatable
{
    package let scenario: ActiveIngestionDeletionSQLPermitCleanupMismatchV1
    package let stickyFaultPresent: Bool
    package let subsequentSetupRejected: Bool
    package let subsequentMutationRejected: Bool
    package let subsequentResolutionRejected: Bool
}

private struct ActiveIngestionDeletionSQLPermitDebugSnapshotV1 {
    let installAttempts: Int
    let rawRegistrationCalls: Int
    let successfulRegistrations: Int
    let destroyCalls: Int
    let contextDeinits: Int
    let activeEntries: Int
    let stickyFaultPresent: Bool
    let connectionNonceFingerprint: String
}

private enum ActiveIngestionDeletionSQLPermitProbeErrorV1: Error {
    case laterSetupFailure
    case noInstalledConnection
    case rawOpenFailed(code: Int32)
    case rawPrepareFailed(code: Int32)
    case rawStepFailed(code: Int32)
    case rawCloseFailed(code: Int32)
    case lifecycleAssertionFailed
    case registrationUnexpectedlySucceeded
}

extension ActiveIngestionDeletionSQLPermitRegistryV1 {
    fileprivate func installFixtureConnection(
        pointer: OpaquePointer,
        invalidFunctionName: Bool = false
    ) throws {
        synchronized { installAttempts += 1 }
        try installConnectionUDF(
            pointer: pointer,
            role: .writer,
            invalidFunctionNameForTesting: invalidFunctionName
        )
    }

    fileprivate func exerciseSQLiteOwnedRegistrationFailure() throws {
        var pointer: OpaquePointer?
        let openCode = sqlite3_open(":memory:", &pointer)
        guard openCode == SQLITE_OK, let pointer else {
            if let pointer {
                _ = sqlite3_close(pointer)
            }
            throw ActiveIngestionDeletionSQLPermitProbeErrorV1
                .rawOpenFailed(code: openCode)
        }
        defer { _ = sqlite3_close(pointer) }
        do {
            try installFixtureConnection(
                pointer: pointer,
                invalidFunctionName: true
            )
        } catch ActiveIngestionDeletionSQLPermitErrorV1
                    .sqliteRegistrationFailed(code: SQLITE_MISUSE) {
            return
        }
        throw ActiveIngestionDeletionSQLPermitProbeErrorV1
            .registrationUnexpectedlySucceeded
    }

    fileprivate func debugSnapshot()
        -> ActiveIngestionDeletionSQLPermitDebugSnapshotV1
    {
        synchronized {
            ActiveIngestionDeletionSQLPermitDebugSnapshotV1(
                installAttempts: installAttempts,
                rawRegistrationCalls: rawRegistrationCalls,
                successfulRegistrations: successfulRegistrations,
                destroyCalls: destroyCalls,
                contextDeinits: contextDeinits,
                activeEntries: entriesByPointer.count,
                stickyFaultPresent: stickyLifecycleFault != nil,
                connectionNonceFingerprint: lastConnectionNonceFingerprint
            )
        }
    }

    fileprivate func injectCleanupMismatchForTesting(
        _ scenario: ActiveIngestionDeletionSQLPermitCleanupMismatchV1
    ) throws {
        let installed: (
            key: ActiveIngestionDeletionSQLConnectionKeyV1,
            cell: ActiveIngestionDeletionSQLPermitCellV1
        ) = try synchronized {
            guard let entry = entriesByPointer.values.first,
                  let cell = weakCellsByKey[entry.key]?.value
            else {
                throw ActiveIngestionDeletionSQLPermitProbeErrorV1
                    .noInstalledConnection
            }
            return (entry.key, cell)
        }
        switch scenario {
        case .missing:
            removeDestroyedConnection(
                exactKey: ActiveIngestionDeletionSQLConnectionKeyV1(
                    pointerIdentity: UInt.max,
                    nonce: UUID()
                ),
                cellIdentity: ObjectIdentifier(installed.cell)
            )
        case .wrongKey:
            removeDestroyedConnection(
                exactKey: ActiveIngestionDeletionSQLConnectionKeyV1(
                    pointerIdentity: installed.key.pointerIdentity,
                    nonce: UUID()
                ),
                cellIdentity: ObjectIdentifier(installed.cell)
            )
        case .wrongCell:
            let other = ActiveIngestionDeletionSQLPermitCellV1(
                key: installed.key,
                role: .writer
            )
            removeDestroyedConnection(
                exactKey: installed.key,
                cellIdentity: ObjectIdentifier(other)
            )
        case .replaced:
            let other = ActiveIngestionDeletionSQLPermitCellV1(
                key: installed.key,
                role: .writer
            )
            synchronized {
                entriesByPointer[installed.key.pointerIdentity] = ConnectionEntry(
                    key: installed.key,
                    cellIdentity: ObjectIdentifier(other),
                    phase: .installed
                )
                weakCellsByKey[installed.key] = WeakCell(other)
            }
            removeDestroyedConnection(
                exactKey: installed.key,
                cellIdentity: ObjectIdentifier(installed.cell)
            )
        case .duplicateCleanup:
            removeDestroyedConnection(
                exactKey: installed.key,
                cellIdentity: ObjectIdentifier(installed.cell)
            )
            removeDestroyedConnection(
                exactKey: installed.key,
                cellIdentity: ObjectIdentifier(installed.cell)
            )
        }
    }
}

package enum ActiveIngestionDeletionSQLPermitTestProbeV1 {
    package static func runLifecycleScenario(
        _ scenario: ActiveIngestionDeletionSQLPermitLifecycleScenarioV1
    ) throws -> ActiveIngestionDeletionSQLPermitLifecycleReportV1 {
        let registry = ActiveIngestionDeletionSQLPermitRegistryV1()
        var firstCloseResultClass:
            ActiveIngestionDeletionSQLCloseResultClassV1 = .notAttempted
        var secondCloseResultClass:
            ActiveIngestionDeletionSQLCloseResultClassV1 = .notAttempted
        var destroyBeforeFinalRelease = false
        var destroyAfterFinalRelease = false
        var duplicateRejectedBeforeRawCall = false
        var pointerReuseCount = 0
        var oldContextDestroyedBeforeReuse = false

        switch scenario {
        case .registrationFailure:
            try registry.exerciseSQLiteOwnedRegistrationFailure()
            destroyAfterFinalRelease = registry.debugSnapshot().destroyCalls == 1

        case .laterPrepareDatabaseSetupThrow,
             .directPoolClose,
             .duplicatePointerInstall:
            var configuration = Configuration()
            configuration.prepareDatabase { database in
                try registry.installConnectionUDF(on: database)
                if scenario == .duplicatePointerInstall {
                    do {
                        try registry.installConnectionUDF(on: database)
                    } catch ActiveIngestionDeletionSQLPermitErrorV1
                                .duplicateConnectionRegistration {
                    }
                }
                if scenario == .laterPrepareDatabaseSetupThrow {
                    throw ActiveIngestionDeletionSQLPermitProbeErrorV1
                        .laterSetupFailure
                }
            }
            do {
                var queue: DatabaseQueue? = try DatabaseQueue(
                    configuration: configuration
                )
                try queue?.read { _ in }
                queue = nil
            } catch ActiveIngestionDeletionSQLPermitProbeErrorV1
                        .laterSetupFailure {
            }
            let snapshot = registry.debugSnapshot()
            destroyAfterFinalRelease = snapshot.destroyCalls == 1
            duplicateRejectedBeforeRawCall =
                scenario == .duplicatePointerInstall
                && snapshot.installAttempts == 2
                && snapshot.rawRegistrationCalls == 1

        case .busyCloseThenRetry:
            var pointer: OpaquePointer?
            let openCode = sqlite3_open(":memory:", &pointer)
            guard openCode == SQLITE_OK, let pointer else {
                if let pointer { _ = sqlite3_close(pointer) }
                throw ActiveIngestionDeletionSQLPermitProbeErrorV1
                    .rawOpenFailed(code: openCode)
            }
            var connectionNeedsClose = true
            defer {
                if connectionNeedsClose { _ = sqlite3_close(pointer) }
            }
            try registry.installFixtureConnection(pointer: pointer)
            var statement: OpaquePointer?
            let prepareCode = sqlite3_prepare_v2(
                pointer,
                "SELECT 1 UNION ALL SELECT 2",
                -1,
                &statement,
                nil
            )
            guard prepareCode == SQLITE_OK, let statement else {
                throw ActiveIngestionDeletionSQLPermitProbeErrorV1
                    .rawPrepareFailed(code: prepareCode)
            }
            var statementNeedsFinalize = true
            defer {
                if statementNeedsFinalize { _ = sqlite3_finalize(statement) }
            }
            let stepCode = sqlite3_step(statement)
            guard stepCode == SQLITE_ROW else {
                throw ActiveIngestionDeletionSQLPermitProbeErrorV1
                    .rawStepFailed(code: stepCode)
            }
            let firstCloseCode = sqlite3_close(pointer)
            guard firstCloseCode == SQLITE_BUSY else {
                throw ActiveIngestionDeletionSQLPermitProbeErrorV1
                    .rawCloseFailed(code: firstCloseCode)
            }
            firstCloseResultClass = .busy
            destroyBeforeFinalRelease =
                registry.debugSnapshot().destroyCalls > 0
            _ = sqlite3_finalize(statement)
            statementNeedsFinalize = false
            let secondCloseCode = sqlite3_close(pointer)
            guard secondCloseCode == SQLITE_OK else {
                throw ActiveIngestionDeletionSQLPermitProbeErrorV1
                    .rawCloseFailed(code: secondCloseCode)
            }
            connectionNeedsClose = false
            secondCloseResultClass = .success
            destroyAfterFinalRelease =
                registry.debugSnapshot().destroyCalls == 1

        case .closeV2ZombieFinalRelease:
            var pointer: OpaquePointer?
            let openCode = sqlite3_open(":memory:", &pointer)
            guard openCode == SQLITE_OK, let pointer else {
                if let pointer { _ = sqlite3_close(pointer) }
                throw ActiveIngestionDeletionSQLPermitProbeErrorV1
                    .rawOpenFailed(code: openCode)
            }
            var connectionNeedsClose = true
            defer {
                if connectionNeedsClose { _ = sqlite3_close(pointer) }
            }
            try registry.installFixtureConnection(pointer: pointer)
            var statement: OpaquePointer?
            let prepareCode = sqlite3_prepare_v2(
                pointer,
                "SELECT 1",
                -1,
                &statement,
                nil
            )
            guard prepareCode == SQLITE_OK, let statement else {
                throw ActiveIngestionDeletionSQLPermitProbeErrorV1
                    .rawPrepareFailed(code: prepareCode)
            }
            let closeCode = sqlite3_close_v2(pointer)
            guard closeCode == SQLITE_OK else {
                _ = sqlite3_finalize(statement)
                throw ActiveIngestionDeletionSQLPermitProbeErrorV1
                    .rawCloseFailed(code: closeCode)
            }
            connectionNeedsClose = false
            firstCloseResultClass = .success
            destroyBeforeFinalRelease =
                registry.debugSnapshot().destroyCalls > 0
            _ = sqlite3_finalize(statement)
            destroyAfterFinalRelease =
                registry.debugSnapshot().destroyCalls == 1

        case .boundedPointerReuse:
            var seenPointers = Set<UInt>()
            var everyOldContextWasDestroyed = true
            for _ in 0..<256 {
                var pointer: OpaquePointer?
                let openCode = sqlite3_open(":memory:", &pointer)
                guard openCode == SQLITE_OK, let pointer else {
                    if let pointer { _ = sqlite3_close(pointer) }
                    throw ActiveIngestionDeletionSQLPermitProbeErrorV1
                        .rawOpenFailed(code: openCode)
                }
                let pointerIdentity =
                    ActiveIngestionDeletionSQLConnectionKeyV1
                        .pointerIdentity(pointer)
                if seenPointers.contains(pointerIdentity) {
                    pointerReuseCount += 1
                    let beforeReuse = registry.debugSnapshot()
                    everyOldContextWasDestroyed =
                        everyOldContextWasDestroyed
                        && beforeReuse.activeEntries == 0
                        && beforeReuse.destroyCalls
                            == beforeReuse.successfulRegistrations
                        && beforeReuse.contextDeinits
                            == beforeReuse.destroyCalls
                } else {
                    seenPointers.insert(pointerIdentity)
                }
                do {
                    try registry.installFixtureConnection(pointer: pointer)
                } catch {
                    _ = sqlite3_close(pointer)
                    throw error
                }
                let closeCode = sqlite3_close(pointer)
                guard closeCode == SQLITE_OK else {
                    throw ActiveIngestionDeletionSQLPermitProbeErrorV1
                        .rawCloseFailed(code: closeCode)
                }
                let afterClose = registry.debugSnapshot()
                guard afterClose.activeEntries == 0,
                      afterClose.destroyCalls
                        == afterClose.successfulRegistrations,
                      afterClose.contextDeinits == afterClose.destroyCalls
                else {
                    throw ActiveIngestionDeletionSQLPermitProbeErrorV1
                        .lifecycleAssertionFailed
                }
            }
            oldContextDestroyedBeforeReuse =
                pointerReuseCount > 0 && everyOldContextWasDestroyed
            destroyAfterFinalRelease =
                registry.debugSnapshot().destroyCalls == 256
        }
        let snapshot = registry.debugSnapshot()
        return ActiveIngestionDeletionSQLPermitLifecycleReportV1(
            scenario: scenario,
            completed: true,
            installAttempts: snapshot.installAttempts,
            rawRegistrationCalls: snapshot.rawRegistrationCalls,
            successfulRegistrations: snapshot.successfulRegistrations,
            xDestroyCalls: snapshot.destroyCalls,
            contextDeinits: snapshot.contextDeinits,
            activeEntries: snapshot.activeEntries,
            stickyFaultPresent: snapshot.stickyFaultPresent,
            connectionNonceFingerprint: snapshot.connectionNonceFingerprint,
            firstCloseResultClass: firstCloseResultClass,
            secondCloseResultClass: secondCloseResultClass,
            destroyBeforeFinalRelease: destroyBeforeFinalRelease,
            destroyAfterFinalRelease: destroyAfterFinalRelease,
            duplicateRejectedBeforeRawCall: duplicateRejectedBeforeRawCall,
            pointerReuseCount: pointerReuseCount,
            oldContextDestroyedBeforeReuse: oldContextDestroyedBeforeReuse
        )
    }

    package static func injectCleanupMismatch(
        _ scenario: ActiveIngestionDeletionSQLPermitCleanupMismatchV1
    ) throws -> ActiveIngestionDeletionSQLPermitCleanupReportV1 {
        let registry = ActiveIngestionDeletionSQLPermitRegistryV1()
        var configuration = Configuration()
        configuration.prepareDatabase { database in
            try registry.installConnectionUDF(on: database)
        }
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "agentloop-p1e-permit-cleanup-\(UUID().uuidString).sqlite"
            ).path
        var queue: DatabaseQueue? = try DatabaseQueue(
            path: path,
            configuration: configuration
        )
        try queue?.writeWithoutTransaction { database in
            try registry.injectCleanupMismatchForTesting(scenario)
        }
        let setupRejected: Bool = (try? queue?.writeWithoutTransaction {
            try registry.installConnectionUDF(on: $0)
        }) == nil
        let mutationRejected: Bool = (try? queue?.write { database in
            _ = try registry.requireWriterCell(for: database)
        }) == nil
        let resolutionRejected: Bool = (try? queue?.writeWithoutTransaction {
            try registry.assertNoActiveGenerationForResolution(for: $0)
        }) == nil
        let sticky = registry.debugSnapshot().stickyFaultPresent
        queue = nil
        return ActiveIngestionDeletionSQLPermitCleanupReportV1(
            scenario: scenario,
            stickyFaultPresent: sticky,
            subsequentSetupRejected: setupRejected,
            subsequentMutationRejected: mutationRejected,
            subsequentResolutionRejected: resolutionRejected
        )
    }
}
#endif
