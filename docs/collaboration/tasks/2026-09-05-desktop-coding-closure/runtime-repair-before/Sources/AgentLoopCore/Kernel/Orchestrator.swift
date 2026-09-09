import Foundation
import CoreFoundation
import CryptoKit
import GRDB
import Darwin
import os
import Security
import Dispatch

package struct PlanningEntryRuntimeSelection: Sendable, Equatable {
    package let runtimeProfileId: String
    package let plannerModel: String

    package init(runtimeProfileId: String, plannerModel: String) {
        self.runtimeProfileId = runtimeProfileId
        self.plannerModel = plannerModel
    }
}

package struct EngineWorkspaceIdentityV1: Codable, Sendable, Equatable {
    package let schemaVersion: Int
    package let campId: String
    package let squadId: String
    package let workspacePath: String
    package let bookmarkHash: String?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case campId
        case squadId
        case workspacePath
        case bookmarkHash
    }

    package init(
        schemaVersion: Int = 1,
        campId: String,
        squadId: String,
        workspacePath: String,
        bookmarkHash: String?
    ) throws {
        guard schemaVersion == 1,
              workspacePath.hasPrefix("/"),
              workspacePath == URL(fileURLWithPath: workspacePath)
                .standardizedFileURL.path,
              workspacePath == "/" || !workspacePath.hasSuffix("/")
        else {
            throw EngineContextValidationErrorV1()
        }
        try CanonicalContractCodingV1.validateCampID(campId)
        try CanonicalContractCodingV1.validateCanonicalUUID(squadId)
        if let bookmarkHash {
            try CanonicalContractCodingV1.validateLowercaseHash(bookmarkHash)
        }
        self.schemaVersion = schemaVersion
        self.campId = campId
        self.squadId = squadId
        self.workspacePath = workspacePath
        self.bookmarkHash = bookmarkHash
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(campId, forKey: .campId)
        try container.encode(squadId, forKey: .squadId)
        try container.encode(workspacePath, forKey: .workspacePath)
        if let bookmarkHash {
            try container.encode(bookmarkHash, forKey: .bookmarkHash)
        } else {
            try container.encodeNil(forKey: .bookmarkHash)
        }
    }

    package init(from decoder: any Decoder) throws {
        try EngineContractValidationV1.requireExactKeys(
            decoder,
            [
                "bookmarkHash", "campId", "schemaVersion", "squadId",
                "workspacePath",
            ]
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            campId: container.decode(String.self, forKey: .campId),
            squadId: container.decode(String.self, forKey: .squadId),
            workspacePath: container.decode(String.self, forKey: .workspacePath),
            bookmarkHash: container.decodeIfPresent(
                String.self,
                forKey: .bookmarkHash
            )
        )
    }
}

package struct EngineWorkspaceResolveRequestV1: Sendable, Equatable {
    package let cardId: String
    package let campId: String
    package let expectedWorkspace: EngineWorkspaceRefV1

    package init(
        cardId: String,
        campId: String,
        expectedWorkspace: EngineWorkspaceRefV1
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(cardId)
        try CanonicalContractCodingV1.validateCampID(campId)
        try CanonicalContractCodingV1.validateNonempty(
            expectedWorkspace.reference
        )
        try CanonicalContractCodingV1.validateLowercaseHash(
            expectedWorkspace.hash
        )
        self.cardId = cardId
        self.campId = campId
        self.expectedWorkspace = expectedWorkspace
    }
}

package struct EnginePreparedWorkspaceClaimV1: Sendable {
    package let request: EngineWorkspaceResolveRequestV1
    package let workspace: EngineWorkspaceRefV1

    package init(
        request: EngineWorkspaceResolveRequestV1,
        workspace: EngineWorkspaceRefV1
    ) {
        self.request = request
        self.workspace = workspace
    }
}

package final class EngineResolvedWorkspaceV1: @unchecked Sendable {
    private final class ReleaseState: @unchecked Sendable {
        private let lock = NSLock()
        private var releaseClosure: (@Sendable () -> Void)?

        init(release: @escaping @Sendable () -> Void) {
            releaseClosure = release
        }

        func release() {
            lock.lock()
            let action = releaseClosure
            releaseClosure = nil
            lock.unlock()
            action?()
        }
    }

    package let identity: EngineWorkspaceIdentityV1
    package let url: URL
    private let releaseState: ReleaseState

    package init(
        identity: EngineWorkspaceIdentityV1,
        url: URL,
        release: @escaping @Sendable () -> Void
    ) throws {
        guard url.isFileURL, url.baseURL == nil,
              url.path.hasPrefix("/"),
              url.standardizedFileURL.path == identity.workspacePath
        else {
            throw EngineContextValidationErrorV1()
        }
        self.identity = identity
        self.url = url
        releaseState = ReleaseState(release: release)
    }

    deinit {
        releaseState.release()
    }

    package func release() {
        releaseState.release()
    }
}

package struct EngineWorkspaceResolverV1: Sendable {
    package let database: AppDatabase

    package init(database: AppDatabase) {
        self.database = database
    }

    package func prepareCurrent(
        cardId: String,
        campId: String
    ) throws -> EnginePreparedWorkspaceClaimV1 {
        let material = try identityMaterial(cardId: cardId, campId: campId)
        let access = try Self.startValidatedAccess(material)
        defer { access.stop() }
        let request = try EngineWorkspaceResolveRequestV1(
            cardId: cardId,
            campId: campId,
            expectedWorkspace: material.workspace
        )
        return EnginePreparedWorkspaceClaimV1(
            request: request,
            workspace: material.workspace
        )
    }

    package func resolve(
        _ request: EngineWorkspaceResolveRequestV1
    ) throws -> EngineResolvedWorkspaceV1 {
        let material = try identityMaterial(
            cardId: request.cardId,
            campId: request.campId
        )
        guard request.expectedWorkspace == material.workspace else {
            throw EngineContextValidationErrorV1()
        }

        let access = try Self.startValidatedAccess(material)
        var transferred = false
        defer {
            if !transferred {
                access.stop()
            }
        }
        guard let url = access.url else {
            throw EngineContextValidationErrorV1()
        }
        let resolved = try EngineResolvedWorkspaceV1(
            identity: material.identity,
            url: url,
            release: { access.stop() }
        )
        transferred = true
        return resolved
    }

    private func identityMaterial(
        cardId: String,
        campId: String
    ) throws -> EngineWorkspaceIdentityMaterialV1 {
        try CanonicalContractCodingV1.validateCanonicalUUID(cardId)
        try CanonicalContractCodingV1.validateCampID(campId)
        let graph = try database.pool.read { database in
            guard let card = try CardRecord.fetchOne(
                database,
                key: cardId
            ),
            let mission = try MissionRecord.fetchOne(
                database,
                key: card.missionId
            ),
            let squad = try SquadRecord.fetchOne(
                database,
                key: mission.squadId
            ),
            let camp = try CampRecord.fetchOne(database, key: squad.campId),
            let workspacePath = squad.workspacePath
            else {
                throw EngineContextValidationErrorV1()
            }
            do {
                try CanonicalContractCodingV1.validateCanonicalUUID(card.id)
                try CanonicalContractCodingV1.validateCanonicalUUID(
                    card.missionId
                )
                try CanonicalContractCodingV1.validateCanonicalUUID(mission.id)
                try CanonicalContractCodingV1.validateCanonicalUUID(
                    mission.squadId
                )
                try CanonicalContractCodingV1.validateCanonicalUUID(squad.id)
                try CanonicalContractCodingV1.validateCampID(squad.campId)
                try CanonicalContractCodingV1.validateCampID(camp.id)
            } catch {
                throw EngineContextValidationErrorV1()
            }
            guard card.id == cardId,
                  mission.id == card.missionId,
                  squad.id == mission.squadId,
                  camp.id == campId,
                  squad.campId == camp.id
            else {
                throw EngineContextValidationErrorV1()
            }
            return (
                camp: camp,
                squad: squad,
                workspacePath: workspacePath,
                bookmark: squad.workspaceBookmark
            )
        }

        let identity = try EngineWorkspaceIdentityV1(
            campId: graph.camp.id,
            squadId: graph.squad.id,
            workspacePath: graph.workspacePath,
            bookmarkHash: graph.bookmark.map(CanonicalJSONV1.sha256Hex)
        )
        let identityBytes = try CanonicalJSONV1.encode(identity)
        return EngineWorkspaceIdentityMaterialV1(
            identity: identity,
            workspace: EngineWorkspaceRefV1(
                reference: "squad-workspace.v1:\(graph.squad.id)",
                hash: CanonicalJSONV1.sha256Hex(identityBytes)
            ),
            bookmark: graph.bookmark
        )
    }

    private static func startValidatedAccess(
        _ material: EngineWorkspaceIdentityMaterialV1
    ) throws -> WorkspaceScopedAccess {
        try validateNoFollowDirectory(material.identity.workspacePath)
        let access = WorkspaceScopedAccess(
            workspacePath: material.identity.workspacePath,
            bookmark: material.bookmark
        )
        var valid = false
        defer {
            if !valid {
                access.stop()
            }
        }
        guard let url = access.url,
              url.isFileURL,
              url.baseURL == nil,
              url.standardizedFileURL.path == material.identity.workspacePath
        else {
            throw EngineContextValidationErrorV1()
        }
        try Self.validateNoFollowDirectory(url.path)
        valid = true
        return access
    }

    private static func validateNoFollowDirectory(_ path: String) throws {
        guard path.hasPrefix("/"),
              path == URL(fileURLWithPath: path).standardizedFileURL.path,
              path == "/" || !path.hasSuffix("/")
        else {
            throw EngineContextValidationErrorV1()
        }
        let flags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        var pathStatus = stat()
        guard Darwin.lstat(path, &pathStatus) == 0,
              pathStatus.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR)
        else {
            throw EngineContextValidationErrorV1()
        }
        let directoryDescriptor = Darwin.open(path, flags)
        guard directoryDescriptor >= 0 else {
            throw EngineContextValidationErrorV1()
        }
        defer { Darwin.close(directoryDescriptor) }

        var openedStatus = stat()
        guard Darwin.fstat(directoryDescriptor, &openedStatus) == 0,
              openedStatus.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR),
              openedStatus.st_dev == pathStatus.st_dev,
              openedStatus.st_ino == pathStatus.st_ino
        else {
            throw EngineContextValidationErrorV1()
        }
    }
}

private struct EngineWorkspaceIdentityMaterialV1: Sendable {
    let identity: EngineWorkspaceIdentityV1
    let workspace: EngineWorkspaceRefV1
    let bookmark: Data?
}

package typealias EngineRoutedEventCommitV1 =
    @Sendable (EngineExecutionEvent) async throws -> Void

package typealias EngineTerminalManifestResolveV1 =
    @Sendable (HandoffPayload) throws
        -> [EngineTerminalArtifactDeclarationV1]

package struct EngineAdapterTerminalRouterSinkV1: EngineTerminalSink {
    package let router: EngineEventRouterV1
    package let manifestResolver: EngineTerminalManifestResolveV1
    package let commit: EngineRoutedEventCommitV1

    package init(
        router: EngineEventRouterV1,
        manifestResolver: @escaping EngineTerminalManifestResolveV1,
        commit: @escaping EngineRoutedEventCommitV1
    ) {
        self.router = router
        self.manifestResolver = manifestResolver
        self.commit = commit
    }

    package func submit(_ intent: EngineTerminalIntentV1) async throws {
        let artifacts: [EngineTerminalArtifactDeclarationV1]
        switch intent {
        case let .completed(handoff):
            artifacts = try manifestResolver(handoff)
        case .blocked, .needsHumanInput, .failed, .canceled:
            artifacts = []
        }
        let event = try await router.routeTerminal(
            intent,
            artifacts: artifacts
        )
        try await commit(event)
    }
}

package struct EngineBoardTerminalRouterSinkV1: EngineBoardTerminalSink {
    package let router: EngineEventRouterV1
    package let manifestResolver: EngineTerminalManifestResolveV1
    package let commit: EngineRoutedEventCommitV1

    package init(
        router: EngineEventRouterV1,
        manifestResolver: @escaping EngineTerminalManifestResolveV1,
        commit: @escaping EngineRoutedEventCommitV1
    ) {
        self.router = router
        self.manifestResolver = manifestResolver
        self.commit = commit
    }

    package func submit(_ intent: EngineBoardTerminalIntentV1) async throws {
        let terminalIntent: EngineTerminalIntentV1
        let artifacts: [EngineTerminalArtifactDeclarationV1]
        switch intent {
        case let .completed(handoff):
            terminalIntent = .completed(handoff: handoff)
            artifacts = try manifestResolver(handoff)
        case let .blocked(reasonCode, detail):
            terminalIntent = .blocked(
                subtype: .ordinary,
                reasonCode: reasonCode,
                detail: detail
            )
            artifacts = []
        case let .needsHumanInput(kind, prompt, options):
            terminalIntent = .needsHumanInput(
                kind: kind,
                prompt: prompt,
                options: options
            )
            artifacts = []
        }
        let event = try await router.routeTerminal(
            terminalIntent,
            artifacts: artifacts
        )
        try await commit(event)
    }
}

package struct EngineProgressRouterSinkV1: EngineProgressSink {
    package let router: EngineEventRouterV1
    package let commit: EngineRoutedEventCommitV1

    package init(
        router: EngineEventRouterV1,
        commit: @escaping EngineRoutedEventCommitV1
    ) {
        self.router = router
        self.commit = commit
    }

    package func submit(
        _ payload: EngineExecutionEventPayloadV1
    ) async throws {
        let event = try await router.route(payload)
        try await commit(event)
    }
}

package typealias EngineExecutionTransportSeedResolveV1 =
    @Sendable (EngineExecutionRequest) async throws
        -> EngineExecutionTransportSeedV1

package struct EnginePreparedDispatchV1: Sendable {
    package let requestFields: EngineExecutionRequestFieldsV1
    package let idempotencyKey: String
    package let context: EnginePreparedContextV1
    package let workspace: EnginePreparedWorkspaceClaimV1
    package let selected: EngineAdapterPreparedRequestV1

    package init(
        requestFields: EngineExecutionRequestFieldsV1,
        idempotencyKey: String,
        context: EnginePreparedContextV1,
        workspace: EnginePreparedWorkspaceClaimV1,
        selected: EngineAdapterPreparedRequestV1
    ) {
        self.requestFields = requestFields
        self.idempotencyKey = idempotencyKey
        self.context = context
        self.workspace = workspace
        self.selected = selected
    }
}

package struct EngineDispatchIdentityV1: Sendable, Equatable {
    package let campId: String
    package let cardId: String
    package let companionId: String
    package let cause: EngineCardReadyCauseV1

    package init(
        campId: String,
        cardId: String,
        companionId: String,
        cause: EngineCardReadyCauseV1
    ) {
        self.campId = campId
        self.cardId = cardId
        self.companionId = companionId
        self.cause = cause
    }
}

package enum EngineExecutionBindDispositionV1: Sendable, Equatable {
    case dispatch
    case cancel(reason: String)
}

package typealias EngineExecutionDidBindV1 =
    @Sendable (EngineExecutionRequest) async throws
        -> EngineExecutionBindDispositionV1

package typealias EngineRoutedEventDidCommitV1 =
    @Sendable (_ cardId: String, _ event: EngineExecutionEvent) async -> Void

package typealias EngineCancellationResolveV1 =
    @Sendable (
        _ handle: EngineExecutionCompletionHandleV1,
        _ reason: String
    ) async throws -> EngineTerminalCommitReceiptV1

package enum EngineCancellationLifecycleDispositionV1: Sendable, Equatable {
    case noTransport
    case registeredCleanupComplete
}

package enum EngineActiveExecutionRegistrationDispositionV1:
    Sendable, Equatable
{
    case installed
    case pendingCancellationConsumed(reason: String)
}

package enum EngineActiveExecutionCancellationDispositionV1:
    Sendable, Equatable
{
    case latched
    case cancelledAndAwaited
}

private final class EngineExecutionStartGateStateV1: @unchecked Sendable {
    private let lock = NSLock()
    private var opened = false
    private var canceled = false
    private var waiter: CheckedContinuation<Void, Error>?

    func waitUntilOpened() async throws {
        try Task.checkCancellation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let outcome = lock.withLock { () -> Result<Void, Error>? in
                    if opened { return .success(()) }
                    if canceled { return .failure(CancellationError()) }
                    guard waiter == nil else {
                        return .failure(EngineDispatchConflictErrorV1())
                    }
                    waiter = continuation
                    return nil
                }
                if let outcome { continuation.resume(with: outcome) }
            }
        } onCancel: {
            cancel()
        }
    }

    func open() throws {
        let current: CheckedContinuation<Void, Error>? = try lock.withLock {
            if canceled { return nil }
            guard !opened else {
                throw EngineDispatchConflictErrorV1()
            }
            opened = true
            let current = waiter
            waiter = nil
            return current
        }
        current?.resume()
    }

    func cancel() {
        let current = lock.withLock { () -> CheckedContinuation<Void, Error>? in
            guard !opened, !canceled else { return nil }
            canceled = true
            let current = waiter
            waiter = nil
            return current
        }
        current?.resume(throwing: CancellationError())
    }

    func snapshotWaiterCount() -> Int {
        lock.withLock { waiter == nil ? 0 : 1 }
    }
}

package actor EngineExecutionStartGateV1 {
    private nonisolated let state = EngineExecutionStartGateStateV1()

    package init() {}

    package func waitUntilOpened() async throws {
        try await state.waitUntilOpened()
    }

    package func open() throws {
        try state.open()
    }

    package func snapshotWaiterCount() -> Int {
        state.snapshotWaiterCount()
    }
}

private actor EngineExecutionCancellationStateV1 {
    private var resolver: EngineCancellationResolveV1?
    private var resolverDiscarded = false
    private var reason: String?
    private var resolutionInFlight = false
    private var resolutionWaiters: [
        CheckedContinuation<EngineTerminalCommitReceiptV1, Error>
    ] = []
    private var resolvedReceipt: EngineTerminalCommitReceiptV1?
    private var lifecycle: EngineCancellationLifecycleDispositionV1?
    private var standaloneExternalLifecyclePending = false
    private var lifecycleConsumed = false
    private var lifecycleWaiter: CheckedContinuation<
        EngineCancellationLifecycleDispositionV1,
        Error
    >?

    init(resolver: @escaping EngineCancellationResolveV1) {
        self.resolver = resolver
    }

    func resolve(
        handle: EngineExecutionCompletionHandleV1,
        reason proposedReason: String
    ) async throws -> EngineTerminalCommitReceiptV1 {
        try EngineContractValidationV1.validateReasonCode(proposedReason)
        if let reason {
            guard reason == proposedReason else {
                throw EngineDispatchConflictErrorV1()
            }
        } else {
            reason = proposedReason
        }
        if let resolvedReceipt { return resolvedReceipt }
        if resolutionInFlight {
            return try await withCheckedThrowingContinuation {
                resolutionWaiters.append($0)
            }
        }
        guard let resolver, !resolverDiscarded else {
            throw EngineDispatchConflictErrorV1()
        }
        self.resolver = nil
        resolutionInFlight = true
        do {
            let receipt = try await resolver(handle, proposedReason)
            guard receipt.executionId == handle.executionId else {
                throw EngineDispatchConflictErrorV1()
            }
            resolutionInFlight = false
            resolvedReceipt = receipt
            let waiters = resolutionWaiters
            resolutionWaiters.removeAll()
            waiters.forEach { $0.resume(returning: receipt) }
            return receipt
        } catch {
            resolutionInFlight = false
            if !resolverDiscarded { self.resolver = resolver }
            let waiters = resolutionWaiters
            resolutionWaiters.removeAll()
            waiters.forEach { $0.resume(throwing: error) }
            throw error
        }
    }

    func publishLifecycle(
        _ disposition: EngineCancellationLifecycleDispositionV1
    ) throws {
        if let lifecycle {
            guard lifecycle == disposition else {
                throw EngineDispatchConflictErrorV1()
            }
            return
        }
        lifecycle = disposition
        if let waiter = lifecycleWaiter {
            lifecycleWaiter = nil
            lifecycleConsumed = true
            waiter.resume(returning: disposition)
        }
    }

    func markStandaloneExternalLifecyclePending() throws {
        guard lifecycle == nil,
              !lifecycleConsumed,
              lifecycleWaiter == nil
        else {
            throw EngineDispatchConflictErrorV1()
        }
        standaloneExternalLifecyclePending = true
    }

    func resolveLifecycle(
        for activeDisposition:
            EngineActiveExecutionCancellationDispositionV1
    ) async throws -> EngineCancellationLifecycleDispositionV1 {
        switch activeDisposition {
        case .latched:
            if standaloneExternalLifecyclePending {
                try publishLifecycle(.noTransport)
            }
        case .cancelledAndAwaited:
            try publishLifecycle(.registeredCleanupComplete)
        }
        return try await waitForLifecycle()
    }

    func waitForLifecycle() async throws
        -> EngineCancellationLifecycleDispositionV1
    {
        guard !lifecycleConsumed, lifecycleWaiter == nil else {
            throw EngineDispatchConflictErrorV1()
        }
        if let lifecycle {
            lifecycleConsumed = true
            return lifecycle
        }
        return try await withCheckedThrowingContinuation { continuation in
            lifecycleWaiter = continuation
        }
    }

    func discardResolver() {
        resolverDiscarded = true
        resolver = nil
    }
}

private final class EngineExecutionCancellationBindingV1:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var pending: EngineExecutionCancellationStateV1?
    private weak var installed: EngineExecutionCancellationStateV1?

    init(resolver: @escaping EngineCancellationResolveV1) {
        pending = EngineExecutionCancellationStateV1(resolver: resolver)
    }

    func take() throws -> EngineExecutionCancellationStateV1 {
        try lock.withLock {
            guard let pending else {
                throw EngineDispatchConflictErrorV1()
            }
            self.pending = nil
            installed = pending
            return pending
        }
    }

    func state() throws -> EngineExecutionCancellationStateV1 {
        try lock.withLock {
            if let pending { return pending }
            guard let installed else {
                throw EngineDispatchConflictErrorV1()
            }
            return installed
        }
    }
}

package actor EngineExecutionCompletionHandleV1 {
    package nonisolated let executionId: String

    private enum Completion {
        case receipt(EngineTerminalCommitReceiptV1)
        case failure(any Error)

        func value() throws -> EngineTerminalCommitReceiptV1 {
            switch self {
            case let .receipt(receipt): return receipt
            case let .failure(error): throw error
            }
        }
    }

    private var completion: Completion?
    private var authorizedReceipt: EngineTerminalCommitReceiptV1?
    private var receiptWaiters: [
        UUID: CheckedContinuation<EngineTerminalCommitReceiptV1, Error>
    ] = [:]
    private nonisolated let cancellationBinding:
        EngineExecutionCancellationBindingV1

    package init(
        executionId: String,
        resolveCancellation: @escaping EngineCancellationResolveV1
    ) throws {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        } catch {
            throw EngineDispatchConflictErrorV1()
        }
        self.executionId = executionId
        cancellationBinding = EngineExecutionCancellationBindingV1(
            resolver: resolveCancellation
        )
    }

    fileprivate nonisolated func takeCancellationState() throws
        -> EngineExecutionCancellationStateV1
    {
        try cancellationBinding.take()
    }

    private nonisolated func installedCancellationState() throws
        -> EngineExecutionCancellationStateV1
    {
        try cancellationBinding.state()
    }

    package func waitForReceipt() async throws
        -> EngineTerminalCommitReceiptV1
    {
        try Task.checkCancellation()
        let waiterID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if let completion {
                    continuation.resume(with: Result {
                        try completion.value()
                    })
                } else if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    receiptWaiters[waiterID] = continuation
                }
            }
        } onCancel: {
            Task { await self.cancelReceiptWaiter(waiterID) }
        }
    }

    private func cancelReceiptWaiter(_ waiterID: UUID) {
        receiptWaiters.removeValue(forKey: waiterID)?
            .resume(throwing: CancellationError())
    }

    package func resolveCancellation(
        reason: String
    ) async throws -> EngineTerminalCommitReceiptV1 {
        let state = try installedCancellationState()
        return try await state.resolve(handle: self, reason: reason)
    }

    package func publishCancellationLifecycle(
        _ disposition: EngineCancellationLifecycleDispositionV1
    ) async throws {
        let state = try installedCancellationState()
        try await state.publishLifecycle(disposition)
    }

    package func waitForCancellationLifecycle() async throws
        -> EngineCancellationLifecycleDispositionV1
    {
        let state = try installedCancellationState()
        return try await state.waitForLifecycle()
    }

    fileprivate func markStandaloneExternalCancellationOwner() async throws {
        let state = try installedCancellationState()
        try await state.markStandaloneExternalLifecyclePending()
    }

    fileprivate func resolveCancellationLifecycle(
        for activeDisposition:
            EngineActiveExecutionCancellationDispositionV1
    ) async throws -> EngineCancellationLifecycleDispositionV1
    {
        let state = try installedCancellationState()
        return try await state.resolveLifecycle(for: activeDisposition)
    }

    fileprivate func authorizeDelivery(
        receipt: EngineTerminalCommitReceiptV1
    ) throws {
        guard receipt.executionId == executionId else {
            throw EngineDispatchConflictErrorV1()
        }
        if let authorizedReceipt {
            guard authorizedReceipt == receipt else {
                throw EngineDispatchConflictErrorV1()
            }
            return
        }
        authorizedReceipt = receipt
    }

    package func complete(
        receipt: EngineTerminalCommitReceiptV1
    ) throws {
        guard authorizedReceipt == receipt else {
            throw EngineDispatchConflictErrorV1()
        }
        if let completion {
            guard case let .receipt(stored) = completion,
                  stored == receipt
            else { throw EngineDispatchConflictErrorV1() }
            return
        }
        completion = .receipt(receipt)
        let waiters = Array(receiptWaiters.values)
        receiptWaiters.removeAll()
        waiters.forEach { $0.resume(returning: receipt) }
    }

    fileprivate func completeTerminalWinner(
        receipt: EngineTerminalCommitReceiptV1
    ) throws {
        try complete(receipt: receipt)
    }

    fileprivate func fail(_ error: any Error) throws {
        guard completion == nil else {
            throw EngineDispatchConflictErrorV1()
        }
        completion = .failure(error)
        let waiters = Array(receiptWaiters.values)
        receiptWaiters.removeAll()
        waiters.forEach { $0.resume(throwing: error) }
    }

    package func snapshotHasDeliveredCompletion() -> Bool {
        completion != nil
    }
}

private final class EngineExecutionCompletionAttemptTokenV1:
    @unchecked Sendable
{}

private final class EngineExecutionCompletionGenerationTokenV1:
    @unchecked Sendable
{}

private final class EngineExecutionCompletionChildTokenV1:
    @unchecked Sendable
{}

private final class EngineExecutionCompletionOutcomeCellV1:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var result: Result<EngineTerminalCommitReceiptV1, any Error>?
    private var primaryMayResolve = true
    private var waiters: [
        CheckedContinuation<EngineTerminalCommitReceiptV1, Error>
    ] = []

    func wait() async throws -> EngineTerminalCommitReceiptV1 {
        try await withCheckedThrowingContinuation { continuation in
            let immediate = lock.withLock {
                () -> Result<EngineTerminalCommitReceiptV1, any Error>? in
                if let result { return result }
                waiters.append(continuation)
                return nil
            }
            guard let immediate else { return }
            continuation.resume(with: immediate)
        }
    }

    func suppressPrimaryResolution() {
        lock.withLock { primaryMayResolve = false }
    }

    func resolveFromPrimaryIfAllowed(
        _ result: Result<EngineTerminalCommitReceiptV1, any Error>
    ) {
        let current = lock.withLock { () -> [
            CheckedContinuation<EngineTerminalCommitReceiptV1, Error>
        ] in
            guard primaryMayResolve, self.result == nil else { return [] }
            self.result = result
            let current = waiters
            waiters.removeAll()
            return current
        }
        current.forEach { $0.resume(with: result) }
    }

    func resolveIfPending(
        _ result: Result<EngineTerminalCommitReceiptV1, any Error>
    ) {
        let current = lock.withLock { () -> [
            CheckedContinuation<EngineTerminalCommitReceiptV1, Error>
        ] in
            guard self.result == nil else { return [] }
            self.result = result
            let current = waiters
            waiters.removeAll()
            return current
        }
        current.forEach { $0.resume(with: result) }
    }
}

private struct EngineExecutionCompletionGenerationControlV1: Sendable {
    let registry: EngineExecutionCompletionRegistryV1
    let executionId: String
    let generation: EngineExecutionCompletionGenerationTokenV1
    let attemptToken: EngineExecutionCompletionAttemptTokenV1

    func claimDispatchPermit() async throws {
        try await registry.claimDispatchPermit(
            executionId: executionId,
            generation: generation,
            attemptToken: attemptToken
        )
    }

    func claimTerminalPermit() async throws {
        try await registry.claimTerminalPermit(
            executionId: executionId,
            generation: generation,
            attemptToken: attemptToken
        )
    }

    func requestCancellation(
        reason: String,
        requiresNoTransport: Bool
    ) async throws -> EngineTerminalCommitReceiptV1 {
        guard let task = try await registry.requestCancellationFromPrimary(
            executionId: executionId,
            generation: generation,
            attemptToken: attemptToken,
            reason: reason,
            requiresNoTransport: requiresNoTransport
        ) else { throw CancellationError() }
        return try await task.value
    }
}

private struct EngineExecutionCompletionTaskClaimV1: Sendable {
    let handle: EngineExecutionCompletionHandleV1
    let task: Task<EngineTerminalCommitReceiptV1, Error>
    let didInstallGeneration: Bool
    let didInstallOwner: Bool
}

package actor EngineExecutionCompletionRegistryV1 {
    private enum CancellationOrigin: Sendable, Equatable {
        case external
        case primary
    }

    private enum Phase: Sendable, Equatable {
        case binding
        case dispatchPermitted
        case terminalOwned
        case cancellationRunning
    }

    private struct PrimaryChild: Sendable {
        let token: EngineExecutionCompletionChildTokenV1
        let task: Task<EngineTerminalCommitReceiptV1, Error>
    }

    private struct CancellationChild: Sendable {
        let token: EngineExecutionCompletionChildTokenV1
        let task: Task<EngineTerminalCommitReceiptV1, Error>
        let origin: CancellationOrigin
    }

    private struct Attempt: Sendable {
        let token: EngineExecutionCompletionAttemptTokenV1
        let outcome: EngineExecutionCompletionOutcomeCellV1
        let outcomeTask: Task<EngineTerminalCommitReceiptV1, Error>
        var primary: PrimaryChild?
        var cancellation: CancellationChild?
        var cancellationReason: String?
        var phase: Phase
    }

    private struct Entry: Sendable {
        let generation: EngineExecutionCompletionGenerationTokenV1
        let handle: EngineExecutionCompletionHandleV1
        let cancellationState: EngineExecutionCancellationStateV1
        let externallyPreinstalled: Bool
        var authorizedReceipt: EngineTerminalCommitReceiptV1?
        var attempt: Attempt?
        var claimCount: Int
    }

    private var entries: [String: Entry] = [:]
    private let captureCounter: EngineRuntimeCaptureCounterV1?
    private let cancellationCommandObserver: @Sendable (String) async -> Void
    private let primaryCancellationChildSettledObserver: @Sendable (
        String,
        String
    ) async -> Void
    private let beforeAuthorizedRemoval: @Sendable (
        String,
        EngineTerminalCommitReceiptV1,
        EngineExecutionCompletionHandleV1
    ) async throws -> Void

    package init(
        cancellationCommandObserver: @escaping @Sendable (String) async
            -> Void = { _ in },
        primaryCancellationChildSettledObserver: @escaping @Sendable (
            String,
            String
        ) async -> Void = { _, _ in },
        beforeAuthorizedRemoval: @escaping @Sendable (
            String,
            EngineTerminalCommitReceiptV1,
            EngineExecutionCompletionHandleV1
        ) async throws -> Void = { _, _, _ in }
    ) {
        captureCounter = nil
        self.cancellationCommandObserver = cancellationCommandObserver
        self.primaryCancellationChildSettledObserver =
            primaryCancellationChildSettledObserver
        self.beforeAuthorizedRemoval = beforeAuthorizedRemoval
    }

    fileprivate init(captureCounter: EngineRuntimeCaptureCounterV1) {
        self.captureCounter = captureCounter
        cancellationCommandObserver = { _ in }
        primaryCancellationChildSettledObserver = { _, _ in }
        beforeAuthorizedRemoval = { _, _, _ in }
    }

    package func lookupOrInstall(
        executionId: String,
        makeHandle: @Sendable () throws
            -> EngineExecutionCompletionHandleV1
    ) async throws -> (
        handle: EngineExecutionCompletionHandleV1,
        didInstall: Bool
    ) {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        } catch {
            throw EngineDispatchConflictErrorV1()
        }
        if let entry = entries[executionId] {
            return (entry.handle, false)
        }
        let handle = try makeHandle()
        guard handle.executionId == executionId else {
            throw EngineDispatchConflictErrorV1()
        }
        let cancellationState = try handle.takeCancellationState()
        try captureCounter?.retain()
        entries[executionId] = Entry(
            generation: EngineExecutionCompletionGenerationTokenV1(),
            handle: handle,
            cancellationState: cancellationState,
            externallyPreinstalled: true,
            authorizedReceipt: nil,
            attempt: nil,
            claimCount: 0
        )
        return (handle, true)
    }

    package func authorizeRemoval(
        executionId: String,
        terminalReceipt: EngineTerminalCommitReceiptV1
    ) async throws {
        try await authorizeRemovalCore(
            executionId: executionId,
            terminalReceipt: terminalReceipt,
            matching: nil
        )
    }

    fileprivate func authorizeRemoval(
        executionId: String,
        terminalReceipt: EngineTerminalCommitReceiptV1,
        matching handle: EngineExecutionCompletionHandleV1
    ) async throws {
        try await authorizeRemovalCore(
            executionId: executionId,
            terminalReceipt: terminalReceipt,
            matching: handle
        )
    }

    private func authorizeRemovalCore(
        executionId: String,
        terminalReceipt: EngineTerminalCommitReceiptV1,
        matching handle: EngineExecutionCompletionHandleV1?
    ) async throws {
        try validateExecutionID(executionId)
        guard terminalReceipt.executionId == executionId,
              var entry = entries[executionId]
        else {
            throw EngineDispatchConflictErrorV1()
        }
        if let handle, entry.handle !== handle {
            throw EngineDispatchConflictErrorV1()
        }
        if let authorized = entry.authorizedReceipt {
            guard authorized == terminalReceipt else {
                throw EngineDispatchConflictErrorV1()
            }
            return
        }
        await entry.cancellationState.discardResolver()
        try await entry.handle.authorizeDelivery(receipt: terminalReceipt)
        guard let current = entries[executionId],
              current.generation === entry.generation,
              current.handle === entry.handle,
              current.authorizedReceipt == nil
        else {
            throw EngineDispatchConflictErrorV1()
        }
        entry.authorizedReceipt = terminalReceipt
        entries[executionId] = entry
    }

    package func remove(
        executionId: String,
        terminalReceipt: EngineTerminalCommitReceiptV1
    ) async throws {
        try await removeCore(
            executionId: executionId,
            terminalReceipt: terminalReceipt,
            matching: nil
        )
    }

    fileprivate func remove(
        executionId: String,
        terminalReceipt: EngineTerminalCommitReceiptV1,
        matching handle: EngineExecutionCompletionHandleV1
    ) async throws {
        try await removeCore(
            executionId: executionId,
            terminalReceipt: terminalReceipt,
            matching: handle
        )
    }

    private func removeCore(
        executionId: String,
        terminalReceipt: EngineTerminalCommitReceiptV1,
        matching handle: EngineExecutionCompletionHandleV1?
    ) async throws {
        try validateExecutionID(executionId)
        guard terminalReceipt.executionId == executionId,
              let entry = entries[executionId],
              entry.authorizedReceipt == terminalReceipt
        else {
            throw EngineDispatchConflictErrorV1()
        }
        if let handle, entry.handle !== handle {
            throw EngineDispatchConflictErrorV1()
        }
        try await beforeAuthorizedRemoval(
            executionId,
            terminalReceipt,
            entry.handle
        )
        guard let current = entries[executionId],
              current.generation === entry.generation,
              current.handle === entry.handle,
              current.authorizedReceipt == terminalReceipt
        else {
            throw EngineDispatchConflictErrorV1()
        }
        entries.removeValue(forKey: executionId)
        captureCounter?.release()
    }

    package func snapshotCount() -> Int { entries.count }

    package func snapshotClaimCount(executionId: String) -> Int {
        entries[executionId]?.claimCount ?? 0
    }

    fileprivate func claimOwner(
        executionId: String,
        makeHandle: @Sendable () throws
            -> EngineExecutionCompletionHandleV1,
        operation: @escaping @Sendable (
            EngineExecutionCompletionHandleV1,
            Bool,
            EngineExecutionCompletionGenerationControlV1
        ) async throws -> EngineTerminalCommitReceiptV1
    ) async throws -> EngineExecutionCompletionTaskClaimV1 {
        try validateExecutionID(executionId)
        let handle: EngineExecutionCompletionHandleV1
        let generation: EngineExecutionCompletionGenerationTokenV1
        let didInstallGeneration: Bool
        var entry: Entry
        if let current = entries[executionId] {
            handle = current.handle
            generation = current.generation
            didInstallGeneration = false
            entry = current
        } else {
            handle = try makeHandle()
            guard handle.executionId == executionId else {
                throw EngineDispatchConflictErrorV1()
            }
            let cancellationState = try handle.takeCancellationState()
            try captureCounter?.retain()
            generation = EngineExecutionCompletionGenerationTokenV1()
            didInstallGeneration = true
            entry = Entry(
                generation: generation,
                handle: handle,
                cancellationState: cancellationState,
                externallyPreinstalled: false,
                authorizedReceipt: nil,
                attempt: nil,
                claimCount: 0
            )
        }
        guard entry.claimCount < Int.max else {
            throw EngineDispatchConflictErrorV1()
        }
        entry.claimCount += 1
        if let installed = entry.attempt {
            entries[executionId] = entry
            return EngineExecutionCompletionTaskClaimV1(
                handle: handle,
                task: installed.outcomeTask,
                didInstallGeneration: didInstallGeneration,
                didInstallOwner: false
            )
        }

        let token = EngineExecutionCompletionAttemptTokenV1()
        let outcome = EngineExecutionCompletionOutcomeCellV1()
        let outcomeTask = Task { try await outcome.wait() }
        let control = EngineExecutionCompletionGenerationControlV1(
            registry: self,
            executionId: executionId,
            generation: generation,
            attemptToken: token
        )
        let childToken = EngineExecutionCompletionChildTokenV1()
        let gate = EngineExecutionStartGateV1()
        let primaryTask = Task {
            let result: Result<EngineTerminalCommitReceiptV1, any Error>
            do {
                try await gate.waitUntilOpened()
                result = .success(try await operation(
                    handle,
                    didInstallGeneration,
                    control
                ))
            } catch {
                result = .failure(error)
            }
            self.finishPrimary(
                executionId: executionId,
                generation: generation,
                attemptToken: token,
                childToken: childToken,
                didInstallGeneration: didInstallGeneration,
                outcome: outcome,
                result: result
            )
            return try result.get()
        }
        let attempt = Attempt(
            token: token,
            outcome: outcome,
            outcomeTask: outcomeTask,
            primary: PrimaryChild(token: childToken, task: primaryTask),
            cancellation: nil,
            cancellationReason: nil,
            phase: .binding
        )
        entry.attempt = attempt
        entries[executionId] = entry
        do {
            try await gate.open()
        } catch {
            primaryTask.cancel()
            throw error
        }
        return EngineExecutionCompletionTaskClaimV1(
            handle: handle,
            task: outcomeTask,
            didInstallGeneration: didInstallGeneration,
            didInstallOwner: true
        )
    }

    fileprivate func claimCancellation(
        executionId: String,
        reason: String,
        makeHandle: @Sendable () throws
            -> EngineExecutionCompletionHandleV1
    ) async throws -> EngineExecutionCompletionTaskClaimV1 {
        try validateExecutionID(executionId)
        try EngineContractValidationV1.validateReasonCode(reason)
        let handle: EngineExecutionCompletionHandleV1
        let generation: EngineExecutionCompletionGenerationTokenV1
        let didInstallGeneration: Bool
        var entry: Entry
        if let current = entries[executionId] {
            handle = current.handle
            generation = current.generation
            didInstallGeneration = false
            entry = current
        } else {
            handle = try makeHandle()
            guard handle.executionId == executionId else {
                throw EngineDispatchConflictErrorV1()
            }
            let cancellationState = try handle.takeCancellationState()
            try captureCounter?.retain()
            generation = EngineExecutionCompletionGenerationTokenV1()
            didInstallGeneration = true
            entry = Entry(
                generation: generation,
                handle: handle,
                cancellationState: cancellationState,
                externallyPreinstalled: false,
                authorizedReceipt: nil,
                attempt: nil,
                claimCount: 0
            )
        }
        guard entry.claimCount < Int.max else {
            throw EngineDispatchConflictErrorV1()
        }
        entry.claimCount += 1

        if let current = entry.attempt,
           entry.authorizedReceipt != nil
        {
            entries[executionId] = entry
            return EngineExecutionCompletionTaskClaimV1(
                handle: handle,
                task: current.outcomeTask,
                didInstallGeneration: didInstallGeneration,
                didInstallOwner: false
            )
        }


        if let current = entry.attempt,
           current.phase == .terminalOwned
        {
            entries[executionId] = entry
            return EngineExecutionCompletionTaskClaimV1(
                handle: handle,
                task: current.outcomeTask,
                didInstallGeneration: didInstallGeneration,
                didInstallOwner: false
            )
        }

        if entry.attempt?.cancellation != nil {
            guard entry.attempt?.cancellationReason == reason else {
                throw EngineDispatchConflictErrorV1()
            }
            entries[executionId] = entry
            return EngineExecutionCompletionTaskClaimV1(
                handle: handle,
                task: entry.attempt!.outcomeTask,
                didInstallGeneration: didInstallGeneration,
                didInstallOwner: false
            )
        }

        if let current = entry.attempt,
           current.phase == .cancellationRunning,
           current.cancellation == nil,
           let currentReason = current.cancellationReason
        {
            guard currentReason == reason else {
                throw EngineDispatchConflictErrorV1()
            }
            entries[executionId] = entry
            return EngineExecutionCompletionTaskClaimV1(
                handle: handle,
                task: current.outcomeTask,
                didInstallGeneration: didInstallGeneration,
                didInstallOwner: false
            )
        }

        let didInstallStandaloneOwner = entry.attempt == nil
        if entry.attempt == nil {
            let token = EngineExecutionCompletionAttemptTokenV1()
            let outcome = EngineExecutionCompletionOutcomeCellV1()
            entry.attempt = Attempt(
                token: token,
                outcome: outcome,
                outcomeTask: Task { try await outcome.wait() },
                primary: nil,
                cancellation: nil,
                cancellationReason: nil,
                phase: .binding
            )
        }
        let installed = try installCancellation(
            executionId: executionId,
            entry: &entry,
            reason: reason,
            origin: .external,
            requiresNoTransport: false,
            standaloneExternalOwner: didInstallStandaloneOwner
        )
        entries[executionId] = entry
        installed.primaryToCancel?.cancel()
        do {
            try await installed.gate.open()
        } catch {
            installed.task.cancel()
            throw error
        }
        return EngineExecutionCompletionTaskClaimV1(
            handle: handle,
            task: entry.attempt!.outcomeTask,
            didInstallGeneration: didInstallGeneration,
            didInstallOwner: didInstallStandaloneOwner
        )
    }

    fileprivate func claimDispatchPermit(
        executionId: String,
        generation: EngineExecutionCompletionGenerationTokenV1,
        attemptToken: EngineExecutionCompletionAttemptTokenV1
    ) throws {
        guard var entry = entries[executionId],
              entry.generation === generation,
              var attempt = entry.attempt,
              attempt.token === attemptToken,
              attempt.cancellation == nil,
              attempt.phase == .binding
        else { throw CancellationError() }
        attempt.phase = .dispatchPermitted
        entry.attempt = attempt
        entries[executionId] = entry
    }

    fileprivate func claimTerminalPermit(
        executionId: String,
        generation: EngineExecutionCompletionGenerationTokenV1,
        attemptToken: EngineExecutionCompletionAttemptTokenV1
    ) throws {
        guard var entry = entries[executionId],
              entry.generation === generation,
              var attempt = entry.attempt,
              attempt.token === attemptToken,
              attempt.cancellation == nil,
              attempt.phase == .binding
        else { throw CancellationError() }
        attempt.phase = .terminalOwned
        entry.attempt = attempt
        entries[executionId] = entry
    }

    fileprivate func requestCancellationFromPrimary(
        executionId: String,
        generation: EngineExecutionCompletionGenerationTokenV1,
        attemptToken: EngineExecutionCompletionAttemptTokenV1,
        reason: String,
        requiresNoTransport: Bool
    ) async throws -> Task<EngineTerminalCommitReceiptV1, Error>? {
        try EngineContractValidationV1.validateReasonCode(reason)
        guard var entry = entries[executionId],
              entry.generation === generation,
              let attempt = entry.attempt,
              attempt.token === attemptToken
        else { throw EngineDispatchConflictErrorV1() }
        if let cancellation = attempt.cancellation {
            guard attempt.cancellationReason == reason else {
                throw EngineDispatchConflictErrorV1()
            }
            return cancellation.origin == .primary ? cancellation.task : nil
        }
        let installed = try installCancellation(
            executionId: executionId,
            entry: &entry,
            reason: reason,
            origin: .primary,
            requiresNoTransport: requiresNoTransport,
            standaloneExternalOwner: false
        )
        entries[executionId] = entry
        installed.primaryToCancel?.cancel()
        do {
            try await installed.gate.open()
        } catch {
            installed.task.cancel()
            throw error
        }
        return installed.task
    }

    private func installCancellation(
        executionId: String,
        entry: inout Entry,
        reason: String,
        origin: CancellationOrigin,
        requiresNoTransport: Bool,
        standaloneExternalOwner: Bool
    ) throws -> (
        task: Task<EngineTerminalCommitReceiptV1, Error>,
        gate: EngineExecutionStartGateV1,
        primaryToCancel: Task<EngineTerminalCommitReceiptV1, Error>?
    ) {
        guard var attempt = entry.attempt,
              attempt.cancellation == nil,
              attempt.cancellationReason == nil
        else { throw EngineDispatchConflictErrorV1() }
        let lifecycle: EngineCancellationLifecycleDispositionV1?
        let primaryToCancel: Task<EngineTerminalCommitReceiptV1, Error>?
        let primaryToJoin: Task<EngineTerminalCommitReceiptV1, Error>?
        if origin == .primary {
            lifecycle = requiresNoTransport ? .noTransport : nil
            primaryToCancel = nil
            primaryToJoin = nil
        } else {
            switch attempt.phase {
            case .binding:
                if let primary = attempt.primary {
                    lifecycle = .noTransport
                    primaryToCancel = primary.task
                } else {
                    guard standaloneExternalOwner else {
                        throw EngineDispatchConflictErrorV1()
                    }
                    lifecycle = nil
                    primaryToCancel = nil
                }
            case .dispatchPermitted:
                lifecycle = nil
                primaryToCancel = nil
            case .terminalOwned:
                throw EngineDispatchConflictErrorV1()
            case .cancellationRunning:
                throw EngineDispatchConflictErrorV1()
            }
            primaryToJoin = attempt.primary?.task
        }
        let childToken = EngineExecutionCompletionChildTokenV1()
        let gate = EngineExecutionStartGateV1()
        let generation = entry.generation
        let attemptToken = attempt.token
        let handle = entry.handle
        let cancellationState = entry.cancellationState
        let outcome = attempt.outcome
        if origin == .external {
            outcome.suppressPrimaryResolution()
        }
        let task = Task {
            let result: Result<EngineTerminalCommitReceiptV1, any Error>
            do {
                try await gate.waitUntilOpened()
                await self.cancellationCommandObserver(executionId)
                if standaloneExternalOwner {
                    try await handle
                        .markStandaloneExternalCancellationOwner()
                }
                if let lifecycle {
                    try await cancellationState.publishLifecycle(lifecycle)
                }
                result = .success(
                    try await cancellationState.resolve(
                        handle: handle,
                        reason: reason
                    )
                )
            } catch {
                result = .failure(error)
            }
            if origin == .external {
                if case .failure = result { primaryToJoin?.cancel() }
                _ = await primaryToJoin?.result
            }
            await self.finishCancellation(
                executionId: executionId,
                generation: generation,
                attemptToken: attemptToken,
                childToken: childToken,
                origin: origin,
                outcome: outcome,
                result: result
            )
            return try result.get()
        }
        attempt.cancellation = CancellationChild(
            token: childToken,
            task: task,
            origin: origin
        )
        attempt.cancellationReason = reason
        attempt.phase = .cancellationRunning
        entry.attempt = attempt
        return (task, gate, primaryToCancel)
    }

    private func finishPrimary(
        executionId: String,
        generation: EngineExecutionCompletionGenerationTokenV1,
        attemptToken: EngineExecutionCompletionAttemptTokenV1,
        childToken: EngineExecutionCompletionChildTokenV1,
        didInstallGeneration: Bool,
        outcome: EngineExecutionCompletionOutcomeCellV1,
        result: Result<EngineTerminalCommitReceiptV1, any Error>
    ) {
        guard var entry = entries[executionId],
              entry.generation === generation,
              var attempt = entry.attempt,
              attempt.token === attemptToken,
              attempt.primary?.token === childToken
        else {
            outcome.resolveFromPrimaryIfAllowed(result)
            return
        }
        attempt.primary = nil
        if let cancellation = attempt.cancellation,
           cancellation.origin == .external
        {
            entry.attempt = attempt
            entries[executionId] = entry
            return
        }
        if case .failure = result, entry.authorizedReceipt == nil {
            entry.attempt = nil
            if didInstallGeneration, !entry.externallyPreinstalled {
                entries.removeValue(forKey: executionId)
                captureCounter?.release()
            } else {
                entries[executionId] = entry
            }
        } else {
            entry.attempt = attempt
            entries[executionId] = entry
        }
        outcome.resolveFromPrimaryIfAllowed(result)
    }

    private func finishCancellation(
        executionId: String,
        generation: EngineExecutionCompletionGenerationTokenV1,
        attemptToken: EngineExecutionCompletionAttemptTokenV1,
        childToken: EngineExecutionCompletionChildTokenV1,
        origin: CancellationOrigin,
        outcome: EngineExecutionCompletionOutcomeCellV1,
        result: Result<EngineTerminalCommitReceiptV1, any Error>
    ) async {
        guard var entry = entries[executionId],
              entry.generation === generation,
              var attempt = entry.attempt,
              attempt.token === attemptToken,
              attempt.cancellation?.token === childToken
        else {
            if origin == .external {
                outcome.resolveIfPending(result)
            }
            return
        }
        attempt.cancellation = nil
        if origin == .primary {
            guard let settledReason = attempt.cancellationReason else {
                preconditionFailure(
                    "primary cancellation settled without a frozen reason"
                )
            }
            entry.attempt = attempt
            entries[executionId] = entry
            await primaryCancellationChildSettledObserver(
                executionId,
                settledReason
            )
            return
        }
        attempt.primary = nil
        if case .failure = result, entry.authorizedReceipt == nil {
            entry.attempt = nil
            if entry.externallyPreinstalled {
                entries[executionId] = entry
            } else {
                entries.removeValue(forKey: executionId)
                captureCounter?.release()
            }
        } else {
            entry.attempt = attempt
            entries[executionId] = entry
        }
        outcome.resolveIfPending(result)
    }

    private func validateExecutionID(_ executionId: String) throws {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        } catch {
            throw EngineDispatchConflictErrorV1()
        }
    }
}

private final class EngineRuntimeCaptureCounterV1: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var closed = false

    func retain() throws {
        try lock.withLock {
            guard !closed, count < Int.max else {
                throw EngineRuntimeAuthorityErrorV1.authorityClosed
            }
            count += 1
        }
    }

    func release() {
        lock.withLock {
            precondition(count > 0, "unbalanced runtime capture release")
            count -= 1
        }
    }

    var outstanding: Int { lock.withLock { count } }

    func closeIfEmpty() throws {
        try lock.withLock {
            guard !closed else {
                throw EngineRuntimeAuthorityErrorV1.authorityClosed
            }
            closed = true
            guard count == 0 else {
                throw EngineRuntimeAuthorityErrorV1.outstandingLeases
            }
        }
    }
}

package actor EngineActiveExecutionRegistryV1 {
    private struct LiveEntry {
        let cancelAndAwait: @Sendable () async throws -> Void
        var reason: String?
        var inFlight: Task<Void, Error>?
        var attempt: Int
        var cleanupComplete: Bool
    }

    private var liveByExecutionID: [String: LiveEntry] = [:]
    private var pendingReasonByExecutionID: [String: String] = [:]
    private let captureCounter: EngineRuntimeCaptureCounterV1?

    package init() { captureCounter = nil }

    fileprivate init(captureCounter: EngineRuntimeCaptureCounterV1) {
        self.captureCounter = captureCounter
    }

    package func register(
        executionId: String,
        cancelAndAwait: @escaping @Sendable () async throws -> Void
    ) async throws -> EngineActiveExecutionRegistrationDispositionV1 {
        try validateExecutionID(executionId)
        guard liveByExecutionID[executionId] == nil else {
            throw EngineDispatchConflictErrorV1()
        }
        try captureCounter?.retain()
        liveByExecutionID[executionId] = LiveEntry(
            cancelAndAwait: cancelAndAwait,
            reason: nil,
            inFlight: nil,
            attempt: 0,
            cleanupComplete: false
        )
        guard let pendingReason = pendingReasonByExecutionID.removeValue(
            forKey: executionId
        ) else {
            return .installed
        }
        try await cancelLiveExecution(
            executionId: executionId,
            reason: pendingReason
        )
        return .pendingCancellationConsumed(reason: pendingReason)
    }

    package func cancel(
        executionId: String,
        reason: String
    ) async throws -> EngineActiveExecutionCancellationDispositionV1 {
        try validateExecutionID(executionId)
        try EngineContractValidationV1.validateReasonCode(reason)
        guard liveByExecutionID[executionId] != nil else {
            if let stored = pendingReasonByExecutionID[executionId] {
                guard stored == reason else {
                    throw EngineDispatchConflictErrorV1()
                }
            } else {
                pendingReasonByExecutionID[executionId] = reason
            }
            return .latched
        }
        try await cancelLiveExecution(
            executionId: executionId,
            reason: reason
        )
        return .cancelledAndAwaited
    }

    package func remove(
        executionId: String,
        terminalReceipt: EngineTerminalCommitReceiptV1
    ) throws {
        guard terminalReceipt.executionId == executionId,
              pendingReasonByExecutionID[executionId] == nil,
              let entry = liveByExecutionID[executionId],
              entry.inFlight == nil
        else {
            throw EngineDispatchConflictErrorV1()
        }
        if let reason = entry.reason {
            guard entry.cleanupComplete,
                  terminalReceipt.terminalKind == .canceled,
                  terminalReceipt.reasonCode == reason
            else {
                throw EngineDispatchConflictErrorV1()
            }
        }
        liveByExecutionID.removeValue(forKey: executionId)
        captureCounter?.release()
    }

    package func finishPending(
        executionId: String,
        terminalReceipt: EngineTerminalCommitReceiptV1
    ) throws {
        guard terminalReceipt.executionId == executionId,
              terminalReceipt.terminalKind == .canceled,
              liveByExecutionID[executionId] == nil,
              let reason = pendingReasonByExecutionID[executionId],
              terminalReceipt.reasonCode == reason
        else {
            throw EngineDispatchConflictErrorV1()
        }
        pendingReasonByExecutionID.removeValue(forKey: executionId)
    }

    package func snapshotCounts() -> (
        live: Int,
        pending: Int,
        inFlight: Int
    ) {
        (
            liveByExecutionID.count,
            pendingReasonByExecutionID.count,
            liveByExecutionID.values.reduce(into: 0) { count, entry in
                if entry.inFlight != nil { count += 1 }
            }
        )
    }

    private func cancelLiveExecution(
        executionId: String,
        reason: String
    ) async throws {
        guard var entry = liveByExecutionID[executionId] else {
            throw EngineDispatchConflictErrorV1()
        }
        if let storedReason = entry.reason {
            guard storedReason == reason else {
                throw EngineDispatchConflictErrorV1()
            }
        } else {
            entry.reason = reason
        }
        if entry.cleanupComplete {
            liveByExecutionID[executionId] = entry
            return
        }

        let task: Task<Void, Error>
        let attempt: Int
        if let current = entry.inFlight {
            task = current
            attempt = entry.attempt
        } else {
            guard entry.attempt < Int.max else {
                throw EngineDispatchConflictErrorV1()
            }
            entry.attempt += 1
            attempt = entry.attempt
            let action = entry.cancelAndAwait
            task = Task { try await action() }
            entry.inFlight = task
        }
        liveByExecutionID[executionId] = entry

        do {
            try await task.value
            guard var current = liveByExecutionID[executionId],
                  current.attempt == attempt
            else {
                throw EngineDispatchConflictErrorV1()
            }
            current.inFlight = nil
            current.cleanupComplete = true
            liveByExecutionID[executionId] = current
        } catch {
            if var current = liveByExecutionID[executionId],
               current.attempt == attempt
            {
                current.inFlight = nil
                liveByExecutionID[executionId] = current
            }
            throw error
        }
    }

    private func validateExecutionID(_ executionId: String) throws {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        } catch {
            throw EngineDispatchConflictErrorV1()
        }
    }
}

private struct EngineCoordinatorAuthorityV1: Sendable {
    let profile: RuntimeProfileRecord
    let execution: EngineExecutionRecord
    let selection: EngineAdapterSelectionV1
}

private struct EngineCoordinatorRuntimeV1: Sendable {
    let router: EngineEventRouterV1
    let terminalSink: EngineAdapterTerminalRouterSinkV1
    let runtime: EngineAdapterRuntimeV1
}

private final class EngineCoordinatorReleaseOnceV1: @unchecked Sendable {
    private let lock = NSLock()
    private var executionId: String?
    private var workspace: EngineResolvedWorkspaceV1?
    private var adapter: (any ExecutionEngineAdapter)?
    private var cleanupTask: Task<Void, Error>?
    private var cancellationMarked = false

    init(
        executionId: String?,
        workspace: EngineResolvedWorkspaceV1?
    ) {
        self.executionId = executionId
        self.workspace = workspace
    }

    func bindExecutionID(_ value: String) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(value)
        try lock.withLock {
            guard executionId == nil || executionId == value else {
                throw EngineDispatchConflictErrorV1()
            }
            executionId = value
        }
    }

    func installWorkspace(_ value: EngineResolvedWorkspaceV1) throws {
        try lock.withLock {
            guard workspace == nil else {
                throw EngineDispatchConflictErrorV1()
            }
            workspace = value
        }
    }

    func installAdapter(_ value: any ExecutionEngineAdapter) throws {
        let cleanup: Task<Void, Error>? = try lock.withLock {
            guard adapter == nil, cleanupTask == nil,
                  let executionId
            else {
                throw EngineDispatchConflictErrorV1()
            }
            adapter = value
            guard cancellationMarked else { return nil }
            let task = Task {
                try await value.cancel(executionId: executionId)
            }
            cleanupTask = task
            return task
        }
        _ = cleanup
    }

    func signalCancellation() {
        lock.withLock {
            cancellationMarked = true
            guard cleanupTask == nil,
                  let adapter,
                  let executionId
            else { return }
            cleanupTask = Task {
                try await adapter.cancel(executionId: executionId)
            }
        }
    }

    func waitForPublishedCleanup() async throws {
        let task = lock.withLock { cleanupTask }
        try await task?.value
    }

    func releaseWorkspace() {
        let current = lock.withLock { () -> EngineResolvedWorkspaceV1? in
            let value = workspace
            workspace = nil
            return value
        }
        current?.release()
    }
}

private enum EngineCoordinatorActiveCleanupV1 {
    case none
    case pending
    case live
}

private enum EngineCoordinatorHandleCompletionV1 {
    case ordinary
    case terminalWinner
}

package struct EngineExecutionCoordinatorV1: Sendable {
    package let store: EngineExecutionStore
    package let registry: EngineAdapterRegistryV1
    package let artifactStager: ArtifactStager
    package let contextResolver: EngineContextTransportResolverV1
    package let workspaceResolver: EngineWorkspaceResolverV1
    package let transportSeedResolver: EngineExecutionTransportSeedResolveV1
    package let activeExecutions: EngineActiveExecutionRegistryV1
    package let completionRegistry: EngineExecutionCompletionRegistryV1
    package let eventObserver: EngineRoutedEventDidCommitV1
    package let clock: @Sendable () -> Date

    package init(
        store: EngineExecutionStore,
        registry: EngineAdapterRegistryV1,
        artifactStager: ArtifactStager,
        contextResolver: EngineContextTransportResolverV1,
        workspaceResolver: EngineWorkspaceResolverV1,
        transportSeedResolver:
            @escaping EngineExecutionTransportSeedResolveV1,
        activeExecutions: EngineActiveExecutionRegistryV1,
        completionRegistry: EngineExecutionCompletionRegistryV1,
        eventObserver: @escaping EngineRoutedEventDidCommitV1,
        clock: @escaping @Sendable () -> Date
    ) {
        self.store = store
        self.registry = registry
        self.artifactStager = artifactStager
        self.contextResolver = contextResolver
        self.workspaceResolver = workspaceResolver
        self.transportSeedResolver = transportSeedResolver
        self.activeExecutions = activeExecutions
        self.completionRegistry = completionRegistry
        self.eventObserver = eventObserver
        self.clock = clock
    }

    package func execute(
        _ prepared: EnginePreparedDispatchV1,
        onExecutionBound: @escaping EngineExecutionDidBindV1
    ) async throws -> EngineTerminalCommitReceiptV1 {
        try Task.checkCancellation()
        try validatePreparedDispatch(prepared)
        let resolvedWorkspace = try workspaceResolver.resolve(
            prepared.workspace.request
        )
        let release = EngineCoordinatorReleaseOnceV1(
            executionId: nil,
            workspace: resolvedWorkspace
        )
        var transferredWorkspace = false
        defer {
            if !transferredWorkspace { release.releaseWorkspace() }
        }
        try validatePreparedWorkspace(
            prepared,
            workspace: resolvedWorkspace
        )
        try Task.checkCancellation()

        let request = try store.beginEngineExecution(
            requestFields: prepared.requestFields,
            idempotencyKey: prepared.idempotencyKey
        )
        try release.bindExecutionID(request.executionId)
        try validatePreparedRequest(
            prepared,
            request: request,
            workspace: resolvedWorkspace
        )
        let claimed = try await completionRegistry.claimOwner(
            executionId: request.executionId,
            makeHandle: {
                try EngineExecutionCompletionHandleV1(
                    executionId: request.executionId,
                    resolveCancellation: { handle, reason in
                        try await resolveCancellation(
                            handle: handle,
                            reason: reason,
                            release: release
                        )
                    }
                )
            },
            operation: { handle, didInstallGeneration, control in
                do {
                    return try await runDispatchOwner(
                        prepared: prepared,
                        request: request,
                        workspace: resolvedWorkspace,
                        release: release,
                        handle: handle,
                        didInstallGeneration: didInstallGeneration,
                        control: control,
                        onExecutionBound: onExecutionBound
                    )
                } catch {
                    release.releaseWorkspace()
                    throw error
                }
            }
        )
        if !claimed.didInstallOwner { release.releaseWorkspace() }
        transferredWorkspace = true
        return try await claimed.task.value
    }

    private func runDispatchOwner(
        prepared: EnginePreparedDispatchV1,
        request: EngineExecutionRequest,
        workspace: EngineResolvedWorkspaceV1,
        release: EngineCoordinatorReleaseOnceV1,
        handle: EngineExecutionCompletionHandleV1,
        didInstallGeneration: Bool,
        control: EngineExecutionCompletionGenerationControlV1,
        onExecutionBound: @escaping EngineExecutionDidBindV1
    ) async throws -> EngineTerminalCommitReceiptV1 {

        let bind: EngineExecutionBindDispositionV1
        do {
            bind = try await onExecutionBound(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled { throw CancellationError() }
            _ = try await control.requestCancellation(
                reason: "engine_bind_failed",
                requiresNoTransport: true
            )
            throw EngineDispatchConflictErrorV1()
        }
        if Task.isCancelled { throw CancellationError() }
        switch bind {
        case let .cancel(reason):
            return try await control.requestCancellation(
                reason: reason,
                requiresNoTransport: true
            )
        case .dispatch:
            try await control.claimDispatchPermit()
            try Task.checkCancellation()
        }

        let execution = try loadRunningExecution(request.executionId)
        let authority: EngineCoordinatorAuthorityV1
        do {
            authority = try loadAuthority(
                request: request,
                execution: execution,
                requiredCapabilities: request.requiredCapabilities
            )
            try validatePreparedSelection(
                prepared.selected,
                request: request,
                authority: authority
            )
        } catch {
            let receipt = try commitPreDispatchProtocolFailure(
                execution: execution,
                detail: "Engine pre-dispatch validation failed."
            )
            try await finalizeTerminal(
                receipt: receipt,
                observedEvent: try terminalObservationEvent(receipt),
                handle: handle,
                release: release,
                activeCleanup: .none
            )
            return try await handle.waitForReceipt()
        }

        let dispatch = try store.markEngineDispatchStarted(
            executionId: request.executionId,
            expectedVersion: execution.version,
            requestHash: request.requestHash,
            commandIdempotencyKey: dispatchCommandKey(request.executionId),
            now: clock()
        )
        switch dispatch {
        case .alreadyStarted:
            if didInstallGeneration {
                try await recoverExactExecution(
                    request: request,
                    handle: handle,
                    release: release,
                    control: control,
                    now: clock()
                )
            } else {
                release.releaseWorkspace()
            }

        case let .startNow(persistedRequest):
            guard persistedRequest == request else {
                throw EngineExecutionReplayConflictError()
            }
            try await startConsumption(
                prepared: prepared,
                request: request,
                authority: authority,
                workspace: workspace,
                release: release,
                handle: handle
            )
        }
        return try await handle.waitForReceipt()
    }

    package func cancel(
        executionId: String,
        reason: String
    ) async throws {
        try EngineContractValidationV1.validateReasonCode(reason)
        let execution = try loadExecutionAnyState(executionId)
        if execution.state != .running {
            guard case let .terminalWon(receipt) = try store
                .requestCancellation(
                    executionId: executionId,
                    reason: reason,
                    now: clock()
                )
            else {
                throw EngineDispatchConflictErrorV1()
            }
            try await observeTerminalReceipt(receipt)
            return
        }
        let release = EngineCoordinatorReleaseOnceV1(
            executionId: execution.id,
            workspace: nil
        )
        let claimed = try await completionRegistry.claimCancellation(
            executionId: execution.id,
            reason: reason,
            makeHandle: {
                try EngineExecutionCompletionHandleV1(
                    executionId: execution.id,
                    resolveCancellation: { handle, frozenReason in
                        try await resolveCancellation(
                            handle: handle,
                            reason: frozenReason,
                            release: release
                        )
                    }
                )
            }
        )
        if !claimed.didInstallGeneration { release.releaseWorkspace() }
        _ = try await claimed.task.value
    }

    package func recover(
        missionId: String?,
        now: Date
    ) async throws -> EngineRecoverySummaryV1 {
        let scanned = try store.recoverInterruptedEngineExecutions(
            missionId: missionId,
            now: now
        )
        var receipts = scanned.terminalReceipts
        var deferred: [EngineRecoveryDirectiveV1] = []
        for receipt in scanned.terminalReceipts {
            try await observeTerminalReceipt(receipt)
        }
        for directive in scanned.directives {
            switch directive.action {
            case .deferCampDeletion:
                deferred.append(directive)

            case .cancelAndReconcile:
                guard let request = directive.request,
                      request.executionId == directive.executionId
                else {
                    throw EngineExecutionReplayConflictError()
                }
                let receipt = try await recoverCLIRequestedCancellation(
                    directive: directive,
                    request: request,
                    now: now
                )
                receipts.append(receipt)

            case .prepareAndCommitProposal,
                 .startPrepared,
                 .resumeSession,
                 .replayExecution:
                guard let request = directive.request,
                      request.executionId == directive.executionId
                else {
                    throw EngineExecutionReplayConflictError()
                }
                if let receipt = try await recoverDirective(
                    directive: directive,
                    request: request,
                    now: now
                ) { receipts.append(receipt) }
            }
        }
        return EngineRecoverySummaryV1(
            scannedCount: scanned.scannedCount,
            terminalReceipts: receipts,
            directives: deferred
        )
    }

    private func resolveCancellation(
        handle: EngineExecutionCompletionHandleV1,
        reason: String,
        release: EngineCoordinatorReleaseOnceV1
    ) async throws -> EngineTerminalCommitReceiptV1 {
        let disposition = try store.requestCancellation(
            executionId: handle.executionId,
            reason: reason,
            now: clock()
        )
        switch disposition {
        case let .requested(execution):
            guard execution.id == handle.executionId,
                  execution.state == .running,
                  execution.cancellationReason == reason,
                  execution.cancellationRequestedAt != nil
            else {
                throw EngineDispatchConflictErrorV1()
            }
        case let .terminalWon(receipt):
            try await finalizeTerminal(
                receipt: receipt,
                observedEvent: try terminalObservationEvent(receipt),
                handle: handle,
                release: release,
                activeCleanup: .none,
                handleCompletion: .terminalWinner
            )
            return receipt
        }
        let cancellation = try await activeExecutions.cancel(
            executionId: handle.executionId,
            reason: reason
        )
        let lifecycle = try await handle.resolveCancellationLifecycle(
            for: cancellation
        )
        let activeCleanup: EngineCoordinatorActiveCleanupV1
        switch lifecycle {
        case .noTransport:
            activeCleanup = .pending
        case .registeredCleanupComplete:
            activeCleanup = .live
        }

        let recovered = try store.recoverInterruptedEngineExecution(
            executionId: handle.executionId,
            now: clock()
        )
        guard case let .receipt(receipt) = recovered,
              receipt.executionId == handle.executionId,
              receipt.terminalKind == .canceled,
              receipt.reasonCode == reason
        else {
            throw EngineDispatchConflictErrorV1()
        }
        try await finalizeTerminal(
            receipt: receipt,
            observedEvent: try terminalObservationEvent(receipt),
            handle: handle,
            release: release,
            activeCleanup: activeCleanup
        )
        return receipt
    }

    private func recoverExactExecution(
        request: EngineExecutionRequest,
        handle: EngineExecutionCompletionHandleV1,
        release: EngineCoordinatorReleaseOnceV1,
        control: EngineExecutionCompletionGenerationControlV1,
        now: Date
    ) async throws {
        let execution = try loadExecutionAnyState(request.executionId)
        if let reason = execution.cancellationReason,
           execution.cancellationRequestedAt != nil
        {
            _ = try await control.requestCancellation(
                reason: reason,
                requiresNoTransport: true
            )
            return
        }
        let result = try store.recoverInterruptedEngineExecution(
            executionId: request.executionId,
            now: now
        )
        switch result {
        case let .receipt(receipt):
            try await finalizeTerminal(
                receipt: receipt,
                observedEvent: try terminalObservationEvent(receipt),
                handle: handle,
                release: release,
                activeCleanup: .none
            )
        case let .directive(directive):
            guard let recovered = try await recoverDirective(
                directive: directive,
                request: request,
                now: now,
                installedHandle: handle,
                installedRelease: release,
                installedControl: control
            ), recovered.executionId == request.executionId else {
                throw EngineDispatchConflictErrorV1()
            }
        case .noLongerActive:
            throw EngineDispatchConflictErrorV1()
        }
    }

    private func startConsumption(
        prepared: EnginePreparedDispatchV1,
        request: EngineExecutionRequest,
        authority: EngineCoordinatorAuthorityV1,
        workspace: EngineResolvedWorkspaceV1,
        release: EngineCoordinatorReleaseOnceV1,
        handle: EngineExecutionCompletionHandleV1
    ) async throws {
        try await startSelectedConsumption(
            selected: prepared.selected,
            request: request,
            authority: authority,
            context: prepared.selected.context.resolved,
            workspace: workspace,
            resolvedSessionRef: request.sessionRef,
            release: release,
            handle: handle
        )
    }

    private func startSelectedConsumption(
        selected: EngineAdapterPreparedRequestV1,
        request: EngineExecutionRequest,
        authority: EngineCoordinatorAuthorityV1,
        context: EngineResolvedContextTransportV1,
        workspace: EngineResolvedWorkspaceV1,
        resolvedSessionRef: EngineSessionReferenceV1?,
        release: EngineCoordinatorReleaseOnceV1,
        handle: EngineExecutionCompletionHandleV1
    ) async throws {
        let gate = EngineExecutionStartGateV1()
        let consumption = Task {
            try await runConsumption(
                selected: selected,
                request: request,
                authority: authority,
                context: context,
                workspace: workspace,
                resolvedSessionRef: resolvedSessionRef,
                gate: gate,
                release: release,
                handle: handle
            )
        }
        let registration: EngineActiveExecutionRegistrationDispositionV1
        do {
            registration = try await activeExecutions.register(
                executionId: request.executionId,
                cancelAndAwait: {
                    consumption.cancel()
                    try await consumption.value
                }
            )
        } catch {
            consumption.cancel()
            _ = await consumption.result
            throw error
        }
        switch registration {
        case .installed:
            try await gate.open()
        case .pendingCancellationConsumed:
            try await handle.publishCancellationLifecycle(
                .registeredCleanupComplete
            )
        }
    }

    private func validatePreparedDispatch(
        _ prepared: EnginePreparedDispatchV1
    ) throws {
        let fields = prepared.requestFields
        let context = prepared.selected.context
        let descriptor = prepared.selected.descriptor
        guard prepared.context.profile.id == fields.profileId,
              prepared.context.profile.kind == descriptor.profileKind,
              prepared.context.contract == fields.contract,
              prepared.context.companionModel == fields.model,
              prepared.selected.engineKind == fields.engineKind,
              prepared.selected.model == fields.model,
              prepared.selected.budget == fields.budget,
              prepared.selected.requiredCapabilities
                == fields.requiredCapabilities,
              descriptor.adapterId == fields.engineKind,
              context.request.campId == fields.campId,
              context.request.cardId == fields.cardId,
              context.request.companionId
                == prepared.context.companionId,
              context.request.contextJson == fields.contextJson,
              context.request.contextHash == fields.contextHash,
              context.resolved.canonicalEnvelopeJSON == fields.contextJson,
              context.resolved.hash == fields.contextHash,
              context.resolved.envelope.campId == fields.campId,
              context.resolved.envelope.cardId == fields.cardId,
              prepared.workspace.request.cardId == fields.cardId,
              prepared.workspace.request.campId == fields.campId,
              prepared.workspace.request.expectedWorkspace == fields.workspace,
              prepared.workspace.workspace == fields.workspace,
              fields.requiredCapabilities.allSatisfy({
                  descriptor.support(for: $0) == .supported
              })
        else {
            throw EngineContextValidationErrorV1()
        }
    }

    private func validatePreparedWorkspace(
        _ prepared: EnginePreparedDispatchV1,
        workspace: EngineResolvedWorkspaceV1
    ) throws {
        let fields = prepared.requestFields
        guard workspace.identity.campId == fields.campId,
              workspace.url.standardizedFileURL.path
                == workspace.identity.workspacePath,
              fields.workspace.reference
                == "squad-workspace.v1:\(workspace.identity.squadId)"
        else {
            throw EngineContextValidationErrorV1()
        }
    }

    private func validatePreparedRequest(
        _ prepared: EnginePreparedDispatchV1,
        request: EngineExecutionRequest,
        workspace: EngineResolvedWorkspaceV1
    ) throws {
        try request.validateCanonicalIdentity()
        guard request.idempotencyKey == prepared.idempotencyKey,
              request.campId == prepared.requestFields.campId,
              request.cardId == prepared.requestFields.cardId,
              request.contract == prepared.requestFields.contract,
              request.profileId == prepared.requestFields.profileId,
              request.engineKind == prepared.selected.engineKind,
              request.model == prepared.selected.model,
              request.contextJson == prepared.selected.context.request.contextJson,
              request.contextHash == prepared.selected.context.request.contextHash,
              request.requiredCapabilities
                == prepared.selected.requiredCapabilities,
              request.budget == prepared.selected.budget,
              request.workspace == prepared.workspace.workspace,
              workspace.identity.campId == request.campId
        else {
            throw EngineExecutionReplayConflictError()
        }
    }

    private func validatePreparedSelection(
        _ prepared: EngineAdapterPreparedRequestV1,
        request: EngineExecutionRequest,
        authority: EngineCoordinatorAuthorityV1
    ) throws {
        guard descriptorsMatch(
            prepared.descriptor,
            authority.selection.descriptor
        ), prepared.engineKind == authority.execution.engineKind,
           prepared.model == authority.execution.model,
           prepared.requiredCapabilities
            == request.requiredCapabilities
        else {
            throw EngineDescriptorMismatchErrorV1()
        }
    }

    private func descriptorsMatch(
        _ lhs: ExecutionEngineDescriptor,
        _ rhs: ExecutionEngineDescriptor
    ) -> Bool {
        guard lhs.adapterId == rhs.adapterId,
              lhs.adapterVersion == rhs.adapterVersion,
              lhs.profileKind == rhs.profileKind
        else { return false }
        return EngineCapabilityV1.allCases.allSatisfy {
            lhs.support(for: $0) == rhs.support(for: $0)
        }
    }

    private func recoveryContextVariant(
        seed: EngineExecutionTransportSeedV1,
        descriptor: ExecutionEngineDescriptor
    ) throws -> EnginePreparedContextVariantV1 {
        switch descriptor.profileKind {
        case .cliCodex, .cliClaude:
            guard seed.context.cli.namespace == .ranchMCP else {
                throw EngineDescriptorMismatchErrorV1()
            }
            return seed.context.cli
        case .anthropicAPI, .openAIAPI, .chatGPTOAuth:
            guard seed.context.modelLoop.namespace == .modelLoop else {
                throw EngineDescriptorMismatchErrorV1()
            }
            return seed.context.modelLoop
        }
    }

    private func validateRecoverySeed(
        _ seed: EngineExecutionTransportSeedV1,
        request: EngineExecutionRequest,
        descriptor: ExecutionEngineDescriptor,
        context: EnginePreparedContextVariantV1,
        resolvedContext: EngineResolvedContextTransportV1,
        workspace: EngineResolvedWorkspaceV1
    ) throws {
        guard seed.context.profile.id == request.profileId,
              seed.context.profile.kind == descriptor.profileKind,
              seed.context.contract == request.contract,
              seed.context.companionModel == request.model,
              seed.baseRequiredCapabilities == request.requiredCapabilities,
              context.request.campId == request.campId,
              context.request.cardId == request.cardId,
              context.request.companionId == seed.context.companionId,
              context.request.contextJson == request.contextJson,
              context.request.contextHash == request.contextHash,
              resolvedContext.canonicalEnvelopeJSON == request.contextJson,
              resolvedContext.hash == request.contextHash,
              resolvedContext.envelope.campId == request.campId,
              resolvedContext.envelope.cardId == request.cardId,
              seed.workspace.request.cardId == request.cardId,
              seed.workspace.request.campId == request.campId,
              seed.workspace.request.expectedWorkspace == request.workspace,
              seed.workspace.workspace == request.workspace,
              workspace.identity.campId == request.campId,
              workspace.url.standardizedFileURL.path
                == workspace.identity.workspacePath,
              request.workspace.reference
                == "squad-workspace.v1:\(workspace.identity.squadId)"
        else {
            throw EngineContextValidationErrorV1()
        }
    }

    private func validateResolvedTransport(
        request: EngineExecutionRequest,
        transport: EngineExecutionTransportV1,
        context: EngineResolvedContextTransportV1,
        workspace: EngineResolvedWorkspaceV1
    ) throws {
        guard transport.contextRequest.campId == request.campId,
              transport.contextRequest.cardId == request.cardId,
              transport.contextRequest.contextJson == request.contextJson,
              transport.contextRequest.contextHash == request.contextHash,
              transport.workspaceRequest.cardId == request.cardId,
              transport.workspaceRequest.campId == request.campId,
              transport.workspaceRequest.expectedWorkspace
                == request.workspace,
              context.canonicalEnvelopeJSON == request.contextJson,
              context.hash == request.contextHash,
              context.envelope.campId == request.campId,
              context.envelope.cardId == request.cardId,
              workspace.identity.campId == request.campId,
              request.workspace.reference
                == "squad-workspace.v1:\(workspace.identity.squadId)"
        else {
            throw EngineContextValidationErrorV1()
        }
    }

    private func loadRunningExecution(
        _ executionId: String
    ) throws -> EngineExecutionRecord {
        try contextResolver.database.pool.read { database in
            guard let execution = try EngineExecutionRecord.fetchOne(
                database,
                key: executionId
            ), execution.state == .running,
               execution.redactedAt == nil
            else {
                throw EngineDispatchConflictErrorV1()
            }
            return execution
        }
    }

    private func loadExecutionAnyState(
        _ executionId: String
    ) throws -> EngineExecutionRecord {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        } catch {
            throw EngineDispatchConflictErrorV1()
        }
        return try contextResolver.database.pool.read { database in
            guard let execution = try EngineExecutionRecord.fetchOne(
                database,
                key: executionId
            ), execution.id == executionId,
               execution.redactedAt == nil
            else {
                throw EngineDispatchConflictErrorV1()
            }
            return execution
        }
    }

    private func loadAuthority(
        request: EngineExecutionRequest,
        execution: EngineExecutionRecord,
        requiredCapabilities: [EngineCapabilityV1]
    ) throws -> EngineCoordinatorAuthorityV1 {
        let profile = try contextResolver.database.pool.read { database in
            guard let profile = try RuntimeProfileRecord.fetchOne(
                database,
                key: request.profileId
            ) else {
                throw EngineDescriptorMismatchErrorV1()
            }
            return profile
        }
        let selection = try registry.resolve(
            profile: profile,
            requiredCapabilities: requiredCapabilities
        )
        let descriptor = selection.descriptor
        let scope = try CanonicalContractCodingV1.decode(
            EngineSessionScopeV1.self,
            from: Data(request.sessionScopeJson.utf8)
        )
        guard execution.id == request.executionId,
              execution.requestHash == request.requestHash,
              execution.profileId == request.profileId,
              execution.adapterId == request.adapterId,
              execution.adapterVersion == request.adapterVersion,
              execution.runId == request.runId,
              execution.cardId == request.cardId,
              execution.sessionScopeJson == request.sessionScopeJson,
              execution.sessionScopeHash == request.sessionScopeHash,
              execution.nextSequence >= 0,
              execution.inputTokens >= 0,
              execution.outputTokens >= 0,
              execution.cacheReadTokens >= 0,
              execution.costMicros >= 0,
              profile.id == request.profileId,
              descriptor.adapterId == request.adapterId,
              descriptor.adapterVersion == request.adapterVersion,
              descriptor.profileKind == profile.kind,
              descriptor.executionReplayClass(for: scope)
                == request.replayClass
        else {
            throw EngineDescriptorMismatchErrorV1()
        }
        return EngineCoordinatorAuthorityV1(
            profile: profile,
            execution: execution,
            selection: selection
        )
    }

    private func makeRuntime(
        request: EngineExecutionRequest,
        authority: EngineCoordinatorAuthorityV1,
        transport: EngineExecutionTransportV1,
        context: EngineResolvedContextTransportV1,
        workspace: EngineResolvedWorkspaceV1,
        resolvedSessionRef: EngineSessionReferenceV1?,
        handle: EngineExecutionCompletionHandleV1,
        release: EngineCoordinatorReleaseOnceV1,
        activeCleanup: EngineCoordinatorActiveCleanupV1
    ) throws -> EngineCoordinatorRuntimeV1 {
        let execution = authority.execution
        let router = EngineEventRouterV1(
            executionId: request.executionId,
            runId: request.runId,
            cardId: request.cardId,
            nextSequence: execution.nextSequence,
            initialUsage: EngineUsageV1(
                inputTokens: execution.inputTokens,
                outputTokens: execution.outputTokens,
                cacheReadTokens: execution.cacheReadTokens,
                costMicros: execution.costMicros
            )
        )
        let manifestResolver: EngineTerminalManifestResolveV1 = {
            [artifactStager, workspaceRoot = workspace.url] handoff in
            try artifactStager.buildManifest(
                workspaceRoot: workspaceRoot,
                handoff: handoff
            )
        }
        let commit = routedCommit(
            router: router,
            request: request,
            workspaceRoot: workspace.url,
            handle: handle,
            release: release,
            activeCleanup: activeCleanup
        )
        let terminalSink = EngineAdapterTerminalRouterSinkV1(
            router: router,
            manifestResolver: manifestResolver,
            commit: commit
        )
        let boardTerminalSink = EngineBoardTerminalRouterSinkV1(
            router: router,
            manifestResolver: manifestResolver,
            commit: commit
        )
        let progressSink = EngineProgressRouterSinkV1(
            router: router,
            commit: commit
        )
        let runtime = try EngineAdapterRuntimeV1(
            descriptor: authority.selection.descriptor,
            context: context,
            workspace: workspace,
            boundCapabilityTools: transport.boundCapabilityTools,
            resolvedSessionRef: resolvedSessionRef,
            terminalSink: terminalSink,
            boardTerminalSink: boardTerminalSink,
            progressSink: progressSink,
            modelLoopDriver: transport.modelLoopDriver,
            cliProcessDriver: transport.cliProcessDriver,
            cliConfiguration: transport.cliConfiguration
        )
        return EngineCoordinatorRuntimeV1(
            router: router,
            terminalSink: terminalSink,
            runtime: runtime
        )
    }

    private func routedCommit(
        router: EngineEventRouterV1,
        request: EngineExecutionRequest,
        workspaceRoot: URL,
        handle: EngineExecutionCompletionHandleV1,
        release: EngineCoordinatorReleaseOnceV1,
        activeCleanup: EngineCoordinatorActiveCleanupV1
    ) -> EngineRoutedEventCommitV1 {
        { event in
            switch event.payload {
            case let .terminal(content):
                let proposal = try store.recordEngineTerminalProposal(content)
                let receipt: EngineTerminalCommitReceiptV1
                if content.terminalSubtype == .needsHumanInput {
                    receipt = try store.commitEngineAskUser(
                        proposalId: proposal.proposal.id,
                        checkedUsage: await router.usage,
                        now: clock()
                    )
                } else {
                    if !content.artifacts.isEmpty {
                        do {
                            _ = try artifactStager.prepare(
                                proposalId: proposal.proposal.id,
                                workspaceRoot: workspaceRoot,
                                expectedWorkspaceHash: request.workspace.hash
                            )
                        } catch {
                            receipt = try invalidatePreparation(
                                proposal: proposal.proposal,
                                now: clock()
                            )
                            try await finalizeTerminal(
                                receipt: receipt,
                                observedEvent:
                                    try terminalObservationEvent(receipt),
                                handle: handle,
                                release: release,
                                activeCleanup: activeCleanup
                            )
                            return
                        }
                    }
                    receipt = try store.commitEngineTerminal(
                        proposalId: proposal.proposal.id,
                        checkedUsage: await router.usage,
                        now: clock()
                    )
                }
                try await finalizeTerminal(
                    receipt: receipt,
                    observedEvent: event,
                    handle: handle,
                    release: release,
                    activeCleanup: activeCleanup
                )

            case .accepted, .sessionBound, .progress, .toolActivity, .usage:
                try store.acceptRoutedEngineEvent(
                    executionId: event.executionId,
                    sequence: event.sequence,
                    event: event
                )
                await eventObserver(request.cardId, event)
            }
        }
    }

    private func validateAdapter(
        _ adapter: any ExecutionEngineAdapter,
        profile: RuntimeProfileRecord,
        descriptor: ExecutionEngineDescriptor,
        request: EngineExecutionRequest
    ) throws {
        let observed = try adapter.descriptor(profile: profile)
        guard observed.adapterId == descriptor.adapterId,
              observed.adapterVersion == descriptor.adapterVersion,
              observed.profileKind == descriptor.profileKind,
              request.adapterId == descriptor.adapterId,
              request.adapterVersion == descriptor.adapterVersion,
              EngineCapabilityV1.allCases.allSatisfy({ capability in
                  observed.support(for: capability)
                    == descriptor.support(for: capability)
              })
        else {
            throw EngineDescriptorMismatchErrorV1()
        }
    }

    private func commitPreDispatchProtocolFailure(
        execution: EngineExecutionRecord,
        detail: String
    ) throws -> EngineTerminalCommitReceiptV1 {
        try store.commitEnginePreDispatchFailure(
            executionId: execution.id,
            expectedVersion: execution.version,
            failure: EnginePreDispatchFailureV1(
                terminalKind: .blocked,
                terminalSubtype: .engineProtocolError,
                reasonCode: "engine_protocol_error",
                detail: detail
            ),
            commandIdempotencyKey:
                "engine.terminal.v1:engine.pre-dispatch-failure.v1:\(execution.id)",
            now: clock()
        )
    }

    private func runConsumption(
        selected: EngineAdapterPreparedRequestV1,
        request: EngineExecutionRequest,
        authority: EngineCoordinatorAuthorityV1,
        context: EngineResolvedContextTransportV1,
        workspace: EngineResolvedWorkspaceV1,
        resolvedSessionRef: EngineSessionReferenceV1?,
        gate: EngineExecutionStartGateV1,
        release: EngineCoordinatorReleaseOnceV1,
        handle: EngineExecutionCompletionHandleV1
    ) async throws {
        do {
            try await withTaskCancellationHandler {
                try await gate.waitUntilOpened()
                try Task.checkCancellation()
                let transport = try selected.makeTransport(
                    request,
                    context,
                    workspace
                )
                try validateResolvedTransport(
                    request: request,
                    transport: transport,
                    context: context,
                    workspace: workspace
                )
                try Task.checkCancellation()
                let runtime = try makeRuntime(
                    request: request,
                    authority: authority,
                    transport: transport,
                    context: context,
                    workspace: workspace,
                    resolvedSessionRef: resolvedSessionRef,
                    handle: handle,
                    release: release,
                    activeCleanup: .live
                )
                let adapter: any ExecutionEngineAdapter
                do {
                    adapter = try authority.selection.makeAdapter(
                        runtime.runtime
                    )
                    try validateAdapter(
                        adapter,
                        profile: authority.profile,
                        descriptor: authority.selection.descriptor,
                        request: request
                    )
                    try release.installAdapter(adapter)
                    try Task.checkCancellation()
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    try await runtime.terminalSink.submit(
                        .blocked(
                            subtype: .engineProtocolError,
                            reasonCode: "engine_protocol_error",
                            detail:
                                "Engine adapter construction failed."
                        )
                    )
                    return
                }
                try await consumeStream(
                    adapter.execute(request: request),
                    runtime: runtime
                )
            } onCancel: {
                release.signalCancellation()
            }
        } catch is CancellationError {
            release.signalCancellation()
            try await release.waitForPublishedCleanup()
        } catch {
            if Task.isCancelled {
                release.signalCancellation()
                try await release.waitForPublishedCleanup()
                return
            }
            let execution = try loadRunningExecution(request.executionId)
            let receipt = try commitStartedProtocolFailure(
                execution: execution,
                detail: "Engine transport construction failed."
            )
            try await finalizeTerminal(
                receipt: receipt,
                observedEvent: try terminalObservationEvent(receipt),
                handle: handle,
                release: release,
                activeCleanup: .live
            )
        }
    }

    private func consumeStream(
        _ stream: AsyncThrowingStream<
            EngineExecutionEventPayloadV1,
            Error
        >,
        runtime: EngineCoordinatorRuntimeV1
    ) async throws {
        var streamFailure: (any Error)?
        do {
            for try await payload in stream {
                try await runtime.runtime.progressSink.submit(payload)
            }
        } catch {
            streamFailure = error
        }

        if Task.isCancelled { throw CancellationError() }

        if try await runtime.router.state() == .open {
            do {
                try await runtime.terminalSink.submit(
                    .blocked(
                        subtype: .engineProtocolError,
                        reasonCode: "engine_protocol_error",
                        detail: "Engine execution ended without terminal intent."
                    )
                )
            } catch is EngineDuplicateTerminalErrorV1 {
                // A Board or adapter terminal won while EOF was reconciling.
            }
        }
        if case .accepted = try await runtime.router.state() {
            return
        }
        if let streamFailure {
            throw streamFailure
        }
        throw EngineTerminalConflictErrorV1()
    }

    private func commitStartedProtocolFailure(
        execution: EngineExecutionRecord,
        detail: String
    ) throws -> EngineTerminalCommitReceiptV1 {
        guard execution.state == .running,
              execution.dispatchState == .started
                || execution.dispatchState == .sessionBound
        else {
            throw EngineTerminalConflictErrorV1()
        }
        let content = try EngineTerminalProposalContentV1(
            protocolVersion: engineExecutionProtocolVersionV1,
            executionId: execution.id,
            runId: execution.runId,
            cardId: execution.cardId,
            sequence: execution.nextSequence,
            terminalIdempotencyKey:
                "engine.runtime-protocol-failure.v1:\(execution.id)",
            terminalKind: .blocked,
            terminalSubtype: .engineProtocolError,
            payload: .blocked(
                reasonCode: "engine_protocol_error",
                detail: detail
            ),
            artifacts: []
        )
        let proposal = try store.recordEngineTerminalProposal(content)
        return try store.commitEngineTerminal(
            proposalId: proposal.proposal.id,
            checkedUsage: executionUsage(execution),
            now: clock()
        )
    }

    private func terminalObservationEvent(
        _ receipt: EngineTerminalCommitReceiptV1
    ) throws -> EngineExecutionEvent {
        try contextResolver.database.pool.read { database in
            guard let proposal = try EngineTerminalProposalRecord.fetchOne(
                database,
                key: receipt.proposalId
            ), proposal.id == receipt.proposalId,
               proposal.executionId == receipt.executionId,
               proposal.proposalHash == receipt.proposalHash,
               proposal.redactedAt == nil,
               proposal.state == .committed || proposal.state == .invalid
            else {
                throw EngineTerminalConflictErrorV1()
            }
            let content = try CanonicalContractCodingV1.decode(
                EngineTerminalProposalContentV1.self,
                from: Data(proposal.proposalJson.utf8)
            )
            guard content.executionId == receipt.executionId,
                  content.sequence == proposal.sequence,
                  content.terminalIdempotencyKey
                    == proposal.terminalIdempotencyKey
            else {
                throw EngineTerminalConflictErrorV1()
            }
            return EngineExecutionEvent(
                executionId: receipt.executionId,
                sequence: content.sequence,
                payload: .terminal(content)
            )
        }
    }

    private func observedEventCardID(
        _ event: EngineExecutionEvent
    ) throws -> String {
        guard case let .terminal(content) = event.payload,
              content.executionId == event.executionId,
              content.sequence == event.sequence
        else {
            throw EngineTerminalConflictErrorV1()
        }
        return content.cardId
    }

    private func observeTerminalReceipt(
        _ receipt: EngineTerminalCommitReceiptV1
    ) async throws {
        let event = try terminalObservationEvent(receipt)
        await eventObserver(try observedEventCardID(event), event)
    }

    private func finalizeTerminal(
        receipt: EngineTerminalCommitReceiptV1,
        observedEvent: EngineExecutionEvent,
        handle: EngineExecutionCompletionHandleV1,
        release: EngineCoordinatorReleaseOnceV1,
        activeCleanup: EngineCoordinatorActiveCleanupV1,
        handleCompletion: EngineCoordinatorHandleCompletionV1 = .ordinary
    ) async throws {
        guard receipt.executionId == handle.executionId,
              observedEvent.executionId == receipt.executionId
        else {
            throw EngineTerminalConflictErrorV1()
        }
        let cardId = try observedEventCardID(observedEvent)
        let shield = Task {
            var firstError: (any Error)?
            await eventObserver(cardId, observedEvent)
            release.releaseWorkspace()

            do {
                switch activeCleanup {
                case .none:
                    break
                case .pending:
                    try await activeExecutions.finishPending(
                        executionId: receipt.executionId,
                        terminalReceipt: receipt
                    )
                case .live:
                    try await activeExecutions.remove(
                        executionId: receipt.executionId,
                        terminalReceipt: receipt
                    )
                }
            } catch {
                firstError = error
            }

            do {
                try await completionRegistry.authorizeRemoval(
                    executionId: receipt.executionId,
                    terminalReceipt: receipt,
                    matching: handle
                )
            } catch {
                if firstError == nil { firstError = error }
            }

            do {
                try await completionRegistry.remove(
                    executionId: receipt.executionId,
                    terminalReceipt: receipt,
                    matching: handle
                )
            } catch {
                if firstError == nil { firstError = error }
            }

            if let firstError {
                var deliveryError: (any Error)?
                do {
                    try await handle.fail(firstError)
                } catch {
                    deliveryError = error
                }
                if deliveryError != nil {
                    Logger(
                        subsystem: "AgentLoop",
                        category: "EngineExecutionCoordinator"
                    ).error("terminal finalizer failure delivery conflicted")
                }
                _ = deliveryError
                throw firstError
            }
            switch handleCompletion {
            case .ordinary:
                try await handle.complete(receipt: receipt)
            case .terminalWinner:
                try await handle.completeTerminalWinner(receipt: receipt)
            }
        }
        try await shield.value
    }

    private func invalidatePreparation(
        proposal: EngineTerminalProposalRecord,
        now: Date
    ) throws -> EngineTerminalCommitReceiptV1 {
        try store.invalidateProposalAndCommitProtocolError(
            proposalId: proposal.id,
            expectedVersion: proposal.version,
            failure: EngineTerminalPreparationFailure(
                reasonCode: "artifact_preparation_failed",
                detail: "Engine artifact preparation failed."
            ),
            commandIdempotencyKey:
                "engine.terminal.v1:engine.artifact-preparation-failed.v1:\(proposal.id)",
            now: now
        )
    }

    private func recoverCLIRequestedCancellation(
        directive: EngineRecoveryDirectiveV1,
        request: EngineExecutionRequest,
        now: Date
    ) async throws -> EngineTerminalCommitReceiptV1 {
        let release = EngineCoordinatorReleaseOnceV1(
            executionId: request.executionId,
            workspace: nil
        )
        let claimed = try await completionRegistry.claimOwner(
            executionId: request.executionId,
            makeHandle: {
                try EngineExecutionCompletionHandleV1(
                    executionId: request.executionId,
                    resolveCancellation: { handle, frozenReason in
                        try await resolveCancellation(
                            handle: handle,
                            reason: frozenReason,
                            release: release
                        )
                    }
                )
            },
            operation: { handle, _, control in
                do {
                    return try await performCLIRequestedCancellation(
                        directive: directive,
                        request: request,
                        now: now,
                        handle: handle,
                        release: release,
                        control: control
                    )
                } catch {
                    release.releaseWorkspace()
                    throw error
                }
            }
        )
        return try await claimed.task.value
    }

    private func performCLIRequestedCancellation(
        directive: EngineRecoveryDirectiveV1,
        request: EngineExecutionRequest,
        now: Date,
        handle: EngineExecutionCompletionHandleV1,
        release: EngineCoordinatorReleaseOnceV1,
        control: EngineExecutionCompletionGenerationControlV1
    ) async throws -> EngineTerminalCommitReceiptV1 {
        try request.validateCanonicalIdentity()
        guard directive.executionId == request.executionId,
              directive.action == .cancelAndReconcile,
              handle.executionId == request.executionId
        else {
            throw EngineDispatchConflictErrorV1()
        }
        let execution = try loadRunningExecution(request.executionId)
        guard execution.cancellationRequestedAt != nil,
              let reason = execution.cancellationReason,
              execution.dispatchState == .started
                || execution.dispatchState == .sessionBound
        else {
            throw EngineDispatchConflictErrorV1()
        }
        try await control.claimTerminalPermit()
        try Task.checkCancellation()
        let authority = try loadAuthority(
            request: request,
            execution: execution,
            requiredCapabilities: request.requiredCapabilities
        )
        let descriptor = authority.selection.descriptor
        guard descriptor.profileKind == .cliCodex
                || descriptor.profileKind == .cliClaude,
              descriptor.adapterId == request.adapterId,
              descriptor.adapterVersion == request.adapterVersion,
              descriptor.adapterId == request.engineKind,
              authority.profile.kind == descriptor.profileKind
        else {
            throw EngineDescriptorMismatchErrorV1()
        }

        let seed = try await transportSeedResolver(request)
        let contextVariant = try recoveryContextVariant(
            seed: seed,
            descriptor: descriptor
        )
        let resolvedContext = try await contextResolver.reload(
            contextVariant.request
        )
        let resolvedWorkspace = try workspaceResolver.resolve(
            seed.workspace.request
        )
        do {
            try release.installWorkspace(resolvedWorkspace)
        } catch {
            resolvedWorkspace.release()
            throw error
        }
        try validateRecoverySeed(
            seed,
            request: request,
            descriptor: descriptor,
            context: contextVariant,
            resolvedContext: resolvedContext,
            workspace: resolvedWorkspace
        )
        let transport = try authority.selection.makeRecoveryTransport(
            request,
            resolvedContext,
            resolvedWorkspace,
            seed
        )
        try validateResolvedTransport(
            request: request,
            transport: transport,
            context: resolvedContext,
            workspace: resolvedWorkspace
        )
        guard transport.modelLoopDriver == nil,
              let cliProcessDriver = transport.cliProcessDriver,
              transport.cliConfiguration != nil,
              cliProcessDriver.supportsProcessGroupCancellation
        else {
            throw EngineDescriptorMismatchErrorV1()
        }
        let evidence = try await cliProcessDriver.cancel(
            executionId: request.executionId
        )
        guard evidence.pid > 1,
              evidence.processGroupID == evidence.pid,
              evidence.status != -1,
              evidence.termSent,
              !evidence.killSent || evidence.termSent,
              evidence.stdoutEOF,
              evidence.stderrEOF,
              evidence.childReaped
        else {
            throw EngineDispatchConflictErrorV1()
        }

        try await handle.publishCancellationLifecycle(.noTransport)
        let result = try store.recoverInterruptedEngineExecution(
            executionId: request.executionId,
            now: now
        )
        guard case let .receipt(receipt) = result,
              receipt.executionId == request.executionId,
              receipt.terminalKind == .canceled,
              receipt.reasonCode == reason
        else {
            throw EngineDispatchConflictErrorV1()
        }
        try await finalizeTerminal(
            receipt: receipt,
            observedEvent: try terminalObservationEvent(receipt),
            handle: handle,
            release: release,
            activeCleanup: .none
        )
        return receipt
    }

    private func recoverDirective(
        directive: EngineRecoveryDirectiveV1,
        request: EngineExecutionRequest,
        now: Date,
        installedHandle: EngineExecutionCompletionHandleV1? = nil,
        installedRelease: EngineCoordinatorReleaseOnceV1? = nil,
        installedControl: EngineExecutionCompletionGenerationControlV1? = nil,
        installResolvedWorkspaceInRelease: Bool = false
    ) async throws -> EngineTerminalCommitReceiptV1? {
        if installedHandle == nil {
            guard installedRelease == nil, installedControl == nil else {
                throw EngineDispatchConflictErrorV1()
            }
            let release = EngineCoordinatorReleaseOnceV1(
                executionId: request.executionId,
                workspace: nil
            )
            let claimed = try await completionRegistry.claimOwner(
                executionId: request.executionId,
                makeHandle: {
                    try EngineExecutionCompletionHandleV1(
                        executionId: request.executionId,
                        resolveCancellation: { handle, reason in
                            try await resolveCancellation(
                                handle: handle,
                                reason: reason,
                                release: release
                            )
                        }
                    )
                },
                operation: { handle, _, control in
                    do {
                        guard let receipt = try await recoverDirective(
                            directive: directive,
                            request: request,
                            now: now,
                            installedHandle: handle,
                            installedRelease: release,
                            installedControl: control,
                            installResolvedWorkspaceInRelease: true
                        ) else {
                            throw EngineDispatchConflictErrorV1()
                        }
                        return receipt
                    } catch {
                        release.releaseWorkspace()
                        throw error
                    }
                }
            )
            return try await claimed.task.value
        }

        guard let installedHandle, let installedRelease,
              let installedControl
        else {
            throw EngineDispatchConflictErrorV1()
        }

        try request.validateCanonicalIdentity()
        guard directive.executionId == request.executionId else {
            throw EngineDispatchConflictErrorV1()
        }
        let execution = try loadRunningExecution(request.executionId)
        let requiredCapabilities: [EngineCapabilityV1]
        if case .resumeSession = directive.action {
            var values = Set(request.requiredCapabilities)
            values.insert(.sessionResume)
            requiredCapabilities = values.sorted {
                $0.rawValue < $1.rawValue
            }
        } else {
            requiredCapabilities = request.requiredCapabilities
        }
        let authority = try loadAuthority(
            request: request,
            execution: execution,
            requiredCapabilities: requiredCapabilities
        )
        let seed = try await transportSeedResolver(request)
        let contextVariant = try recoveryContextVariant(
            seed: seed,
            descriptor: authority.selection.descriptor
        )
        let resolvedContext = try await contextResolver.reload(
            contextVariant.request
        )
        let resolvedWorkspace = try workspaceResolver.resolve(
            seed.workspace.request
        )
        let release = installedRelease
        var releaseResolvedWorkspaceDirectly = false
        if installResolvedWorkspaceInRelease {
            do {
                try release.installWorkspace(resolvedWorkspace)
            } catch {
                resolvedWorkspace.release()
                throw error
            }
        } else {
            releaseResolvedWorkspaceDirectly = true
        }
        defer {
            if releaseResolvedWorkspaceDirectly {
                resolvedWorkspace.release()
            }
        }
        try validateRecoverySeed(
            seed,
            request: request,
            descriptor: authority.selection.descriptor,
            context: contextVariant,
            resolvedContext: resolvedContext,
            workspace: resolvedWorkspace
        )
        let recoveredSelection = EngineAdapterPreparedRequestV1(
            descriptor: authority.selection.descriptor,
            engineKind: request.engineKind,
            model: request.model,
            budget: request.budget,
            context: contextVariant,
            requiredCapabilities: requiredCapabilities,
            makeTransport: {
                [selection = authority.selection, seed]
                recoveredRequest,
                recoveredContext,
                recoveredWorkspace in
                try selection.makeRecoveryTransport(
                    recoveredRequest,
                    recoveredContext,
                    recoveredWorkspace,
                    seed
                )
            }
        )

        switch directive.action {
        case let .prepareAndCommitProposal(proposalId):
            try await installedControl.claimTerminalPermit()
            try Task.checkCancellation()
            let proposal = try loadProposal(
                proposalId,
                executionId: request.executionId
            )
            do {
                _ = try artifactStager.recoverPreparation(
                    proposalId: proposal.id,
                    workspaceRoot: resolvedWorkspace.url,
                    expectedWorkspaceHash: request.workspace.hash
                )
            } catch {
                let receipt = try invalidatePreparation(
                    proposal: proposal,
                    now: now
                )
                try await finalizeTerminal(
                    receipt: receipt,
                    observedEvent: try terminalObservationEvent(receipt),
                    handle: installedHandle,
                    release: release,
                    activeCleanup: .none
                )
                return receipt
            }
            let receipt = try store.commitEngineTerminal(
                proposalId: proposal.id,
                checkedUsage: executionUsage(execution),
                now: now
            )
            try await finalizeTerminal(
                receipt: receipt,
                observedEvent: try terminalObservationEvent(receipt),
                handle: installedHandle,
                release: release,
                activeCleanup: .none
            )
            return receipt

        case .startPrepared:
            try await installedControl.claimDispatchPermit()
            try Task.checkCancellation()
            guard execution.dispatchState == .prepared else {
                throw EngineDispatchConflictErrorV1()
            }
            let dispatch = try store.markEngineDispatchStarted(
                executionId: request.executionId,
                expectedVersion: execution.version,
                requestHash: request.requestHash,
                commandIdempotencyKey:
                    dispatchCommandKey(request.executionId),
                now: now
            )
            guard case let .startNow(persistedRequest) = dispatch,
                  persistedRequest == request
            else {
                throw EngineDispatchConflictErrorV1()
            }
            try await startSelectedConsumption(
                selected: recoveredSelection,
                request: request,
                authority: authority,
                context: resolvedContext,
                workspace: resolvedWorkspace,
                resolvedSessionRef: nil,
                release: release,
                handle: installedHandle
            )
            return try await installedHandle.waitForReceipt()

        case .replayExecution:
            try await installedControl.claimDispatchPermit()
            try Task.checkCancellation()
            guard request.replayClass == .replaySafe
                    || request.replayClass == .idempotencyKeyed,
                  execution.dispatchState == .started
            else {
                throw EngineExecutionReplayConflictError()
            }
            try await startSelectedConsumption(
                selected: recoveredSelection,
                request: request,
                authority: authority,
                context: resolvedContext,
                workspace: resolvedWorkspace,
                resolvedSessionRef: nil,
                release: release,
                handle: installedHandle
            )
            return try await installedHandle.waitForReceipt()

        case .cancelAndReconcile:
            throw EngineDispatchConflictErrorV1()

        case let .resumeSession(sessionId, externalSessionId):
            try await installedControl.claimDispatchPermit()
            try Task.checkCancellation()
            let descriptor = authority.selection.descriptor
            guard descriptor.profileKind == .cliCodex
                    || descriptor.profileKind == .cliClaude,
                  descriptor.adapterId == request.adapterId,
                  descriptor.adapterVersion == request.adapterVersion,
                  descriptor.profileKind == authority.profile.kind,
                  descriptor.sessionResume == .supported
            else {
                throw EngineDescriptorMismatchErrorV1()
            }
            let resolvedSessionRef = try store
                .resolveRecoverySessionReference(
                    executionId: directive.executionId,
                    requestHash: request.requestHash,
                    sessionId: sessionId,
                    externalSessionId: externalSessionId
                )
            try await startSelectedConsumption(
                selected: recoveredSelection,
                request: request,
                authority: authority,
                context: resolvedContext,
                workspace: resolvedWorkspace,
                resolvedSessionRef: resolvedSessionRef,
                release: release,
                handle: installedHandle
            )
            return try await installedHandle.waitForReceipt()

        case .deferCampDeletion:
            return nil
        }
    }

    private func loadProposal(
        _ proposalId: String,
        executionId: String
    ) throws -> EngineTerminalProposalRecord {
        try contextResolver.database.pool.read { database in
            guard let proposal = try EngineTerminalProposalRecord.fetchOne(
                database,
                key: proposalId
            ), proposal.executionId == executionId,
               proposal.state == .pending,
               proposal.redactedAt == nil
            else {
                throw EngineTerminalConflictErrorV1()
            }
            return proposal
        }
    }

    private func executionUsage(
        _ execution: EngineExecutionRecord
    ) -> EngineUsageV1 {
        EngineUsageV1(
            inputTokens: execution.inputTokens,
            outputTokens: execution.outputTokens,
            cacheReadTokens: execution.cacheReadTokens,
            costMicros: execution.costMicros
        )
    }

    private func dispatchCommandKey(_ executionId: String) -> String {
        "engine.dispatch-start.v1:\(executionId)"
    }
}

package struct PlanningMissionStartArguments: Sendable, Equatable {
    package let goal: String
    package let companionIds: [String]
    package let workspacePath: String?
    package let budgetTokens: Int
    package let campId: String?
    package let autonomy: MissionAutonomy

    package init(
        goal: String,
        companionIds: [String],
        workspacePath: String?,
        budgetTokens: Int,
        campId: String?,
        autonomy: MissionAutonomy
    ) {
        self.goal = goal
        self.companionIds = companionIds
        self.workspacePath = workspacePath
        self.budgetTokens = budgetTokens
        self.campId = campId
        self.autonomy = autonomy
    }
}

package struct ManualMissionStartSnapshot: Sendable, Equatable {
    package let mission: PlanningMissionStartArguments
    package let runtime: PlanningEntryRuntimeSelection

    package init(
        mission: PlanningMissionStartArguments,
        runtime: PlanningEntryRuntimeSelection
    ) {
        self.mission = mission
        self.runtime = runtime
    }
}

package struct PendingManualMissionStart: Sendable, Equatable {
    package let snapshot: ManualMissionStartSnapshot
    package let idempotencyKey: String
    package let traceId: String

    package init(
        snapshot: ManualMissionStartSnapshot,
        idempotencyKey: String,
        traceId: String
    ) {
        self.snapshot = snapshot
        self.idempotencyKey = idempotencyKey
        self.traceId = traceId
    }
}

package struct CapturedCandidateMissionStart: Sendable, Equatable {
    package let draft: CodingRanchMissionDraft
    package let runtime: PlanningEntryRuntimeSelection
    package let idempotencyKey: String
    package let traceId: String

    package init(
        draft: CodingRanchMissionDraft,
        runtime: PlanningEntryRuntimeSelection,
        idempotencyKey: String,
        traceId: String
    ) {
        self.draft = draft
        self.runtime = runtime
        self.idempotencyKey = idempotencyKey
        self.traceId = traceId
    }
}

#if DEBUG
package enum A3CandidatePostCommitObservationForTesting:
    Sendable, Equatable
{
    case ensureTick
    case planningStarted
    case kick
}
#endif

package struct CapturedProposalMissionStart: Sendable, Equatable {
    package let messageId: String
    package let proposalId: String
    package let runtime: PlanningEntryRuntimeSelection
    package let fallbackBudget: Int
    package let autonomy: MissionAutonomy
    package let idempotencyKey: String
    package let traceId: String

    package init(
        messageId: String,
        proposalId: String,
        runtime: PlanningEntryRuntimeSelection,
        fallbackBudget: Int,
        autonomy: MissionAutonomy,
        idempotencyKey: String,
        traceId: String
    ) {
        self.messageId = messageId
        self.proposalId = proposalId
        self.runtime = runtime
        self.fallbackBudget = fallbackBudget
        self.autonomy = autonomy
        self.idempotencyKey = idempotencyKey
        self.traceId = traceId
    }
}

public enum KernelEvent: Sendable {
    case planningStarted(missionId: String)
    case planCompleted(missionId: String, fallback: Bool)
    case missionChanged(missionId: String)
    case cardEvent(cardId: String, AgentEvent)
    case kernelError(missionId: String, message: String)
    case operationFailed(UserVisibleFailure)
    case contextDegraded(ContextDegradationNotice)
    /// 收营蒸馏产出营地笔记（source: "closeout" | "fallback"）
    case campNoteCreated(missionId: String, noteId: String)
    /// M7-D5：紧急收哨状态翻转（true=已收哨）
    case haltStateChanged(Bool)
    case ruminationChanged(RuminationChange)
    case ruminationPhase(
        ingestionId: String,
        workId: String,
        attempt: Int,
        phase: RuminationPhase
    )
}

public enum RuminationChange: Sendable, Equatable {
    case phaseInvalidated(RuminationPhaseIdentity)
    case projectionCommitted(
        RuminationProjectionCommitIdentity,
        invalidatedPhaseIdentity: RuminationPhaseIdentity?
    )
}

public struct MissionStateError: Error, Sendable, Equatable {
    public let missionId: String
    public let from: MissionStatus
    public let expected: MissionStatus

    public init(missionId: String, from: MissionStatus, expected: MissionStatus) {
        self.missionId = missionId
        self.from = from
        self.expected = expected
    }
}

public struct KernelHaltedError: LocalizedError, Sendable, Equatable {
    public init() {}

    public var errorDescription: String? {
        "全部行动已紧急收哨，请先恢复后再出发。"
    }
}

public struct ProviderUnavailableError: LocalizedError, Sendable, Equatable {
    public let model: String
    public let companionId: String?

    public init(model: String, companionId: String?) {
        self.model = model
        self.companionId = companionId
    }

    public var errorDescription: String? {
        if let companionId {
            return "伙伴 \(companionId) 的供给线没有可用模型或凭据：\(model)"
        }
        return "默认供给线没有可用模型或凭据：\(model)"
    }
}

public struct HaltPersistenceError: LocalizedError, Sendable, Equatable {
    public let detail: String

    public init(detail: String) {
        self.detail = detail
    }

    public var errorDescription: String? {
        "当前行动工作已经停止，但持久化收哨状态未能保存。请勿退出 AgentLoop，修复存储问题后重试保存。详情：\(detail)"
    }
}

public struct PlanningHaltCleanupError: LocalizedError, Sendable, Equatable {
    public let detail: String

    public init(detail: String) {
        self.detail = detail
    }

    public var errorDescription: String? {
        "当前行动工作已经停止，但被中断的规划未能安全收口。全部行动仍保持暂停；修复存储问题后重试恢复。详情：\(detail)"
    }
}

public struct HaltRecoveryError: LocalizedError, Sendable, Equatable {
    public let detail: String

    public init(detail: String) {
        self.detail = detail
    }

    public var errorDescription: String? {
        "恢复前的中断任务收编失败。全部行动仍保持暂停，没有启动新工作；修复存储问题后重试恢复。详情：\(detail)"
    }
}

public struct KernelTransitionInProgressError: LocalizedError, Sendable, Equatable {
    public init() {}

    public var errorDescription: String? {
        "停营或恢复状态正在由另一项操作处理，请确认当前状态后重试。"
    }
}

package enum EngineRuntimeAuthorityErrorV1: Error, Sendable, Equatable {
    case invalidStateRoot
    case invalidDirectory
    case invalidOwner
    case descriptorFailure(Int32)
    case authorityClosed
    case leaseClosed
    case outstandingLeases
    case uncheckedReleaseFault
    case cleanupFailure(Int32)
    case collisionExhausted
    case socketPathTooLong
    case processSnapshot
    case processDrift
    case unknownMember
    case processSignal(Int32)
    case processGroupSurvived
    case managedPolicy
}

package struct EngineRuntimeCleanupAggregateErrorV1:
    Error, @unchecked Sendable
{
    package let primary: any Error
    package let cleanupFailures: [any Error]

    package init(
        primary: any Error,
        cleanupFailures: [any Error]
    ) {
        self.primary = primary
        self.cleanupFailures = cleanupFailures
    }
}

private enum EngineRuntimeCleanupV1 {
    static func runAll(
        _ operations: [() throws -> Void]
    ) -> [any Error] {
        var failures: [any Error] = []
        for operation in operations {
            do {
                try operation()
            } catch {
                failures.append(error)
            }
        }
        return failures
    }

    static func throwPreserving(
        _ primary: any Error,
        cleanup operations: [() throws -> Void]
    ) throws -> Never {
        let failures = runAll(operations)
        guard !failures.isEmpty else { throw primary }
        throw EngineRuntimeCleanupAggregateErrorV1(
            primary: primary,
            cleanupFailures: failures
        )
    }

    static func throwCleanupFailures(
        _ failures: [any Error]
    ) throws {
        guard let first = failures.first else { return }
        if failures.count == 1 { throw first }
        throw EngineRuntimeCleanupAggregateErrorV1(
            primary: first,
            cleanupFailures: Array(failures.dropFirst())
        )
    }
}

package enum EngineRuntimeOwnedDescriptorV1 {
    package static func closeOnce(
        _ descriptor: inout Int32,
        close: (Int32) throws -> Void = { owned in
            guard Darwin.close(owned) == 0 else {
                throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
            }
        }
    ) throws {
        guard descriptor >= 0 else { return }
        let owned = descriptor
        descriptor = -1
        try close(owned)
    }
}

package struct EngineStateRootIdentityV1: Codable, Sendable, Equatable {
    package let canonicalPath: String
    package let device: UInt64
    package let inode: UInt64
    package let uid: UInt32

    package init(
        canonicalPath: String,
        device: UInt64,
        inode: UInt64,
        uid: UInt32
    ) {
        self.canonicalPath = canonicalPath
        self.device = device
        self.inode = inode
        self.uid = uid
    }

    package static func capture(
        stateDirectoryLock: StateDirectoryLock
    ) throws -> EngineStateRootIdentityV1 {
        var descriptor = try stateDirectoryLock
            .duplicateLockedDirectoryDescriptor()
        let identity: EngineStateRootIdentityV1
        do {
            var info = stat()
            guard Darwin.fstat(descriptor, &info) == 0,
                  info.st_mode & S_IFMT == S_IFDIR,
                  info.st_uid == getuid()
            else {
                throw EngineRuntimeAuthorityErrorV1.invalidStateRoot
            }
            var pathBytes = [CChar](
                repeating: 0,
                count: Int(MAXPATHLEN)
            )
            let pathResult = Darwin.fcntl(
                descriptor,
                F_GETPATH,
                &pathBytes
            )
            guard pathResult == 0 else {
                throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
            }
            let path = String(
                decoding: pathBytes.prefix { $0 != 0 }
                    .map { UInt8(bitPattern: $0) },
                as: UTF8.self
            )
            guard path.hasPrefix("/"),
                  URL(fileURLWithPath: path).standardizedFileURL.path == path
            else {
                throw EngineRuntimeAuthorityErrorV1.invalidStateRoot
            }
            identity = EngineStateRootIdentityV1(
                canonicalPath: path,
                device: UInt64(info.st_dev),
                inode: UInt64(info.st_ino),
                uid: UInt32(info.st_uid)
            )
        } catch {
            let primary = error
            try EngineRuntimeCleanupV1.throwPreserving(
                primary,
                cleanup: [{
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
                }]
            )
        }
        try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
        return identity
    }

    package func canonicalBytes() throws -> Data {
        let bytes = try CanonicalJSONV1.encode(self)
        guard bytes.last != UInt8(ascii: "\n") else {
            throw EngineRuntimeAuthorityErrorV1.invalidStateRoot
        }
        return bytes
    }

    package func identityHash() throws -> String {
        CanonicalJSONV1.sha256Hex(try canonicalBytes())
    }
}

package final class EngineBoardSocketDirectoryAuthorityV1:
    @unchecked Sendable, Equatable
{
    package let directoryURL: URL
    package let device: UInt64
    package let inode: UInt64
    package let uid: UInt32
    package let mode: UInt16
    package let ownerIdentityHash: String
    package let bootId: String

    private let stateLock = NSLock()
    private var ownedDescriptor: Int32
    private var activeLeaseCount = 0
    private var authorityClosed = false
    private var uncheckedReleaseFault = false
    private weak var runtimeDirectoryAuthoritySet:
        EngineRuntimeDirectoryAuthoritySetV1?

    package init(
        directoryURL: URL,
        ownedDescriptor: Int32,
        device: UInt64,
        inode: UInt64,
        uid: UInt32,
        mode: UInt16,
        ownerIdentityHash: String,
        bootId: String
    ) throws {
        var info = stat()
        var descriptorPath = [CChar](
            repeating: 0,
            count: Int(MAXPATHLEN)
        )
        let descriptorPathResult = ownedDescriptor >= 0
            ? Darwin.fcntl(ownedDescriptor, F_GETPATH, &descriptorPath)
            : -1
        guard directoryURL.isFileURL,
              directoryURL.baseURL == nil,
              directoryURL.path.hasPrefix("/"),
              ownedDescriptor >= 0,
              descriptorPathResult == 0,
              String(
                  decoding: descriptorPath.prefix { $0 != 0 }
                      .map { UInt8(bitPattern: $0) },
                  as: UTF8.self
              ) == directoryURL.path,
              Darwin.fstat(ownedDescriptor, &info) == 0,
              info.st_mode & S_IFMT == S_IFDIR,
              UInt64(info.st_dev) == device,
              UInt64(info.st_ino) == inode,
              UInt32(info.st_uid) == uid,
              UInt16(info.st_mode & mode_t(0o777)) == mode,
              uid == UInt32(getuid()),
              mode == 0o700,
              ownerIdentityHash.utf8.count == 64,
              ownerIdentityHash.utf8.allSatisfy({ byte in
                  (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                      || (UInt8(ascii: "a")...UInt8(ascii: "f"))
                          .contains(byte)
              }),
              let bootUUID = UUID(uuidString: bootId),
              bootUUID.uuidString == bootId
        else {
            throw EngineRuntimeAuthorityErrorV1.invalidDirectory
        }
        self.directoryURL = directoryURL
        self.ownedDescriptor = ownedDescriptor
        self.device = device
        self.inode = inode
        self.uid = uid
        self.mode = mode
        self.ownerIdentityHash = ownerIdentityHash
        self.bootId = bootId
    }

    package func makeDescriptorLease() throws
        -> EngineBoardSocketDirectoryDescriptorLeaseV1
    {
        try stateLock.withLock {
            guard !authorityClosed else {
                throw EngineRuntimeAuthorityErrorV1.authorityClosed
            }
            guard uncheckedReleaseFault == false else {
                throw EngineRuntimeAuthorityErrorV1.uncheckedReleaseFault
            }
            let duplicate = Darwin.fcntl(
                ownedDescriptor,
                F_DUPFD_CLOEXEC,
                0
            )
            guard duplicate >= 0 else {
                throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
            }
            activeLeaseCount += 1
            return EngineBoardSocketDirectoryDescriptorLeaseV1(
                fileDescriptor: duplicate,
                authority: self
            )
        }
    }

    package func close() throws {
        try stateLock.withLock {
            guard !authorityClosed else {
                throw EngineRuntimeAuthorityErrorV1.authorityClosed
            }
            guard activeLeaseCount == 0 else {
                throw EngineRuntimeAuthorityErrorV1.outstandingLeases
            }
            guard uncheckedReleaseFault == false else {
                throw EngineRuntimeAuthorityErrorV1.uncheckedReleaseFault
            }
            var descriptor = ownedDescriptor
            ownedDescriptor = -1
            authorityClosed = true
            try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
        }
    }

    fileprivate func releaseLease(checked: Bool) {
        stateLock.withLock {
            if activeLeaseCount > 0 {
                activeLeaseCount -= 1
            } else {
                uncheckedReleaseFault = true
            }
            if !checked {
                uncheckedReleaseFault = true
            }
        }
    }

    fileprivate func recordUncheckedReleaseFault() {
        releaseLease(checked: false)
    }

    fileprivate func installRuntimeDirectoryAuthoritySet(
        _ authoritySet: EngineRuntimeDirectoryAuthoritySetV1
    ) {
        stateLock.withLock {
            precondition(!authorityClosed)
            precondition(runtimeDirectoryAuthoritySet == nil)
            runtimeDirectoryAuthoritySet = authoritySet
        }
    }

    fileprivate func retainedRuntimeDirectoryAuthoritySet()
        -> EngineRuntimeDirectoryAuthoritySetV1?
    {
        stateLock.withLock { runtimeDirectoryAuthoritySet }
    }

    fileprivate func withOwnedDescriptor<T>(
        _ operation: (Int32) throws -> T
    ) throws -> T {
        try stateLock.withLock {
            guard !authorityClosed,
                  activeLeaseCount == 0,
                  !uncheckedReleaseFault,
                  ownedDescriptor >= 0
            else {
                throw EngineRuntimeAuthorityErrorV1.outstandingLeases
            }
            return try operation(ownedDescriptor)
        }
    }

    deinit {
        let descriptor = stateLock.withLock { () -> Int32 in
            if authorityClosed { return -1 }
            authorityClosed = true
            let value = ownedDescriptor
            ownedDescriptor = -1
            return value
        }
        if descriptor >= 0 {
            _ = Darwin.close(descriptor)
        }
    }

    package static func == (
        lhs: EngineBoardSocketDirectoryAuthorityV1,
        rhs: EngineBoardSocketDirectoryAuthorityV1
    ) -> Bool {
        lhs.directoryURL == rhs.directoryURL
            && lhs.device == rhs.device
            && lhs.inode == rhs.inode
            && lhs.uid == rhs.uid
            && lhs.mode == rhs.mode
            && lhs.ownerIdentityHash == rhs.ownerIdentityHash
            && lhs.bootId == rhs.bootId
    }
}

package final class EngineBoardSocketDirectoryDescriptorLeaseV1:
    @unchecked Sendable
{
    private let stateLock = NSLock()
    private weak var authority: EngineBoardSocketDirectoryAuthorityV1?
    private var ownedDescriptor: Int32
    private var leaseClosed = false

    package var fileDescriptor: Int32 {
        stateLock.withLock { ownedDescriptor }
    }

    fileprivate init(
        fileDescriptor: Int32,
        authority: EngineBoardSocketDirectoryAuthorityV1
    ) {
        ownedDescriptor = fileDescriptor
        self.authority = authority
    }

    package func close() throws {
        let owned = try stateLock.withLock {
            () throws -> (Int32, EngineBoardSocketDirectoryAuthorityV1?) in
            guard !leaseClosed else {
                throw EngineRuntimeAuthorityErrorV1.leaseClosed
            }
            leaseClosed = true
            let descriptor = ownedDescriptor
            ownedDescriptor = -1
            return (descriptor, authority)
        }
        var descriptor = owned.0
        do {
            try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
            owned.1?.releaseLease(checked: true)
        } catch {
            owned.1?.releaseLease(checked: false)
            throw error
        }
    }

    deinit {
        let owned = stateLock.withLock {
            () -> (Int32, EngineBoardSocketDirectoryAuthorityV1?)? in
            guard !leaseClosed else { return nil }
            leaseClosed = true
            let descriptor = ownedDescriptor
            ownedDescriptor = -1
            return (descriptor, authority)
        }
        if let owned {
            _ = Darwin.close(owned.0)
            owned.1?.recordUncheckedReleaseFault()
        }
    }
}

package struct EngineExecutionEnvironmentV1: Sendable {
    package let database: AppDatabase
    package let stateDirectoryLock: StateDirectoryLock
    package let artifactStoreRoot: URL
    package let bridgeExecutablePath: String?
    package let boardSocketDirectoryAuthority:
        EngineBoardSocketDirectoryAuthorityV1?
    package let validateCodexManagedPolicy:
        EngineCliManagedPolicyValidateV1?
    package let validateClaudeManagedPolicy:
        EngineCliManagedPolicyValidateV1?
    package let claudeConfigDirectory: URL
    package let cliExecutableDirectory: URL
    package let processInspector: any EngineRuntimeProcessInspectingV1
    package let dependencyLoader: any ContextDependencyLoading
    package let resolveInitialModelLoopProvider:
        EngineInitialModelLoopProviderResolveV1
    package let resolveRecoveryModelLoopProvider:
        EngineRecoveryModelLoopProviderResolveV1
    package let helpProbe: CliHelpProbeV1
    package let makeCliProcessDriver:
        @Sendable () throws -> any CliProcessDrivingV1
    package let clock: @Sendable () -> Date

    package init(
        database: AppDatabase,
        stateDirectoryLock: StateDirectoryLock,
        artifactStoreRoot: URL,
        bridgeExecutablePath: String?,
        boardSocketDirectoryAuthority:
            EngineBoardSocketDirectoryAuthorityV1?,
        validateCodexManagedPolicy:
            EngineCliManagedPolicyValidateV1?,
        validateClaudeManagedPolicy:
            EngineCliManagedPolicyValidateV1?,
        claudeConfigDirectory: URL,
        cliExecutableDirectory: URL,
        processInspector: any EngineRuntimeProcessInspectingV1,
        dependencyLoader: any ContextDependencyLoading,
        resolveInitialModelLoopProvider:
            @escaping EngineInitialModelLoopProviderResolveV1,
        resolveRecoveryModelLoopProvider:
            @escaping EngineRecoveryModelLoopProviderResolveV1,
        helpProbe: CliHelpProbeV1,
        makeCliProcessDriver:
            @escaping @Sendable () throws -> any CliProcessDrivingV1,
        clock: @escaping @Sendable () -> Date
    ) throws {
        for url in [
            artifactStoreRoot, claudeConfigDirectory,
            cliExecutableDirectory,
        ] {
            guard url.isFileURL,
                  url.baseURL == nil,
                  url.path.hasPrefix("/"),
                  url.standardizedFileURL.path == url.path
            else {
                throw EngineRuntimeAuthorityErrorV1.invalidDirectory
            }
        }
        if let bridgeExecutablePath {
            guard bridgeExecutablePath.hasPrefix("/"),
                  URL(fileURLWithPath: bridgeExecutablePath)
                    .standardizedFileURL.path == bridgeExecutablePath,
                  boardSocketDirectoryAuthority != nil,
                  validateCodexManagedPolicy != nil,
                  validateClaudeManagedPolicy != nil
            else {
                throw EngineRuntimeAuthorityErrorV1.invalidDirectory
            }
        } else {
            guard boardSocketDirectoryAuthority == nil,
                  validateCodexManagedPolicy == nil,
                  validateClaudeManagedPolicy == nil
            else {
                throw EngineRuntimeAuthorityErrorV1.invalidDirectory
            }
        }
        self.database = database
        self.stateDirectoryLock = stateDirectoryLock
        self.artifactStoreRoot = artifactStoreRoot
        self.bridgeExecutablePath = bridgeExecutablePath
        self.boardSocketDirectoryAuthority =
            boardSocketDirectoryAuthority
        self.validateCodexManagedPolicy = validateCodexManagedPolicy
        self.validateClaudeManagedPolicy = validateClaudeManagedPolicy
        self.claudeConfigDirectory = claudeConfigDirectory
        self.cliExecutableDirectory = cliExecutableDirectory
        self.processInspector = processInspector
        self.dependencyLoader = dependencyLoader
        self.resolveInitialModelLoopProvider =
            resolveInitialModelLoopProvider
        self.resolveRecoveryModelLoopProvider =
            resolveRecoveryModelLoopProvider
        self.helpProbe = helpProbe
        self.makeCliProcessDriver = makeCliProcessDriver
        self.clock = clock
    }
}

private struct EngineRuntimeFileIdentityV1: Equatable {
    let path: String
    let device: UInt64
    let inode: UInt64
    let uid: UInt32
    let mode: UInt16
    let linkCount: UInt64
    let hash: String
}

package struct EngineRuntimeSigningIdentitySnapshotV1:
    Sendable, Equatable
{
    package let designatedRequirement: String
    package let teamIdentifier: String?
    package let cdHash: String

    package init(
        designatedRequirement: String,
        teamIdentifier: String?,
        cdHash: String
    ) {
        self.designatedRequirement = designatedRequirement
        self.teamIdentifier = teamIdentifier
        self.cdHash = cdHash
    }
}

private enum EngineRuntimeIdentityReaderV1 {
    static func file(
        path: String,
        requireExecutable: Bool
    ) throws -> EngineRuntimeFileIdentityV1 {
        var descriptor = path.withCString {
            Darwin.open($0, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard descriptor >= 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        let value: EngineRuntimeFileIdentityV1
        do {
            var before = stat()
            guard Darwin.fstat(descriptor, &before) == 0,
                  before.st_mode & S_IFMT == S_IFREG,
                  before.st_uid == getuid(),
                  before.st_nlink == 1,
                  !requireExecutable
                    || before.st_mode & mode_t(0o111) != 0
            else {
                throw EngineRuntimeAuthorityErrorV1.processSnapshot
            }
            var hasher = SHA256()
            var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
            while true {
                let amount = buffer.withUnsafeMutableBytes {
                    Darwin.read(descriptor, $0.baseAddress, $0.count)
                }
                if amount > 0 {
                    hasher.update(data: Data(buffer[0..<amount]))
                    continue
                }
                if amount == 0 { break }
                if errno == EINTR { continue }
                throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
            }
            var after = stat()
            guard Darwin.fstat(descriptor, &after) == 0,
                  before.st_dev == after.st_dev,
                  before.st_ino == after.st_ino,
                  before.st_mode == after.st_mode,
                  before.st_uid == after.st_uid,
                  before.st_nlink == after.st_nlink,
                  before.st_size == after.st_size,
                  before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
                  before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec
            else {
                throw EngineRuntimeAuthorityErrorV1.processDrift
            }
            value = EngineRuntimeFileIdentityV1(
                path: path,
                device: UInt64(before.st_dev),
                inode: UInt64(before.st_ino),
                uid: UInt32(before.st_uid),
                mode: UInt16(before.st_mode & mode_t(0o777)),
                linkCount: UInt64(before.st_nlink),
                hash: hasher.finalize().map {
                    String(format: "%02x", $0)
                }.joined()
            )
        } catch {
            let primary = error
            try EngineRuntimeCleanupV1.throwPreserving(
                primary,
                cleanup: [{
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
                }]
            )
        }
        try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
        return value
    }

    static func signing(
        path: String
    ) throws -> EngineRuntimeSigningIdentitySnapshotV1 {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(
            URL(fileURLWithPath: path) as CFURL,
            SecCSFlags(),
            &staticCode
        ) == errSecSuccess,
              let staticCode,
              SecStaticCodeCheckValidity(
                  staticCode,
                  SecCSFlags(rawValue: kSecCSStrictValidate),
                  nil
              ) == errSecSuccess
        else {
            throw EngineRuntimeAuthorityErrorV1.processSnapshot
        }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information
        ) == errSecSuccess,
              let dictionary = information as NSDictionary?,
              let cdHashData = dictionary[kSecCodeInfoUnique] as? Data,
              cdHashData.count == 20
        else {
            throw EngineRuntimeAuthorityErrorV1.processSnapshot
        }
        var requirement: SecRequirement?
        var text: CFString?
        guard SecCodeCopyDesignatedRequirement(
            staticCode,
            SecCSFlags(),
            &requirement
        ) == errSecSuccess,
              let requirement,
              SecRequirementCopyString(
                  requirement,
                  SecCSFlags(),
                  &text
              ) == errSecSuccess,
              let text
        else {
            throw EngineRuntimeAuthorityErrorV1.processSnapshot
        }
        return EngineRuntimeSigningIdentitySnapshotV1(
            designatedRequirement: (text as String)
                .split(whereSeparator: { $0.isWhitespace })
                .joined(separator: " "),
            teamIdentifier:
                dictionary[kSecCodeInfoTeamIdentifier] as? String,
            cdHash: cdHashData.map {
                String(format: "%02x", $0)
            }.joined()
        )
    }
}

package struct EngineRuntimeExecutableRemovalSnapshotV1:
    Sendable, Equatable
{
    fileprivate let authorityName: String
    fileprivate let parentDevice: UInt64
    fileprivate let parentInode: UInt64
    fileprivate let parentUID: UInt32
    fileprivate let directoryDevice: UInt64
    fileprivate let directoryInode: UInt64
    fileprivate let directoryUID: UInt32
    fileprivate let directoryMode: UInt16
    fileprivate let directoryLinkCount: UInt64
    fileprivate let executablePath: String
    fileprivate let executableDevice: UInt64
    fileprivate let executableInode: UInt64
    fileprivate let executableUID: UInt32
    fileprivate let executableMode: UInt16
    fileprivate let executableLinkCount: UInt64
    fileprivate let executableHash: String
    fileprivate let signing: EngineRuntimeSigningIdentitySnapshotV1

    fileprivate var processAuthority: EngineOwnedRuntimeExecutableV1 {
        EngineOwnedRuntimeExecutableV1(
            executablePath: executablePath,
            executableDevice: executableDevice,
            executableInode: executableInode,
            executableHash: executableHash,
            designatedRequirement: signing.designatedRequirement,
            cdHash: signing.cdHash
        )
    }
}

package enum EngineRuntimeExecutableRemovalCheckpointV1:
    Sendable, Equatable
{
    case afterUnseal
    case afterExecutableUnlink
    case afterChildFsync
}

package enum EngineRuntimeExecutableRemovalValidatorV1 {
    package typealias SignatureInspector =
        @Sendable (String) throws
            -> EngineRuntimeSigningIdentitySnapshotV1

    package static func capture(
        parentDescriptor: Int32,
        authorityName: String,
        inspectSignature: SignatureInspector
    ) throws -> EngineRuntimeExecutableRemovalSnapshotV1 {
        guard let expectedHash = authorityHash(authorityName) else {
            throw EngineRuntimeAuthorityErrorV1.invalidDirectory
        }
        var parentInfo = stat()
        guard Darwin.fstat(parentDescriptor, &parentInfo) == 0,
              parentInfo.st_mode & S_IFMT == S_IFDIR,
              parentInfo.st_uid == getuid()
        else {
            throw EngineRuntimeAuthorityErrorV1.processDrift
        }
        let directoryDescriptor = authorityName.withCString {
            Darwin.openat(
                parentDescriptor,
                $0,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard directoryDescriptor >= 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        var executableDescriptor: Int32 = -1
        do {
            var directoryInfo = stat()
            guard Darwin.fstat(directoryDescriptor, &directoryInfo) == 0,
                  directoryInfo.st_mode & S_IFMT == S_IFDIR,
                  directoryInfo.st_uid == getuid(),
                  directoryInfo.st_mode & mode_t(0o777) == mode_t(0o500),
                  try names(in: directoryDescriptor) == ["executable"]
            else {
                throw EngineRuntimeAuthorityErrorV1.invalidDirectory
            }
            executableDescriptor = "executable".withCString {
                Darwin.openat(
                    directoryDescriptor,
                    $0,
                    O_RDONLY | O_CLOEXEC | O_NOFOLLOW
                )
            }
            guard executableDescriptor >= 0 else {
                throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
            }
            let executablePath = try path(
                parentDescriptor: parentDescriptor,
                authorityName: authorityName
            )
            let file = try fileIdentity(
                descriptor: executableDescriptor,
                path: executablePath
            )
            guard file.hash == expectedHash else {
                throw EngineRuntimeAuthorityErrorV1.invalidDirectory
            }
            let signing = try inspectSignature(executablePath)
            let snapshot = EngineRuntimeExecutableRemovalSnapshotV1(
                authorityName: authorityName,
                parentDevice: UInt64(parentInfo.st_dev),
                parentInode: UInt64(parentInfo.st_ino),
                parentUID: UInt32(parentInfo.st_uid),
                directoryDevice: UInt64(directoryInfo.st_dev),
                directoryInode: UInt64(directoryInfo.st_ino),
                directoryUID: UInt32(directoryInfo.st_uid),
                directoryMode: UInt16(
                    directoryInfo.st_mode & mode_t(0o777)
                ),
                directoryLinkCount: UInt64(directoryInfo.st_nlink),
                executablePath: executablePath,
                executableDevice: file.device,
                executableInode: file.inode,
                executableUID: file.uid,
                executableMode: file.mode,
                executableLinkCount: file.linkCount,
                executableHash: file.hash,
                signing: signing
            )
            try closeOwned(&executableDescriptor)
            var ownedDirectory = directoryDescriptor
            try closeOwned(&ownedDirectory)
            return snapshot
        } catch {
            let primary = error
            var ownedDirectory = directoryDescriptor
            let cleanupFailures = EngineRuntimeCleanupV1.runAll([
                { try closeOwned(&executableDescriptor) },
                { try closeOwned(&ownedDirectory) },
            ])
            guard !cleanupFailures.isEmpty else { throw primary }
            throw EngineRuntimeCleanupAggregateErrorV1(
                primary: primary,
                cleanupFailures: cleanupFailures
            )
        }
    }

    package static func validateImmediatelyBeforeUnseal(
        _ expected: EngineRuntimeExecutableRemovalSnapshotV1,
        parentDescriptor: Int32,
        inspectSignature: SignatureInspector
    ) throws {
        let current = try capture(
            parentDescriptor: parentDescriptor,
            authorityName: expected.authorityName,
            inspectSignature: inspectSignature
        )
        guard current == expected else {
            throw EngineRuntimeAuthorityErrorV1.processDrift
        }
    }

    package static func removeImmediately(
        _ expected: EngineRuntimeExecutableRemovalSnapshotV1,
        parentDescriptor: Int32,
        inspectSignature: SignatureInspector,
        checkpoint: (EngineRuntimeExecutableRemovalCheckpointV1) throws
            -> Void = { _ in }
    ) throws {
        try validateParentIdentity(
            expected,
            parentDescriptor: parentDescriptor
        )
        var child = expected.authorityName.withCString {
            Darwin.openat(
                parentDescriptor,
                $0,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        let openFailure = errno
        if child < 0, openFailure == ENOENT {
            guard Darwin.fsync(parentDescriptor) == 0 else {
                throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
            }
            return
        }
        guard child >= 0 else {
            throw EngineRuntimeAuthorityErrorV1
                .descriptorFailure(openFailure)
        }
        var unsealed = false
        var executableUnlinked = false
        do {
            var directoryInfo = stat()
            guard Darwin.fstat(child, &directoryInfo) == 0,
                  directoryInfo.st_mode & S_IFMT == S_IFDIR,
                  UInt64(directoryInfo.st_dev) == expected.directoryDevice,
                  UInt64(directoryInfo.st_ino) == expected.directoryInode,
                  UInt32(directoryInfo.st_uid) == expected.directoryUID
            else {
                throw EngineRuntimeAuthorityErrorV1.processDrift
            }
            let mode = directoryInfo.st_mode & mode_t(0o777)
            let entries = try names(in: child)
            if entries == ["executable"] {
                guard UInt64(directoryInfo.st_nlink)
                        == expected.directoryLinkCount,
                      mode == mode_t(0o500) || mode == mode_t(0o700)
                else {
                    throw EngineRuntimeAuthorityErrorV1.processDrift
                }
                if mode == mode_t(0o500) {
                    try validateImmediatelyBeforeUnseal(
                        expected,
                        parentDescriptor: parentDescriptor,
                        inspectSignature: inspectSignature
                    )
                    guard Darwin.fchmod(child, mode_t(0o700)) == 0 else {
                        throw EngineRuntimeAuthorityErrorV1
                            .cleanupFailure(errno)
                    }
                }
                unsealed = true
                try checkpoint(.afterUnseal)
                try validateExecutableImmediatelyBeforeUnlink(
                    expected,
                    childDescriptor: child,
                    inspectSignature: inspectSignature
                )
                guard "executable".withCString({
                    Darwin.unlinkat(child, $0, 0)
                }) == 0 else {
                    throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
                }
                executableUnlinked = true
                try checkpoint(.afterExecutableUnlink)
                guard Darwin.fsync(child) == 0 else {
                    throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
                }
                try checkpoint(.afterChildFsync)
            } else {
                // APFS decrements a directory's link count when its only
                // regular-file entry is unlinked. A retry after the checked
                // unlink or child-fsync checkpoints must accept exactly that
                // controlled tombstone state, while an intact authority still
                // requires the captured count above.
                let currentLinkCount = UInt64(directoryInfo.st_nlink)
                let matchesCapturedCount =
                    currentLinkCount == expected.directoryLinkCount
                let matchesUnlinkedExecutableCount =
                    expected.directoryLinkCount > 0
                    && currentLinkCount == expected.directoryLinkCount - 1
                guard entries.isEmpty,
                      mode == mode_t(0o700),
                      matchesCapturedCount || matchesUnlinkedExecutableCount
                else {
                    throw EngineRuntimeAuthorityErrorV1.processDrift
                }
                executableUnlinked = true
                guard Darwin.fsync(child) == 0 else {
                    throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
                }
            }
            try EngineRuntimeOwnedDescriptorV1.closeOnce(&child)
            try validateParentIdentity(
                expected,
                parentDescriptor: parentDescriptor
            )
            guard expected.authorityName.withCString({
                      Darwin.unlinkat(parentDescriptor, $0, AT_REMOVEDIR)
                  }) == 0,
                  Darwin.fsync(parentDescriptor) == 0
            else {
                throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
            }
        } catch {
            let primary = error
            var cleanup: [() throws -> Void] = []
            if child >= 0, unsealed, !executableUnlinked {
                cleanup.append {
                    guard Darwin.fchmod(child, mode_t(0o500)) == 0 else {
                        throw EngineRuntimeAuthorityErrorV1
                            .cleanupFailure(errno)
                    }
                }
            }
            cleanup.append {
                try EngineRuntimeOwnedDescriptorV1.closeOnce(&child)
            }
            try EngineRuntimeCleanupV1.throwPreserving(
                primary,
                cleanup: cleanup
            )
        }
    }

    private static func validateParentIdentity(
        _ expected: EngineRuntimeExecutableRemovalSnapshotV1,
        parentDescriptor: Int32
    ) throws {
        var parentInfo = stat()
        guard Darwin.fstat(parentDescriptor, &parentInfo) == 0,
              parentInfo.st_mode & S_IFMT == S_IFDIR,
              UInt32(parentInfo.st_uid) == expected.parentUID,
              UInt64(parentInfo.st_dev) == expected.parentDevice,
              UInt64(parentInfo.st_ino) == expected.parentInode
        else {
            throw EngineRuntimeAuthorityErrorV1.processDrift
        }
    }

    private static func validateExecutableImmediatelyBeforeUnlink(
        _ expected: EngineRuntimeExecutableRemovalSnapshotV1,
        childDescriptor: Int32,
        inspectSignature: SignatureInspector
    ) throws {
        var descriptor = "executable".withCString {
            Darwin.openat(
                childDescriptor,
                $0,
                O_RDONLY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard descriptor >= 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        do {
            let file = try fileIdentity(
                descriptor: descriptor,
                path: expected.executablePath
            )
            let signing = try inspectSignature(expected.executablePath)
            guard file.device == expected.executableDevice,
                  file.inode == expected.executableInode,
                  file.uid == expected.executableUID,
                  file.mode == expected.executableMode,
                  file.linkCount == expected.executableLinkCount,
                  file.hash == expected.executableHash,
                  signing == expected.signing
            else {
                throw EngineRuntimeAuthorityErrorV1.processDrift
            }
            try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
        } catch {
            try EngineRuntimeCleanupV1.throwPreserving(
                error,
                cleanup: [{
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
                }]
            )
        }
    }

    private static func authorityHash(_ name: String) -> String? {
        let prefixes = ["cli_codex-", "cli_claude-", "board-bridge-"]
        guard let prefix = prefixes.first(where: { name.hasPrefix($0) }) else {
            return nil
        }
        let value = String(name.dropFirst(prefix.count))
        guard value.utf8.count == 64,
              value.utf8.allSatisfy({ byte in
                  (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                      || (UInt8(ascii: "a")...UInt8(ascii: "f"))
                          .contains(byte)
              })
        else { return nil }
        return value
    }

    private static func path(
        parentDescriptor: Int32,
        authorityName: String
    ) throws -> String {
        var bytes = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard Darwin.fcntl(parentDescriptor, F_GETPATH, &bytes) == 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        let parentPath = String(
            decoding: bytes.prefix { $0 != 0 }
                .map { UInt8(bitPattern: $0) },
            as: UTF8.self
        )
        let value = URL(fileURLWithPath: parentPath, isDirectory: true)
            .appendingPathComponent(authorityName, isDirectory: true)
            .appendingPathComponent("executable")
            .path
        guard value.hasPrefix("/"),
              URL(fileURLWithPath: value).standardizedFileURL.path == value
        else {
            throw EngineRuntimeAuthorityErrorV1.invalidDirectory
        }
        return value
    }

    private static func fileIdentity(
        descriptor: Int32,
        path: String
    ) throws -> EngineRuntimeFileIdentityV1 {
        var before = stat()
        guard Darwin.fstat(descriptor, &before) == 0,
              before.st_mode & S_IFMT == S_IFREG,
              before.st_uid == getuid(),
              before.st_nlink == 1,
              before.st_mode & mode_t(0o777) == mode_t(0o500)
        else {
            throw EngineRuntimeAuthorityErrorV1.processDrift
        }
        guard Darwin.lseek(descriptor, 0, SEEK_SET) == 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        var hasher = SHA256()
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
        while true {
            let amount = buffer.withUnsafeMutableBytes {
                Darwin.read(descriptor, $0.baseAddress, $0.count)
            }
            if amount > 0 {
                hasher.update(data: Data(buffer[0..<amount]))
                continue
            }
            if amount == 0 { break }
            if errno == EINTR { continue }
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        var after = stat()
        guard Darwin.fstat(descriptor, &after) == 0,
              sameStableEntry(before, after)
        else {
            throw EngineRuntimeAuthorityErrorV1.processDrift
        }
        return EngineRuntimeFileIdentityV1(
            path: path,
            device: UInt64(after.st_dev),
            inode: UInt64(after.st_ino),
            uid: UInt32(after.st_uid),
            mode: UInt16(after.st_mode & mode_t(0o777)),
            linkCount: UInt64(after.st_nlink),
            hash: hasher.finalize().map {
                String(format: "%02x", $0)
            }.joined()
        )
    }

    private static func sameStableEntry(_ lhs: stat, _ rhs: stat) -> Bool {
        lhs.st_dev == rhs.st_dev
            && lhs.st_ino == rhs.st_ino
            && lhs.st_mode == rhs.st_mode
            && lhs.st_uid == rhs.st_uid
            && lhs.st_nlink == rhs.st_nlink
            && lhs.st_size == rhs.st_size
            && lhs.st_mtimespec.tv_sec == rhs.st_mtimespec.tv_sec
            && lhs.st_mtimespec.tv_nsec == rhs.st_mtimespec.tv_nsec
    }

    private static func names(in descriptor: Int32) throws -> [String] {
        var duplicate = Darwin.fcntl(descriptor, F_DUPFD_CLOEXEC, 0)
        guard duplicate >= 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        guard let directory = fdopendir(duplicate) else {
            let failure = errno
            try EngineRuntimeCleanupV1.throwPreserving(
                EngineRuntimeAuthorityErrorV1.descriptorFailure(failure),
                cleanup: [{
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(&duplicate)
                }]
            )
        }
        duplicate = -1
        var values: [String] = []
        errno = 0
        while let entry = Darwin.readdir(directory) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String(cString: $0)
                }
            }
            if name != "." && name != ".." { values.append(name) }
            errno = 0
        }
        let readFailure = errno
        guard Darwin.closedir(directory) == 0 else {
            throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
        }
        guard readFailure == 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(
                readFailure
            )
        }
        return values.sorted()
    }

    private static func closeOwned(_ descriptor: inout Int32) throws {
        try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
    }
}

package enum EnginePackagedBridgeSignatureModeV1:
    Sendable, Equatable
{
    case developerID
    case adHocPreview
}

package struct EnginePackagedCodeSignatureFactsV1:
    Sendable, Equatable
{
    package let identifier: String
    package let cdHash: String
    package let teamIdentifier: String?
    package let designatedRequirement: String
    package let trustedDeveloperID: Bool
    package let hardenedRuntime: Bool
    package let secureTimestamp: Bool
    package let adHoc: Bool
    package let previewInvocation: String?

    package init(
        identifier: String,
        cdHash: String,
        teamIdentifier: String?,
        designatedRequirement: String,
        trustedDeveloperID: Bool,
        hardenedRuntime: Bool,
        secureTimestamp: Bool,
        adHoc: Bool,
        previewInvocation: String?
    ) {
        self.identifier = identifier
        self.cdHash = cdHash
        self.teamIdentifier = teamIdentifier
        self.designatedRequirement = designatedRequirement
        self.trustedDeveloperID = trustedDeveloperID
        self.hardenedRuntime = hardenedRuntime
        self.secureTimestamp = secureTimestamp
        self.adHoc = adHoc
        self.previewInvocation = previewInvocation
    }
}

package struct EnginePackagedBridgePackageFactsV1:
    Sendable, Equatable
{
    package let containingAppPath: String
    package let helperPath: String
    package let nestedCodeSealed: Bool
    package let sealedHelperIdentifier: String
    package let sealedHelperCDHash: String
    package let appSignature: EnginePackagedCodeSignatureFactsV1
    package let helperSignature: EnginePackagedCodeSignatureFactsV1

    package init(
        containingAppPath: String,
        helperPath: String,
        nestedCodeSealed: Bool,
        sealedHelperIdentifier: String,
        sealedHelperCDHash: String,
        appSignature: EnginePackagedCodeSignatureFactsV1,
        helperSignature: EnginePackagedCodeSignatureFactsV1
    ) {
        self.containingAppPath = containingAppPath
        self.helperPath = helperPath
        self.nestedCodeSealed = nestedCodeSealed
        self.sealedHelperIdentifier = sealedHelperIdentifier
        self.sealedHelperCDHash = sealedHelperCDHash
        self.appSignature = appSignature
        self.helperSignature = helperSignature
    }
}

package struct EnginePackagedBridgePackageIdentityV1:
    Sendable, Equatable
{
    package let mode: EnginePackagedBridgeSignatureModeV1
    package let appCDHash: String
    package let helperCDHash: String
    package let teamIdentifier: String?
    package let previewInvocation: String?
}

package enum EnginePackagedBridgeAuthenticityValidatorV1 {
    private static let appIdentifier = "com.muzi.agentloop"
    private static let helperIdentifier =
        "com.muzi.agentloop.board-bridge"

    package static func validate(
        _ facts: EnginePackagedBridgePackageFactsV1
    ) throws -> EnginePackagedBridgePackageIdentityV1 {
        let appURL = URL(fileURLWithPath: facts.containingAppPath)
        let helperURL = URL(fileURLWithPath: facts.helperPath)
        guard facts.containingAppPath.hasPrefix("/"),
              appURL.standardizedFileURL.path == facts.containingAppPath,
              appURL.pathExtension == "app",
              facts.helperPath
                == appURL.appendingPathComponent(
                    "Contents/Helpers/AgentLoopBoardBridge"
                ).path,
              helperURL.standardizedFileURL.path == facts.helperPath,
              facts.nestedCodeSealed,
              facts.sealedHelperIdentifier == helperIdentifier,
              facts.appSignature.identifier == appIdentifier,
              facts.helperSignature.identifier == helperIdentifier,
              facts.sealedHelperCDHash
                == facts.helperSignature.cdHash,
              isLowercaseCDHash(facts.appSignature.cdHash),
              isLowercaseCDHash(facts.helperSignature.cdHash)
        else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }

        let app = facts.appSignature
        let helper = facts.helperSignature
        if !app.adHoc && !helper.adHoc {
            guard app.trustedDeveloperID,
                  helper.trustedDeveloperID,
                  app.hardenedRuntime,
                  helper.hardenedRuntime,
                  app.secureTimestamp,
                  helper.secureTimestamp,
                  app.previewInvocation == nil,
                  helper.previewInvocation == nil,
                  let appTeam = app.teamIdentifier,
                  !appTeam.isEmpty,
                  helper.teamIdentifier == appTeam,
                  hasAppleGenericAnchor(app.designatedRequirement),
                  hasAppleGenericAnchor(helper.designatedRequirement)
            else {
                throw EngineRuntimeAuthorityErrorV1.managedPolicy
            }
            return EnginePackagedBridgePackageIdentityV1(
                mode: .developerID,
                appCDHash: app.cdHash,
                helperCDHash: helper.cdHash,
                teamIdentifier: appTeam,
                previewInvocation: nil
            )
        }

        guard app.adHoc,
              helper.adHoc,
              !app.trustedDeveloperID,
              !helper.trustedDeveloperID,
              app.teamIdentifier == nil,
              helper.teamIdentifier == nil,
              !app.hardenedRuntime,
              !helper.hardenedRuntime,
              !app.secureTimestamp,
              !helper.secureTimestamp,
              app.previewInvocation == nil,
              helper.previewInvocation == nil
        else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }
        return EnginePackagedBridgePackageIdentityV1(
            mode: .adHocPreview,
            appCDHash: app.cdHash,
            helperCDHash: helper.cdHash,
            teamIdentifier: nil,
            previewInvocation: nil
        )
    }

    private static func isLowercaseCDHash(_ value: String) -> Bool {
        value.utf8.count == 40
            && value.utf8.allSatisfy { byte in
                (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                    || (UInt8(ascii: "a")...UInt8(ascii: "f"))
                        .contains(byte)
            }
    }

    private static func hasAppleGenericAnchor(_ value: String) -> Bool {
        value.split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .contains("anchor apple generic")
    }
}

package enum EnginePackagedBridgeAuthenticityReaderV1 {
    private static let helperRelativePath =
        "Contents/Helpers/AgentLoopBoardBridge"
    private static let sealedHelperRelativePath =
        "Helpers/AgentLoopBoardBridge"

    package static func validate(
        helperSourcePath: String
    ) throws -> EnginePackagedBridgePackageIdentityV1 {
        try validate(
            helperSourcePath: helperSourcePath,
            readPackageFacts: { appPath, helperPath in
                let appURL = URL(fileURLWithPath: appPath)
                let helperURL = URL(fileURLWithPath: helperPath)
                let appCode = try staticCode(appURL)
                let helperCode = try staticCode(helperURL)
                let nestedFlags = SecCSFlags(
                    rawValue: kSecCSStrictValidate
                        | kSecCSCheckAllArchitectures
                        | kSecCSCheckNestedCode
                )
                guard SecStaticCodeCheckValidity(
                    appCode,
                    nestedFlags,
                    nil
                ) == errSecSuccess else {
                    throw EngineRuntimeAuthorityErrorV1.managedPolicy
                }
                let appSignature = try signature(appCode)
                let helperSignature = try signature(helperCode)
                let sealed = try sealedHelperRecord(
                    appURL: appURL,
                    helperSignature: helperSignature
                )
                return EnginePackagedBridgePackageFactsV1(
                    containingAppPath: appPath,
                    helperPath: helperPath,
                    nestedCodeSealed: sealed.matches,
                    sealedHelperIdentifier: sealed.identifier,
                    sealedHelperCDHash: sealed.cdHash,
                    appSignature: appSignature,
                    helperSignature: helperSignature
                )
            }
        )
    }

    package static func validate(
        helperSourcePath: String,
        readPackageFacts: (String, String) throws
            -> EnginePackagedBridgePackageFactsV1
    ) throws -> EnginePackagedBridgePackageIdentityV1 {
        let helperURL = URL(fileURLWithPath: helperSourcePath)
        let appURL = helperURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        guard helperSourcePath.hasPrefix("/"),
              helperURL.standardizedFileURL.path == helperSourcePath,
              helperSourcePath
                == appURL.appendingPathComponent(helperRelativePath).path,
              appURL.pathExtension == "app"
        else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }
        let facts = try readPackageFacts(appURL.path, helperURL.path)
        guard facts.containingAppPath == appURL.path,
              facts.helperPath == helperURL.path
        else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }
        return try EnginePackagedBridgeAuthenticityValidatorV1.validate(
            facts
        )
    }

    private static func staticCode(_ url: URL) throws -> SecStaticCode {
        var value: SecStaticCode?
        guard SecStaticCodeCreateWithPath(
            url as CFURL,
            SecCSFlags(),
            &value
        ) == errSecSuccess,
              let value
        else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }
        return value
    }

    private static func signature(
        _ code: SecStaticCode
    ) throws -> EnginePackagedCodeSignatureFactsV1 {
        let strictFlags = SecCSFlags(
            rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures
        )
        guard SecStaticCodeCheckValidity(code, strictFlags, nil)
                == errSecSuccess
        else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information
        ) == errSecSuccess,
              let dictionary = information as NSDictionary?,
              let identifier = dictionary[kSecCodeInfoIdentifier]
                as? String,
              let cdHashData = dictionary[kSecCodeInfoUnique] as? Data,
              cdHashData.count == 20,
              let flags = dictionary[kSecCodeInfoFlags] as? NSNumber
        else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }
        var requirement: SecRequirement?
        var requirementText: CFString?
        guard SecCodeCopyDesignatedRequirement(
            code,
            SecCSFlags(),
            &requirement
        ) == errSecSuccess,
              let requirement,
              SecRequirementCopyString(
                requirement,
                SecCSFlags(),
                &requirementText
              ) == errSecSuccess,
              let requirementText
        else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }
        let rawFlags = flags.uint32Value
        let adHoc = rawFlags & 0x0002 != 0
        let hardenedRuntime = rawFlags & 0x0001_0000 != 0
        return EnginePackagedCodeSignatureFactsV1(
            identifier: identifier,
            cdHash: cdHashData.map {
                String(format: "%02x", $0)
            }.joined(),
            teamIdentifier:
                dictionary[kSecCodeInfoTeamIdentifier] as? String,
            designatedRequirement: (requirementText as String)
                .split(whereSeparator: { $0.isWhitespace })
                .joined(separator: " "),
            trustedDeveloperID: !adHoc && isTrustedDeveloperID(code),
            hardenedRuntime: hardenedRuntime,
            secureTimestamp: dictionary[kSecCodeInfoTimestamp] as? Date
                != nil,
            adHoc: adHoc,
            previewInvocation: nil
        )
    }

    private static func isTrustedDeveloperID(
        _ code: SecStaticCode
    ) -> Bool {
        var requirement: SecRequirement?
        let text = "anchor apple generic and certificate "
            + "leaf[field.1.2.840.113635.100.6.1.13] exists"
        guard SecRequirementCreateWithString(
            text as CFString,
            SecCSFlags(),
            &requirement
        ) == errSecSuccess,
              let requirement
        else { return false }
        let kSecCSCheckTrustedAnchors: UInt32 = 1 << 27
        let flags = SecCSFlags(
            rawValue: kSecCSStrictValidate
                | kSecCSCheckAllArchitectures
                | kSecCSCheckTrustedAnchors
        )
        return SecStaticCodeCheckValidity(code, flags, requirement)
            == errSecSuccess
    }

    private static func sealedHelperRecord(
        appURL: URL,
        helperSignature: EnginePackagedCodeSignatureFactsV1
    ) throws -> (matches: Bool, identifier: String, cdHash: String) {
        let resourcesURL = appURL.appendingPathComponent(
            "Contents/_CodeSignature/CodeResources"
        )
        let bytes = try readNoFollow(resourcesURL)
        let plist = try PropertyListSerialization.propertyList(
            from: bytes,
            options: [],
            format: nil
        )
        guard let root = plist as? [String: Any],
              let files = root["files2"] as? [String: Any],
              let nested = files[sealedHelperRelativePath] as? [String: Any],
              let sealedCDHash = nested["cdhash"] as? Data,
              sealedCDHash.count == 20,
              let sealedRequirement = nested["requirement"] as? String
        else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }
        let cdHash = sealedCDHash.map {
            String(format: "%02x", $0)
        }.joined()
        let normalized = sealedRequirement
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        let expectedAdHocRequirement =
            "cdhash H\"\(helperSignature.cdHash)\""
        let requirementMatches = helperSignature.adHoc
            ? normalized == expectedAdHocRequirement
            : normalized.contains(
                "identifier \"com.muzi.agentloop.board-bridge\""
            )
        return (
            matches: requirementMatches
                && cdHash == helperSignature.cdHash,
            identifier: "com.muzi.agentloop.board-bridge",
            cdHash: cdHash
        )
    }

    private static func readNoFollow(_ url: URL) throws -> Data {
        var descriptor = url.path.withCString {
            Darwin.open($0, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard descriptor >= 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        do {
            var before = stat()
            guard Darwin.fstat(descriptor, &before) == 0,
                  before.st_mode & S_IFMT == S_IFREG,
                  before.st_size > 0,
                  before.st_size <= 4 * 1_024 * 1_024
            else {
                throw EngineRuntimeAuthorityErrorV1.managedPolicy
            }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
            while true {
                let count = buffer.withUnsafeMutableBytes {
                    Darwin.read(descriptor, $0.baseAddress, $0.count)
                }
                if count > 0 {
                    data.append(contentsOf: buffer[0..<count])
                    continue
                }
                if count == 0 { break }
                if errno == EINTR { continue }
                throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
            }
            var after = stat()
            guard Darwin.fstat(descriptor, &after) == 0,
                  before.st_dev == after.st_dev,
                  before.st_ino == after.st_ino,
                  before.st_mode == after.st_mode,
                  before.st_uid == after.st_uid,
                  before.st_nlink == after.st_nlink,
                  before.st_size == after.st_size,
                  before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
                  before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec
            else {
                throw EngineRuntimeAuthorityErrorV1.processDrift
            }
            try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
            return data
        } catch {
            let primary = error
            try EngineRuntimeCleanupV1.throwPreserving(
                primary,
                cleanup: [{
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
                }]
            )
        }
    }
}

package enum EngineDarwinProcessCensusV1 {
    package static func enumerate(
        initialCapacity: Int = 64,
        page: (Int) throws -> [Int32]
    ) throws -> [Int32] {
        guard initialCapacity > 0 else {
            throw EngineRuntimeAuthorityErrorV1.processSnapshot
        }
        var capacity = initialCapacity
        while true {
            let values = try page(capacity)
            guard values.count <= capacity else {
                throw EngineRuntimeAuthorityErrorV1.processSnapshot
            }
            if values.count < capacity { return values }
            let (grown, overflow) = capacity.multipliedReportingOverflow(by: 2)
            guard !overflow,
                  grown > capacity,
                  grown <= Int(Int32.max) / MemoryLayout<pid_t>.stride
            else {
                throw EngineRuntimeAuthorityErrorV1.processSnapshot
            }
            capacity = grown
        }
    }
}

package struct DarwinEngineRuntimeProcessInspectorV1:
    EngineRuntimeProcessInspectingV1, Sendable
{
    private struct CensusEntry {
        let pid: pid_t
        let processGroupId: Int32
        let uid: UInt32
        let startSeconds: UInt64
        let startMicroseconds: UInt32
    }

    package init() {}

    package func snapshots() throws
        -> [EngineRuntimeProcessSnapshotV1]
    {
        let requested = max(Int(proc_listallpids(nil, 0)), 64)
        let pids = try EngineDarwinProcessCensusV1.enumerate(
            initialCapacity: requested + 64
        ) { capacity in
            var page = [pid_t](repeating: 0, count: capacity)
            let count = page.withUnsafeMutableBytes {
                proc_listallpids(
                    $0.baseAddress,
                    Int32($0.count)
                )
            }
            guard count >= 0, Int(count) <= capacity else {
                throw EngineRuntimeAuthorityErrorV1.processSnapshot
            }
            return Array(page.prefix(Int(count)))
        }
        var census: [CensusEntry] = []
        census.reserveCapacity(pids.count)
        for pid in pids where pid > 0 {
            var info = proc_bsdinfo()
            let infoSize = Int32(MemoryLayout.size(ofValue: info))
            let readInfo = withUnsafeMutablePointer(to: &info) {
                proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, $0, infoSize)
            }
            if readInfo <= 0 {
                if errno == ESRCH { continue }
                // A member whose UID/PGID cannot be enumerated makes the
                // complete census unusable. Callers therefore signal nobody.
                throw EngineRuntimeAuthorityErrorV1.processSnapshot
            }
            census.append(
                CensusEntry(
                    pid: pid,
                    processGroupId: Int32(info.pbi_pgid),
                    uid: UInt32(info.pbi_uid),
                    startSeconds: UInt64(info.pbi_start_tvsec),
                    startMicroseconds: UInt32(info.pbi_start_tvusec)
                )
            )
        }

        // Do not perform path/hash/signature work until the UID/PGID census
        // for every inspectable process has completed successfully.
        var result: [EngineRuntimeProcessSnapshotV1] = []
        result.reserveCapacity(census.count)
        for entry in census {
            if entry.uid != UInt32(getuid()) {
                result.append(
                    EngineRuntimeProcessSnapshotV1(
                        pid: Int32(entry.pid),
                        processGroupId: entry.processGroupId,
                        uid: entry.uid,
                        startSeconds: entry.startSeconds,
                        startMicroseconds: entry.startMicroseconds,
                        executablePath: "",
                        executableDevice: 0,
                        executableInode: 0,
                        executableHash: "",
                        designatedRequirement: "",
                        cdHash: ""
                    )
                )
            } else if let snapshot = try snapshot(entry) {
                result.append(snapshot)
            }
        }
        return result.sorted { $0.pid < $1.pid }
    }

    package func send(
        signal: Int32,
        processGroupId: Int32
    ) throws {
        guard processGroupId > 1 else {
            throw EngineRuntimeAuthorityErrorV1.processSignal(EINVAL)
        }
        guard Darwin.kill(-processGroupId, signal) == 0 else {
            throw EngineRuntimeAuthorityErrorV1.processSignal(errno)
        }
    }

    package func processGroupExists(
        _ processGroupId: Int32
    ) throws -> Bool {
        guard processGroupId > 1 else {
            throw EngineRuntimeAuthorityErrorV1.processSignal(EINVAL)
        }
        if Darwin.kill(-processGroupId, 0) == 0 { return true }
        let failure = errno
        if failure == ESRCH { return false }
        throw EngineRuntimeAuthorityErrorV1.processSignal(failure)
    }

    private func snapshot(
        _ entry: CensusEntry
    ) throws -> EngineRuntimeProcessSnapshotV1? {
        var pathBytes = [CChar](
            repeating: 0,
            count: Int(MAXPATHLEN) * 4
        )
        let pathCount = pathBytes.withUnsafeMutableBytes {
            proc_pidpath(entry.pid, $0.baseAddress, UInt32($0.count))
        }
        if pathCount <= 0 {
            if errno == ESRCH { return nil }
            throw EngineRuntimeAuthorityErrorV1.processSnapshot
        }
        let path = String(
            decoding: pathBytes.prefix { $0 != 0 }
                .map { UInt8(bitPattern: $0) },
            as: UTF8.self
        )
        let file = try EngineRuntimeIdentityReaderV1.file(
            path: path,
            requireExecutable: true
        )
        let signing = try EngineRuntimeIdentityReaderV1.signing(path: path)
        return EngineRuntimeProcessSnapshotV1(
            pid: Int32(entry.pid),
            processGroupId: entry.processGroupId,
            uid: entry.uid,
            startSeconds: entry.startSeconds,
            startMicroseconds: entry.startMicroseconds,
            executablePath: path,
            executableDevice: file.device,
            executableInode: file.inode,
            executableHash: file.hash,
            designatedRequirement: signing.designatedRequirement,
            cdHash: signing.cdHash
        )
    }
}

package struct EngineOwnedRuntimeExecutableV1: Sendable, Equatable {
    package let executablePath: String
    package let executableDevice: UInt64
    package let executableInode: UInt64
    package let executableHash: String
    package let designatedRequirement: String
    package let cdHash: String

    package init(
        executablePath: String,
        executableDevice: UInt64,
        executableInode: UInt64,
        executableHash: String,
        designatedRequirement: String,
        cdHash: String
    ) {
        self.executablePath = executablePath
        self.executableDevice = executableDevice
        self.executableInode = executableInode
        self.executableHash = executableHash
        self.designatedRequirement = designatedRequirement
        self.cdHash = cdHash
    }

    fileprivate func matches(
        _ snapshot: EngineRuntimeProcessSnapshotV1
    ) -> Bool {
        snapshot.uid == UInt32(getuid())
            && snapshot.executablePath == executablePath
            && snapshot.executableDevice == executableDevice
            && snapshot.executableInode == executableInode
            && snapshot.executableHash == executableHash
            && snapshot.designatedRequirement == designatedRequirement
            && snapshot.cdHash == cdHash
    }
}

package struct EngineOldBootProcessCleanupV1: Sendable {
    private let processInspector: any EngineRuntimeProcessInspectingV1
    private let terminationGrace: Duration
    private let sleep: @Sendable (Duration) throws -> Void

    package init(
        processInspector: any EngineRuntimeProcessInspectingV1,
        terminationGrace: Duration = .seconds(5),
        sleep: @escaping @Sendable (Duration) throws -> Void = { duration in
            let components = duration.components
            var request = timespec(
                tv_sec: Int(components.seconds),
                tv_nsec: Int(components.attoseconds / 1_000_000_000)
            )
            while true {
                var remaining = timespec()
                if Darwin.nanosleep(&request, &remaining) == 0 { break }
                let failure = errno
                guard failure == EINTR else {
                    throw EngineRuntimeAuthorityErrorV1.descriptorFailure(
                        failure
                    )
                }
                request = remaining
            }
        }
    ) {
        self.processInspector = processInspector
        self.terminationGrace = terminationGrace
        self.sleep = sleep
    }

    package func terminateOwnedProcessGroups(
        authorities: [EngineOwnedRuntimeExecutableV1]
    ) throws {
        guard !authorities.isEmpty else { return }
        let initial = try processInspector.snapshots()
        let ownedProcessGroups = Dictionary(
            grouping: initial.filter { snapshot in
                authorities.contains { $0.matches(snapshot) }
            },
            by: \.processGroupId
        )
        for processGroupId in ownedProcessGroups.keys.sorted() {
            guard let expected = ownedProcessGroups[processGroupId] else {
                throw EngineRuntimeAuthorityErrorV1.processSnapshot
            }
            let frozen = try allCurrentUIDMembers(
                processGroupId: processGroupId,
                snapshots: initial,
                authorities: authorities,
                expectedOwned: expected
            )
            try processInspector.send(
                signal: SIGSTOP,
                processGroupId: processGroupId
            )
            let afterStop = try processInspector.snapshots()
            do {
                _ = try revalidateOwnedProcessGroup(
                    processGroupId: processGroupId,
                    expected: frozen,
                    snapshots: afterStop,
                    authorities: authorities
                )
            } catch {
                try resumeStillMatchingGroupAfterDrift(
                    processGroupId: processGroupId,
                    expected: frozen,
                    snapshots: afterStop
                )
                throw error
            }
            try terminateValidatedGroup(processGroupId)
        }
    }

    private func terminateValidatedGroup(
        _ processGroupId: Int32
    ) throws {
        var primary: (any Error)?
        var cleanupFailures: [any Error] = []
        do {
            try processInspector.send(
                signal: SIGTERM,
                processGroupId: processGroupId
            )
        } catch {
            primary = error
        }
        do {
            try processInspector.send(
                signal: SIGCONT,
                processGroupId: processGroupId
            )
        } catch {
            if primary == nil { primary = error }
            else { cleanupFailures.append(error) }
        }

        if primary == nil {
            do {
                if try waitForExactESRCH(processGroupId) { return }
            } catch {
                primary = error
            }
        }

        do {
            try processInspector.send(
                signal: SIGKILL,
                processGroupId: processGroupId
            )
        } catch {
            if primary == nil { primary = error }
            else { cleanupFailures.append(error) }
        }
        do {
            guard try waitForExactESRCH(processGroupId) else {
                throw EngineRuntimeAuthorityErrorV1.processGroupSurvived
            }
        } catch {
            if primary == nil { primary = error }
            else { cleanupFailures.append(error) }
        }
        if let primary {
            guard !cleanupFailures.isEmpty else { throw primary }
            throw EngineRuntimeCleanupAggregateErrorV1(
                primary: primary,
                cleanupFailures: cleanupFailures
            )
        }
    }

    private func allCurrentUIDMembers(
        processGroupId: Int32,
        snapshots: [EngineRuntimeProcessSnapshotV1],
        authorities: [EngineOwnedRuntimeExecutableV1],
        expectedOwned: [EngineRuntimeProcessSnapshotV1]
    ) throws -> [EngineRuntimeProcessSnapshotV1] {
        let members = snapshots.filter {
            $0.processGroupId == processGroupId
        }.sorted { $0.pid < $1.pid }
        guard processGroupId > 1,
              members.allSatisfy({ $0.uid == UInt32(getuid()) }),
              members.contains(where: {
                  $0.pid == processGroupId
              }),
              members.count == expectedOwned.count,
              members.allSatisfy({ snapshot in
                  authorities.contains { $0.matches(snapshot) }
              })
        else {
            throw EngineRuntimeAuthorityErrorV1.unknownMember
        }
        return members
    }

    private func revalidateOwnedProcessGroup(
        processGroupId: Int32,
        expected: [EngineRuntimeProcessSnapshotV1],
        snapshots: [EngineRuntimeProcessSnapshotV1],
        authorities: [EngineOwnedRuntimeExecutableV1]
    ) throws -> [EngineRuntimeProcessSnapshotV1] {
        let members = try allCurrentUIDMembers(
            processGroupId: processGroupId,
            snapshots: snapshots,
            authorities: authorities,
            expectedOwned: expected
        )
        guard members == expected else {
            throw EngineRuntimeAuthorityErrorV1.processDrift
        }
        return members
    }

    private func resumeStillMatchingGroupAfterDrift(
        processGroupId: Int32,
        expected: [EngineRuntimeProcessSnapshotV1],
        snapshots: [EngineRuntimeProcessSnapshotV1]
    ) throws {
        let stillMatching = snapshots.contains { current in
            current.processGroupId == processGroupId
                && expected.contains(current)
        }
        if stillMatching {
            try processInspector.send(
                signal: SIGCONT,
                processGroupId: processGroupId
            )
        }
    }

    private func waitForExactESRCH(
        _ processGroupId: Int32
    ) throws -> Bool {
        let deadline = ContinuousClock.now.advanced(by: terminationGrace)
        while ContinuousClock.now < deadline {
            if try !processInspector.processGroupExists(processGroupId) {
                // Live inspector returns false only for exact ESRCH.
                return true
            }
            try sleep(.milliseconds(10))
        }
        return try !processInspector.processGroupExists(processGroupId)
    }
}

package struct EngineRuntimeOwnerDocumentV1:
    Codable, Sendable, Equatable
{
    package let bootUUID: String
    package let stateRootIdentityHash: String

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case bootUUID
        case stateRootIdentityHash
    }

    package init(
        bootUUID: String,
        stateRootIdentityHash: String
    ) throws {
        guard let uuid = UUID(uuidString: bootUUID),
              uuid.uuidString == bootUUID,
              Self.isLowercaseSHA256(stateRootIdentityHash)
        else {
            throw EngineRuntimeAuthorityErrorV1.invalidOwner
        }
        self.bootUUID = bootUUID
        self.stateRootIdentityHash = stateRootIdentityHash
    }

    package static func decodeCanonical(
        _ bytes: Data
    ) throws -> EngineRuntimeOwnerDocumentV1 {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(
                with: bytes,
                options: []
            )
        } catch {
            throw EngineRuntimeAuthorityErrorV1.invalidOwner
        }
        guard let object = json as? [String: Any],
              Set(object.keys) == Set(CodingKeys.allCases.map(\.rawValue))
        else {
            throw EngineRuntimeAuthorityErrorV1.invalidOwner
        }
        let value: EngineRuntimeOwnerDocumentV1
        do {
            value = try CanonicalContractCodingV1.decode(
                EngineRuntimeOwnerDocumentV1.self,
                from: bytes
            )
        } catch {
            throw EngineRuntimeAuthorityErrorV1.invalidOwner
        }
        guard let uuid = UUID(uuidString: value.bootUUID),
              uuid.uuidString == value.bootUUID,
              isLowercaseSHA256(value.stateRootIdentityHash),
              try value.canonicalBytes() == bytes
        else {
            throw EngineRuntimeAuthorityErrorV1.invalidOwner
        }
        return value
    }

    package func canonicalBytes() throws -> Data {
        let bytes = try CanonicalJSONV1.encode(self)
        guard bytes.last != UInt8(ascii: "\n") else {
            throw EngineRuntimeAuthorityErrorV1.invalidOwner
        }
        return bytes
    }

    package func ownerIdentityHash() throws -> String {
        CanonicalJSONV1.sha256Hex(try canonicalBytes())
    }

    package func shortDirectoryName() throws -> String {
        let hash = try ownerIdentityHash()
        return "a-" + hash.prefix(12)
    }

    private static func isLowercaseSHA256(_ value: String) -> Bool {
        value.utf8.count == 64
            && value.utf8.allSatisfy { byte in
                (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                    || (UInt8(ascii: "a")...UInt8(ascii: "f"))
                        .contains(byte)
            }
    }
}

private struct EngineOldBootDirectorySnapshotV1 {
    let name: String
    let device: UInt64
    let inode: UInt64
}

package final class EngineRuntimeDirectoryAuthoritySetV1:
    @unchecked Sendable
{
    package let stateRootIdentity: EngineStateRootIdentityV1
    package let stateRootIdentityHash: String
    package let bootId: String
    package let longBootDirectory: URL
    package let claudeConfigDirectory: URL
    package let cliExecutableDirectory: URL
    package let boardSocketDirectoryAuthority:
        EngineBoardSocketDirectoryAuthorityV1

    private let stateLock = NSLock()
    private var retainedDescriptors: [Int32]
    private var closed = false
    private var currentResidueRemoved = false

    fileprivate init(
        stateRootIdentity: EngineStateRootIdentityV1,
        stateRootIdentityHash: String,
        bootId: String,
        longBootDirectory: URL,
        claudeConfigDirectory: URL,
        cliExecutableDirectory: URL,
        boardSocketDirectoryAuthority:
            EngineBoardSocketDirectoryAuthorityV1,
        retainedDescriptors: [Int32]
    ) {
        self.stateRootIdentity = stateRootIdentity
        self.stateRootIdentityHash = stateRootIdentityHash
        self.bootId = bootId
        self.longBootDirectory = longBootDirectory
        self.claudeConfigDirectory = claudeConfigDirectory
        self.cliExecutableDirectory = cliExecutableDirectory
        self.boardSocketDirectoryAuthority =
            boardSocketDirectoryAuthority
        self.retainedDescriptors = retainedDescriptors
    }

    package func close() throws {
        var descriptors = try stateLock.withLock { () throws -> [Int32] in
            guard !closed else {
                throw EngineRuntimeAuthorityErrorV1.authorityClosed
            }
            closed = true
            let values = retainedDescriptors
            retainedDescriptors = []
            return values
        }
        var failures: [any Error] = []
        for index in descriptors.indices.reversed() {
            do {
                try EngineRuntimeOwnedDescriptorV1.closeOnce(
                    &descriptors[index]
                )
            } catch {
                failures.append(error)
            }
        }
        try EngineRuntimeCleanupV1.throwCleanupFailures(failures)
    }

    fileprivate func removeCurrentBootResidue() throws {
        let descriptors = try stateLock.withLock { () throws -> [Int32] in
            guard !closed, !currentResidueRemoved,
                  retainedDescriptors.count == 6
            else {
                throw EngineRuntimeAuthorityErrorV1.authorityClosed
            }
            currentResidueRemoved = true
            return retainedDescriptors
        }
        try EngineRuntimeDirectoryBootstrapV1.removeCurrentBootResidue(
            authoritySet: self,
            engineRootDescriptor: descriptors[1],
            longBootDescriptor: descriptors[2],
            configDescriptor: descriptors[3],
            executableDescriptor: descriptors[4],
            shortRootDescriptor: descriptors[5]
        )
    }

    deinit {
        let descriptors = stateLock.withLock { () -> [Int32] in
            guard !closed else { return [] }
            closed = true
            let values = retainedDescriptors
            retainedDescriptors = []
            return values
        }
        for descriptor in descriptors.reversed() {
            _ = Darwin.close(descriptor)
        }
    }
}

package enum EngineRuntimeShortRootCollisionGateV1 {
    package static let maximumAttempts = 8

    package static func resolve<Value>(
        _ attempt: () throws -> Value
    ) throws -> Value {
        for _ in 0..<maximumAttempts {
            do {
                return try attempt()
            } catch let error as EngineRuntimeAuthorityErrorV1
                where error == .descriptorFailure(EEXIST)
            {
                continue
            }
        }
        throw EngineRuntimeAuthorityErrorV1.collisionExhausted
    }
}

package enum EngineRuntimeDirectoryBootstrapV1 {
    private static let directoryMode = mode_t(0o700)
    private static let ownerMode = mode_t(0o600)

    package static func prepareBeforeDatabase(
        stateDirectoryLock: StateDirectoryLock,
        processInspector: any EngineRuntimeProcessInspectingV1
    ) throws -> EngineRuntimeDirectoryAuthoritySetV1 {
        let stateIdentity = try EngineStateRootIdentityV1.capture(
            stateDirectoryLock: stateDirectoryLock
        )
        let stateHash = try stateIdentity.identityHash()
        var stateDescriptor = try stateDirectoryLock
            .duplicateLockedDirectoryDescriptor()
        do {
            try validateStateDescriptor(
                stateDescriptor,
                identity: stateIdentity
            )
        } catch {
            try EngineRuntimeCleanupV1.throwPreserving(
                error,
                cleanup: [{
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(
                        &stateDescriptor
                    )
                }]
            )
        }

        let engineRootDescriptor: Int32
        do {
            engineRootDescriptor = try openOrCreateDirectory(
                parent: stateDescriptor,
                name: "engine-runtime",
                mode: directoryMode
            )
        } catch {
            try EngineRuntimeCleanupV1.throwPreserving(
                error,
                cleanup: [{
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(
                        &stateDescriptor
                    )
                }]
            )
        }

        let shortRoot: (url: URL, descriptor: Int32)
        do {
            shortRoot = try openCanonicalDarwinUserTempDirectory()
        } catch {
            let primary = error
            var owned = [engineRootDescriptor, stateDescriptor]
            try throwPreservingAndClose(primary, descriptors: &owned)
        }

        do {
            let oldBoots = try validateOldBootShapes(
                engineRootDescriptor: engineRootDescriptor,
                stateIdentity: stateIdentity
            )
            let oldExecutableSnapshots = try oldOwnedExecutables(
                oldBoots: oldBoots,
                engineRootURL: URL(fileURLWithPath: stateIdentity.canonicalPath)
                    .appendingPathComponent("engine-runtime"),
                engineRootDescriptor: engineRootDescriptor
            )
            try EngineOldBootProcessCleanupV1(
                processInspector: processInspector
            ).terminateOwnedProcessGroups(
                authorities: oldExecutableSnapshots.map(\.processAuthority)
            )
            try sweepValidatedResidue(
                oldBoots: oldBoots,
                executableSnapshots: oldExecutableSnapshots,
                engineRootURL: URL(
                    fileURLWithPath: stateIdentity.canonicalPath
                ).appendingPathComponent("engine-runtime"),
                engineRootDescriptor: engineRootDescriptor
            )
            try sweepOwnedShortResidue(
                parentDescriptor: shortRoot.descriptor,
                stateRootIdentityHash: stateHash
            )

            return try EngineRuntimeShortRootCollisionGateV1.resolve {
                let bootId = UUID().uuidString
                let owner = try EngineRuntimeOwnerDocumentV1(
                    bootUUID: bootId,
                    stateRootIdentityHash: stateHash
                )
                let ownerBytes = try owner.canonicalBytes()
                let shortName = try owner.shortDirectoryName()
                let longBootDescriptor = try createDirectoryExclusive(
                    parent: engineRootDescriptor,
                    name: bootId,
                    mode: directoryMode
                )
                let cliConfigDescriptor: Int32
                let cliExecutableDescriptor: Int32
                do {
                    cliConfigDescriptor = try createDirectoryExclusive(
                        parent: longBootDescriptor,
                        name: "cli-config",
                        mode: directoryMode
                    )
                    cliExecutableDescriptor = try createDirectoryExclusive(
                        parent: longBootDescriptor,
                        name: "cli-executables",
                        mode: directoryMode
                    )
                } catch {
                    let primary = error
                    try removeEmptyLongBootCandidate(
                        name: bootId,
                        engineRootDescriptor: engineRootDescriptor,
                        longBootDescriptor: longBootDescriptor
                    )
                    throw primary
                }

                let shortDescriptor: Int32
                do {
                    shortDescriptor = try createDirectoryExclusive(
                        parent: shortRoot.descriptor,
                        name: String(shortName),
                        mode: directoryMode
                    )
                } catch let error as EngineRuntimeAuthorityErrorV1 {
                    var owned = [
                        cliExecutableDescriptor,
                        cliConfigDescriptor,
                    ]
                    let cleanupFailures = EngineRuntimeCleanupV1.runAll(
                        [
                            { try closeDescriptors(&owned) },
                            {
                                try removeEmptyLongBootCandidate(
                                    name: bootId,
                                    engineRootDescriptor:
                                        engineRootDescriptor,
                                    longBootDescriptor: longBootDescriptor
                                )
                            },
                        ]
                    )
                    if error == .descriptorFailure(EEXIST),
                       cleanupFailures.isEmpty { throw error }
                    guard !cleanupFailures.isEmpty else { throw error }
                    throw EngineRuntimeCleanupAggregateErrorV1(
                        primary: error,
                        cleanupFailures: cleanupFailures
                    )
                }

                do {
                    try writeOwner(
                        ownerBytes,
                        directoryDescriptor: shortDescriptor
                    )
                    var shortInfo = stat()
                    guard Darwin.fstat(shortDescriptor, &shortInfo) == 0 else {
                        throw EngineRuntimeAuthorityErrorV1
                            .descriptorFailure(errno)
                    }
                    let shortURL = shortRoot.url.appendingPathComponent(
                        String(shortName),
                        isDirectory: true
                    )
                    let socketAuthority = try
                        EngineBoardSocketDirectoryAuthorityV1(
                            directoryURL: shortURL,
                            ownedDescriptor: shortDescriptor,
                            device: UInt64(shortInfo.st_dev),
                            inode: UInt64(shortInfo.st_ino),
                            uid: UInt32(shortInfo.st_uid),
                            mode: UInt16(
                                shortInfo.st_mode & mode_t(0o777)
                            ),
                            ownerIdentityHash: stateHash,
                            bootId: bootId
                        )
                    let longURL = URL(
                        fileURLWithPath: stateIdentity.canonicalPath,
                        isDirectory: true
                    )
                        .appendingPathComponent(
                            "engine-runtime",
                            isDirectory: true
                        )
                        .appendingPathComponent(bootId, isDirectory: true)
                    let authoritySet = EngineRuntimeDirectoryAuthoritySetV1(
                        stateRootIdentity: stateIdentity,
                        stateRootIdentityHash: stateHash,
                        bootId: bootId,
                        longBootDirectory: longURL,
                        claudeConfigDirectory: longURL.appendingPathComponent(
                            "cli-config",
                            isDirectory: true
                        ),
                        cliExecutableDirectory: longURL.appendingPathComponent(
                            "cli-executables",
                            isDirectory: true
                        ),
                        boardSocketDirectoryAuthority: socketAuthority,
                        retainedDescriptors: [
                            stateDescriptor, engineRootDescriptor,
                            longBootDescriptor, cliConfigDescriptor,
                            cliExecutableDescriptor, shortRoot.descriptor,
                        ]
                    )
                    socketAuthority
                        .installRuntimeDirectoryAuthoritySet(authoritySet)
                    return authoritySet
                } catch {
                    let primary = error
                    var owned = [
                        cliExecutableDescriptor,
                        cliConfigDescriptor,
                    ]
                    let cleanupFailures = EngineRuntimeCleanupV1.runAll(
                        [
                            {
                                try removeFailedShortCandidate(
                                    name: String(shortName),
                                    descriptor: shortDescriptor,
                                    parentDescriptor: shortRoot.descriptor
                                )
                            },
                            { try closeDescriptors(&owned) },
                            {
                                try removeEmptyLongBootCandidate(
                                    name: bootId,
                                    engineRootDescriptor:
                                        engineRootDescriptor,
                                    longBootDescriptor: longBootDescriptor
                                )
                            },
                        ]
                    )
                    guard !cleanupFailures.isEmpty else { throw primary }
                    throw EngineRuntimeCleanupAggregateErrorV1(
                        primary: primary,
                        cleanupFailures: cleanupFailures
                    )
                }
            }
        } catch {
            let primary = error
            var owned = [
                shortRoot.descriptor,
                engineRootDescriptor,
                stateDescriptor,
            ]
            try throwPreservingAndClose(primary, descriptors: &owned)
        }
    }

    package static func makeSocketURL(
        directoryAuthority: EngineBoardSocketDirectoryAuthorityV1,
        executionId: String
    ) throws -> URL {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        } catch {
            throw EngineRuntimeAuthorityErrorV1.invalidOwner
        }
        let suffix = CanonicalJSONV1.sha256Hex(Data(executionId.utf8))
            .prefix(16)
        let basename = "s-\(suffix).sock"
        let url = directoryAuthority.directoryURL.appendingPathComponent(
            basename,
            isDirectory: false
        )
        let socketPathCapacity = MemoryLayout.size(
            ofValue: sockaddr_un().sun_path
        )
        guard url.path.utf8.count + 1 <= socketPathCapacity else {
            throw EngineRuntimeAuthorityErrorV1.socketPathTooLong
        }
        return url
    }

    fileprivate static func removeCurrentBootResidue(
        authoritySet: EngineRuntimeDirectoryAuthoritySetV1,
        engineRootDescriptor: Int32,
        longBootDescriptor: Int32,
        configDescriptor: Int32,
        executableDescriptor: Int32,
        shortRootDescriptor: Int32
    ) throws {
        for name in try listNames(configDescriptor) {
            try validateConfigName(name)
            try validateRegularFile(
                parent: configDescriptor,
                name: name,
                mode: ownerMode
            )
            guard name.withCString({
                Darwin.unlinkat(configDescriptor, $0, 0)
            }) == 0 else {
                throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
            }
        }
        guard try listNames(executableDescriptor).isEmpty,
              Darwin.fsync(configDescriptor) == 0,
              Darwin.fsync(executableDescriptor) == 0
        else {
            throw EngineRuntimeAuthorityErrorV1.invalidDirectory
        }
        for name in ["cli-executables", "cli-config"] {
            guard name.withCString({
                Darwin.unlinkat(longBootDescriptor, $0, AT_REMOVEDIR)
            }) == 0 else {
                throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
            }
        }
        guard Darwin.fsync(longBootDescriptor) == 0,
              authoritySet.bootId.withCString({
                  Darwin.unlinkat(
                      engineRootDescriptor,
                      $0,
                      AT_REMOVEDIR
                  )
              }) == 0,
              Darwin.fsync(engineRootDescriptor) == 0
        else {
            throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
        }

        let shortAuthority = authoritySet.boardSocketDirectoryAuthority
        let shortName = shortAuthority.directoryURL.lastPathComponent
        try shortAuthority.withOwnedDescriptor { shortDescriptor in
            guard try listNames(shortDescriptor) == ["owner"] else {
                throw EngineRuntimeAuthorityErrorV1.invalidDirectory
            }
            let owner = try EngineRuntimeOwnerDocumentV1.decodeCanonical(
                readOwner(directoryDescriptor: shortDescriptor)
            )
            guard owner.bootUUID == authoritySet.bootId,
                  owner.stateRootIdentityHash
                    == authoritySet.stateRootIdentityHash,
                  try owner.shortDirectoryName() == shortName
            else {
                throw EngineRuntimeAuthorityErrorV1.processDrift
            }
            try validateRegularFile(
                parent: shortDescriptor,
                name: "owner",
                mode: ownerMode
            )
            guard "owner".withCString({
                Darwin.unlinkat(shortDescriptor, $0, 0)
            }) == 0,
                  Darwin.fsync(shortDescriptor) == 0
            else {
                throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
            }
        }
        guard shortName.withCString({
            Darwin.unlinkat(shortRootDescriptor, $0, AT_REMOVEDIR)
        }) == 0,
              Darwin.fsync(shortRootDescriptor) == 0
        else {
            throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
        }
    }

    private static func validateStateDescriptor(
        _ descriptor: Int32,
        identity: EngineStateRootIdentityV1
    ) throws {
        var info = stat()
        var path = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let pathResult = Darwin.fcntl(descriptor, F_GETPATH, &path)
        guard Darwin.fstat(descriptor, &info) == 0,
              pathResult == 0,
              info.st_mode & S_IFMT == S_IFDIR,
              UInt64(info.st_dev) == identity.device,
              UInt64(info.st_ino) == identity.inode,
              UInt32(info.st_uid) == identity.uid,
              String(
                  decoding: path.prefix { $0 != 0 }
                      .map { UInt8(bitPattern: $0) },
                  as: UTF8.self
              ) == identity.canonicalPath
        else {
            throw EngineRuntimeAuthorityErrorV1.invalidStateRoot
        }
    }

    private static func openOrCreateDirectory(
        parent: Int32,
        name: String,
        mode: mode_t
    ) throws -> Int32 {
        let createResult = name.withCString {
            Darwin.mkdirat(parent, $0, mode)
        }
        if createResult != 0 && errno != EEXIST {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        var descriptor = name.withCString {
            Darwin.openat(
                parent,
                $0,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard descriptor >= 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        do {
            try validatePrivateDirectory(descriptor)
        } catch {
            let primary = error
            try EngineRuntimeCleanupV1.throwPreserving(
                primary,
                cleanup: [{
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
                }]
            )
        }
        return descriptor
    }

    private static func createDirectoryExclusive(
        parent: Int32,
        name: String,
        mode: mode_t
    ) throws -> Int32 {
        guard name.withCString({ Darwin.mkdirat(parent, $0, mode) }) == 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        return try openOrCreateDirectory(
            parent: parent,
            name: name,
            mode: mode
        )
    }

    private static func validatePrivateDirectory(_ descriptor: Int32) throws {
        var info = stat()
        guard Darwin.fstat(descriptor, &info) == 0,
              info.st_mode & S_IFMT == S_IFDIR,
              info.st_uid == getuid(),
              info.st_mode & mode_t(0o777) == directoryMode
        else {
            throw EngineRuntimeAuthorityErrorV1.invalidDirectory
        }
    }

    private static func closeDescriptors(
        _ descriptors: inout [Int32]
    ) throws {
        let failures = closeDescriptorFailures(&descriptors)
        try EngineRuntimeCleanupV1.throwCleanupFailures(failures)
    }

    private static func closeDescriptorFailures(
        _ descriptors: inout [Int32]
    ) -> [any Error] {
        var failures: [any Error] = []
        for index in descriptors.indices {
            do {
                try EngineRuntimeOwnedDescriptorV1.closeOnce(
                    &descriptors[index]
                )
            } catch {
                failures.append(error)
            }
        }
        return failures
    }

    private static func throwPreservingAndClose(
        _ primary: any Error,
        descriptors: inout [Int32]
    ) throws -> Never {
        let failures = closeDescriptorFailures(&descriptors)
        guard !failures.isEmpty else { throw primary }
        throw EngineRuntimeCleanupAggregateErrorV1(
            primary: primary,
            cleanupFailures: failures
        )
    }

    private static func openCanonicalDarwinUserTempDirectory() throws
        -> (url: URL, descriptor: Int32)
    {
        let required = Darwin.confstr(_CS_DARWIN_USER_TEMP_DIR, nil, 0)
        guard required > 1 else {
            throw EngineRuntimeAuthorityErrorV1.invalidDirectory
        }
        var systemBytes = [CChar](repeating: 0, count: required)
        guard systemBytes.withUnsafeMutableBufferPointer({ buffer in
            Darwin.confstr(
                _CS_DARWIN_USER_TEMP_DIR,
                buffer.baseAddress,
                buffer.count
            )
        }) == required else {
            throw EngineRuntimeAuthorityErrorV1.invalidDirectory
        }
        let systemPath = String(
            decoding: systemBytes.prefix { $0 != 0 }
                .map { UInt8(bitPattern: $0) },
            as: UTF8.self
        )
        var resolvedBytes = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard systemPath.withCString({ source in
            Darwin.realpath(source, &resolvedBytes)
        }) != nil else {
            throw EngineRuntimeAuthorityErrorV1.invalidDirectory
        }
        let resolved = String(
            decoding: resolvedBytes.prefix { $0 != 0 }
                .map { UInt8(bitPattern: $0) },
            as: UTF8.self
        )
        let canonical = resolved.hasPrefix("/var/")
            ? "/private" + resolved
            : resolved
        // `realpath` above is the canonical authority. Foundation rewrites
        // `/private/var/...` back through the public `/var` symlink when
        // standardizing a file URL, which would make the exact-realpath guard
        // reject every production App bootstrap on macOS.
        let url = URL(fileURLWithPath: canonical, isDirectory: true)
        guard url.path == canonical,
              canonical.hasPrefix("/private/var/folders/"),
              url.lastPathComponent == "T"
        else {
            throw EngineRuntimeAuthorityErrorV1.invalidDirectory
        }
        let descriptor = try descriptorOpenCanonicalComponents(url)
        return (url, descriptor)
    }

    private static func descriptorOpenCanonicalComponents(
        _ url: URL
    ) throws -> Int32 {
        var current = Darwin.open(
            "/",
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard current >= 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        do {
            let components = url.path.split(separator: "/").map(String.init)
            for (index, component) in components.enumerated() {
                var next = component.withCString {
                    Darwin.openat(
                        current,
                        $0,
                        O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
                    )
                }
                guard next >= 0 else {
                    throw EngineRuntimeAuthorityErrorV1
                        .descriptorFailure(errno)
                }
                do {
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(&current)
                } catch {
                    try EngineRuntimeCleanupV1.throwPreserving(
                        error,
                        cleanup: [{
                            try EngineRuntimeOwnedDescriptorV1.closeOnce(&next)
                        }]
                    )
                }
                current = next
                next = -1
                var info = stat()
                guard Darwin.fstat(current, &info) == 0,
                      info.st_mode & S_IFMT == S_IFDIR
                else {
                    throw EngineRuntimeAuthorityErrorV1.invalidDirectory
                }
                if index == components.indices.last {
                    guard info.st_uid == getuid(),
                          info.st_mode & mode_t(0o777) == directoryMode
                    else {
                        throw EngineRuntimeAuthorityErrorV1.invalidDirectory
                    }
                } else if info.st_uid != getuid() {
                    guard info.st_uid == 0,
                          info.st_mode & mode_t(0o022) == 0
                    else {
                        throw EngineRuntimeAuthorityErrorV1.invalidDirectory
                    }
                }
            }
            var frozenPath = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            let pathResult = Darwin.fcntl(
                current,
                F_GETPATH,
                &frozenPath
            )
            guard pathResult == 0,
                  String(
                      decoding: frozenPath.prefix { $0 != 0 }
                          .map { UInt8(bitPattern: $0) },
                      as: UTF8.self
                  ) == url.path
            else {
                throw EngineRuntimeAuthorityErrorV1.invalidDirectory
            }
            return current
        } catch {
            let primary = error
            try EngineRuntimeCleanupV1.throwPreserving(
                primary,
                cleanup: [{
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(&current)
                }]
            )
        }
    }

    private static func validateOldBootShapes(
        engineRootDescriptor: Int32,
        stateIdentity: EngineStateRootIdentityV1
    ) throws -> [EngineOldBootDirectorySnapshotV1] {
        var snapshots: [EngineOldBootDirectorySnapshotV1] = []
        for name in try listNames(engineRootDescriptor) {
            guard let uuid = UUID(uuidString: name),
                  uuid.uuidString == name
            else {
                throw EngineRuntimeAuthorityErrorV1.invalidDirectory
            }
            let descriptor = try openExistingDirectory(
                parent: engineRootDescriptor,
                name: name,
                mode: directoryMode
            )
            var owned = [descriptor]
            do {
                let children = try listNames(descriptor)
                guard children == ["cli-config", "cli-executables"] else {
                    throw EngineRuntimeAuthorityErrorV1.invalidDirectory
                }
                let config = try openExistingDirectory(
                    parent: descriptor,
                    name: "cli-config",
                    mode: directoryMode
                )
                owned.append(config)
                let executables = try openExistingDirectory(
                    parent: descriptor,
                    name: "cli-executables",
                    mode: directoryMode
                )
                owned.append(executables)
                try validateConfigResidue(config)
                var info = stat()
                guard Darwin.fstat(descriptor, &info) == 0 else {
                    throw EngineRuntimeAuthorityErrorV1
                        .descriptorFailure(errno)
                }
                snapshots.append(
                    EngineOldBootDirectorySnapshotV1(
                        name: name,
                        device: UInt64(info.st_dev),
                        inode: UInt64(info.st_ino)
                    )
                )
                owned.reverse()
                try closeDescriptors(&owned)
            } catch {
                let primary = error
                owned.reverse()
                try throwPreservingAndClose(
                    primary,
                    descriptors: &owned
                )
            }
        }
        return snapshots
    }

    private static func oldOwnedExecutables(
        oldBoots: [EngineOldBootDirectorySnapshotV1],
        engineRootURL: URL,
        engineRootDescriptor: Int32
    ) throws -> [EngineRuntimeExecutableRemovalSnapshotV1] {
        var snapshots: [EngineRuntimeExecutableRemovalSnapshotV1] = []
        for boot in oldBoots {
            let bootDescriptor = try openExistingDirectory(
                parent: engineRootDescriptor,
                name: boot.name,
                mode: directoryMode
            )
            var owned = [bootDescriptor]
            do {
                let executableRoot = try openExistingDirectory(
                    parent: bootDescriptor,
                    name: "cli-executables",
                    mode: directoryMode
                )
                owned.append(executableRoot)
                for childName in try listNames(executableRoot) {
                    guard authorityDirectoryHash(childName) != nil else {
                        throw EngineRuntimeAuthorityErrorV1.invalidDirectory
                    }
                    let snapshot = try
                        EngineRuntimeExecutableRemovalValidatorV1.capture(
                            parentDescriptor: executableRoot,
                            authorityName: childName,
                            inspectSignature: {
                                try EngineRuntimeIdentityReaderV1.signing(
                                    path: $0
                                )
                            }
                        )
                    let expectedPath = engineRootURL
                        .appendingPathComponent(boot.name)
                        .appendingPathComponent("cli-executables")
                        .appendingPathComponent(childName)
                        .appendingPathComponent("executable")
                        .path
                    guard snapshot.executablePath == expectedPath else {
                        throw EngineRuntimeAuthorityErrorV1.processDrift
                    }
                    snapshots.append(snapshot)
                }
                owned.reverse()
                try closeDescriptors(&owned)
            } catch {
                let primary = error
                owned.reverse()
                try throwPreservingAndClose(
                    primary,
                    descriptors: &owned
                )
            }
        }
        return snapshots
    }

    private static func sweepValidatedResidue(
        oldBoots: [EngineOldBootDirectorySnapshotV1],
        executableSnapshots: [EngineRuntimeExecutableRemovalSnapshotV1],
        engineRootURL: URL,
        engineRootDescriptor: Int32
    ) throws {
        for boot in oldBoots {
            var bootDescriptor = try openExistingDirectory(
                parent: engineRootDescriptor,
                name: boot.name,
                mode: directoryMode
            )
            var bootInfo = stat()
            guard Darwin.fstat(bootDescriptor, &bootInfo) == 0,
                  UInt64(bootInfo.st_dev) == boot.device,
                  UInt64(bootInfo.st_ino) == boot.inode
            else {
                try EngineRuntimeCleanupV1.throwPreserving(
                    EngineRuntimeAuthorityErrorV1.processDrift,
                    cleanup: [{
                        try EngineRuntimeOwnedDescriptorV1.closeOnce(
                            &bootDescriptor
                        )
                    }]
                )
            }
            var owned = [bootDescriptor]
            do {
                let config = try openExistingDirectory(
                    parent: bootDescriptor,
                    name: "cli-config",
                    mode: directoryMode
                )
                owned.append(config)
                let executables = try openExistingDirectory(
                    parent: bootDescriptor,
                    name: "cli-executables",
                    mode: directoryMode
                )
                owned.append(executables)
                for name in try listNames(config) {
                    try validateConfigName(name)
                    try validateRegularFile(
                        parent: config,
                        name: name,
                        mode: ownerMode
                    )
                    guard name.withCString({
                        Darwin.unlinkat(config, $0, 0)
                    }) == 0 else {
                        throw EngineRuntimeAuthorityErrorV1
                            .cleanupFailure(errno)
                    }
                }
                guard Darwin.fsync(config) == 0 else {
                    throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
                }
                let executableRootPath = engineRootURL
                    .appendingPathComponent(boot.name)
                    .appendingPathComponent("cli-executables")
                for name in try listNames(executables) {
                    let expectedPath = executableRootPath
                        .appendingPathComponent(name)
                        .appendingPathComponent("executable")
                        .path
                    guard let snapshot = executableSnapshots.first(where: {
                        $0.executablePath == expectedPath
                    }) else {
                        throw EngineRuntimeAuthorityErrorV1.invalidDirectory
                    }
                    try checkedUnseal(
                        authorityName: name,
                        parentDescriptor: executables,
                        expectedSnapshot: snapshot
                    )
                }
                var childDescriptors = [owned[2], owned[1]]
                owned[2] = -1
                owned[1] = -1
                try closeDescriptors(&childDescriptors)
                for name in ["cli-executables", "cli-config"] {
                    guard name.withCString({
                        Darwin.unlinkat(bootDescriptor, $0, AT_REMOVEDIR)
                    }) == 0 else {
                        throw EngineRuntimeAuthorityErrorV1
                            .cleanupFailure(errno)
                    }
                }
                guard Darwin.fsync(bootDescriptor) == 0 else {
                    throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
                }
                var bootOwner = [owned[0]]
                owned[0] = -1
                try closeDescriptors(&bootOwner)
                guard boot.name.withCString({
                          Darwin.unlinkat(
                              engineRootDescriptor,
                              $0,
                              AT_REMOVEDIR
                          )
                      }) == 0,
                      Darwin.fsync(engineRootDescriptor) == 0
                else {
                    throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
                }
            } catch {
                let primary = error
                owned.reverse()
                try throwPreservingAndClose(
                    primary,
                    descriptors: &owned
                )
            }
        }
    }

    private static func checkedUnseal(
        authorityName: String,
        parentDescriptor: Int32,
        expectedSnapshot: EngineRuntimeExecutableRemovalSnapshotV1
    ) throws {
        guard authorityDirectoryHash(authorityName) != nil,
              authorityName == expectedSnapshot.authorityName
        else {
            throw EngineRuntimeAuthorityErrorV1.invalidDirectory
        }
        try EngineRuntimeExecutableRemovalValidatorV1.removeImmediately(
            expectedSnapshot,
            parentDescriptor: parentDescriptor,
            inspectSignature: {
                try EngineRuntimeIdentityReaderV1.signing(path: $0)
            }
        )
    }

    private static func sweepOwnedShortResidue(
        parentDescriptor: Int32,
        stateRootIdentityHash: String
    ) throws {
        for name in try listNames(parentDescriptor) {
            guard isShortDirectoryName(name) else { continue }
            var child = try openExistingDirectory(
                parent: parentDescriptor,
                name: name,
                mode: directoryMode
            )
            do {
                let ownerBytes = try readOwner(
                    directoryDescriptor: child
                )
                let owner = try EngineRuntimeOwnerDocumentV1
                    .decodeCanonical(ownerBytes)
                if owner.stateRootIdentityHash != stateRootIdentityHash {
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(&child)
                    continue
                }
                let expectedName = try owner.shortDirectoryName()
                guard name == expectedName else {
                    throw EngineRuntimeAuthorityErrorV1.invalidOwner
                }
                for entry in try listNames(child) where entry != "owner" {
                    guard isSocketName(entry) else {
                        throw EngineRuntimeAuthorityErrorV1.invalidDirectory
                    }
                    var socketInfo = stat()
                    guard entry.withCString({
                        Darwin.fstatat(
                            child,
                            $0,
                            &socketInfo,
                            AT_SYMLINK_NOFOLLOW
                        )
                    }) == 0,
                          socketInfo.st_mode & S_IFMT == S_IFSOCK,
                          socketInfo.st_uid == getuid(),
                          socketInfo.st_nlink == 1,
                          entry.withCString({
                              Darwin.unlinkat(child, $0, 0)
                          }) == 0
                    else {
                        throw EngineRuntimeAuthorityErrorV1
                            .cleanupFailure(errno)
                    }
                }
                try validateRegularFile(
                    parent: child,
                    name: "owner",
                    mode: ownerMode
                )
                guard "owner".withCString({
                    Darwin.unlinkat(child, $0, 0)
                }) == 0,
                      Darwin.fsync(child) == 0
                else {
                    throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
                }
                try EngineRuntimeOwnedDescriptorV1.closeOnce(&child)
                guard name.withCString({
                          Darwin.unlinkat(
                              parentDescriptor,
                              $0,
                              AT_REMOVEDIR
                          )
                      }) == 0,
                      Darwin.fsync(parentDescriptor) == 0
                else {
                    throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
                }
            } catch {
                let primary = error
                try EngineRuntimeCleanupV1.throwPreserving(
                    primary,
                    cleanup: [{
                        try EngineRuntimeOwnedDescriptorV1.closeOnce(&child)
                    }]
                )
            }
        }
    }

    private static func validateConfigResidue(_ descriptor: Int32) throws {
        for name in try listNames(descriptor) {
            try validateConfigName(name)
            try validateRegularFile(
                parent: descriptor,
                name: name,
                mode: ownerMode
            )
        }
    }

    private static func validateConfigName(_ name: String) throws {
        let prefix = "agentloop-"
        let suffix = ".mcp.json"
        guard name.hasPrefix(prefix), name.hasSuffix(suffix) else {
            throw EngineRuntimeAuthorityErrorV1.invalidDirectory
        }
        let id = String(name.dropFirst(prefix.count).dropLast(suffix.count))
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(id)
        } catch {
            throw EngineRuntimeAuthorityErrorV1.invalidDirectory
        }
    }

    private static func authorityDirectoryHash(
        _ name: String
    ) -> String? {
        let prefixes = ["cli_codex-", "cli_claude-", "board-bridge-"]
        guard let prefix = prefixes.first(where: { name.hasPrefix($0) }) else {
            return nil
        }
        let hash = String(name.dropFirst(prefix.count))
        guard hash.utf8.count == 64,
              hash.utf8.allSatisfy({ byte in
                  (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                      || (UInt8(ascii: "a")...UInt8(ascii: "f"))
                          .contains(byte)
              })
        else { return nil }
        return hash
    }

    private static func isShortDirectoryName(_ name: String) -> Bool {
        name.utf8.count == 14
            && name.hasPrefix("a-")
            && name.dropFirst(2).utf8.allSatisfy { byte in
                (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                    || (UInt8(ascii: "a")...UInt8(ascii: "f"))
                        .contains(byte)
            }
    }

    private static func isSocketName(_ name: String) -> Bool {
        guard name.utf8.count == 23,
              name.hasPrefix("s-"),
              name.hasSuffix(".sock")
        else { return false }
        return name.dropFirst(2).dropLast(5).utf8.allSatisfy { byte in
            (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                || (UInt8(ascii: "a")...UInt8(ascii: "f"))
                    .contains(byte)
        }
    }

    private static func validateRegularFile(
        parent: Int32,
        name: String,
        mode: mode_t
    ) throws {
        var info = stat()
        guard name.withCString({
            Darwin.fstatat(parent, $0, &info, AT_SYMLINK_NOFOLLOW)
        }) == 0,
              info.st_mode & S_IFMT == S_IFREG,
              info.st_uid == getuid(),
              info.st_mode & mode_t(0o777) == mode,
              info.st_nlink == 1
        else {
            throw EngineRuntimeAuthorityErrorV1.invalidDirectory
        }
    }

    private static func openExistingDirectory(
        parent: Int32,
        name: String,
        mode: mode_t
    ) throws -> Int32 {
        var descriptor = name.withCString {
            Darwin.openat(
                parent,
                $0,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard descriptor >= 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        var info = stat()
        guard Darwin.fstat(descriptor, &info) == 0,
              info.st_mode & S_IFMT == S_IFDIR,
              info.st_uid == getuid(),
              info.st_mode & mode_t(0o777) == mode
        else {
            let failure = errno
            try EngineRuntimeCleanupV1.throwPreserving(
                EngineRuntimeAuthorityErrorV1.descriptorFailure(failure),
                cleanup: [{
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
                }]
            )
        }
        return descriptor
    }

    private static func listNames(_ descriptor: Int32) throws -> [String] {
        var duplicate = Darwin.fcntl(descriptor, F_DUPFD_CLOEXEC, 0)
        guard duplicate >= 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        guard let directory = Darwin.fdopendir(duplicate) else {
            let failure = errno
            try EngineRuntimeCleanupV1.throwPreserving(
                EngineRuntimeAuthorityErrorV1.descriptorFailure(failure),
                cleanup: [{
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(&duplicate)
                }]
            )
        }
        duplicate = -1
        var names: [String] = []
        errno = 0
        while let entry = Darwin.readdir(directory) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String(cString: $0)
                }
            }
            if name != "." && name != ".." {
                names.append(name)
            }
            errno = 0
        }
        let readFailure = errno
        guard Darwin.closedir(directory) == 0 else {
            throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
        }
        guard readFailure == 0 else {
            throw EngineRuntimeAuthorityErrorV1
                .descriptorFailure(readFailure)
        }
        return names.sorted()
    }

    private static func writeOwner(
        _ bytes: Data,
        directoryDescriptor: Int32
    ) throws {
        var descriptor = "owner".withCString {
            Darwin.openat(
                directoryDescriptor,
                $0,
                O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC | O_NOFOLLOW,
                ownerMode
            )
        }
        guard descriptor >= 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        do {
            var offset = 0
            while offset < bytes.count {
                let amount = bytes.withUnsafeBytes {
                    Darwin.write(
                        descriptor,
                        $0.baseAddress?.advanced(by: offset),
                        bytes.count - offset
                    )
                }
                if amount > 0 {
                    offset += amount
                    continue
                }
                if amount < 0 && errno == EINTR { continue }
                throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
            }
            var info = stat()
            guard Darwin.fsync(descriptor) == 0,
                  Darwin.fstat(descriptor, &info) == 0,
                  info.st_mode & S_IFMT == S_IFREG,
                  info.st_uid == getuid(),
                  info.st_mode & mode_t(0o777) == ownerMode,
                  info.st_nlink == 1,
                  info.st_size == bytes.count
            else {
                throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
            }
            try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
            guard Darwin.fsync(directoryDescriptor) == 0 else {
                throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
            }
        } catch {
            let primary = error
            try EngineRuntimeCleanupV1.throwPreserving(
                primary,
                cleanup: [{
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
                }]
            )
        }
    }

    private static func readOwner(
        directoryDescriptor: Int32
    ) throws -> Data {
        try validateRegularFile(
            parent: directoryDescriptor,
            name: "owner",
            mode: ownerMode
        )
        var descriptor = "owner".withCString {
            Darwin.openat(
                directoryDescriptor,
                $0,
                O_RDONLY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard descriptor >= 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        var bytes = Data()
        do {
            var buffer = [UInt8](repeating: 0, count: 1_024)
            while true {
                let amount = buffer.withUnsafeMutableBytes {
                    Darwin.read(descriptor, $0.baseAddress, $0.count)
                }
                if amount > 0 {
                    bytes.append(buffer, count: amount)
                    guard bytes.count <= 4_096 else {
                        throw EngineRuntimeAuthorityErrorV1.invalidOwner
                    }
                    continue
                }
                if amount == 0 { break }
                if errno == EINTR { continue }
                throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
            }
            try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
            return bytes
        } catch {
            let primary = error
            try EngineRuntimeCleanupV1.throwPreserving(
                primary,
                cleanup: [{
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
                }]
            )
        }
    }

    private static func removeFailedShortCandidate(
        name: String,
        descriptor: Int32,
        parentDescriptor: Int32
    ) throws {
        var ownedDescriptor = descriptor
        do {
            var ownerInfo = stat()
            let ownerStat = "owner".withCString {
                Darwin.fstatat(
                    ownedDescriptor,
                    $0,
                    &ownerInfo,
                    AT_SYMLINK_NOFOLLOW
                )
            }
            if ownerStat == 0 {
                try validateRegularFile(
                    parent: ownedDescriptor,
                    name: "owner",
                    mode: ownerMode
                )
                guard "owner".withCString({
                    Darwin.unlinkat(ownedDescriptor, $0, 0)
                }) == 0,
                      Darwin.fsync(ownedDescriptor) == 0
                else {
                    throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
                }
            } else if errno != ENOENT {
                throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
            }
            try EngineRuntimeOwnedDescriptorV1.closeOnce(&ownedDescriptor)
            guard name.withCString({
                      Darwin.unlinkat(parentDescriptor, $0, AT_REMOVEDIR)
                  }) == 0,
                  Darwin.fsync(parentDescriptor) == 0
            else {
                throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
            }
        } catch {
            try EngineRuntimeCleanupV1.throwPreserving(
                error,
                cleanup: [{
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(
                        &ownedDescriptor
                    )
                }]
            )
        }
    }

    private static func removeEmptyLongBootCandidate(
        name: String,
        engineRootDescriptor: Int32,
        longBootDescriptor: Int32
    ) throws {
        var ownedDescriptor = longBootDescriptor
        do {
            for child in ["cli-executables", "cli-config"] {
                var info = stat()
                let result = child.withCString {
                    Darwin.fstatat(
                        ownedDescriptor,
                        $0,
                        &info,
                        AT_SYMLINK_NOFOLLOW
                    )
                }
                if result == 0 {
                    guard info.st_mode & S_IFMT == S_IFDIR,
                          child.withCString({
                              Darwin.unlinkat(
                                  ownedDescriptor,
                                  $0,
                                  AT_REMOVEDIR
                              )
                          }) == 0
                    else {
                        throw EngineRuntimeAuthorityErrorV1
                            .cleanupFailure(errno)
                    }
                } else if errno != ENOENT {
                    throw EngineRuntimeAuthorityErrorV1
                        .descriptorFailure(errno)
                }
            }
            guard Darwin.fsync(ownedDescriptor) == 0 else {
                throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
            }
            try EngineRuntimeOwnedDescriptorV1.closeOnce(&ownedDescriptor)
            guard name.withCString({
                      Darwin.unlinkat(
                          engineRootDescriptor,
                          $0,
                          AT_REMOVEDIR
                      )
                  }) == 0,
                  Darwin.fsync(engineRootDescriptor) == 0
            else {
                throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
            }
        } catch {
            try EngineRuntimeCleanupV1.throwPreserving(
                error,
                cleanup: [{
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(
                        &ownedDescriptor
                    )
                }]
            )
        }
    }
}

package enum EngineManagedProbeObservationV1: Sendable, Equatable {
    case running
    case exited(status: Int32)
    case deadline
    case outputLimit
}

package struct EngineManagedProbeCapturedOutputV1: Sendable, Equatable {
    package let stdout: Data
    package let stderr: Data

    package init(stdout: Data, stderr: Data) {
        self.stdout = stdout
        self.stderr = stderr
    }
}

package enum EngineManagedProbeLeaderWaitObservationV1:
    Sendable, Equatable
{
    case running
    case interrupted
    case exited(status: Int32)
    case failure(errno: Int32)
}

package struct EngineManagedProbeBoundedLeaderReaperV1: Sendable {
    private let deadline: ContinuousClock.Instant
    private let waitNoHang:
        @Sendable () -> EngineManagedProbeLeaderWaitObservationV1
    private let now: @Sendable () -> ContinuousClock.Instant
    private let pause: @Sendable () throws -> Void

    package init(
        deadline: ContinuousClock.Instant,
        waitNoHang: @escaping @Sendable () ->
            EngineManagedProbeLeaderWaitObservationV1,
        now: @escaping @Sendable () -> ContinuousClock.Instant = {
            ContinuousClock.now
        },
        pause: @escaping @Sendable () throws -> Void = {
            var request = timespec(tv_sec: 0, tv_nsec: 10_000_000)
            var remaining = timespec()
            let result = Darwin.nanosleep(&request, &remaining)
            let failure = errno
            guard result == 0 || failure == EINTR
            else {
                throw EngineRuntimeAuthorityErrorV1
                    .descriptorFailure(failure)
            }
        }
    ) {
        self.deadline = deadline
        self.waitNoHang = waitNoHang
        self.now = now
        self.pause = pause
    }

    package func reap(observedStatus: Int32?) throws -> Int32 {
        if let observedStatus { return observedStatus }
        while true {
            switch waitNoHang() {
            case .exited(let status):
                return status
            case .failure(let failure):
                throw EngineRuntimeAuthorityErrorV1.cleanupFailure(failure)
            case .running, .interrupted:
                guard now() < deadline else {
                    throw EngineRuntimeAuthorityErrorV1
                        .processGroupSurvived
                }
                try pause()
            }
        }
    }
}

package protocol EngineManagedProbeProcessV1: Sendable {
    func startBoundedConcurrentDrain(maximumOutputBytes: Int) throws
    func verifySuspendedImage() throws
    func resumeSuspended() throws
    func send(signal: Int32) throws
    func nextObservation() throws -> EngineManagedProbeObservationV1
    func processGroupExists() throws -> Bool
    func stopDrains()
    func finishDrains() throws -> EngineManagedProbeCapturedOutputV1
    func reapLeader() throws -> Int32
}

package enum EngineManagedProbeLifecycleV1 {
    package static func abortSuspended(
        process: any EngineManagedProbeProcessV1,
        maximumOutputBytes: Int
    ) throws {
        var failures: [any Error] = []
        var drainStarted = false
        do {
            try process.startBoundedConcurrentDrain(
                maximumOutputBytes: maximumOutputBytes
            )
            drainStarted = true
        } catch {
            failures.append(error)
        }
        for signal in [SIGTERM, SIGCONT, SIGKILL] {
            do {
                try process.send(signal: signal)
            } catch {
                failures.append(error)
            }
        }
        var groupAbsent = false
        do {
            try waitForExactGroupAbsence(process: process)
            groupAbsent = true
        } catch {
            failures.append(error)
        }
        if drainStarted {
            failures.append(
                contentsOf: terminalJoinDrains(
                    process: process,
                    groupAbsent: groupAbsent,
                    priorDrainTimedOut: false
                )
            )
        }
        do {
            _ = try process.reapLeader()
        } catch {
            failures.append(error)
        }
        try EngineRuntimeCleanupV1.throwCleanupFailures(failures)
    }

    package static func run(
        process: any EngineManagedProbeProcessV1,
        maximumOutputBytes: Int
    ) throws -> Data {
        guard maximumOutputBytes > 0 else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }
        var drainStarted = false
        var drainFinished = false
        var leaderReaped = false
        do {
            try process.startBoundedConcurrentDrain(
                maximumOutputBytes: maximumOutputBytes
            )
            drainStarted = true
            try process.verifySuspendedImage()
            try process.resumeSuspended()
            let status: Int32
            observationLoop: while true {
                switch try process.nextObservation() {
                case .running:
                    continue observationLoop
                case .deadline, .outputLimit:
                    throw EngineRuntimeAuthorityErrorV1.managedPolicy
                case .exited(let value):
                    guard try !process.processGroupExists() else {
                        // The leader exited while a fork remained in the
                        // probe's private group.
                        throw EngineRuntimeAuthorityErrorV1
                            .processGroupSurvived
                    }
                    status = value
                    break observationLoop
                }
            }
            let output = try process.finishDrains()
            drainFinished = true
            let reapedStatus = try process.reapLeader()
            leaderReaped = true
            guard status == reapedStatus,
                  status == 0,
                  output.stdout.count <= maximumOutputBytes,
                  output.stderr.count <= maximumOutputBytes,
                  output.stderr.isEmpty
            else {
                throw EngineRuntimeAuthorityErrorV1.managedPolicy
            }
            return output.stdout
        } catch {
            let primary = error
            var cleanupFailures: [any Error] = []
            for signal in [SIGTERM, SIGCONT, SIGKILL] {
                do {
                    try process.send(signal: signal)
                } catch {
                    cleanupFailures.append(error)
                }
            }
            var groupAbsent = false
            do {
                try waitForExactGroupAbsence(process: process)
                groupAbsent = true
            } catch {
                cleanupFailures.append(error)
            }
            if drainStarted && !drainFinished {
                cleanupFailures.append(
                    contentsOf: terminalJoinDrains(
                        process: process,
                        groupAbsent: groupAbsent,
                        priorDrainTimedOut:
                            (primary as? EngineRuntimeAuthorityErrorV1)
                                == .processGroupSurvived
                    )
                )
            }
            if !leaderReaped {
                do {
                    _ = try process.reapLeader()
                    leaderReaped = true
                } catch {
                    cleanupFailures.append(error)
                }
            }
            guard !cleanupFailures.isEmpty else { throw primary }
            throw EngineRuntimeCleanupAggregateErrorV1(
                primary: primary,
                cleanupFailures: cleanupFailures
            )
        }
    }

    private static func waitForExactGroupAbsence(
        process: any EngineManagedProbeProcessV1
    ) throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        while ContinuousClock.now < deadline {
            if try !process.processGroupExists() { return }
            var request = timespec(tv_sec: 0, tv_nsec: 10_000_000)
            while true {
                var remaining = timespec()
                if Darwin.nanosleep(&request, &remaining) == 0 { break }
                let failure = errno
                guard failure == EINTR else {
                    throw EngineRuntimeAuthorityErrorV1
                        .descriptorFailure(failure)
                }
                request = remaining
            }
        }
        guard try !process.processGroupExists() else {
            throw EngineRuntimeAuthorityErrorV1.processGroupSurvived
        }
    }

    private static func terminalJoinDrains(
        process: any EngineManagedProbeProcessV1,
        groupAbsent: Bool,
        priorDrainTimedOut: Bool
    ) -> [any Error] {
        if !groupAbsent || priorDrainTimedOut { process.stopDrains() }
        do {
            _ = try process.finishDrains()
            return []
        } catch let first as EngineRuntimeAuthorityErrorV1
            where first == .processGroupSurvived
        {
            process.stopDrains()
            do {
                _ = try process.finishDrains()
                return []
            } catch {
                return [first, error]
            }
        } catch {
            return [error]
        }
    }
}

package final class EngineManagedProbeDrainBarrierV1:
    @unchecked Sendable
{
    private enum State {
        case idle
        case draining(attempts: Int)
        case joining(attempt: Int)
        case joined
    }

    private let lock = NSLock()
    private var state: State = .idle

    package init() {}

    package func startDraining() throws {
        try lock.withLock {
            guard case .idle = state else {
                throw EngineRuntimeAuthorityErrorV1.managedPolicy
            }
            state = .draining(attempts: 0)
        }
    }

    package func join<Output>(
        waitUntilClosed: (_ retryingAfterTimeout: Bool) -> Bool,
        result: () throws -> Output
    ) throws -> Output {
        let attempt = try lock.withLock { () throws -> Int in
            guard case .draining(let attempts) = state else {
                throw EngineRuntimeAuthorityErrorV1.managedPolicy
            }
            let value = attempts + 1
            state = .joining(attempt: value)
            return value
        }
        guard waitUntilClosed(attempt > 1) else {
            lock.withLock { state = .draining(attempts: attempt) }
            throw EngineRuntimeAuthorityErrorV1.processGroupSurvived
        }
        lock.withLock { state = .joined }
        return try result()
    }
}

private final class EngineManagedProbeDrainStateV1:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var stdout = Data()
    private var stderr = Data()
    private var outputLimitExceeded = false
    private var failures: [any Error] = []

    func append(
        _ bytes: UnsafeRawBufferPointer,
        standardError: Bool,
        limit: Int
    ) {
        lock.withLock {
            var target = standardError ? stderr : stdout
            if target.count <= limit,
               bytes.count <= limit - target.count
            {
                target.append(contentsOf: bytes)
            } else {
                outputLimitExceeded = true
            }
            if standardError { stderr = target } else { stdout = target }
        }
    }

    func record(_ error: any Error) {
        lock.withLock { failures.append(error) }
    }

    var exceeded: Bool { lock.withLock { outputLimitExceeded } }

    func result() throws -> EngineManagedProbeCapturedOutputV1 {
        try lock.withLock {
            if let first = failures.first {
                if failures.count == 1 { throw first }
                throw EngineRuntimeCleanupAggregateErrorV1(
                    primary: first,
                    cleanupFailures: Array(failures.dropFirst())
                )
            }
            guard !outputLimitExceeded else {
                throw EngineRuntimeAuthorityErrorV1.managedPolicy
            }
            return EngineManagedProbeCapturedOutputV1(
                stdout: stdout,
                stderr: stderr
            )
        }
    }
}

private final class EngineManagedProbeDrainControlV1:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var stopRequested = false
    private var activeWorkers = 0

    func requestStop() { lock.withLock { stopRequested = true } }

    var shouldStop: Bool { lock.withLock { stopRequested } }

    func workerStarted() { lock.withLock { activeWorkers += 1 } }
    func workerFinished() { lock.withLock { activeWorkers -= 1 } }

    var activeWorkerCount: Int { lock.withLock { activeWorkers } }
}

package final class EngineManagedProbeLiveDrainV1:
    @unchecked Sendable
{
    private let stdoutDescriptor: Int32
    private let stderrDescriptor: Int32
    private let state = EngineManagedProbeDrainStateV1()
    private let control = EngineManagedProbeDrainControlV1()
    private let group = DispatchGroup()
    private let barrier = EngineManagedProbeDrainBarrierV1()
    private let diagnosticId = UUID()

    package init(
        stdoutDescriptor: Int32,
        stderrDescriptor: Int32
    ) {
        self.stdoutDescriptor = stdoutDescriptor
        self.stderrDescriptor = stderrDescriptor
    }

    package var exceeded: Bool { state.exceeded }
    package var activeWorkerCount: Int { control.activeWorkerCount }

    package func start(maximumOutputBytes: Int) throws {
        guard maximumOutputBytes > 0 else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }
        try barrier.startDraining()
        startDrain(
            descriptor: stdoutDescriptor,
            standardError: false,
            maximumOutputBytes: maximumOutputBytes
        )
        startDrain(
            descriptor: stderrDescriptor,
            standardError: true,
            maximumOutputBytes: maximumOutputBytes
        )
    }

    package func finish() throws -> EngineManagedProbeCapturedOutputV1 {
        let diagnosticId = diagnosticId
        return try barrier.join(
            waitUntilClosed: { retryingAfterTimeout in
                let attempt = retryingAfterTimeout ? 2 : 1
                RuntimeLifecycleDiagnostics.event(
                    .drainJoinStarted,
                    owner: diagnosticId,
                    value: attempt
                )
                let joined = group.wait(
                    timeout: .now() + .seconds(1)
                ) == .success
                RuntimeLifecycleDiagnostics.event(
                    joined ? .drainJoinCompleted : .drainJoinTimedOut,
                    owner: diagnosticId,
                    value: attempt
                )
                return joined
            },
            result: { try state.result() }
        )
    }

    package func stop() { control.requestStop() }

    private func startDrain(
        descriptor: Int32,
        standardError: Bool,
        maximumOutputBytes: Int
    ) {
        let diagnosticId = diagnosticId
        let streamValue = standardError ? 1 : 0
        group.enter()
        control.workerStarted()
        RuntimeLifecycleDiagnostics.event(
            .drainQueued,
            owner: diagnosticId,
            value: streamValue
        )
        DispatchQueue.global(qos: .utility).async {
            [state, control, group, diagnosticId] in
            RuntimeLifecycleDiagnostics.event(
                .drainStarted,
                owner: diagnosticId,
                value: streamValue
            )
            var ownedDescriptor = descriptor
            defer {
                do {
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(
                        &ownedDescriptor
                    )
                } catch {
                    state.record(error)
                }
                control.workerFinished()
                RuntimeLifecycleDiagnostics.event(
                    .drainFinished,
                    owner: diagnosticId,
                    value: streamValue
                )
                group.leave()
            }
            let flags = Darwin.fcntl(ownedDescriptor, F_GETFL)
            guard flags >= 0,
                  Darwin.fcntl(
                      ownedDescriptor,
                      F_SETFL,
                      flags | O_NONBLOCK
                  ) == 0
            else {
                state.record(
                    EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
                )
                return
            }
            var buffer = [UInt8](repeating: 0, count: 16 * 1_024)
            while !control.shouldStop {
                let count = buffer.withUnsafeMutableBytes {
                    Darwin.read(ownedDescriptor, $0.baseAddress, $0.count)
                }
                if count > 0 {
                    buffer.withUnsafeBytes { bytes in
                        state.append(
                            UnsafeRawBufferPointer(
                                start: bytes.baseAddress,
                                count: count
                            ),
                            standardError: standardError,
                            limit: maximumOutputBytes
                        )
                    }
                    continue
                }
                if count == 0 {
                    RuntimeLifecycleDiagnostics.event(
                        .drainEOF,
                        owner: diagnosticId,
                        value: streamValue
                    )
                    return
                }
                let failure = errno
                if failure == EINTR { continue }
                if failure == EAGAIN || failure == EWOULDBLOCK {
                    var readiness = pollfd(
                        fd: ownedDescriptor,
                        events: Int16(POLLIN | POLLHUP | POLLERR),
                        revents: 0
                    )
                    let pollResult = Darwin.poll(&readiness, 1, 20)
                    if pollResult >= 0 || errno == EINTR { continue }
                    state.record(
                        EngineRuntimeAuthorityErrorV1
                            .descriptorFailure(errno)
                    )
                    return
                }
                state.record(
                    EngineRuntimeAuthorityErrorV1
                        .descriptorFailure(failure)
                )
                return
            }
        }
    }
}

private final class EngineManagedProbeLiveProcessV1:
    EngineManagedProbeProcessV1, @unchecked Sendable
{
    private let pid: pid_t
    private let processGroupId: pid_t
    private let expected: EngineOwnedRuntimeExecutableV1
    private let inspector: any EngineRuntimeProcessInspectingV1
    private let deadline: ContinuousClock.Instant
    private let stateLock = NSLock()
    private var observedWaitStatus: Int32?
    private var reaped = false
    private let drain: EngineManagedProbeLiveDrainV1

    init(
        pid: pid_t,
        stdoutDescriptor: Int32,
        stderrDescriptor: Int32,
        expected: EngineOwnedRuntimeExecutableV1,
        inspector: any EngineRuntimeProcessInspectingV1,
        deadline: ContinuousClock.Instant
    ) {
        self.pid = pid
        processGroupId = pid
        self.expected = expected
        self.inspector = inspector
        self.deadline = deadline
        drain = EngineManagedProbeLiveDrainV1(
            stdoutDescriptor: stdoutDescriptor,
            stderrDescriptor: stderrDescriptor
        )
    }

    func startBoundedConcurrentDrain(
        maximumOutputBytes: Int
    ) throws {
        try drain.start(maximumOutputBytes: maximumOutputBytes)
    }

    func verifySuspendedImage() throws {
        let matches = try inspector.snapshots().filter { $0.pid == pid }
        guard matches.count == 1,
              matches[0].processGroupId == processGroupId,
              expected.matches(matches[0])
        else {
            throw EngineRuntimeAuthorityErrorV1.processDrift
        }
    }

    func resumeSuspended() throws {
        guard Darwin.kill(-processGroupId, SIGCONT) == 0 else {
            throw EngineRuntimeAuthorityErrorV1.processSignal(errno)
        }
    }

    func send(signal: Int32) throws {
        if Darwin.kill(-processGroupId, signal) == 0 { return }
        let failure = errno
        if failure == ESRCH { return }
        throw EngineRuntimeAuthorityErrorV1.processSignal(failure)
    }

    private static func decodedTerminatedWaitStatus(
        _ raw: Int32
    ) -> Int32? {
        let signal = raw & 0x7f
        if signal == 0 {
            return (raw >> 8) & 0xff
        }
        guard signal < 0x7f else { return nil }
        return 128 + signal
    }

    func nextObservation() throws -> EngineManagedProbeObservationV1 {
        if drain.exceeded { return .outputLimit }
        var status: Int32 = 0
        let result = Darwin.waitpid(pid, &status, WNOHANG)
        if result == pid {
            let normalized = Self.decodedTerminatedWaitStatus(status)
                ?? status
            stateLock.withLock { observedWaitStatus = normalized }
            return .exited(status: normalized)
        }
        if result < 0 {
            if errno == EINTR { return .running }
            throw EngineRuntimeAuthorityErrorV1.cleanupFailure(errno)
        }
        if ContinuousClock.now >= deadline { return .deadline }
        var request = timespec(tv_sec: 0, tv_nsec: 10_000_000)
        while true {
            var remaining = timespec()
            if Darwin.nanosleep(&request, &remaining) == 0 { break }
            let failure = errno
            guard failure == EINTR else {
                throw EngineRuntimeAuthorityErrorV1
                    .descriptorFailure(failure)
            }
            request = remaining
        }
        return .running
    }

    func processGroupExists() throws -> Bool {
        if Darwin.kill(-processGroupId, 0) == 0 { return true }
        let failure = errno
        if failure == ESRCH { return false }
        throw EngineRuntimeAuthorityErrorV1.processSignal(failure)
    }

    func stopDrains() { drain.stop() }

    func finishDrains() throws -> EngineManagedProbeCapturedOutputV1 {
        try drain.finish()
    }

    func reapLeader() throws -> Int32 {
        let observed = stateLock.withLock { observedWaitStatus }
        let reaper = EngineManagedProbeBoundedLeaderReaperV1(
            deadline: ContinuousClock.now.advanced(by: .seconds(1)),
            waitNoHang: { [pid] in
                var status: Int32 = 0
                let result = Darwin.waitpid(pid, &status, WNOHANG)
                if result == pid {
                    if let normalized = Self
                        .decodedTerminatedWaitStatus(status)
                    {
                        return .exited(status: normalized)
                    }
                    return .running
                }
                if result == 0 { return .running }
                let failure = errno
                if result < 0, failure == EINTR { return .interrupted }
                return .failure(
                    errno: result < 0 ? failure : ECHILD
                )
            }
        )
        let status = try reaper.reap(observedStatus: observed)
        try stateLock.withLock {
            guard !reaped else {
                throw EngineRuntimeAuthorityErrorV1.managedPolicy
            }
            reaped = true
        }
        return status
    }

}

private enum EngineManagedProbeSpawnerV1 {
    static func spawnSuspended(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        expected: EngineOwnedRuntimeExecutableV1,
        processInspector: any EngineRuntimeProcessInspectingV1,
        deadline: Duration
    ) throws -> EngineManagedProbeLiveProcessV1 {
        var stdoutPipe = [Int32](repeating: -1, count: 2)
        var stderrPipe = [Int32](repeating: -1, count: 2)
        guard Darwin.pipe(&stdoutPipe) == 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        guard Darwin.pipe(&stderrPipe) == 0 else {
            let primary = EngineRuntimeAuthorityErrorV1
                .descriptorFailure(errno)
            var failures: [any Error] = []
            for index in stdoutPipe.indices {
                do { try closeDescriptorOnce(&stdoutPipe[index]) }
                catch { failures.append(error) }
            }
            guard !failures.isEmpty else { throw primary }
            throw EngineRuntimeCleanupAggregateErrorV1(
                primary: primary,
                cleanupFailures: failures
            )
        }

        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        var actionsInitialized = false
        var attributesInitialized = false
        var pid: pid_t = 0
        var spawnedProcess: EngineManagedProbeLiveProcessV1?
        do {
            var code = posix_spawn_file_actions_init(&actions)
            guard code == 0 else {
                throw EngineRuntimeAuthorityErrorV1.descriptorFailure(code)
            }
            actionsInitialized = true
            code = posix_spawnattr_init(&attributes)
            guard code == 0 else {
                throw EngineRuntimeAuthorityErrorV1.descriptorFailure(code)
            }
            attributesInitialized = true
            let flags = Int16(
                POSIX_SPAWN_START_SUSPENDED
                    | POSIX_SPAWN_SETPGROUP
                    | POSIX_SPAWN_CLOEXEC_DEFAULT
            )
            code = posix_spawnattr_setflags(&attributes, flags)
            guard code == 0 else {
                throw EngineRuntimeAuthorityErrorV1.descriptorFailure(code)
            }
            code = posix_spawnattr_setpgroup(&attributes, 0)
            guard code == 0 else {
                throw EngineRuntimeAuthorityErrorV1.descriptorFailure(code)
            }
            code = "/dev/null".withCString { path in
                posix_spawn_file_actions_addopen(
                    &actions,
                    STDIN_FILENO,
                    path,
                    O_RDONLY,
                    0
                )
            }
            guard code == 0 else {
                throw EngineRuntimeAuthorityErrorV1.descriptorFailure(code)
            }
            for (source, destination) in [
                (stdoutPipe[1], STDOUT_FILENO),
                (stderrPipe[1], STDERR_FILENO),
            ] {
                code = posix_spawn_file_actions_adddup2(
                    &actions,
                    source,
                    destination
                )
                guard code == 0 else {
                    throw EngineRuntimeAuthorityErrorV1
                        .descriptorFailure(code)
                }
            }
            for descriptor in stdoutPipe + stderrPipe {
                code = posix_spawn_file_actions_addclose(
                    &actions,
                    descriptor
                )
                guard code == 0 else {
                    throw EngineRuntimeAuthorityErrorV1
                        .descriptorFailure(code)
                }
            }
            var argv = try cStrings([executablePath] + arguments)
            defer { freeCStrings(argv) }
            var envp = try cStrings(
                environment.keys.sorted().map {
                    "\($0)=\(environment[$0]!)"
                }
            )
            defer { freeCStrings(envp) }
            code = executablePath.withCString { path in
                argv.withUnsafeMutableBufferPointer { arguments in
                    envp.withUnsafeMutableBufferPointer { variables in
                        posix_spawn(
                            &pid,
                            path,
                            &actions,
                            &attributes,
                            arguments.baseAddress,
                            variables.baseAddress
                        )
                    }
                }
            }
            guard code == 0, pid > 1 else {
                throw EngineRuntimeAuthorityErrorV1.descriptorFailure(code)
            }
            let process = EngineManagedProbeLiveProcessV1(
                pid: pid,
                stdoutDescriptor: stdoutPipe[0],
                stderrDescriptor: stderrPipe[0],
                expected: expected,
                inspector: processInspector,
                deadline: ContinuousClock.now.advanced(by: deadline)
            )
            spawnedProcess = process
            stdoutPipe[0] = -1
            stderrPipe[0] = -1
            let destroyFailures = destroy(
                actions: &actions,
                actionsInitialized: &actionsInitialized,
                attributes: &attributes,
                attributesInitialized: &attributesInitialized
            )
            try EngineRuntimeCleanupV1.throwCleanupFailures(destroyFailures)
            var closeFailures: [any Error] = []
            do { try closeDescriptorOnce(&stdoutPipe[1]) }
            catch { closeFailures.append(error) }
            do { try closeDescriptorOnce(&stderrPipe[1]) }
            catch { closeFailures.append(error) }
            try EngineRuntimeCleanupV1.throwCleanupFailures(closeFailures)
            return process
        } catch {
            let primary = error
            let destroyFailures = destroy(
                actions: &actions,
                actionsInitialized: &actionsInitialized,
                attributes: &attributes,
                attributesInitialized: &attributesInitialized
            )
            var closeFailures: [any Error] = []
            for index in stdoutPipe.indices {
                do { try closeDescriptorOnce(&stdoutPipe[index]) }
                catch { closeFailures.append(error) }
            }
            for index in stderrPipe.indices {
                do { try closeDescriptorOnce(&stderrPipe[index]) }
                catch { closeFailures.append(error) }
            }
            var failures = destroyFailures + closeFailures
            if let spawnedProcess {
                do {
                    try EngineManagedProbeLifecycleV1.abortSuspended(
                        process: spawnedProcess,
                        maximumOutputBytes: 1
                    )
                } catch {
                    failures.append(error)
                }
            }
            guard !failures.isEmpty else { throw primary }
            throw EngineRuntimeCleanupAggregateErrorV1(
                primary: primary,
                cleanupFailures: failures
            )
        }
    }

    private static func cStrings(
        _ values: [String]
    ) throws -> [UnsafeMutablePointer<CChar>?] {
        var result: [UnsafeMutablePointer<CChar>?] = []
        for value in values {
            guard !value.utf8.contains(0), let pointer = strdup(value) else {
                freeCStrings(result)
                throw EngineRuntimeAuthorityErrorV1.managedPolicy
            }
            result.append(pointer)
        }
        result.append(nil)
        return result
    }

    private static func freeCStrings(
        _ values: [UnsafeMutablePointer<CChar>?]
    ) {
        for pointer in values { if let pointer { free(pointer) } }
    }

    private static func closeDescriptorOnce(
        _ descriptor: inout Int32
    ) throws {
        try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
    }

    private static func destroy(
        actions: inout posix_spawn_file_actions_t?,
        actionsInitialized: inout Bool,
        attributes: inout posix_spawnattr_t?,
        attributesInitialized: inout Bool
    ) -> [any Error] {
        var failures: [any Error] = []
        if actionsInitialized {
            let code = posix_spawn_file_actions_destroy(&actions)
            actionsInitialized = false
            if code != 0 {
                failures.append(
                    EngineRuntimeAuthorityErrorV1.descriptorFailure(code)
                )
            }
        }
        if attributesInitialized {
            let code = posix_spawnattr_destroy(&attributes)
            attributesInitialized = false
            if code != 0 {
                failures.append(
                    EngineRuntimeAuthorityErrorV1.descriptorFailure(code)
                )
            }
        }
        return failures
    }
}

package enum EngineCliManagedPolicyValidatorV1 {
    private static let probeDeadline: Duration = .seconds(5)
    private static let maximumOutputBytes = 64 * 1_024

    package static func codex(
        processInspector: any EngineRuntimeProcessInspectingV1
    ) -> EngineCliManagedPolicyValidateV1 {
        { executableAuthority in
            guard executableAuthority.kind == .cliCodex else {
                throw EngineRuntimeAuthorityErrorV1.managedPolicy
            }
            try validateStagedAuthority(executableAuthority)
            for path in [
                "/etc/codex/config.toml",
                "/etc/codex/managed_config.toml",
            ] {
                try requireExactENOENT(path)
            }
            try requireNilManagedPreferences(
                applicationID: "com.openai.codex",
                keys: ["config", "managedConfig", "requirements"]
            )
            try requireExactNonEnrolledProfilesOutput(
                processInspector: processInspector
            )
            let account = try runBoundedStagedProbe(
                executableAuthority,
                arguments: ["app-server", "account/read"],
                processInspector: processInspector
            )
            try validateCodexProAccount(account)
            try validateStagedAuthority(executableAuthority)
        }
    }

    package static func claude(
        processInspector: any EngineRuntimeProcessInspectingV1
    ) -> EngineCliManagedPolicyValidateV1 {
        { executableAuthority in
            guard executableAuthority.kind == .cliClaude else {
                throw EngineRuntimeAuthorityErrorV1.managedPolicy
            }
            try validateStagedAuthority(executableAuthority)
            let username = try currentUsername()
            for path in [
                "/Library/Application Support/ClaudeCode/managed-settings.json",
                "/Library/Managed Preferences/com.anthropic.claude-code.plist",
                "/Library/Managed Preferences/\(username)/com.anthropic.claude-code.plist",
            ] {
                try requireExactENOENT(path)
            }
            try requireNilManagedPreferences(
                applicationID: "com.anthropic.claude-code",
                keys: ["managedSettings", "policy", "requirements"]
            )
            try requireExactNonEnrolledProfilesOutput(
                processInspector: processInspector
            )
            let status = try runBoundedStagedProbe(
                executableAuthority,
                arguments: ["auth", "status", "--json"],
                processInspector: processInspector
            )
            try validateClaudeProAccount(status)
            try validateStagedAuthority(executableAuthority)
        }
    }

    private static func validateStagedAuthority(
        _ authority: CliExecutableAuthorityV1
    ) throws {
        try authority.validateCanonical()
        let file = try EngineRuntimeIdentityReaderV1.file(
            path: authority.stagedPath,
            requireExecutable: true
        )
        guard file.device == authority.stagedDevice,
              file.inode == authority.stagedInode,
              file.hash == authority.executableHash
        else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }
        try authority.revalidateStagedCodeSignature()
    }

    private static func requireExactENOENT(_ path: String) throws {
        var info = stat()
        let result = path.withCString { Darwin.lstat($0, &info) }
        let failure = errno
        guard result == -1, failure == ENOENT else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }
    }

    private static func requireNilManagedPreferences(
        applicationID: String,
        keys: [String]
    ) throws {
        for key in keys {
            let value = CFPreferencesCopyValue(
                key as CFString,
                applicationID as CFString,
                kCFPreferencesAnyUser,
                kCFPreferencesCurrentHost
            )
            guard value == nil else {
                throw EngineRuntimeAuthorityErrorV1.managedPolicy
            }
        }
    }

    private static func requireExactNonEnrolledProfilesOutput(
        processInspector: any EngineRuntimeProcessInspectingV1
    ) throws {
        // The system enrollment proof is deliberately a fixed, nonsecret read;
        // vendor identity is never resolved through PATH for this gate.
        let path = "/usr/bin/profiles"
        let file = try EngineRuntimeIdentityReaderV1.file(
            path: path,
            requireExecutable: true
        )
        let signing = try EngineRuntimeIdentityReaderV1.signing(path: path)
        let expected = EngineOwnedRuntimeExecutableV1(
            executablePath: path,
            executableDevice: file.device,
            executableInode: file.inode,
            executableHash: file.hash,
            designatedRequirement: signing.designatedRequirement,
            cdHash: signing.cdHash
        )
        let process = try EngineManagedProbeSpawnerV1.spawnSuspended(
            executablePath: path,
            arguments: ["status", "-type", "enrollment"],
            environment: [
                "LANG": "C", "LC_ALL": "C", "PATH": "/usr/bin:/bin",
            ],
            expected: expected,
            processInspector: processInspector,
            deadline: probeDeadline
        )
        let stdout = try EngineManagedProbeLifecycleV1.run(
            process: process,
            maximumOutputBytes: maximumOutputBytes
        )
        guard stdout == Data(
                  "Enrolled via DEP: No\nMDM enrollment: No\n".utf8
              )
        else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }
    }

    private static func currentUsername() throws -> String {
        let capacity = max(Int(sysconf(_SC_GETPW_R_SIZE_MAX)), 1_024)
        var record = passwd()
        var result: UnsafeMutablePointer<passwd>?
        var buffer = [CChar](repeating: 0, count: capacity)
        let code = buffer.withUnsafeMutableBufferPointer {
            getpwuid_r(
                getuid(),
                &record,
                $0.baseAddress,
                $0.count,
                &result
            )
        }
        guard code == 0,
              result != nil,
              let name = record.pw_name,
              name.pointee != 0
        else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }
        return String(cString: name)
    }

    private static func validateCodexProAccount(_ bytes: Data) throws {
        guard let object = try JSONSerialization.jsonObject(with: bytes)
                as? [String: Any],
              Set(object.keys) == ["account", "requiresOpenAIAuth"],
              object["requiresOpenAIAuth"] as? Bool == true,
              let account = object["account"] as? [String: Any],
              Set(account.keys) == ["planType"],
              account["planType"] as? String == "pro"
        else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }
    }

    private static func validateClaudeProAccount(_ bytes: Data) throws {
        guard let object = try JSONSerialization.jsonObject(with: bytes)
                as? [String: Any],
              Set(object.keys) == ["loggedIn", "subscriptionType"],
              object["loggedIn"] as? Bool == true,
              object["subscriptionType"] as? String == "pro"
        else {
            throw EngineRuntimeAuthorityErrorV1.managedPolicy
        }
    }

    private static func runBoundedStagedProbe(
        _ authority: CliExecutableAuthorityV1,
        arguments: [String],
        processInspector: any EngineRuntimeProcessInspectingV1
    ) throws -> Data {
        try validateStagedAuthority(authority)
        let expected = EngineOwnedRuntimeExecutableV1(
            executablePath: authority.stagedPath,
            executableDevice: authority.stagedDevice,
            executableInode: authority.stagedInode,
            executableHash: authority.executableHash,
            designatedRequirement: authority.designatedRequirement,
            cdHash: authority.cdHash
        )
        let process = try EngineManagedProbeSpawnerV1.spawnSuspended(
            executablePath: authority.stagedPath,
            arguments: arguments,
            environment: [
                "HOME": "/dev/null",
                "LANG": "C",
                "LC_ALL": "C",
                "PATH": "/usr/bin:/bin",
            ],
            expected: expected,
            processInspector: processInspector,
            deadline: probeDeadline
        )
        let stdout = try EngineManagedProbeLifecycleV1.run(
            process: process,
            maximumOutputBytes: maximumOutputBytes
        )
        try validateStagedAuthority(authority)
        return stdout
    }
}

package final class EngineSynchronousLazyCellV1<Value: Sendable>:
    @unchecked Sendable
{
    private enum State {
        case unresolved
        case resolving(ObjectIdentifier)
        case resolved(Value)
    }

    private let condition = NSCondition()
    private let maker: @Sendable () throws -> Value
    private var state: State = .unresolved

    package init(_ maker: @escaping @Sendable () throws -> Value) {
        self.maker = maker
    }

    package var isResolved: Bool {
        condition.lock()
        defer { condition.unlock() }
        if case .resolved = state { return true }
        return false
    }

    package func makeValueClosure() -> @Sendable () throws -> Value {
        { [self] in try value() }
    }

    private func value() throws -> Value {
        let caller = ObjectIdentifier(Thread.current)
        while true {
            condition.lock()
            switch state {
            case .resolved(let value):
                condition.unlock()
                return value
            case .resolving(let owner):
                if owner == caller {
                    condition.unlock()
                    throw EngineRuntimeAuthorityErrorV1.managedPolicy
                }
                condition.wait()
                condition.unlock()
                continue
            case .unresolved:
                state = .resolving(caller)
                condition.unlock()
            }
            break
        }

        do {
            let made = try maker()
            condition.lock()
            if case .resolving(let owner) = state, owner == caller {
                state = .resolved(made)
            }
            condition.broadcast()
            condition.unlock()
            return made
        } catch {
            condition.lock()
            if case .resolving(let owner) = state, owner == caller {
                state = .unresolved
            }
            condition.broadcast()
            condition.unlock()
            throw error
        }
    }
}

package enum EngineRuntimeTeardownStepKindV1:
    Sendable, Hashable
{
    case retainedCliGenerations
    case retainedBridgeGenerations
    case currentBootResidue
    case boardSocketAuthority
    case runtimeDirectoryDescriptors
}

package struct EngineRuntimeTeardownStepV1: Sendable {
    package let kind: EngineRuntimeTeardownStepKindV1
    fileprivate let operation: @Sendable () throws -> Void

    package init(
        kind: EngineRuntimeTeardownStepKindV1,
        operation: @escaping @Sendable () throws -> Void
    ) {
        self.kind = kind
        self.operation = operation
    }
}

package final class EngineCheckedRuntimeTeardownV1:
    @unchecked Sendable
{
    private let lock = NSLock()
    private let outstandingCaptureCount: @Sendable () -> Int
    private var steps: [EngineRuntimeTeardownStepV1]
    private var closed = false

    package init(
        outstandingCaptureCount: @escaping @Sendable () -> Int,
        steps: [EngineRuntimeTeardownStepV1]
    ) {
        self.outstandingCaptureCount = outstandingCaptureCount
        self.steps = steps
    }

    package func requireOpen() throws {
        try lock.withLock {
            guard !closed else {
                throw EngineRuntimeAuthorityErrorV1.authorityClosed
            }
        }
    }

    package func close() throws {
        let ownedSteps = try lock.withLock {
            guard !closed else {
                throw EngineRuntimeAuthorityErrorV1.authorityClosed
            }
            guard outstandingCaptureCount() == 0 else {
                throw EngineRuntimeAuthorityErrorV1.outstandingLeases
            }
            closed = true
            let values = steps
            steps = []
            return values
        }
        let failures = EngineRuntimeCleanupV1.runAll(
            ownedSteps.map { step in { try step.operation() } }
        )
        try EngineRuntimeCleanupV1.throwCleanupFailures(failures)
    }

    deinit {
        let ownedSteps = lock.withLock { () -> [EngineRuntimeTeardownStepV1] in
            guard !closed else { return [] }
            closed = true
            let values = steps
            steps = []
            return values
        }
        for step in ownedSteps {
            do {
                try step.operation()
            } catch {
                assertionFailure(
                    "unchecked runtime teardown failed: \(error)"
                )
            }
        }
    }
}

package struct EngineAdapterRegistryCompositionOperationsV1: Sendable {
    package let identifyAndStage:
        @Sendable (RuntimeProfileKind, String) throws
            -> CliExecutableAuthorityV1
    package let snapshot:
        @Sendable (CliExecutableAuthorityV1) async throws
            -> CliHelpSnapshotV1
    package let validateRegistration:
        @Sendable (EngineAdapterFactoryV1, CliHelpSnapshotV1) throws -> Void
    package let sourceIdentityMatches:
        @Sendable (CliExecutableAuthorityV1) throws -> Bool
    package let removeStagedAuthority:
        @Sendable (CliExecutableAuthorityV1) throws -> Void
    package let identifyAndStageBoardBridge:
        @Sendable () throws -> EngineBoardBridgeExecutableAuthorityV1
    package let bridgeSourceIdentityMatches:
        @Sendable (EngineBoardBridgeExecutableAuthorityV1) throws -> Bool
    package let removeStagedBridgeAuthority:
        @Sendable (EngineBoardBridgeExecutableAuthorityV1) throws -> Void

    package init(
        identifyAndStage: @escaping @Sendable (
            RuntimeProfileKind, String
        ) throws -> CliExecutableAuthorityV1,
        snapshot: @escaping @Sendable (
            CliExecutableAuthorityV1
        ) async throws -> CliHelpSnapshotV1,
        validateRegistration: @escaping @Sendable (
            EngineAdapterFactoryV1, CliHelpSnapshotV1
        ) throws -> Void,
        sourceIdentityMatches: @escaping @Sendable (
            CliExecutableAuthorityV1
        ) throws -> Bool,
        removeStagedAuthority: @escaping @Sendable (
            CliExecutableAuthorityV1
        ) throws -> Void,
        identifyAndStageBoardBridge: @escaping @Sendable () throws
            -> EngineBoardBridgeExecutableAuthorityV1,
        bridgeSourceIdentityMatches: @escaping @Sendable (
            EngineBoardBridgeExecutableAuthorityV1
        ) throws -> Bool,
        removeStagedBridgeAuthority: @escaping @Sendable (
            EngineBoardBridgeExecutableAuthorityV1
        ) throws -> Void
    ) {
        self.identifyAndStage = identifyAndStage
        self.snapshot = snapshot
        self.validateRegistration = validateRegistration
        self.sourceIdentityMatches = sourceIdentityMatches
        self.removeStagedAuthority = removeStagedAuthority
        self.identifyAndStageBoardBridge = identifyAndStageBoardBridge
        self.bridgeSourceIdentityMatches = bridgeSourceIdentityMatches
        self.removeStagedBridgeAuthority = removeStagedBridgeAuthority
    }
}

private struct EngineAdapterRegistryGenerationV1: Sendable {
    let requestedProfileKinds: Set<RuntimeProfileKind>
    let registry: EngineAdapterRegistryV1
    let executableAuthorities:
        [RuntimeProfileKind: CliExecutableAuthorityV1]
    let bridgeExecutableAuthority:
        EngineBoardBridgeExecutableAuthorityV1?
}

fileprivate struct EngineAdapterRegistryCompositionV1: Sendable {
    let registry: EngineAdapterRegistryV1
    let bridgeExecutableAuthority:
        EngineBoardBridgeExecutableAuthorityV1?
}

private struct EngineAdapterRegistryAcquisitionTransactionV1 {
    var cli: [CliExecutableAuthorityV1] = []
    var bridge: EngineBoardBridgeExecutableAuthorityV1?
}

package struct EngineAdapterRegistryRetainedAuthoritiesV1: Sendable {
    package let cli: [CliExecutableAuthorityV1]
    package let bridge: [EngineBoardBridgeExecutableAuthorityV1]
}

package enum EngineRuntimeBridgeTeardownAuthoritiesV1 {
    package static func merge(
        composer: [EngineBoardBridgeExecutableAuthorityV1],
        manager: [EngineBoardBridgeExecutableAuthorityV1]
    ) -> [EngineBoardBridgeExecutableAuthorityV1] {
        var byPath = Dictionary(
            uniqueKeysWithValues: composer.map { ($0.stagedPath, $0) }
        )
        for authority in manager {
            byPath[authority.stagedPath] = authority
        }
        return byPath.values.sorted { $0.stagedPath < $1.stagedPath }
    }
}

package actor EngineAdapterRegistryComposerV1 {
    private let factories: [EngineAdapterFactoryV1]
    private let operations: EngineAdapterRegistryCompositionOperationsV1
    private var generations: [EngineAdapterRegistryGenerationV1] = []
    private var cleanupPendingCLI: [String: CliExecutableAuthorityV1] = [:]
    private var cleanupPendingBridge:
        [String: EngineBoardBridgeExecutableAuthorityV1] = [:]
    private var closed = false

    package init(
        factories: [EngineAdapterFactoryV1],
        operations: EngineAdapterRegistryCompositionOperationsV1
    ) {
        self.factories = factories
        self.operations = operations
    }

    package func registry(
        requestedProfileKinds: Set<RuntimeProfileKind>
    ) async throws -> EngineAdapterRegistryV1 {
        try await composition(
            requestedProfileKinds: requestedProfileKinds
        ).registry
    }

    fileprivate func composition(
        requestedProfileKinds: Set<RuntimeProfileKind>
    ) async throws -> EngineAdapterRegistryCompositionV1 {
        guard !closed else {
            throw EngineRuntimeAuthorityErrorV1.authorityClosed
        }
        var transaction = EngineAdapterRegistryAcquisitionTransactionV1()
        do {
            if let retained = generations.reversed().first(where: {
                $0.requestedProfileKinds == requestedProfileKinds
            }), try generationStillMatches(retained) {
                return EngineAdapterRegistryCompositionV1(
                    registry: retained.registry,
                    bridgeExecutableAuthority:
                        retained.bridgeExecutableAuthority
                )
            }

            let modelFactories = try requireModelFactories()
            var admittedFactories = modelFactories
            var helpSnapshots:
                [RuntimeProfileKind: CliHelpSnapshotV1] = [:]
            var authorities:
                [RuntimeProfileKind: CliExecutableAuthorityV1] = [:]

            let requestedCLI = requestedProfileKinds.filter {
                $0 == .cliCodex || $0 == .cliClaude
            }.sorted { $0.rawValue < $1.rawValue }
            for kind in requestedCLI {
                guard let factory = factory(for: kind),
                      let requirement = factory.helpRequirement,
                      requirement.kind == kind
                else { continue }

                if let retained = try reusableCLI(kind: kind) {
                    admittedFactories.append(factory)
                    helpSnapshots[kind] = retained.snapshot
                    authorities[kind] = retained.authority
                    continue
                }

                var staged: CliExecutableAuthorityV1?
                do {
                    let authority = try operations.identifyAndStage(
                        kind,
                        requirement.command
                    )
                    staged = authority
                    transaction.cli.append(authority)
                    let snapshot = try await operations.snapshot(authority)
                    guard snapshot.executableAuthority == authority,
                          try operations.sourceIdentityMatches(authority)
                    else {
                        throw EngineRuntimeAuthorityErrorV1.processDrift
                    }
                    try operations.validateRegistration(factory, snapshot)
                    admittedFactories.append(factory)
                    helpSnapshots[kind] = snapshot
                    authorities[kind] = authority
                } catch {
                    let primary = error
                    var cleanupFailures: [any Error] = []
                    if let staged {
                        if let failure = removeOwnedCLI(staged) {
                            cleanupFailures.append(failure)
                        }
                        transaction.cli.removeAll {
                            $0.stagedPath == staged.stagedPath
                        }
                    }
                    if !cleanupFailures.isEmpty {
                        throw EngineRuntimeCleanupAggregateErrorV1(
                            primary: primary,
                            cleanupFailures: cleanupFailures
                        )
                    }
                    guard canOmitCLI(primary) else { throw primary }
                }
            }

            var bridge: EngineBoardBridgeExecutableAuthorityV1?
            if !authorities.isEmpty {
                if let retainedBridge = try reusableBridge() {
                    bridge = retainedBridge
                } else {
                    do {
                        let value = try operations
                            .identifyAndStageBoardBridge()
                        transaction.bridge = value
                        guard try operations
                            .bridgeSourceIdentityMatches(value)
                        else {
                            throw EngineRuntimeAuthorityErrorV1.processDrift
                        }
                        bridge = value
                    } catch {
                        let primary = error
                        guard canOmitBridge(primary) else { throw primary }
                        let cleanupFailures = unwind(&transaction)
                        if !cleanupFailures.isEmpty {
                            throw EngineRuntimeCleanupAggregateErrorV1(
                                primary: primary,
                                cleanupFailures: cleanupFailures
                            )
                        }
                        admittedFactories = modelFactories
                        helpSnapshots = [:]
                        authorities = [:]
                        bridge = nil
                    }
                }
            }

            let registry = try EngineAdapterRegistryV1(
                factories: admittedFactories,
                helpSnapshots: helpSnapshots
            )
            let generation = EngineAdapterRegistryGenerationV1(
                requestedProfileKinds: requestedProfileKinds,
                registry: registry,
                executableAuthorities: authorities,
                bridgeExecutableAuthority: bridge
            )
            generations.append(generation)
            return EngineAdapterRegistryCompositionV1(
                registry: registry,
                bridgeExecutableAuthority: bridge
            )
        } catch {
            try throwAfterUnwinding(
                error,
                transaction: &transaction
            )
        }
    }

    private func canOmitCLI(_ error: any Error) -> Bool {
        if let failure = error as? CliHelpProbeFailureV1 {
            return failure == .sourceIdentity
                || failure == .unsupportedVersion
        }
        if let failure = error as? EngineAdapterSelectionErrorV1,
           case .unsupportedCapability = failure
        {
            return true
        }
        return (error as? EngineRuntimeAuthorityErrorV1) == .processDrift
    }

    private func canOmitBridge(_ error: any Error) -> Bool {
        guard let failure = error as? EngineRuntimeAuthorityErrorV1 else {
            return false
        }
        return failure == .invalidDirectory || failure == .processDrift
    }

    private func unwind(
        _ transaction: inout EngineAdapterRegistryAcquisitionTransactionV1
    ) -> [any Error] {
        var failures: [any Error] = []
        if let bridge = transaction.bridge,
           let failure = removeOwnedBridge(bridge)
        {
            failures.append(failure)
        }
        for authority in transaction.cli.reversed() {
            if let failure = removeOwnedCLI(authority) {
                failures.append(failure)
            }
        }
        transaction = EngineAdapterRegistryAcquisitionTransactionV1()
        return failures
    }

    private func throwAfterUnwinding(
        _ primary: any Error,
        transaction: inout EngineAdapterRegistryAcquisitionTransactionV1,
        initialCleanupFailures: [any Error] = []
    ) throws -> Never {
        let failures = initialCleanupFailures + unwind(&transaction)
        guard !failures.isEmpty else { throw primary }
        throw EngineRuntimeCleanupAggregateErrorV1(
            primary: primary,
            cleanupFailures: failures
        )
    }

    package func takeRetainedAuthoritiesForTeardown() throws
        -> EngineAdapterRegistryRetainedAuthoritiesV1
    {
        guard !closed else {
            throw EngineRuntimeAuthorityErrorV1.authorityClosed
        }
        closed = true
        var cliByPath: [String: CliExecutableAuthorityV1] = [:]
        var bridgeByPath: [String: EngineBoardBridgeExecutableAuthorityV1] = [:]
        for authority in cleanupPendingCLI.values {
            cliByPath[authority.stagedPath] = authority
        }
        for authority in cleanupPendingBridge.values {
            bridgeByPath[authority.stagedPath] = authority
        }
        for generation in generations {
            for authority in generation.executableAuthorities.values {
                cliByPath[authority.stagedPath] = authority
            }
            if let authority = generation.bridgeExecutableAuthority {
                bridgeByPath[authority.stagedPath] = authority
            }
        }
        generations = []
        cleanupPendingCLI = [:]
        cleanupPendingBridge = [:]
        return EngineAdapterRegistryRetainedAuthoritiesV1(
            cli: cliByPath.values.sorted { $0.stagedPath < $1.stagedPath },
            bridge: bridgeByPath.values.sorted {
                $0.stagedPath < $1.stagedPath
            }
        )
    }

    private func generationStillMatches(
        _ generation: EngineAdapterRegistryGenerationV1
    ) throws -> Bool {
        let requestedCLI = Set(generation.requestedProfileKinds.filter {
            $0 == .cliCodex || $0 == .cliClaude
        })
        guard Set(generation.executableAuthorities.keys) == requestedCLI else {
            return false
        }
        for authority in generation.executableAuthorities.values {
            guard try operations.sourceIdentityMatches(authority) else {
                return false
            }
        }
        if generation.executableAuthorities.isEmpty {
            return generation.bridgeExecutableAuthority == nil
        }
        guard let bridge = generation.bridgeExecutableAuthority else {
            return false
        }
        return try operations.bridgeSourceIdentityMatches(bridge)
    }

    private func removeOwnedCLI(
        _ authority: CliExecutableAuthorityV1
    ) -> (any Error)? {
        do {
            try operations.removeStagedAuthority(authority)
            cleanupPendingCLI.removeValue(forKey: authority.stagedPath)
            return nil
        } catch {
            cleanupPendingCLI[authority.stagedPath] = authority
            return error
        }
    }

    private func removeOwnedBridge(
        _ authority: EngineBoardBridgeExecutableAuthorityV1
    ) -> (any Error)? {
        do {
            try operations.removeStagedBridgeAuthority(authority)
            cleanupPendingBridge.removeValue(forKey: authority.stagedPath)
            return nil
        } catch {
            cleanupPendingBridge[authority.stagedPath] = authority
            return error
        }
    }

    private func reusableCLI(
        kind: RuntimeProfileKind
    ) throws -> (
        authority: CliExecutableAuthorityV1,
        snapshot: CliHelpSnapshotV1
    )? {
        for generation in generations.reversed() {
            guard let authority = generation.executableAuthorities[kind],
                  let snapshot = generation.registry.helpSnapshots[kind]
            else { continue }
            if try operations.sourceIdentityMatches(authority) {
                return (authority, snapshot)
            }
        }
        return nil
    }

    private func reusableBridge() throws
        -> EngineBoardBridgeExecutableAuthorityV1?
    {
        for generation in generations.reversed() {
            guard let authority = generation.bridgeExecutableAuthority else {
                continue
            }
            if try operations.bridgeSourceIdentityMatches(authority) {
                return authority
            }
        }
        return nil
    }

    private func requireModelFactories() throws
        -> [EngineAdapterFactoryV1]
    {
        let values = factories.filter { factory in
            factory.helpRequirement == nil
                && !factory.profileKinds.isEmpty
                && factory.profileKinds.allSatisfy { !$0.isCLI }
        }
        let claimedKinds = values.flatMap { $0.profileKinds }
        guard !values.isEmpty,
              Set(claimedKinds).count == claimedKinds.count
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        return values
    }

    private func factory(
        for kind: RuntimeProfileKind
    ) -> EngineAdapterFactoryV1? {
        factories.first { $0.profileKinds == [kind] }
    }
}

package enum EnginePackagedBridgeStagedOwnershipV1 {
    package typealias SignatureInspector = @Sendable (String) throws
        -> EngineRuntimeSigningIdentitySnapshotV1

    package static func capture(
        authority: EngineBoardBridgeExecutableAuthorityV1,
        stagingDirectory: URL,
        inspectSignature: SignatureInspector
    ) throws -> EngineRuntimeExecutableRemovalSnapshotV1 {
        let authorityName = try validateLocation(
            authority.stagedPath,
            stagingDirectory: stagingDirectory
        )
        let snapshot = try withStagingDescriptor(
            stagingDirectory: stagingDirectory
        ) { descriptor in
            try EngineRuntimeExecutableRemovalValidatorV1.capture(
                parentDescriptor: descriptor,
                authorityName: authorityName,
                inspectSignature: inspectSignature
            )
        }
        guard snapshot.executablePath == authority.stagedPath,
              snapshot.executableDevice == authority.stagedDevice,
              snapshot.executableInode == authority.stagedInode,
              snapshot.executableHash == authority.executableHash,
              snapshot.signing.designatedRequirement
                == authority.designatedRequirement,
              snapshot.signing.teamIdentifier == authority.teamIdentifier,
              snapshot.signing.cdHash == authority.cdHash
        else {
            throw EngineRuntimeAuthorityErrorV1.processDrift
        }
        return snapshot
    }

    package static func remove(
        snapshot: EngineRuntimeExecutableRemovalSnapshotV1,
        stagingDirectory: URL,
        inspectSignature: SignatureInspector
    ) throws {
        let authorityName = try validateLocation(
            snapshot.executablePath,
            stagingDirectory: stagingDirectory
        )
        guard authorityName == snapshot.authorityName else {
            throw EngineRuntimeAuthorityErrorV1.processDrift
        }
        try withStagingDescriptor(stagingDirectory: stagingDirectory) {
            descriptor in
            try EngineRuntimeExecutableRemovalValidatorV1.removeImmediately(
                snapshot,
                parentDescriptor: descriptor,
                inspectSignature: inspectSignature
            )
        }
    }

    private static func validateLocation(
        _ executablePath: String,
        stagingDirectory: URL
    ) throws -> String {
        let executableURL = URL(fileURLWithPath: executablePath)
        let authorityDirectory = executableURL.deletingLastPathComponent()
        guard stagingDirectory.isFileURL,
              stagingDirectory.baseURL == nil,
              stagingDirectory.path.hasPrefix("/"),
              stagingDirectory.standardizedFileURL.path
                == stagingDirectory.path,
              executablePath.hasPrefix("/"),
              executableURL.standardizedFileURL.path == executablePath,
              executableURL.lastPathComponent == "executable",
              authorityDirectory.deletingLastPathComponent().path
                == stagingDirectory.path,
              authorityDirectory.lastPathComponent.hasPrefix(
                  "board-bridge-"
              )
        else {
            throw EngineRuntimeAuthorityErrorV1.invalidDirectory
        }
        return authorityDirectory.lastPathComponent
    }

    private static func withStagingDescriptor<T>(
        stagingDirectory: URL,
        operation: (Int32) throws -> T
    ) throws -> T {
        var descriptor = stagingDirectory.path.withCString {
            Darwin.open(
                $0,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard descriptor >= 0 else {
            throw EngineRuntimeAuthorityErrorV1.descriptorFailure(errno)
        }
        do {
            let result = try operation(descriptor)
            try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
            return result
        } catch {
            try EngineRuntimeCleanupV1.throwPreserving(
                error,
                cleanup: [{
                    try EngineRuntimeOwnedDescriptorV1.closeOnce(&descriptor)
                }]
            )
        }
    }
}

package struct EnginePackagedBridgeGenerationOperationsV1: Sendable {
    package let loadPackageIdentity: @Sendable () throws
        -> EnginePackagedBridgePackageIdentityV1
    package let stage: @Sendable () throws
        -> EngineBoardBridgeExecutableAuthorityV1
    package let captureRemovalSnapshot: @Sendable (
        EngineBoardBridgeExecutableAuthorityV1
    ) throws -> EngineRuntimeExecutableRemovalSnapshotV1
    package let removeStaged: @Sendable (
        EngineRuntimeExecutableRemovalSnapshotV1
    ) throws -> Void

    package init(
        loadPackageIdentity: @escaping @Sendable () throws
            -> EnginePackagedBridgePackageIdentityV1,
        stage: @escaping @Sendable () throws
            -> EngineBoardBridgeExecutableAuthorityV1,
        captureRemovalSnapshot: @escaping @Sendable (
            EngineBoardBridgeExecutableAuthorityV1
        ) throws -> EngineRuntimeExecutableRemovalSnapshotV1,
        removeStaged: @escaping @Sendable (
            EngineRuntimeExecutableRemovalSnapshotV1
        ) throws -> Void
    ) {
        self.loadPackageIdentity = loadPackageIdentity
        self.stage = stage
        self.captureRemovalSnapshot = captureRemovalSnapshot
        self.removeStaged = removeStaged
    }
}

package final class EnginePackagedBridgeGenerationManagerV1:
    @unchecked Sendable
{
    private struct Record: Sendable {
        let authority: EngineBoardBridgeExecutableAuthorityV1
        let packageIdentity: EnginePackagedBridgePackageIdentityV1
        var removalSnapshot: EngineRuntimeExecutableRemovalSnapshotV1?
        var unclaimed: Bool
    }

    private let lock = NSLock()
    private let operations: EnginePackagedBridgeGenerationOperationsV1
    private var records: [String: Record] = [:]

    init(
        sourcePath: String?,
        stagingDirectory: URL,
        probe: CliHelpProbeV1
    ) {
        operations = EnginePackagedBridgeGenerationOperationsV1(
            loadPackageIdentity: {
                guard let sourcePath else {
                    throw EngineRuntimeAuthorityErrorV1.invalidDirectory
                }
                return try EnginePackagedBridgeAuthenticityReaderV1.validate(
                    helperSourcePath: sourcePath
                )
            },
            stage: {
                guard let sourcePath else {
                    throw EngineRuntimeAuthorityErrorV1.invalidDirectory
                }
                return try probe.identifyAndStageBoardBridge(
                    sourcePath: sourcePath,
                    stagingDirectory: stagingDirectory
                )
            },
            captureRemovalSnapshot: { authority in
                try EnginePackagedBridgeStagedOwnershipV1.capture(
                    authority: authority,
                    stagingDirectory: stagingDirectory,
                    inspectSignature: {
                        try EngineRuntimeIdentityReaderV1.signing(path: $0)
                    }
                )
            },
            removeStaged: { snapshot in
                try EnginePackagedBridgeStagedOwnershipV1.remove(
                    snapshot: snapshot,
                    stagingDirectory: stagingDirectory,
                    inspectSignature: {
                        try EngineRuntimeIdentityReaderV1.signing(path: $0)
                    }
                )
            }
        )
    }

    package init(
        operations: EnginePackagedBridgeGenerationOperationsV1
    ) {
        self.operations = operations
    }

    package func identifyAndStage() throws
        -> EngineBoardBridgeExecutableAuthorityV1
    {
        let packageIdentity = try operations.loadPackageIdentity()
        let authority = try operations.stage()
        try lock.withLock {
            guard records[authority.stagedPath] == nil else {
                throw EngineRuntimeAuthorityErrorV1.processDrift
            }
            records[authority.stagedPath] = Record(
                authority: authority,
                packageIdentity: packageIdentity,
                removalSnapshot: nil,
                unclaimed: false
            )
        }
        do {
            let snapshot = try operations.captureRemovalSnapshot(authority)
            try lock.withLock {
                guard var record = records[authority.stagedPath],
                      record.authority == authority
                else {
                    throw EngineRuntimeAuthorityErrorV1.processDrift
                }
                record.removalSnapshot = snapshot
                records[authority.stagedPath] = record
            }
            return authority
        } catch {
            let primary = error
            lock.withLock {
                guard var record = records[authority.stagedPath],
                      record.authority == authority
                else { return }
                record.unclaimed = true
                records[authority.stagedPath] = record
            }
            do {
                try remove(authority)
            } catch {
                throw EngineRuntimeCleanupAggregateErrorV1(
                    primary: primary,
                    cleanupFailures: [error]
                )
            }
            throw primary
        }
    }

    package func sourceIdentityMatches(
        _ authority: EngineBoardBridgeExecutableAuthorityV1
    ) throws -> Bool {
        guard let record = lock.withLock({ records[authority.stagedPath] }),
              record.authority == authority,
              !record.unclaimed,
              let snapshot = record.removalSnapshot
        else { return false }
        return try sourceIdentityMatches(
            authority,
            expectedPackageIdentity: record.packageIdentity,
            expectedSnapshot: snapshot
        )
    }

    package func retainedUnclaimedAuthoritiesForTeardown()
        -> [EngineBoardBridgeExecutableAuthorityV1]
    {
        lock.withLock {
            records.values.filter(\.unclaimed).map(\.authority).sorted {
                $0.stagedPath < $1.stagedPath
            }
        }
    }

    package func remove(
        _ authority: EngineBoardBridgeExecutableAuthorityV1
    ) throws {
        var record = try lock.withLock { () throws -> Record in
            guard let value = records[authority.stagedPath],
                  value.authority == authority
            else {
                throw EngineRuntimeAuthorityErrorV1.processDrift
            }
            return value
        }
        if record.removalSnapshot == nil {
            let snapshot = try operations.captureRemovalSnapshot(authority)
            record.removalSnapshot = snapshot
            try lock.withLock {
                guard records[authority.stagedPath]?.authority == authority
                else {
                    throw EngineRuntimeAuthorityErrorV1.processDrift
                }
                records[authority.stagedPath] = record
            }
        }
        guard let snapshot = record.removalSnapshot else {
            throw EngineRuntimeAuthorityErrorV1.processDrift
        }
        try operations.removeStaged(snapshot)
        lock.withLock {
            if records[authority.stagedPath]?.authority == authority {
                records.removeValue(forKey: authority.stagedPath)
            }
        }
    }

    private func sourceIdentityMatches(
        _ authority: EngineBoardBridgeExecutableAuthorityV1,
        expectedPackageIdentity: EnginePackagedBridgePackageIdentityV1,
        expectedSnapshot: EngineRuntimeExecutableRemovalSnapshotV1
    ) throws -> Bool {
        guard try EnginePackagedBridgeAuthenticityReaderV1.validate(
            helperSourcePath: authority.sourcePath
        ) == expectedPackageIdentity else { return false }
        let source = try EngineRuntimeIdentityReaderV1.file(
            path: authority.sourcePath,
            requireExecutable: true
        )
        let sourceSigning = try EngineRuntimeIdentityReaderV1.signing(
            path: authority.sourcePath
        )
        let staged = try EngineRuntimeIdentityReaderV1.file(
            path: authority.stagedPath,
            requireExecutable: true
        )
        try authority.revalidateStagedCodeSignature()
        guard source.hash == authority.executableHash,
              staged.hash == authority.executableHash,
              staged.device == authority.stagedDevice,
              staged.inode == authority.stagedInode,
              sourceSigning.designatedRequirement
                == authority.designatedRequirement,
              sourceSigning.teamIdentifier == authority.teamIdentifier,
              sourceSigning.cdHash == authority.cdHash
        else { return false }
        let currentSnapshot = try
            EnginePackagedBridgeStagedOwnershipV1.capture(
            authority: authority,
            stagingDirectory: URL(
                fileURLWithPath: authority.stagedPath
            ).deletingLastPathComponent().deletingLastPathComponent(),
            inspectSignature: {
                try EngineRuntimeIdentityReaderV1.signing(path: $0)
            }
        )
        return currentSnapshot == expectedSnapshot
    }
}

private final class EngineRuntimeDescriptorResolverV1:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var registries:
        [RuntimeProfileKind: EngineAdapterRegistryV1] = [:]

    func install(_ registry: EngineAdapterRegistryV1) {
        lock.withLock {
            for factory in registry.factories {
                for kind in factory.profileKinds {
                    registries[kind] = registry
                }
            }
        }
    }

    func resolve(
        profile: RuntimeProfileRecord,
        requiredCapabilities: [EngineCapabilityV1]
    ) throws -> ExecutionEngineDescriptor {
        let registry = lock.withLock { registries[profile.kind] }
        guard let registry else {
            throw EngineDescriptorMismatchErrorV1()
        }
        return try registry.resolve(
            profile: profile,
            requiredCapabilities: requiredCapabilities
        ).descriptor
    }
}

private struct EngineRuntimePreparedGenerationV1: Sendable {
    let requestFields: EngineExecutionRequestFieldsV1
    let composition: EngineAdapterRegistryCompositionV1
}

package actor EngineExecutionRuntimeV1 {
    package let contextResolver: EngineContextTransportResolverV1
    package let workspaceResolver: EngineWorkspaceResolverV1
    package let artifactBlobStore: ArtifactBlobStore
    package let artifactStorageOriginStore: ArtifactStorageOriginStore
    package let artifactStager: ArtifactStager
    package let activeExecutions: EngineActiveExecutionRegistryV1
    package let completionRegistry: EngineExecutionCompletionRegistryV1

    private let environment: EngineExecutionEnvironmentV1
    private let store: EngineExecutionStore
    private let descriptorResolver: EngineRuntimeDescriptorResolverV1
    private let eventObserver: EngineRoutedEventDidCommitV1
    private let registryComposer: EngineAdapterRegistryComposerV1
    private let bridgeManager: EnginePackagedBridgeGenerationManagerV1
    private let cliDriverCell:
        EngineSynchronousLazyCellV1<any CliProcessDrivingV1>
    private let captureCounter: EngineRuntimeCaptureCounterV1
    private var preparedGenerations:
        [String: EngineRuntimePreparedGenerationV1] = [:]
    private var checkedRuntimeTeardown: EngineCheckedRuntimeTeardownV1?
    private var runtimeClosed = false

    package init(
        environment: EngineExecutionEnvironmentV1,
        factories: [EngineAdapterFactoryV1]? = nil,
        eventObserver: @escaping EngineRoutedEventDidCommitV1
    ) {
        self.environment = environment
        self.eventObserver = eventObserver
        contextResolver = EngineContextTransportResolverV1(
            database: environment.database,
            dependencyLoader: environment.dependencyLoader
        )
        workspaceResolver = EngineWorkspaceResolverV1(
            database: environment.database
        )
        let blobStore = ArtifactBlobStore(
            database: environment.database,
            artifactStoreRoot: environment.artifactStoreRoot,
            stateDirectoryLock: environment.stateDirectoryLock
        )
        artifactBlobStore = blobStore
        let originStore = ArtifactStorageOriginStore(
            database: environment.database
        )
        artifactStorageOriginStore = originStore
        artifactStager = ArtifactStager(
            database: environment.database,
            blobStore: blobStore
        )
        let descriptorResolver = EngineRuntimeDescriptorResolverV1()
        self.descriptorResolver = descriptorResolver
        store = EngineExecutionStore(
            database: environment.database,
            descriptorResolver: { profile, requiredCapabilities in
                try descriptorResolver.resolve(
                    profile: profile,
                    requiredCapabilities: requiredCapabilities
                )
            },
            clock: environment.clock,
            artifactBlobStore: blobStore,
            artifactStorageOriginStore: originStore
        )
        let captureCounter = EngineRuntimeCaptureCounterV1()
        self.captureCounter = captureCounter
        activeExecutions = EngineActiveExecutionRegistryV1(
            captureCounter: captureCounter
        )
        completionRegistry = EngineExecutionCompletionRegistryV1(
            captureCounter: captureCounter
        )
        let helpSnapshotCache = CliHelpSnapshotCacheV1(
            probe: environment.helpProbe
        )
        let selectedFactories = factories ?? Self.builtInFactories()
        let bridgeManager = EnginePackagedBridgeGenerationManagerV1(
            sourcePath: environment.bridgeExecutablePath,
            stagingDirectory: environment.cliExecutableDirectory,
            probe: environment.helpProbe
        )
        self.bridgeManager = bridgeManager
        let operations = EngineAdapterRegistryCompositionOperationsV1(
            identifyAndStage: { kind, command in
                try environment.helpProbe.identifyAndStage(
                    for: kind,
                    command: command,
                    stagingDirectory: environment.cliExecutableDirectory
                )
            },
            snapshot: { authority in
                try await helpSnapshotCache.snapshot(for: authority)
            },
            validateRegistration: { factory, snapshot in
                try factory.validateRegistration(
                    helpSnapshot: snapshot,
                    validateCodexManagedPolicy:
                        environment.validateCodexManagedPolicy,
                    validateClaudeManagedPolicy:
                        environment.validateClaudeManagedPolicy
                )
            },
            sourceIdentityMatches: { authority in
                try Self.sourceIdentityMatches(authority)
            },
            removeStagedAuthority: { authority in
                try environment.helpProbe.removeStagedAuthority(authority)
            },
            identifyAndStageBoardBridge: {
                guard environment.boardSocketDirectoryAuthority != nil else {
                    throw EngineRuntimeAuthorityErrorV1.invalidDirectory
                }
                return try bridgeManager.identifyAndStage()
            },
            bridgeSourceIdentityMatches: { authority in
                try bridgeManager.sourceIdentityMatches(authority)
            },
            removeStagedBridgeAuthority: { authority in
                try bridgeManager.remove(authority)
            }
        )
        registryComposer = EngineAdapterRegistryComposerV1(
            factories: selectedFactories,
            operations: operations
        )
        cliDriverCell = EngineSynchronousLazyCellV1(
            environment.makeCliProcessDriver
        )
    }

    package func prepare(
        _ identity: EngineDispatchIdentityV1
    ) async throws -> EnginePreparedDispatchV1 {
        try requireOpen()
        try validateDispatchIdentity(identity)
        let context = try await contextResolver.prepareCurrent(
            campId: identity.campId,
            cardId: identity.cardId,
            companionId: identity.companionId
        )
        let workspace = try workspaceResolver.prepareCurrent(
            cardId: identity.cardId,
            campId: identity.campId
        )
        var requiredCapabilities = Self.baseRequiredCapabilities
        if context.capabilityTools.requiresWorkspaceWrite {
            requiredCapabilities.append(.workspaceWrite)
        }
        requiredCapabilities = Array(Set(requiredCapabilities)).sorted {
            $0.rawValue < $1.rawValue
        }
        let composition = try await registryComposer.composition(
            requestedProfileKinds: [context.profile.kind]
        )
        descriptorResolver.install(composition.registry)
        let selection = try composition.registry.resolve(
            profile: context.profile,
            requiredCapabilities: requiredCapabilities
        )
        let seed = makeSeed(
            context: context,
            workspace: workspace,
            bridgeExecutableAuthority:
                composition.bridgeExecutableAuthority
        )
        let selected = try selection.prepareRequest(seed)
        guard selected.requiredCapabilities == requiredCapabilities else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        let requestFields = try EngineExecutionRequestFieldsV1(
            campId: identity.campId,
            cardId: identity.cardId,
            contract: context.contract,
            profileId: context.profile.id,
            engineKind: selected.engineKind,
            model: selected.model,
            contextJson: selected.context.request.contextJson,
            contextHash: selected.context.request.contextHash,
            requiredCapabilities: selected.requiredCapabilities,
            approvalGrantIds: [],
            budget: selected.budget,
            workspace: workspace.workspace,
            sessionSelection: nil,
            predecessorExecutionId:
                selected.descriptor.sessionResume == .supported
                    ? identity.cause.causalPredecessorExecutionId
                    : nil,
            claimedSessionScopeJson: nil,
            claimedSessionScopeHash: nil
        )
        let prepared = EnginePreparedDispatchV1(
            requestFields: requestFields,
            idempotencyKey: identity.cause.idempotencyKey,
            context: context,
            workspace: workspace,
            selected: selected
        )
        if let existing = preparedGenerations[prepared.idempotencyKey],
           existing.requestFields != requestFields
        {
            throw EngineExecutionReplayConflictError()
        }
        preparedGenerations[prepared.idempotencyKey] =
            EngineRuntimePreparedGenerationV1(
                requestFields: requestFields,
                composition: composition
            )
        return prepared
    }

    package func execute(
        _ prepared: EnginePreparedDispatchV1,
        onExecutionBound: @escaping EngineExecutionDidBindV1
    ) async throws -> EngineTerminalCommitReceiptV1 {
        try requireOpen()
        guard let generation =
                preparedGenerations[prepared.idempotencyKey],
              generation.requestFields == prepared.requestFields
        else {
            throw EngineDispatchConflictErrorV1()
        }
        descriptorResolver.install(generation.composition.registry)
        return try await makeCoordinator(
            generation.composition
        ).execute(
            prepared,
            onExecutionBound: onExecutionBound
        )
    }

    package func recover(
        missionId: String?,
        now: Date
    ) async throws -> EngineRecoverySummaryV1 {
        try requireOpen()
        let kinds = try await environment.database.pool.read { database in
            try EngineExecutionStore.activeRecoveryProfileKinds(
                database: database
            )
        }
        let composition = try await registryComposer.composition(
            requestedProfileKinds: Set(kinds)
        )
        descriptorResolver.install(composition.registry)
        return try await makeCoordinator(composition).recover(
            missionId: missionId,
            now: now
        )
    }

    package func cancel(
        executionId: String,
        reason: String
    ) async throws {
        try requireOpen()
        try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        let kind = try await environment.database.pool.read { database in
            guard let execution = try EngineExecutionRecord.fetchOne(
                database,
                key: executionId
            ), execution.id == executionId,
               execution.redactedAt == nil,
               let profile = try RuntimeProfileRecord.fetchOne(
                   database,
                   key: execution.profileId
               ), profile.id == execution.profileId
            else {
                throw EngineDescriptorMismatchErrorV1()
            }
            return profile.kind
        }
        let composition = try await registryComposer.composition(
            requestedProfileKinds: [kind]
        )
        descriptorResolver.install(composition.registry)
        try await makeCoordinator(composition).cancel(
            executionId: executionId,
            reason: reason
        )
    }

    package func registry(
        requestedProfileKinds: Set<RuntimeProfileKind>
    ) async throws -> EngineAdapterRegistryV1 {
        try requireOpen()
        let registry = try await registryComposer.registry(
            requestedProfileKinds: requestedProfileKinds
        )
        descriptorResolver.install(registry)
        return registry
    }

    package func makeCliProcessDriver() async throws
        -> any CliProcessDrivingV1
    {
        try requireOpen()
        return try cliDriverCell.makeValueClosure()()
    }

    private static let baseRequiredCapabilities: [EngineCapabilityV1] = [
        .boardTerminal, .cancellation, .network, .streamingProgress,
        .toolBridge, .usageMetering, .workspaceRead,
    ]

    private func requireOpen() throws {
        guard !runtimeClosed else {
            throw EngineRuntimeAuthorityErrorV1.authorityClosed
        }
    }

    private func validateDispatchIdentity(
        _ identity: EngineDispatchIdentityV1
    ) throws {
        do {
            try CanonicalContractCodingV1.validateCampID(identity.campId)
            try CanonicalContractCodingV1.validateCanonicalUUID(
                identity.cardId
            )
            try CanonicalContractCodingV1.validateCanonicalUUID(
                identity.companionId
            )
            try CanonicalContractCodingV1.validateCanonicalUUID(
                identity.cause.eventId
            )
            try EngineContractValidationV1.validateIdempotencyKey(
                identity.cause.idempotencyKey
            )
            if let requestID = identity.cause.answeredRequestId {
                try CanonicalContractCodingV1.validateCanonicalUUID(requestID)
            }
            if let predecessorID =
                identity.cause.causalPredecessorExecutionId
            {
                try CanonicalContractCodingV1.validateCanonicalUUID(
                    predecessorID
                )
            }
        } catch {
            throw EngineContextValidationErrorV1()
        }
        let matches = try environment.database.pool.read { database in
            guard let card = try CardRecord.fetchOne(
                database,
                key: identity.cardId
            ), card.id == identity.cardId,
               card.status == .ready,
               card.assigneeId == identity.companionId,
               let mission = try MissionRecord.fetchOne(
                   database,
                   key: card.missionId
               ), mission.id == card.missionId,
               let squad = try SquadRecord.fetchOne(
                   database,
                   key: mission.squadId
               ), squad.id == mission.squadId,
               squad.campId == identity.campId,
               let camp = try CampRecord.fetchOne(
                   database,
                   key: squad.campId
               ), camp.id == identity.campId
            else {
                return false
            }
            return try environment.database.resolveEngineCardReadyCause(
                for: card,
                in: database
            ) == identity.cause
        }
        guard matches else { throw EngineContextValidationErrorV1() }
    }

    private func makeSeed(
        context: EnginePreparedContextV1,
        workspace: EnginePreparedWorkspaceClaimV1,
        bridgeExecutableAuthority:
            EngineBoardBridgeExecutableAuthorityV1?
    ) -> EngineExecutionTransportSeedV1 {
        EngineExecutionTransportSeedV1(
            context: context,
            workspace: workspace,
            baseRequiredCapabilities: Self.baseRequiredCapabilities,
            bridgeExecutableAuthority: bridgeExecutableAuthority,
            boardSocketDirectoryAuthority:
                environment.boardSocketDirectoryAuthority,
            validateCodexManagedPolicy:
                environment.validateCodexManagedPolicy,
            validateClaudeManagedPolicy:
                environment.validateClaudeManagedPolicy,
            claudeConfigDirectory: environment.claudeConfigDirectory,
            cliExecutableDirectory: environment.cliExecutableDirectory,
            resolveInitialModelLoopProvider:
                environment.resolveInitialModelLoopProvider,
            resolveRecoveryModelLoopProvider:
                environment.resolveRecoveryModelLoopProvider,
            makeCliProcessDriver: cliDriverCell.makeValueClosure()
        )
    }

    private func makeCoordinator(
        _ composition: EngineAdapterRegistryCompositionV1
    ) -> EngineExecutionCoordinatorV1 {
        let environment = self.environment
        let contextResolver = self.contextResolver
        let workspaceResolver = self.workspaceResolver
        let makeCliProcessDriver = cliDriverCell.makeValueClosure()
        let bridgeExecutableAuthority =
            composition.bridgeExecutableAuthority
        let registry = composition.registry
        return EngineExecutionCoordinatorV1(
            store: store,
            registry: registry,
            artifactStager: artifactStager,
            contextResolver: contextResolver,
            workspaceResolver: workspaceResolver,
            transportSeedResolver: { request in
                try await Self.makeRecoverySeed(
                    request: request,
                    environment: environment,
                    contextResolver: contextResolver,
                    workspaceResolver: workspaceResolver,
                    registry: registry,
                    bridgeExecutableAuthority:
                        bridgeExecutableAuthority,
                    makeCliProcessDriver: makeCliProcessDriver
                )
            },
            activeExecutions: activeExecutions,
            completionRegistry: completionRegistry,
            eventObserver: eventObserver,
            clock: environment.clock
        )
    }

    private static func makeRecoverySeed(
        request: EngineExecutionRequest,
        environment: EngineExecutionEnvironmentV1,
        contextResolver: EngineContextTransportResolverV1,
        workspaceResolver: EngineWorkspaceResolverV1,
        registry: EngineAdapterRegistryV1,
        bridgeExecutableAuthority:
            EngineBoardBridgeExecutableAuthorityV1?,
        makeCliProcessDriver:
            @escaping @Sendable () throws -> any CliProcessDrivingV1
    ) async throws -> EngineExecutionTransportSeedV1 {
        try request.validateCanonicalIdentity()
        let companionID = try await environment.database.pool.read {
            database in
            guard let card = try CardRecord.fetchOne(
                database,
                key: request.cardId
            ), card.id == request.cardId,
               let companionID = card.assigneeId
            else {
                throw EngineContextValidationErrorV1()
            }
            return companionID
        }
        let persistedContextRequest = try EngineContextResolveRequestV1(
            campId: request.campId,
            cardId: request.cardId,
            companionId: companionID,
            contextJson: request.contextJson,
            contextHash: request.contextHash
        )
        let context = try await contextResolver.reloadPrepared(
            persistedContextRequest
        )
        let workspace = try workspaceResolver.prepareCurrent(
            cardId: request.cardId,
            campId: request.campId
        )
        guard context.profile.id == request.profileId,
              context.contract == request.contract,
              workspace.workspace == request.workspace
        else {
            throw EngineContextValidationErrorV1()
        }
        _ = try registry.resolve(
            profile: context.profile,
            requiredCapabilities: request.requiredCapabilities
        )
        return EngineExecutionTransportSeedV1(
            context: context,
            workspace: workspace,
            baseRequiredCapabilities: baseRequiredCapabilities,
            bridgeExecutableAuthority: bridgeExecutableAuthority,
            boardSocketDirectoryAuthority:
                environment.boardSocketDirectoryAuthority,
            validateCodexManagedPolicy:
                environment.validateCodexManagedPolicy,
            validateClaudeManagedPolicy:
                environment.validateClaudeManagedPolicy,
            claudeConfigDirectory: environment.claudeConfigDirectory,
            cliExecutableDirectory: environment.cliExecutableDirectory,
            resolveInitialModelLoopProvider:
                environment.resolveInitialModelLoopProvider,
            resolveRecoveryModelLoopProvider:
                environment.resolveRecoveryModelLoopProvider,
            makeCliProcessDriver: makeCliProcessDriver
        )
    }

    package func closeRuntimeAuthorities() async throws {
        guard !runtimeClosed else {
            throw EngineRuntimeAuthorityErrorV1.authorityClosed
        }
        runtimeClosed = true
        try captureCounter.closeIfEmpty()
        let retained = try await registryComposer
            .takeRetainedAuthoritiesForTeardown()
        let retainedBridge = EngineRuntimeBridgeTeardownAuthoritiesV1.merge(
            composer: retained.bridge,
            manager: bridgeManager
                .retainedUnclaimedAuthoritiesForTeardown()
        )
        let runtimeDirectories = environment.boardSocketDirectoryAuthority?
            .retainedRuntimeDirectoryAuthoritySet()
        let probe = environment.helpProbe
        let bridgeManager = self.bridgeManager
        let socketAuthority = environment.boardSocketDirectoryAuthority
        let teardown = EngineCheckedRuntimeTeardownV1(
            outstandingCaptureCount: { self.captureCounter.outstanding },
            steps: [
                EngineRuntimeTeardownStepV1(
                    kind: .retainedCliGenerations
                ) {
                    let failures = EngineRuntimeCleanupV1.runAll(
                        retained.cli.map { authority in
                            { try probe.removeStagedAuthority(authority) }
                        }
                    )
                    try EngineRuntimeCleanupV1
                        .throwCleanupFailures(failures)
                },
                EngineRuntimeTeardownStepV1(
                    kind: .retainedBridgeGenerations
                ) {
                    let failures = EngineRuntimeCleanupV1.runAll(
                        retainedBridge.map { authority in
                            { try bridgeManager.remove(authority) }
                        }
                    )
                    try EngineRuntimeCleanupV1
                        .throwCleanupFailures(failures)
                },
                EngineRuntimeTeardownStepV1(
                    kind: .currentBootResidue
                ) {
                    try runtimeDirectories?.removeCurrentBootResidue()
                },
                EngineRuntimeTeardownStepV1(
                    kind: .boardSocketAuthority
                ) {
                    try socketAuthority?.close()
                },
                EngineRuntimeTeardownStepV1(
                    kind: .runtimeDirectoryDescriptors
                ) {
                    try runtimeDirectories?.close()
                },
            ]
        )
        checkedRuntimeTeardown = teardown
        try teardown.close()
    }

    private static func sourceIdentityMatches(
        _ authority: CliExecutableAuthorityV1
    ) throws -> Bool {
        let commandSource = try EngineRuntimeIdentityReaderV1.file(
            path: authority.commandSourcePath,
            requireExecutable: true
        )
        let executable = try EngineRuntimeIdentityReaderV1.file(
            path: authority.resolvedExecutablePath,
            requireExecutable: true
        )
        let staged = try EngineRuntimeIdentityReaderV1.file(
            path: authority.stagedPath,
            requireExecutable: true
        )
        try authority.revalidateStagedCodeSignature()
        return commandSource.hash == authority.commandSourceHash
            && executable.hash == authority.executableHash
            && staged.hash == authority.executableHash
            && staged.device == authority.stagedDevice
            && staged.inode == authority.stagedInode
    }

    private static func builtInFactories() -> [EngineAdapterFactoryV1] {
        EngineAdapterFactoryV1.builtInFactories(
            makeModelLoopAdapter: { profile, runtime in
                guard let driver = runtime.modelLoopDriver else {
                    throw EngineAdapterSelectionErrorV1.descriptorMismatch
                }
                return ModelLoopEngineAdapter(
                    profile: profile,
                    descriptor: runtime.descriptor,
                    driver: driver,
                    context: runtime.context,
                    workspace: runtime.workspace,
                    boundCapabilityTools:
                        runtime.boundCapabilityTools,
                    terminalSink: runtime.terminalSink,
                    boardTerminalSink: runtime.boardTerminalSink,
                    progressSink: runtime.progressSink
                )
            },
            makeCodexAdapter: { profile, runtime in
                try makeCLIAdapter(profile: profile, runtime: runtime)
            },
            makeClaudeAdapter: { profile, runtime in
                try makeCLIAdapter(profile: profile, runtime: runtime)
            }
        )
    }

    private static func makeCLIAdapter(
        profile: RuntimeProfileRecord,
        runtime: EngineAdapterRuntimeV1
    ) throws -> CliEngineAdapter {
        guard let driver = runtime.cliProcessDriver,
              let configuration = runtime.cliConfiguration
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        return CliEngineAdapter(
            profile: profile,
            descriptor: runtime.descriptor,
            processDriver: driver,
            configuration: configuration,
            commandBuilder: CliEngineCommandBuilderV1(),
            codexParser: CodexCliEventParserV1(),
            claudeParserFactory: { expectedSessionId in
                try ClaudeCliEventParserV1(
                    expectedSessionId: expectedSessionId
                )
            },
            sanitizer: CliEngineSecretSanitizerV1(),
            context: runtime.context,
            workspace: runtime.workspace,
            boundCapabilityTools: runtime.boundCapabilityTools,
            resolvedSessionRef: runtime.resolvedSessionRef,
            terminalSink: runtime.terminalSink,
            boardTerminalSink: runtime.boardTerminalSink,
            progressSink: runtime.progressSink
        )
    }
}

public actor Orchestrator {
    private enum DispatchPhase: Sendable, Equatable {
        case running
        case halting
        case halted
        case resuming
        case shuttingDown

        var permitsDispatch: Bool {
            self == .running
        }
    }

    private let db: AppDatabase
    private let planningProviderResolver: any PlanningProviderResolver
    private let planningWorkerId: String
    private let makeProvider:
        @Sendable (String, String?) throws -> (any LLMProvider)?
    /// M6-D7：搜索 key 派发时解析（沿 makeProvider 注入模式），Core 不直连 Keychain 细节
    private let searchKeyProvider: @Sendable () throws -> String?
    private let failureReporter: FailureReporter
    private let contextDependencyLoader: any ContextDependencyLoading
    private let explicitEngineEnvironment: EngineExecutionEnvironmentV1?
    private final class EngineRuntimeFailureBox: @unchecked Sendable {
        let error: any Error

        init(_ error: any Error) {
            self.error = error
        }
    }
    private enum EngineRuntimeConstructionState {
        case unresolved
        case value(EngineExecutionRuntimeV1)
        case failed(EngineRuntimeFailureBox)
    }
    private var engineRuntimeConstructionState:
        EngineRuntimeConstructionState = .unresolved
    private let artifactStoreRoot: URL
    private let reportStore: ManagedExpeditionReportStore
    private var running: [String: RunningEntry] = [:]
    private var continuations: [UUID: AsyncStream<KernelEvent>.Continuation] = [:]
    private let tickInterval: Duration?
    private var tickTask: Task<Void, Never>?
    private var reconciling = false
    private var reconcilePending = false
    private var cancelling: Set<String> = []
    /// 预算耗尽已通知的行动（加预算后移除，避免每次 reconcile 重复发事件）
    private var budgetNotified: Set<String> = []
    private var contextSuppressedCardIds: Set<String> = []
    private var readyCauseSuppression:
        [String: EngineCardReadyObservationV1] = [:]
    /// Durable dispatch mode is projected in SQLite. Transitional phases stay
    /// fail-closed across actor reentrancy while stop/resume await cleanup.
    private var dispatchPhase: DispatchPhase
    /// Ownership token for actor methods that cross await boundaries. Phase values
    /// can repeat (resuming -> halted -> resuming), so the enum alone cannot prevent ABA.
    private var dispatchTransitionToken = UUID()
    /// App startup can opt into a one-shot bootstrap gate. It closes dispatch in
    /// init, before the asynchronous recovery task has a chance to enter the actor.
    private let enforcesStartupRecovery: Bool
    private var startupRecoveryPending: Bool
    private var planningSupervisorRecoveryCompleted = false
    private var startupRecoveryObservedMode: DispatchMode?
    private var planningSupervisorFirstPhaseRetryEligible = false
    private var planningSupervisorCardRetryEligible = false
    private var planningRecoveryCompleted = false
    private var startupDispatchModeError: String?
    private var localIdleWaiters:
        [UUID: CheckedContinuation<Void, Never>] = [:]
    /// A stop that closed this process but failed to persist may be explicitly retried.
    private var haltPersistencePending = false
    /// M7-D8：429 全局冷却截止点（在途不动，只挡新派发）
    private var cooldownUntil: ContinuousClock.Instant?
    private let rateLimitCooldownDuration: Duration
    private let rateLimitNow:
        @Sendable () -> ContinuousClock.Instant
    /// M8-D4：MCP 驿站管理（nil = 未接驿路，一切照旧）
    private let mcpManager: McpServerManager?
    private let externalOperationWorkflow:
        (any ExternalOperationWorkflowPortV1)?
#if DEBUG
    private var a3CandidatePostCommitObserverForTesting:
        (@Sendable (
            A3CandidatePostCommitObservationForTesting
        ) async -> Void)?
#endif
    /// Deterministic test seam for the post-database/pre-dispatch race. Nil in production.
    private let reconcilePostDatabaseGate: (@Sendable () async -> Void)?
    /// Deterministic seams for transition-ownership regression tests. Nil in production.
    private let recoveryPostAdoptionGate: (@Sendable () async -> Void)?
    private let resumePreAdoptionGate: (@Sendable () async -> Void)?
    private let legacyRuminationSnapshot:
        LegacyRuminationStartupSnapshot
    private let ruminationEnabled: Bool
    private struct LiveRuminationPhase {
        let identity: RuminationPhaseIdentity
        let phase: RuminationPhase
    }
    private var liveRuminationPhases:
        [String: LiveRuminationPhase] = [:]
    private var ruminationPhaseTombstones:
        Set<RuminationPhaseIdentity> = []
    private var ruminationProjectionReceipts:
        Set<RuminationProjectionCommitIdentity> = []
    private var highestRuminationProjectionByWork:
        [String: RuminationProjectionCommitIdentity] = [:]
    private static let logger = Logger(subsystem: "com.muzi.agentloop", category: "orchestrator")
    private lazy var planningSupervisor: DurableWorkSupervisor = {
        DurableWorkSupervisor.makeForOrchestrator(
            database: db,
            planningProviderResolver: planningProviderResolver,
            workerId: planningWorkerId,
            now: { Date() },
            sleep: { duration in
                try await Task<Never, Never>.sleep(for: duration)
            },
            onMissionChanged: { [weak self] missionId in
                Task {
                    await self?.planningMissionChanged(missionId)
                }
            },
            ruminationEnabled: ruminationEnabled,
            onRuminationPhase: { [unowned self] command in
                await self.handleRuminationPhaseCommand(command)
            }
        )
    }()
    private lazy var memoryPromotionSupervisor:
        CampMemoryPromotionSupervisorV1 =
    {
        CampMemoryPromotionSupervisorV1(
            database: db,
            makeProvider: makeProvider,
            onEvent: { [weak self] event in
                await self?.handleMemoryPromotionEvent(event)
            }
        )
    }()

    public init(
        db: AppDatabase,
        planningProviderResolver: any PlanningProviderResolver,
        makeProvider: @escaping @Sendable
            (String, String?) throws -> (any LLMProvider)?,
        artifactStoreRoot: URL,
        tickInterval: Duration? = .seconds(5),
        searchKeyProvider:
            @escaping @Sendable () throws -> String? = { nil },
        rateLimitCooldown: Duration = KernelDefaults.rateLimitCooldown,
        mcpManager: McpServerManager? = nil,
        reconcilePostDatabaseGate: (@Sendable () async -> Void)? = nil,
        recoveryPostAdoptionGate: (@Sendable () async -> Void)? = nil,
        resumePreAdoptionGate: (@Sendable () async -> Void)? = nil,
        requiresStartupRecovery: Bool = false,
        failureReporter: FailureReporter? = nil
    ) {
        self.init(
            db: db,
            planningProviderResolver: planningProviderResolver,
            makeProvider: makeProvider,
            artifactStoreRoot: artifactStoreRoot,
            tickInterval: tickInterval,
            searchKeyProvider: searchKeyProvider,
            rateLimitCooldown: rateLimitCooldown,
            mcpManager: mcpManager,
            externalOperationWorkflow: nil,
            rateLimitNow: { ContinuousClock.now },
            reconcilePostDatabaseGate: reconcilePostDatabaseGate,
            recoveryPostAdoptionGate: recoveryPostAdoptionGate,
            resumePreAdoptionGate: resumePreAdoptionGate,
            requiresStartupRecovery: requiresStartupRecovery,
            failureReporter: failureReporter
        )
    }

    package init(
        db: AppDatabase,
        planningProviderResolver: any PlanningProviderResolver,
        makeProvider: @escaping @Sendable
            (String, String?) throws -> (any LLMProvider)?,
        artifactStoreRoot: URL,
        tickInterval: Duration? = .seconds(5),
        searchKeyProvider:
            @escaping @Sendable () throws -> String? = { nil },
        rateLimitCooldown: Duration = KernelDefaults.rateLimitCooldown,
        mcpManager: McpServerManager? = nil,
        externalOperationWorkflow:
            (any ExternalOperationWorkflowPortV1)?,
        rateLimitNow: @escaping @Sendable () ->
            ContinuousClock.Instant = { ContinuousClock.now },
        reconcilePostDatabaseGate: (@Sendable () async -> Void)? = nil,
        recoveryPostAdoptionGate: (@Sendable () async -> Void)? = nil,
        resumePreAdoptionGate: (@Sendable () async -> Void)? = nil,
        requiresStartupRecovery: Bool = false,
        failureReporter: FailureReporter? = nil,
        reportStore: ManagedExpeditionReportStore? = nil
    ) {
        let initialPhase: DispatchPhase
        let initialError: String?
        do {
            let mode = try db.dispatchMode()
            initialPhase = mode == .running
                ? (requiresStartupRecovery ? .resuming : .running)
                : .halted
            initialError = nil
        } catch {
            initialPhase = .halted
            initialError = "读取持久化停营状态失败：\(String(describing: error))"
        }
        self.db = db
        self.planningProviderResolver = planningProviderResolver
        self.planningWorkerId = UUID().uuidString
        self.makeProvider = makeProvider
        self.artifactStoreRoot = artifactStoreRoot
        self.reportStore = reportStore
            ?? ManagedExpeditionReportStore(
                database: db,
                reportStoreRoot: artifactStoreRoot
                    .deletingLastPathComponent()
                    .appendingPathComponent("reports")
            )
        self.tickInterval = tickInterval
        self.searchKeyProvider = searchKeyProvider
        let reporter = failureReporter ?? FailureReporter(database: db)
        self.failureReporter = reporter
        self.contextDependencyLoader = ContextDependencyLoader(
            database: db,
            manager: mcpManager,
            reporter: reporter,
            searchCredential: searchKeyProvider,
            knowledge: .live(database: db),
            makeTrace: { operation, scope in
                OperationTraceFactory.live.generated(
                    operation: operation,
                    scope: scope
                )
            }
        )
        self.explicitEngineEnvironment = nil
        self.rateLimitCooldownDuration = rateLimitCooldown
        self.rateLimitNow = rateLimitNow
        self.mcpManager = mcpManager
        self.externalOperationWorkflow = externalOperationWorkflow
        self.reconcilePostDatabaseGate = reconcilePostDatabaseGate
        self.recoveryPostAdoptionGate = recoveryPostAdoptionGate
        self.resumePreAdoptionGate = resumePreAdoptionGate
        self.legacyRuminationSnapshot =
            .legacyProfileUnresolved
        self.ruminationEnabled = false
        self.enforcesStartupRecovery = requiresStartupRecovery
        self.startupRecoveryPending = requiresStartupRecovery
        self.dispatchPhase = initialPhase
        self.startupDispatchModeError = initialError
    }

    package init(
        db: AppDatabase,
        planningProviderResolver: any PlanningProviderResolver,
        makeProvider: @escaping @Sendable (
            String,
            String?
        ) throws -> (any LLMProvider)?,
        artifactStoreRoot: URL,
        tickInterval: Duration? = .seconds(5),
        searchKeyProvider:
            @escaping @Sendable () throws -> String? = { nil },
        rateLimitCooldown: Duration =
            KernelDefaults.rateLimitCooldown,
        mcpManager: McpServerManager? = nil,
        externalOperationWorkflow:
            (any ExternalOperationWorkflowPortV1)? = nil,
        rateLimitNow: @escaping @Sendable () ->
            ContinuousClock.Instant = { ContinuousClock.now },
        reconcilePostDatabaseGate:
            (@Sendable () async -> Void)? = nil,
        recoveryPostAdoptionGate:
            (@Sendable () async -> Void)? = nil,
        resumePreAdoptionGate:
            (@Sendable () async -> Void)? = nil,
        requiresStartupRecovery: Bool = false,
        legacyRuminationSnapshot:
            LegacyRuminationStartupSnapshot,
        failureReporter: FailureReporter? = nil,
        contextDependencyLoader:
            (any ContextDependencyLoading)? = nil,
        reportStore: ManagedExpeditionReportStore? = nil,
        engineEnvironment: EngineExecutionEnvironmentV1? = nil
    ) {
        let initialPhase: DispatchPhase
        let initialError: String?
        do {
            let mode = try db.dispatchMode()
            initialPhase = mode == .running
                ? (
                    requiresStartupRecovery
                        ? .resuming
                        : .running
                )
                : .halted
            initialError = nil
        } catch {
            initialPhase = .halted
            initialError =
                "读取持久化停营状态失败：\(String(describing: error))"
        }
        self.db = db
        self.planningProviderResolver = planningProviderResolver
        self.planningWorkerId = UUID().uuidString
        self.makeProvider = makeProvider
        self.artifactStoreRoot = artifactStoreRoot
        self.reportStore = reportStore
            ?? ManagedExpeditionReportStore(
                database: db,
                reportStoreRoot: artifactStoreRoot
                    .deletingLastPathComponent()
                    .appendingPathComponent("reports")
            )
        self.tickInterval = tickInterval
        self.searchKeyProvider = searchKeyProvider
        let reporter = failureReporter ?? FailureReporter(database: db)
        self.failureReporter = reporter
        self.contextDependencyLoader = contextDependencyLoader
            ?? ContextDependencyLoader(
                database: db,
                manager: mcpManager,
                reporter: reporter,
                searchCredential: searchKeyProvider,
                knowledge: .live(database: db),
                makeTrace: { operation, scope in
                    OperationTraceFactory.live.generated(
                        operation: operation,
                        scope: scope
                    )
                }
            )
        self.explicitEngineEnvironment = engineEnvironment
        self.rateLimitCooldownDuration = rateLimitCooldown
        self.rateLimitNow = rateLimitNow
        self.mcpManager = mcpManager
        self.externalOperationWorkflow = externalOperationWorkflow
        self.reconcilePostDatabaseGate =
            reconcilePostDatabaseGate
        self.recoveryPostAdoptionGate =
            recoveryPostAdoptionGate
        self.resumePreAdoptionGate = resumePreAdoptionGate
        self.legacyRuminationSnapshot =
            legacyRuminationSnapshot
        self.ruminationEnabled = true
        self.enforcesStartupRecovery = requiresStartupRecovery
        self.startupRecoveryPending = requiresStartupRecovery
        self.dispatchPhase = initialPhase
        self.startupDispatchModeError = initialError
    }

    package func engineExecutionRuntime() throws
        -> EngineExecutionRuntimeV1
    {
        switch engineRuntimeConstructionState {
        case .value(let runtime):
            return runtime
        case .failed(let failure):
            throw failure.error
        case .unresolved:
            break
        }
        do {
            let environment = try explicitEngineEnvironment
                ?? makeCompatibilityEngineEnvironment()
            let runtime = EngineExecutionRuntimeV1(
                environment: environment,
                eventObserver: { [weak self] cardId, event in
                    await self?.observeCommittedEngineEvent(
                        cardId: cardId,
                        event: event
                    )
                }
            )
            engineRuntimeConstructionState = .value(runtime)
            return runtime
        } catch {
            engineRuntimeConstructionState = .failed(
                EngineRuntimeFailureBox(error)
            )
            throw error
        }
    }

    private func makeCompatibilityEngineEnvironment() throws
        -> EngineExecutionEnvironmentV1
    {
        let stateRoot = artifactStoreRoot.deletingLastPathComponent()
        let stateDirectoryLock = try StateDirectoryLock(
            directoryURL: stateRoot
        )
        let processInspector = DarwinEngineRuntimeProcessInspectorV1()
        let helpProbe = CliHelpProbeV1(
            processInspector: processInspector
        )
        let legacyProvider = makeProvider
        return try EngineExecutionEnvironmentV1(
            database: db,
            stateDirectoryLock: stateDirectoryLock,
            artifactStoreRoot: artifactStoreRoot,
            bridgeExecutablePath: nil,
            boardSocketDirectoryAuthority: nil,
            validateCodexManagedPolicy: nil,
            validateClaudeManagedPolicy: nil,
            claudeConfigDirectory: stateRoot,
            cliExecutableDirectory: stateRoot,
            processInspector: processInspector,
            dependencyLoader: contextDependencyLoader,
            resolveInitialModelLoopProvider: {
                profile, companionId, companionModel, modelPolicy in
                guard profile.kind != .cliCodex,
                      profile.kind != .cliClaude,
                      modelPolicy == .pinned,
                      !companionModel.isEmpty
                else {
                    throw EngineAdapterSelectionErrorV1.descriptorMismatch
                }
                return try EngineModelLoopProviderAuthorityV1(
                    profileId: profile.id,
                    effectiveModel: companionModel,
                    makeProvider: {
                        guard let provider = try legacyProvider(
                            companionModel,
                            companionId
                        ) else {
                            throw EngineAdapterSelectionErrorV1
                                .descriptorMismatch
                        }
                        return provider
                    }
                )
            },
            resolveRecoveryModelLoopProvider: {
                profile, companionId, persistedModel in
                guard profile.kind != .cliCodex,
                      profile.kind != .cliClaude,
                      !persistedModel.isEmpty
                else {
                    throw EngineAdapterSelectionErrorV1.descriptorMismatch
                }
                return try EngineModelLoopProviderAuthorityV1(
                    profileId: profile.id,
                    effectiveModel: persistedModel,
                    makeProvider: {
                        guard let provider = try legacyProvider(
                            persistedModel,
                            companionId
                        ) else {
                            throw EngineAdapterSelectionErrorV1
                                .descriptorMismatch
                        }
                        return provider
                    }
                )
            },
            helpProbe: helpProbe,
            makeCliProcessDriver: {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            },
            clock: {
                do {
                    return try P1DTimestampV1.canonical(Date())
                } catch {
                    preconditionFailure(
                        "System clock could not produce a canonical P1 timestamp: \(error)"
                    )
                }
            }
        )
    }

#if DEBUG
    package func armA3CandidatePostCommitObserverForTesting(
        _ observer: @escaping @Sendable (
            A3CandidatePostCommitObservationForTesting
        ) async -> Void
    ) throws {
        guard a3CandidatePostCommitObserverForTesting == nil else {
            throw InvalidDurableWorkStateError()
        }
        a3CandidatePostCommitObserverForTesting = observer
    }

    package func clearA3CandidatePostCommitObserverForTesting() {
        a3CandidatePostCommitObserverForTesting = nil
    }

    private func observeA3CandidatePostCommitForTesting(
        _ observation: A3CandidatePostCommitObservationForTesting
    ) async {
        guard let observer = a3CandidatePostCommitObserverForTesting else {
            return
        }
        await observer(observation)
    }
#endif

    public func events() -> AsyncStream<KernelEvent> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .unbounded) { continuation in
            continuations[id] = continuation
            continuation.onTermination = { _ in
                Task { await self.removeContinuation(id) }
            }
        }
    }

    private func handleRuminationPhaseCommand(
        _ command: RuminationPhaseCommand
    ) {
        switch command {
        case let .set(identity, phase):
            guard identity.attempt >= 1 else {
                preconditionFailure(
                    "attempt-zero rumination cannot publish a phase"
                )
            }
            guard !ruminationPhaseTombstones
                .contains(identity)
            else {
                return
            }
            if let current =
                liveRuminationPhases[identity.ingestionId]
            {
                guard current.identity == identity else {
                    return
                }
                if current.phase == phase {
                    return
                }
                let advances: Bool
                switch (current.phase, phase) {
                case (.reading, .extracting),
                     (.extracting, .organizing):
                    advances = true
                default:
                    advances = false
                }
                guard advances else {
                    preconditionFailure(
                        "rumination phase skipped or regressed"
                    )
                }
            } else {
                guard phase == .reading else {
                    preconditionFailure(
                        "rumination phase must begin at reading"
                    )
                }
            }
            liveRuminationPhases[identity.ingestionId] =
                LiveRuminationPhase(
                    identity: identity,
                    phase: phase
                )
            emit(
                .ruminationPhase(
                    ingestionId: identity.ingestionId,
                    workId: identity.workId,
                    attempt: identity.attempt,
                    phase: phase
                )
            )
        case let .invalidate(milestone):
            switch milestone {
            case let .phase(identity, _):
                guard identity.attempt >= 1 else {
                    preconditionFailure(
                        "attempt-zero rumination cannot invalidate a phase"
                    )
                }
                guard let current =
                    liveRuminationPhases[identity.ingestionId],
                      current.identity == identity
                else {
                    return
                }
                liveRuminationPhases.removeValue(
                    forKey: identity.ingestionId
                )
                ruminationPhaseTombstones.insert(identity)
                emit(
                    .ruminationChanged(
                        .phaseInvalidated(identity)
                    )
                )
            case let .projectionCommitted(identity):
                if ruminationProjectionReceipts
                    .contains(identity)
                {
                    return
                }
                let workId = identity.phaseIdentity.workId
                if let highest =
                    highestRuminationProjectionByWork[workId]
                {
                    guard identity.workVersion
                        > highest.workVersion
                    else {
                        preconditionFailure(
                            "rumination projection version regressed"
                        )
                    }
                }
                var invalidated:
                    RuminationPhaseIdentity?
                if identity.phaseIdentity.attempt >= 1,
                   let current = liveRuminationPhases[
                       identity.phaseIdentity.ingestionId
                   ],
                   current.identity == identity.phaseIdentity
                {
                    liveRuminationPhases.removeValue(
                        forKey:
                            identity.phaseIdentity.ingestionId
                    )
                    ruminationPhaseTombstones.insert(
                        identity.phaseIdentity
                    )
                    invalidated = identity.phaseIdentity
                }
                highestRuminationProjectionByWork[workId] =
                    identity
                ruminationProjectionReceipts.insert(identity)
                emit(
                    .ruminationChanged(
                        .projectionCommitted(
                            identity,
                            invalidatedPhaseIdentity:
                                invalidated
                        )
                    )
                )
            }
        }
    }

    package func startRumination(
        preparation: RuminationStartPreparation,
        command: RuminationStartCommand?
    ) async throws -> DurableWorkRecord {
        guard ruminationEnabled else {
            throw RuminationRequiresDurableRuminationCapabilityError()
        }
        try requireDispatchRunning()
        guard planningRecoveryCompleted else {
            throw SupervisorRecoveryRequiredError()
        }
        return try await planningSupervisor.startRumination(
            preparation: preparation,
            command: command
        )
    }

    package func cancelRumination(
        ingestionId: String
    ) async throws {
        guard ruminationEnabled else {
            throw RuminationRequiresDurableRuminationCapabilityError()
        }
        try await planningSupervisor.cancelRumination(
            ingestionId: ingestionId
        )
    }

    package func convertCandidateAndEnqueuePlanning(
        _ command: CandidatePlanningStartCommand
    ) async throws -> CandidatePlanningStartResult {
        try requireDispatchRunning()
        guard planningRecoveryCompleted else {
            throw SupervisorRecoveryRequiredError()
        }
        let result = try await planningSupervisor
            .convertCandidateAndEnqueuePlanning(command)
        let currentWork = try await db.pool.read { database in
            guard let work = try DurableWorkRecord.fetchOne(
                database,
                key: result.workId
            ) else {
                throw RecordNotFoundError(
                    table: DurableWorkRecord.databaseTableName,
                    id: result.workId
                )
            }
            return work
        }
        let durableMode = try db.dispatchMode()
        guard currentWork.kind == .planning,
              currentWork.aggregateType == "mission",
              currentWork.aggregateId == result.missionId
        else {
            throw DurableWorkReplayConflictError()
        }
        guard dispatchPhase.permitsDispatch,
              durableMode == .running
        else {
            return result
        }
        switch currentWork.state {
        case .queued, .retryScheduled:
#if DEBUG
            await observeA3CandidatePostCommitForTesting(.ensureTick)
#endif
            ensureTickStarted()
            if result.disposition == .inserted {
#if DEBUG
                await observeA3CandidatePostCommitForTesting(
                    .planningStarted
                )
#endif
                emit(.planningStarted(missionId: result.missionId))
            }
#if DEBUG
            await observeA3CandidatePostCommitForTesting(.kick)
#endif
            try await planningSupervisor.kick()
        case .running, .succeeded, .failed, .canceled:
            break
        }
        return result
    }

    package func commitScheduledMission(
        _ command: SchedulePlanningStartCommand
    ) async throws -> ScheduleFireCommitResult {
        try requireDispatchRunning()
        guard planningRecoveryCompleted else {
            throw SupervisorRecoveryRequiredError()
        }
        return try await planningSupervisor.startScheduledMission(command)
    }

    package func replayMissedScheduleFire(
        _ command: ScheduleReplayStartCommand
    ) async throws -> ScheduleFireCommitResult {
        try requireDispatchRunning()
        guard planningRecoveryCompleted else {
            throw SupervisorRecoveryRequiredError()
        }
        return try await planningSupervisor.replayMissedScheduleFire(command)
    }

    package func wakeScheduledPlanning(
        _ result: ScheduleFireCommitResult
    ) async throws {
        switch result.fire.state {
        case .failed:
            guard result.fire.missionId == nil,
                  result.missionId == nil,
                  result.workId == nil
            else {
                throw ScheduleFireReplayIntegrityError(
                    fireId: result.fire.id
                )
            }
            return
        case .started:
            break
        }

        guard let missionId = result.missionId,
              let workId = result.workId,
              result.fire.missionId == missionId
        else {
            throw ScheduleFireReplayIntegrityError(
                fireId: result.fire.id
            )
        }
        let currentWork = try await db.pool.read { database in
            guard let work = try DurableWorkRecord.fetchOne(
                database,
                key: workId
            ) else {
                throw RecordNotFoundError(
                    table: DurableWorkRecord.databaseTableName,
                    id: workId
                )
            }
            return work
        }
        guard currentWork.kind == .planning,
              currentWork.aggregateType == "mission",
              currentWork.aggregateId == missionId
        else {
            throw ScheduleFireReplayIntegrityError(
                fireId: result.fire.id
            )
        }
        let durableMode = try db.dispatchMode()
        guard dispatchPhase.permitsDispatch,
              planningRecoveryCompleted,
              durableMode == .running
        else {
            return
        }
        switch currentWork.state {
        case .queued, .retryScheduled:
#if DEBUG
            await observeA3CandidatePostCommitForTesting(.ensureTick)
#endif
            ensureTickStarted()
            if result.disposition == .inserted {
#if DEBUG
                await observeA3CandidatePostCommitForTesting(
                    .planningStarted
                )
#endif
                emit(.planningStarted(missionId: missionId))
            }
#if DEBUG
            await observeA3CandidatePostCommitForTesting(.kick)
#endif
            try await planningSupervisor.kick()
        case .running, .succeeded, .failed, .canceled:
            break
        }
    }

    public func startMission(
        goal: String,
        companionIds: [String],
        workspacePath: String?,
        plannerModel: String,
        runtimeProfileId: String,
        budgetTokens: Int,
        campId: String?,
        autonomy: MissionAutonomy,
        idempotencyKey: String,
        traceId: String
    ) async throws -> String {
        let trace = try OperationTraceFactory.live.adopting(
            traceId,
            operation: .missionStart,
            scope: .fixed(.missionIndex)
        )
        switch await startMission(
            goal: goal,
            companionIds: companionIds,
            workspacePath: workspacePath,
            plannerModel: plannerModel,
            runtimeProfileId: runtimeProfileId,
            budgetTokens: budgetTokens,
            campId: campId,
            autonomy: autonomy,
            idempotencyKey: idempotencyKey,
            trace: trace
        ) {
        case .notCommitted(let failure):
            throw UserVisibleOperationError(failure: failure)
        case .committed(let missionId):
            return missionId
        case .committedWithVisibilityFailure(let missionId, let failure):
            emit(.operationFailed(failure))
            return missionId
        }
    }

    package func startMission(
        goal: String,
        companionIds: [String],
        workspacePath: String?,
        plannerModel: String,
        runtimeProfileId: String,
        budgetTokens: Int,
        campId: String?,
        autonomy: MissionAutonomy,
        idempotencyKey: String,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<String> {
        let enqueued: (missionId: String, workId: String)
        do {
            try requireDispatchRunning()
            guard planningRecoveryCompleted else {
                throw SupervisorRecoveryRequiredError()
            }
            let planningInput = try PlanningWorkInput(
                plannerModel: plannerModel,
                runtimeProfileId: runtimeProfileId
            )
            enqueued = try db.enqueueMissionPlanning(
                goal: goal,
                companionIds: companionIds,
                workspacePath: workspacePath,
                budgetTokens: budgetTokens,
                campId: campId,
                autonomy: autonomy,
                planningInput: planningInput,
                idempotencyKey: idempotencyKey,
                traceId: trace.traceId,
                planningProviderResolver: planningProviderResolver
            )
        } catch {
            return .notCommitted(
                failureReporter.capture(error, trace: trace)
            )
        }

        ensureTickStarted()
        emit(.planningStarted(missionId: enqueued.missionId))
        do {
            try await planningSupervisor.kick()
            return .committed(enqueued.missionId)
        } catch {
            return .committedWithVisibilityFailure(
                value: enqueued.missionId,
                failure: failureReporter.capture(error, trace: trace)
            )
        }
    }

    private static let engineLifecycleFailureCode =
        "engine_lifecycle_cleanup_failed"
    private static let engineLifecycleFailureDescription =
        "Engine lifecycle cleanup failed."

    private static func validateEngineRecoverySummaryForLifecycle(
        _ summary: EngineRecoverySummaryV1
    ) throws {
        var containsUnexpectedAction = false
        for directive in summary.directives {
            switch directive.action {
            case .deferCampDeletion:
                break
            case .cancelAndReconcile, .prepareAndCommitProposal,
                 .startPrepared, .resumeSession, .replayExecution:
                containsUnexpectedAction = true
            }
        }
        guard !containsUnexpectedAction else {
            throw EngineDispatchConflictErrorV1()
        }
        guard summary.directives.isEmpty else {
            throw EngineRecoveryPendingF2ErrorV1()
        }
    }

    private func preparedEngineRuntimeForRecovery() async throws
        -> EngineExecutionRuntimeV1
    {
        let activeKinds = try await db.pool.read { database in
            try EngineExecutionStore.activeRecoveryProfileKinds(
                database: database
            )
        }
        let runtime = try engineExecutionRuntime()
        _ = try await runtime.registry(
            requestedProfileKinds: Set(activeKinds)
        )
        return runtime
    }

    private func recoverExternalOperationAuthority() async throws {
        if let externalOperationWorkflow {
            try await externalOperationWorkflow.recoverPending()
        } else if !(try ApprovalGrantStore(database: db)
            .pendingUses().isEmpty)
        {
            throw ExternalOperationWorkflowUnavailableError()
        }
    }

    private func persistEngineLifecycleFailure(
        missionId: String,
        code: String,
        description: String
    ) {
        do {
            try db.pool.write { database in
                try AppDatabase.appendEvent(
                    database,
                    missionId: missionId,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.kernelError,
                    payload: [
                        "code": .string(code),
                        "description": .string(description),
                    ]
                )
            }
        } catch {
            Self.logger.error(
                "failed to persist engine lifecycle failure"
            )
        }
        emit(
            .kernelError(
                missionId: missionId,
                message: description
            )
        )
    }

    /// 启动恢复（M5-1，spec §14/§16-M5）：先收编崩溃遗留的孤儿，再照常调度。
    /// 杀进程重启后行动续跑的入口——替代裸 reconcile() 作为 App 启动调用。
    public func recoverAndReconcile() async {
        guard !planningRecoveryCompleted else { return }
        if enforcesStartupRecovery {
            guard startupRecoveryPending else { return }
            guard dispatchPhase != .halting, dispatchPhase != .shuttingDown else {
                startupRecoveryPending = false
                return
            }
            // Claim the one permitted bootstrap call. stop/resume/shutdown can
            // invalidate its transition token while it is suspended.
            startupRecoveryPending = false
        } else {
            guard !haltPersistencePending,
                  dispatchPhase != .halting,
                  dispatchPhase != .resuming,
                  dispatchPhase != .shuttingDown else {
                return
            }
        }
        let recoveryToken = beginTransition(.resuming)
        invalidateStartupPlanningRecoveryEligibility()
        do {
            try await finishStartupRecovery(
                transitionToken: recoveryToken
            )
        } catch let pending as EngineRecoveryPendingF2ErrorV1 {
            guard ownsTransition(recoveryToken, phase: .resuming) else {
                return
            }
            setStartupRetryEligibilityAfterFailure()
            dispatchPhase = .halted
            tickTask?.cancel()
            tickTask = nil
            startupDispatchModeError = pending.errorDescription
            emit(.haltStateChanged(true))
            persistEngineLifecycleFailure(
                missionId: "",
                code: pending.code,
                description: pending.errorDescription ?? ""
            )
            return
        } catch {
            guard ownsTransition(recoveryToken, phase: .resuming) else {
                return
            }
            setStartupRetryEligibilityAfterFailure()
            dispatchPhase = .halted
            tickTask?.cancel()
            tickTask = nil
            let message = "Engine startup recovery failed."
            startupDispatchModeError = message
            Self.logger.error("\(message, privacy: .public)")
            db.appendKernelErrorEvent(missionId: "", message: message)
            emit(.haltStateChanged(true))
            emit(.kernelError(missionId: "", message: message))
            return
        }
    }

    private func finishStartupRecovery(
        transitionToken: UUID
    ) async throws {
        try requireTransition(transitionToken, phase: .resuming)
        let runtime = try await preparedEngineRuntimeForRecovery()
        try requireTransition(transitionToken, phase: .resuming)
        try await recoverExternalOperationAuthority()
        try requireTransition(transitionToken, phase: .resuming)
        let summary = try await runtime.recover(
            missionId: nil,
            now: Date()
        )
        try Self.validateEngineRecoverySummaryForLifecycle(summary)
        try requireTransition(transitionToken, phase: .resuming)

        try await adoptOrphans()
        try requireTransition(transitionToken, phase: .resuming)
        try healOrphanedConfirmedProposals()
        try requireTransition(transitionToken, phase: .resuming)

        if !planningSupervisorRecoveryCompleted {
            startupRecoveryObservedMode =
                try await planningSupervisor.recoverOnStartup(
                    profileModels: try legacyPlanningProfileModels(),
                    legacyRuminationSnapshot:
                        legacyRuminationSnapshot
                )
            try requireTransition(transitionToken, phase: .resuming)
            planningSupervisorRecoveryCompleted = true
        }

        if let recoveryPostAdoptionGate {
            await recoveryPostAdoptionGate()
        }
        try requireTransition(transitionToken, phase: .resuming)

        guard let durableMode = startupRecoveryObservedMode else {
            throw SupervisorRecoveryRequiredError()
        }
        try requireTransition(transitionToken, phase: .resuming)

        if durableMode == .running {
            try await planningSupervisor
                .activateAfterOrchestratorRecovery()
            try requireTransition(transitionToken, phase: .resuming)
        }

        planningRecoveryCompleted = true
        startupDispatchModeError = nil
        invalidateStartupPlanningRecoveryEligibility()
        haltPersistencePending = false
        guard durableMode == .running else {
            dispatchPhase = .halted
            tickTask?.cancel()
            tickTask = nil
            emit(.haltStateChanged(true))
            return
        }
        dispatchPhase = .running
        emit(.haltStateChanged(false))
        await reconcile()
    }

    /// 收编孤儿：DB 里 running 但不在内存注册表的卡（崩溃/强杀遗留）→ ready 续跑，
    /// 其未收口的 run 标记 interrupted；confirmed-无-missionId 的提案回滚 pending 可重确认。
    private func adoptOrphans() async throws {
        let activeCardIds = Set(running.keys)
        let adopted = try await db.pool.write { database -> [(cardId: String, missionId: String)] in
            let stuck = try CardRecord
                .filter(Column("status") == CardStatus.running.rawValue)
                .fetchAll(database)
                .filter { !activeCardIds.contains($0.id) }
            var adopted: [(cardId: String, missionId: String)] = []
            for card in stuck {
                let hasNonredactedEngineRun = try Bool.fetchOne(
                    database,
                    sql: """
                        SELECT EXISTS(
                            SELECT 1
                            FROM run r
                            JOIN engine_execution x ON x.runId=r.id
                            WHERE r.cardId=? AND x.redactedAt IS NULL
                        )
                        """,
                    arguments: [card.id]
                ) ?? false
                guard !hasNonredactedEngineRun else { continue }
                let hasOpenLegacyRun = try Bool.fetchOne(
                    database,
                    sql: """
                        SELECT EXISTS(
                            SELECT 1
                            FROM run r
                            WHERE r.cardId=? AND r.outcome IS NULL
                              AND NOT EXISTS(
                                SELECT 1 FROM engine_execution x
                                WHERE x.runId=r.id AND x.redactedAt IS NULL
                              )
                        )
                        """,
                    arguments: [card.id]
                ) ?? false
                guard hasOpenLegacyRun else { continue }
                try database.execute(
                    sql: """
                        UPDATE run SET outcome = 'interrupted', endedAt = ?
                        WHERE cardId = ? AND outcome IS NULL
                          AND NOT EXISTS(
                            SELECT 1 FROM engine_execution x
                            WHERE x.runId=run.id AND x.redactedAt IS NULL
                          )
                        """,
                    arguments: [Date(), card.id]
                )
                try self.db.transitionCard(
                    database,
                    id: card.id,
                    to: .ready,
                    eventKind: EventKind.cardInterrupted,
                    payload: ["reason": "crash_recovery"]
                )
                try AppDatabase.appendEvent(
                    database,
                    missionId: card.missionId,
                    cardId: card.id,
                    runId: nil,
                    kind: EventKind.cardReady,
                    payload: .object([:])
                )
                adopted.append((cardId: card.id, missionId: card.missionId))
            }
            return adopted
        }
        for orphan in adopted {
            Self.logger.info("adopted orphaned running card \(orphan.cardId, privacy: .public)")
            emit(.missionChanged(missionId: orphan.missionId))
        }
    }

    private func healOrphanedConfirmedProposals() throws {
        // 提案自愈（M4 评审遗留的崩溃窗口：CAS 确认后、建队前崩溃）
        do {
            let healed = try db.healOrphanedConfirmedProposals()
            if !healed.isEmpty {
                Self.logger.info("healed \(healed.count, privacy: .public) orphaned confirmed proposals")
            }
        } catch {
            let message = "提案自愈失败：\(String(describing: error))"
            Self.logger.error("\(message, privacy: .public)")
            db.appendKernelErrorEvent(missionId: "", message: message)
            emit(.kernelError(missionId: "", message: message))
            throw error
        }
    }

    public func reconcile() async {
        // Check before tick creation: a restored halt must remain completely quiet.
        guard dispatchPhase.permitsDispatch else { return }
        ensureTickStarted()
        guard !reconciling else {
            reconcilePending = true
            return
        }
        reconciling = true
        defer {
            reconciling = false
            wakeLocalIdleWaitersIfNeeded()
        }

        repeat {
            guard dispatchPhase.permitsDispatch else {
                reconcilePending = false
                break
            }
            reconcilePending = false
            await reconcileOnce()
        } while reconcilePending
    }

    private func reconcileOnce() async {
        let plan: ReconcilePlan
        let suppressedReadyObservations = readyCauseSuppression
        do {
            plan = try await db.pool.write { database in
                let missions = try MissionRecord
                    .filter(Column("status") == MissionStatus.executing.rawValue)
                    .order(Column("createdAt"), Column.rowID)
                    .fetchAll(database)
                for mission in missions {
                    let cards = try CardRecord
                        .filter(Column("missionId") == mission.id)
                        .order(Column("stage"))
                        .fetchAll(database)
                    let statusById = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0.status) })
                    for card in cards where card.status == .todo {
                        let dependencyIds = try Self.decodeStringArray(card.dependsOnJson)
                        if dependencyIds.allSatisfy({ statusById[$0] == .done }) {
                            try db.transitionCard(
                                database,
                                id: card.id,
                                to: .ready,
                                eventKind: EventKind.cardReady,
                                payload: .object([:])
                            )
                        }
                    }
                }

                let readyCards = try CardRecord.fetchAll(
                    database,
                    sql: """
                        SELECT card.*
                        FROM card
                        JOIN mission ON mission.id = card.missionId
                        WHERE mission.status = ? AND card.status = ?
                        ORDER BY mission.createdAt, mission.rowid, card.stage, card.createdAt, card.rowid
                        """,
                    arguments: [MissionStatus.executing.rawValue, CardStatus.ready.rawValue]
                )
                // 预算收尾线（M5-2，spec §13）：耗尽的行动停止派发，等用户三选
                let executingMissions = try MissionRecord
                    .filter(keys: Set(readyCards.map(\.missionId)))
                    .fetchAll(database)
                let exhaustedMissionIds = Set(
                    executingMissions.filter { $0.spentTokens >= $0.budgetTokens }.map(\.id)
                )
                // M7-D2：档位随候选下发（审批矩阵在 CardRunner 装门时消费）
                let autonomyByMission = Dictionary(
                    uniqueKeysWithValues: executingMissions.map { ($0.id, $0.autonomy) })
                let missionByID = Dictionary(
                    uniqueKeysWithValues: executingMissions.map { ($0.id, $0) }
                )
                var candidates: [DispatchCandidate] = []
                var errors: [KernelErrorRecord] = []
                var readyCauseFailures: [ReadyCauseFailure] = []
                for ready in readyCards where !exhaustedMissionIds.contains(ready.missionId) {
                    let observation = try db.engineCardReadyObservation(
                        for: ready,
                        in: database
                    )
                    guard suppressedReadyObservations[ready.id] != observation else {
                        continue
                    }
                    let cause: EngineCardReadyCauseV1
                    do {
                        cause = try db.resolveEngineCardReadyCause(
                            for: ready,
                            in: database
                        )
                    } catch is EngineCardReadyCauseErrorV1 {
                        readyCauseFailures.append(
                            ReadyCauseFailure(
                                cardId: ready.id,
                                missionId: ready.missionId,
                                observation: observation
                            )
                        )
                        continue
                    }
                    guard let assigneeId = ready.assigneeId,
                          let companion = try CompanionRecord.fetchOne(
                            database,
                            key: assigneeId
                          ),
                          let mission = missionByID[ready.missionId],
                          let squad = try SquadRecord.fetchOne(
                            database,
                            key: mission.squadId
                          ),
                          let camp = try CampRecord.fetchOne(
                            database,
                            key: squad.campId
                          )
                    else {
                        let message = "负责伙伴不存在或未指派"
                        try db.blockCard(
                            database,
                            id: ready.id,
                            runId: nil,
                            reason: "other",
                            detail: message
                        )
                        errors.append(KernelErrorRecord(missionId: ready.missionId, message: message))
                        continue
                    }
                    candidates.append(
                        DispatchCandidate(
                            card: ready,
                            mission: mission,
                            camp: camp,
                            companion: companion,
                            assigneeId: assigneeId,
                            companionName: companion.name,
                            rolePrompt: companion.rolePrompt,
                            model: companion.model,
                            runtimeProfileKind: try Self.runtimeProfileKind(for: companion, database: database),
                            toolsJson: companion.toolsJson,
                            autonomy: autonomyByMission[ready.missionId] ?? .standard,
                            readyCause: cause,
                            readyObservation: observation
                        )
                    )
                }
                return ReconcilePlan(
                    candidates: candidates,
                    kernelErrors: errors,
                    readyCauseFailures: readyCauseFailures,
                    budgetExhaustedMissionIds: exhaustedMissionIds)
            }
        } catch {
            emit(.kernelError(missionId: "", message: String(describing: error)))
            return
        }

        if let reconcilePostDatabaseGate {
            await reconcilePostDatabaseGate()
        }
        // The database write above suspends. A stop may have committed while it was in flight.
        guard dispatchPhase.permitsDispatch else { return }

        for failure in plan.readyCauseFailures {
            readyCauseSuppression[failure.cardId] = failure.observation
            emit(.kernelError(
                missionId: failure.missionId,
                message: "卡片当前就绪事件无效，已暂停本次派发"
            ))
            emit(.missionChanged(missionId: failure.missionId))
        }
        for candidate in plan.candidates {
            readyCauseSuppression.removeValue(forKey: candidate.card.id)
        }

        for error in plan.kernelErrors {
            db.appendKernelErrorEvent(missionId: error.missionId, message: error.message)
            emit(.kernelError(missionId: error.missionId, message: error.message))
            emit(.missionChanged(missionId: error.missionId))
        }

        for missionId in plan.budgetExhaustedMissionIds where !budgetNotified.contains(missionId) {
            budgetNotified.insert(missionId)
            try? await db.pool.write { database in
                try AppDatabase.appendEvent(
                    database, missionId: missionId, cardId: nil, runId: nil,
                    kind: EventKind.missionBudgetExhausted, payload: .object([:]))
            }
            emit(.missionChanged(missionId: missionId))
        }

        // M7-D8：429 冷却期不派发新卡（在途不动）；到点自然恢复
        if let cooldownUntil, rateLimitNow() < cooldownUntil {
            return
        }

        var busy = Set(running.values.map(\.assigneeId))
        for candidate in plan.candidates {
            guard dispatchPhase.permitsDispatch else { break }
            // 全局并发节流（M5-2）
            guard running.count < KernelDefaults.maxConcurrentCardRuns else { break }
            guard !busy.contains(candidate.assigneeId),
                  !cancelling.contains(candidate.card.missionId),
                  !contextSuppressedCardIds.contains(candidate.card.id),
                  running[candidate.card.id] == nil else {
                continue
            }
            let prepared: EnginePreparedDispatchV1
            do {
                let runtime = try engineExecutionRuntime()
                prepared = try await runtime.prepare(
                    EngineDispatchIdentityV1(
                        campId: candidate.camp.id,
                        cardId: candidate.card.id,
                        companionId: candidate.assigneeId,
                        cause: candidate.readyCause
                    )
                )
            } catch {
                guard dispatchPhase.permitsDispatch else { break }
                handleEnginePreflightFailure(error, candidate: candidate)
                continue
            }
            guard dispatchPhase.permitsDispatch,
                  !busy.contains(candidate.assigneeId),
                  !cancelling.contains(candidate.card.missionId),
                  running[candidate.card.id] == nil
            else {
                continue
            }
            let generationID = UUID()
            let startGate = EngineExecutionStartGateV1()
            let task = Task {
                do {
                    try await startGate.waitUntilOpened()
                    await self.run(
                        candidate: candidate,
                        prepared: prepared,
                        generationID: generationID
                    )
                } catch {
                    await self.runnerFinished(
                        cardId: candidate.card.id,
                        missionId: candidate.card.missionId,
                        generationID: generationID
                    )
                }
            }
            running[candidate.card.id] = RunningEntry(
                task: task,
                assigneeId: candidate.assigneeId,
                missionId: candidate.card.missionId,
                generationID: generationID
            )
            busy.insert(candidate.assigneeId)
            do {
                try await startGate.open()
            } catch {
                task.cancel()
                handleEngineExecutionFailure(
                    error,
                    candidate: candidate
                )
            }
        }
    }

    // MARK: - 紧急收哨（M7-D5）

    public var isHalted: Bool { !dispatchPhase.permitsDispatch }

    /// 一键停营：取消全部在途（卡片走既有 card_interrupted → ready 领养语义）+
    /// 终止子进程 + 停派发。恢复用 resume()。
    public func emergencyStop() async throws {
        switch dispatchPhase {
        case .halting, .shuttingDown:
            return
        case .halted:
            let activeKinds = try await db.pool.read { database in
                try EngineExecutionStore.activeRecoveryProfileKinds(
                    database: database
                )
            }
            if !haltPersistencePending,
               try db.dispatchMode() == .halted,
               activeKinds.isEmpty {
                return
            }
        case .running, .resuming:
            break
        }

        try await planningSupervisor.suppressForEmergencyStop()
        startupRecoveryPending = false
        invalidateStartupPlanningRecoveryEligibility()
        let stopToken = beginTransition(.halting)
        tickTask?.cancel()
        tickTask = nil

        var firstError: (any Error)?
        var haltCleanupCommitted = false
        do {
            if try db.dispatchMode() == .running {
                _ = try db.transitionDispatchMode(
                    from: .running,
                    to: .halted
                )
            }
            haltPersistencePending = false
        } catch {
            haltPersistencePending = true
            let detail = String(describing: error)
            let failure = HaltPersistenceError(detail: detail)
            let message = failure.errorDescription ?? detail
            Self.logger.error("\(message, privacy: .public)")
            db.appendKernelErrorEvent(missionId: "", message: message)
            emit(.kernelError(missionId: "", message: message))
            firstError = failure
        }

        let cancellationReason = "emergency_halt"
        for (cardID, var entry) in running {
            entry.cancellationReason = cancellationReason
            running[cardID] = entry
        }
        let runningSnapshot = running
        let runtime: EngineExecutionRuntimeV1?
        do {
            runtime = try engineExecutionRuntime()
        } catch {
            runtime = nil
            if firstError == nil { firstError = error }
        }
        if let runtime {
            for entry in runningSnapshot.values {
                guard let executionID = entry.executionId else { continue }
                do {
                    try await runtime.cancel(
                        executionId: executionID,
                        reason: cancellationReason
                    )
                } catch {
                    if firstError == nil { firstError = error }
                }
            }
        }
        for entry in runningSnapshot.values {
            entry.task.cancel()
        }
        for entry in runningSnapshot.values {
            await entry.task.value
        }

        var engineRecoveryAccepted = false
        do {
            let recoveryRuntime = try await
                preparedEngineRuntimeForRecovery()
            let summary = try await recoveryRuntime.recover(
                missionId: nil,
                now: Date()
            )
            try Self.validateEngineRecoverySummaryForLifecycle(summary)
            engineRecoveryAccepted = true
        } catch {
            if firstError == nil { firstError = error }
        }

        do {
            try await recoverExternalOperationAuthority()
        } catch {
            if firstError == nil { firstError = error }
        }

        if engineRecoveryAccepted {
            do {
                try await adoptOrphans()
            } catch {
                if firstError == nil {
                    firstError = HaltRecoveryError(
                        detail: String(describing: error)
                    )
                }
            }
        }
        guard ownsTransition(stopToken, phase: .halting) else { return }

        do {
            let missionIds = try db.cancelAllPlanningForEmergencyHalt(
                reason: "emergency_halt_during_planning",
                now: Date()
            )
            try await planningSupervisor.didCommitEmergencyPlanningCleanup(
                missionIds: missionIds
            )
            haltCleanupCommitted = true
        } catch {
            reportPlanningCleanupFailure(error, prefix: "紧急收哨")
            if firstError == nil {
                firstError = PlanningHaltCleanupError(
                    detail: String(describing: error)
                )
            }
        }
        guard ownsTransition(stopToken, phase: .halting) else { return }

        // M8：先优雅停驿站（状态回 stopped，恢复后可自动再启），再扫尾杀残余子进程；
        // 直接 terminateAll 会让驿站走「意外死亡」路径卡在 down（down 只能手动重启）。
        await mcpManager?.stopAll()
        guard ownsTransition(stopToken, phase: .halting) else { return }
        ShellProcessRegistry.shared.terminateAll()
        dispatchPhase = .halted
        if haltCleanupCommitted {
            emit(.haltStateChanged(true))
        }
        if let firstError {
            throw firstError
        }
    }

    /// 解除收哨并立即调度（中断的卡已在 ready，直接续跑）
    public func resume() async throws {
        switch dispatchPhase {
        case .running:
            return
        case .resuming:
            throw KernelTransitionInProgressError()
        case .halted:
            break
        case .halting, .shuttingDown:
            throw KernelHaltedError()
        }
        startupRecoveryPending = false
        let resumeToken = beginTransition(.resuming)

        let durableMode: DispatchMode
        do {
            durableMode = try db.dispatchMode()
        } catch {
            guard ownsTransition(resumeToken, phase: .resuming) else {
                throw KernelTransitionInProgressError()
            }
            dispatchPhase = .halted
            reportPlanningCleanupFailure(error, prefix: "恢复前")
            throw PlanningHaltCleanupError(
                detail: String(describing: error)
            )
        }

        if durableMode == .running,
           !planningRecoveryCompleted,
           startupDispatchModeError != nil,
           planningSupervisorFirstPhaseRetryEligible
                != planningSupervisorCardRetryEligible
        {
            try await retryFailedStartupRecovery(
                transitionToken: resumeToken
            )
            return
        }

        do {
            let runtime = try await preparedEngineRuntimeForRecovery()
            try requireTransition(resumeToken, phase: .resuming)
            try await recoverExternalOperationAuthority()
            try requireTransition(resumeToken, phase: .resuming)
            let summary = try await runtime.recover(
                missionId: nil,
                now: Date()
            )
            try Self.validateEngineRecoverySummaryForLifecycle(summary)
        } catch {
            guard ownsTransition(resumeToken, phase: .resuming) else {
                throw KernelTransitionInProgressError()
            }
            dispatchPhase = .halted
            emit(.haltStateChanged(true))
            throw error
        }
        try requireTransition(resumeToken, phase: .resuming)

        if let resumePreAdoptionGate {
            await resumePreAdoptionGate()
        }
        try requireTransition(resumeToken, phase: .resuming)

        // Recover crash residue while the gate is still closed. Opening the durable
        // projection first would let unrelated starts race ahead of failed recovery.
        do {
            try await adoptOrphans()
        } catch {
            guard ownsTransition(resumeToken, phase: .resuming) else {
                throw KernelTransitionInProgressError()
            }
            dispatchPhase = .halted
            let message = "恢复前领养失败，已保持停止：\(String(describing: error))"
            Self.logger.error("\(message, privacy: .public)")
            db.appendKernelErrorEvent(missionId: "", message: message)
            emit(.haltStateChanged(true))
            emit(.kernelError(missionId: "", message: message))
            throw HaltRecoveryError(detail: String(describing: error))
        }
        try requireTransition(resumeToken, phase: .resuming)
        do {
            try healOrphanedConfirmedProposals()
        } catch {
            guard ownsTransition(resumeToken, phase: .resuming) else {
                throw KernelTransitionInProgressError()
            }
            dispatchPhase = .halted
            let message =
                "恢复前提案自愈失败，已保持停止：\(String(describing: error))"
            Self.logger.error("\(message, privacy: .public)")
            emit(.haltStateChanged(true))
            throw HaltRecoveryError(detail: String(describing: error))
        }
        try requireTransition(resumeToken, phase: .resuming)

        do {
            guard durableMode == .halted else {
                throw StaleKernelControlStateError(
                    expected: .halted,
                    actual: durableMode
                )
            }
            if planningSupervisorRecoveryCompleted {
                let missionIds =
                    try db.cancelAllPlanningForEmergencyHalt(
                        reason: "emergency_halt_during_planning",
                        now: Date()
                    )
                try await planningSupervisor
                    .didCommitEmergencyPlanningCleanup(
                        missionIds: missionIds
                    )
            } else {
                let recoveredMode = try await planningSupervisor
                    .recoverOnStartup(
                        profileModels: try legacyPlanningProfileModels(),
                        legacyRuminationSnapshot:
                            legacyRuminationSnapshot
                    )
                try requireTransition(resumeToken, phase: .resuming)
                guard recoveredMode == .halted else {
                    throw StaleKernelControlStateError(
                        expected: .halted,
                        actual: recoveredMode
                    )
                }
                startupRecoveryObservedMode = recoveredMode
                planningSupervisorRecoveryCompleted = true
            }
        } catch {
            guard ownsTransition(resumeToken, phase: .resuming) else {
                throw KernelTransitionInProgressError()
            }
            dispatchPhase = .halted
            reportPlanningCleanupFailure(error, prefix: "恢复前")
            emit(.haltStateChanged(true))
            throw PlanningHaltCleanupError(
                detail: String(describing: error)
            )
        }
        try requireTransition(resumeToken, phase: .resuming)

        do {
            _ = try db.transitionDispatchMode(from: .halted, to: .running)
            do {
                try await planningSupervisor.resumeAfterDurableRunning()
            } catch {
                do {
                    _ = try db.transitionDispatchMode(
                        from: .running,
                        to: .halted
                    )
                } catch {
                    let message =
                        "规划监督器未能恢复，且持久化停营回滚失败：\(String(describing: error))"
                    Self.logger.fault(
                        "\(message, privacy: .public)"
                    )
                    db.appendKernelErrorEvent(
                        missionId: "",
                        message: message
                    )
                    emit(
                        .kernelError(
                            missionId: "",
                            message: message
                        )
                    )
                }
                throw error
            }
        } catch {
            dispatchPhase = .halted
            let message = "恢复全部行动失败，系统仍保持停止：\(String(describing: error))"
            Self.logger.error("\(message, privacy: .public)")
            db.appendKernelErrorEvent(missionId: "", message: message)
            emit(.kernelError(missionId: "", message: message))
            throw error
        }

        startupDispatchModeError = nil
        invalidateStartupPlanningRecoveryEligibility()
        planningSupervisorRecoveryCompleted = true
        planningRecoveryCompleted = true
        haltPersistencePending = false
        dispatchPhase = .running
        emit(.haltStateChanged(false))
        await reconcile()
    }

    private func retryFailedStartupRecovery(
        transitionToken: UUID
    ) async throws {
        try requireTransition(transitionToken, phase: .resuming)
        guard try db.dispatchMode() == .running,
              planningSupervisorFirstPhaseRetryEligible
                != planningSupervisorCardRetryEligible
        else {
            throw KernelTransitionInProgressError()
        }

        let retriesFirstPhase =
            planningSupervisorFirstPhaseRetryEligible
        invalidateStartupPlanningRecoveryEligibility()
        do {
            if retriesFirstPhase {
                planningSupervisorRecoveryCompleted = false
                startupRecoveryObservedMode = nil
            }
            try await finishStartupRecovery(
                transitionToken: transitionToken
            )
        } catch let pending as EngineRecoveryPendingF2ErrorV1 {
            guard ownsTransition(transitionToken, phase: .resuming) else {
                throw KernelTransitionInProgressError()
            }
            setStartupRetryEligibilityAfterFailure()
            dispatchPhase = .halted
            startupDispatchModeError = pending.errorDescription
            emit(.haltStateChanged(true))
            throw pending
        } catch {
            guard ownsTransition(transitionToken, phase: .resuming) else {
                throw KernelTransitionInProgressError()
            }
            setStartupRetryEligibilityAfterFailure()
            dispatchPhase = .halted
            let message = "Engine startup recovery retry failed."
            startupDispatchModeError = message
            Self.logger.error("\(message, privacy: .public)")
            db.appendKernelErrorEvent(missionId: "", message: message)
            emit(.haltStateChanged(true))
            emit(.kernelError(missionId: "", message: message))
            throw HaltRecoveryError(detail: message)
        }
    }

    // MARK: - 限流冷却（M7-D8）

    private static func isRateLimit(_ error: ProviderError) -> Bool {
        switch error {
        case .http(let status, _): return status == 429
        case .overloadedRetriesExhausted: return true
        default: return false
        }
    }

    private func startRateLimitCooldown(missionId: String) {
        cooldownUntil = rateLimitNow() + rateLimitCooldownDuration
        try? db.pool.write { database in
            try AppDatabase.appendEvent(
                database, missionId: missionId, cardId: nil, runId: nil,
                kind: EventKind.rateLimitCooldown,
                payload: ["seconds": .number(15)])
        }
    }

    public func cancelMission(_ missionId: String) async {
        guard let mission = try? db.mission(id: missionId),
              mission.status != .accepted,
              mission.status != .failed else {
            return
        }
        cancelling.insert(missionId)

        if mission.status == .planning {
            defer { cancelling.remove(missionId) }
            do {
                try await planningSupervisor.cancelPlanning(
                    missionId: missionId,
                    reason: "mission_abandoned"
                )
                emit(.missionChanged(missionId: missionId))
            } catch {
                let message = String(describing: error)
                db.appendKernelErrorEvent(
                    missionId: missionId,
                    message: message
                )
                emit(
                    .kernelError(
                        missionId: missionId,
                        message: message
                    )
                )
            }
            return
        }

        let cancellationReason = "mission_abandoned"
        for (cardID, var entry) in running
            where entry.missionId == missionId
        {
            entry.cancellationReason = cancellationReason
            running[cardID] = entry
        }
        let runningForMission = running.filter {
            $0.value.missionId == missionId
        }
        var firstError: (any Error)?
        var firstReport: (code: String, description: String)?
        let runtime: EngineExecutionRuntimeV1?
        do {
            runtime = try engineExecutionRuntime()
        } catch {
            runtime = nil
            firstError = error
            firstReport = (
                Self.engineLifecycleFailureCode,
                Self.engineLifecycleFailureDescription
            )
        }
        if let runtime {
            for entry in runningForMission.values {
                guard let executionID = entry.executionId else { continue }
                do {
                    try await runtime.cancel(
                        executionId: executionID,
                        reason: cancellationReason
                    )
                } catch {
                    if firstError == nil {
                        firstError = error
                        firstReport = (
                            Self.engineLifecycleFailureCode,
                            Self.engineLifecycleFailureDescription
                        )
                    }
                }
            }
        }
        for entry in runningForMission.values {
            entry.task.cancel()
        }
        for entry in runningForMission.values {
            await entry.task.value
        }

        var engineRecoveryAccepted = false
        do {
            let recoveryRuntime = try await
                preparedEngineRuntimeForRecovery()
            let summary = try await recoveryRuntime.recover(
                missionId: missionId,
                now: Date()
            )
            do {
                try Self.validateEngineRecoverySummaryForLifecycle(summary)
                engineRecoveryAccepted = true
            } catch let pending as EngineRecoveryPendingF2ErrorV1 {
                if firstError == nil {
                    firstError = pending
                    firstReport = (
                        pending.code,
                        pending.errorDescription ?? ""
                    )
                }
            } catch {
                if firstError == nil {
                    firstError = error
                    firstReport = (
                        Self.engineLifecycleFailureCode,
                        Self.engineLifecycleFailureDescription
                    )
                }
            }
        } catch {
            if firstError == nil {
                firstError = error
                firstReport = (
                    Self.engineLifecycleFailureCode,
                    Self.engineLifecycleFailureDescription
                )
            }
        }

        do {
            try await recoverExternalOperationAuthority()
        } catch {
            if firstError == nil {
                firstError = error
                firstReport = (
                    Self.engineLifecycleFailureCode,
                    Self.engineLifecycleFailureDescription
                )
            }
        }

        if engineRecoveryAccepted, firstError == nil {
            do {
                try await markOpenRunsCanceled(missionId: missionId)
            } catch {
                firstError = error
                firstReport = (
                    Self.engineLifecycleFailureCode,
                    Self.engineLifecycleFailureDescription
                )
            }
        }

        if engineRecoveryAccepted, firstError == nil {
          do {
            try await db.pool.write { database in
                guard var mission = try MissionRecord.fetchOne(database, key: missionId),
                      mission.status != .accepted,
                      mission.status != .failed else {
                    return
                }
                let previous = mission.status
                mission.status = .failed
                try mission.update(database)
                try AppDatabase.appendEvent(
                    database,
                    missionId: missionId,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.missionFailed,
                    payload: ["reason": "abandoned"]
                )
                try AppDatabase.appendEvent(
                    database,
                    missionId: missionId,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.missionStatusChanged,
                    payload: ["from": .string(previous.rawValue), "to": .string(MissionStatus.failed.rawValue)]
                )
                let cards = try CardRecord
                    .filter(Column("missionId") == missionId)
                    .order(Column("stage"))
                    .fetchAll(database)
                for card in cards where card.status != .done && card.status != .canceled {
                    try db.transitionCard(
                        database,
                        id: card.id,
                        to: .canceled,
                        eventKind: EventKind.cardCanceled,
                        payload: ["reason": "mission_abandoned"]
                    )
                }
            }
            emit(.missionChanged(missionId: missionId))
          } catch {
              firstError = error
              firstReport = (
                  Self.engineLifecycleFailureCode,
                  Self.engineLifecycleFailureDescription
              )
          }
        }
        if let firstReport {
            persistEngineLifecycleFailure(
                missionId: missionId,
                code: firstReport.code,
                description: firstReport.description
            )
            _ = firstError
            return
        }
        cancelling.remove(missionId)
    }

    private func markOpenRunsCanceled(missionId: String) async throws {
        try await db.pool.write { database in
            let runs = try RunRecord.fetchAll(
                database,
                sql: """
                    SELECT r.*
                    FROM run r
                    JOIN card c ON c.id = r.cardId
                    WHERE c.missionId = ? AND r.outcome IS NULL
                      AND NOT EXISTS(
                        SELECT 1 FROM engine_execution execution
                        WHERE execution.runId=r.id
                          AND execution.redactedAt IS NULL
                      )
                      AND NOT EXISTS(
                        SELECT 1 FROM engine_execution execution
                        WHERE execution.cardId=c.id
                          AND execution.redactedAt IS NULL
                      )
                    """,
                arguments: [missionId]
            )
            for var run in runs {
                run.outcome = "canceled"
                run.endedAt = Date()
                try run.update(database)
            }
        }
    }

    public func answerUserRequest(
        requestId: String,
        answerJson: String,
        deviceId: String? = nil
    ) async throws {
        let request = try await db.pool.read { database in
            try UserRequestRecord.fetchOne(database, key: requestId)
        }
        guard let request else {
            throw StaleUserRequestError(requestId: requestId)
        }
        if request.kind == .approval {
            guard let deviceId else {
                throw ApprovalAnswerContractError()
            }
            _ = try ApprovalGrantStore(database: db)
                .answerApprovalRequest(
                    requestId: requestId,
                    answerJson: answerJson,
                    deviceId: deviceId
                )
        } else {
            try db.answerUserRequest(
                requestId: requestId,
                answerJson: answerJson
            )
        }
        let missionId = try await db.pool.read { database -> String in
            guard let card = try CardRecord.fetchOne(
                database,
                key: request.cardId
            ) else {
                throw RecordNotFoundError(
                    table: CardRecord.databaseTableName,
                    id: request.cardId
                )
            }
            return card.missionId
        }
        emit(.missionChanged(missionId: missionId))
        await reconcile()
    }

    public func retryCard(_ cardId: String) async throws {
        try db.transitionCard(id: cardId, to: .ready, eventKind: EventKind.cardReady, payload: .object([:]))
        await reconcile()
    }

    package func retryContext(cardId: String) async throws {
        guard let card = try db.card(id: cardId) else {
            throw RecordNotFoundError(table: "card", id: cardId)
        }
        guard card.status == .ready else {
            throw CardTransitionError(from: card.status, to: .ready)
        }
        guard running[cardId] == nil else {
            throw KernelTransitionInProgressError()
        }
        contextSuppressedCardIds.remove(cardId)
        await reconcile()
    }

    /// M9：用户退回已完成小目标，保留上一版交付作为重做上下文，并立即重新调度。
    public func returnCardForRework(cardId: String, feedback: String) async throws {
        try db.returnCardForRework(cardId: cardId, feedback: feedback)
        if let missionId = try db.card(id: cardId)?.missionId {
            emit(.missionChanged(missionId: missionId))
        }
        await reconcile()
    }

    /// 提案确认（spec §10.2，plan D5/D10）：先 CAS（pending→confirmed）再建队；
    /// 建队失败补偿回滚 pending。重复确认在 CAS 处抛 StaleProposalError——宁可回滚，绝不重复建队。
    package func confirmSquadProposal(
        _ captured: CapturedProposalMissionStart
    ) async throws -> String {
        try requireDispatchRunning()
        let messageId = captured.messageId
        let block = try db.confirmProposalBlock(messageId: messageId)
        do {
            guard block.proposalId == captured.proposalId else {
                throw CapturedProposalIdentityMismatchError(
                    expectedProposalId: captured.proposalId,
                    actualProposalId: block.proposalId
                )
            }
            // 提案建队归属向导所在营地（M5-0：从提案消息所在线程推导）
            let campId = try db.chatThread(forMessage: messageId)?.campId
            let missionId = try await startMission(
                goal: block.goal,
                companionIds: block.memberIds,
                workspacePath: nil,
                plannerModel: captured.runtime.plannerModel,
                runtimeProfileId:
                    captured.runtime.runtimeProfileId,
                budgetTokens:
                    block.budget ?? captured.fallbackBudget,
                campId: campId,
                autonomy: captured.autonomy,
                idempotencyKey: captured.idempotencyKey,
                traceId: captured.traceId
            )
            try db.attachMissionToProposal(messageId: messageId, missionId: missionId)
            try? await db.pool.write { database in
                try AppDatabase.appendEvent(
                    database, missionId: missionId, cardId: nil, runId: nil,
                    kind: EventKind.squadProposalConfirmed,
                    payload: [
                        "proposalId": .string(block.proposalId),
                        "missionId": .string(missionId),
                    ]
                )
            }
            return missionId
        } catch {
            try? db.revertProposalToPending(messageId: messageId)
            throw error
        }
    }

    /// 三选之「加预算」（M5-2）：追加后解除通知去重并立刻恢复调度。
    public func addBudget(missionId: String, tokens: Int) async throws {
        try db.addBudget(missionId: missionId, tokens: tokens)
        budgetNotified.remove(missionId)
        emit(.missionChanged(missionId: missionId))
        await reconcile()
    }

    /// 三选之「就地收成果」（M5-2）：取消未完成的卡，保留已完成的——
    /// rollup 自然落位：有 done → delivering（可正常收营蒸馏）；全军覆没 → failed。
    public func harvestMission(_ missionId: String) async {
        guard let mission = try? db.mission(id: missionId),
              mission.status == .executing else {
            return
        }
        cancelling.insert(missionId)
        defer { cancelling.remove(missionId) }

        let runningForMission = running.filter { $0.value.missionId == missionId }
        for (_, entry) in runningForMission {
            entry.task.cancel()
        }
        for (cardId, entry) in runningForMission {
            await entry.task.value
            running.removeValue(forKey: cardId)
        }
        do {
            try await markOpenRunsCanceled(missionId: missionId)
            try await db.pool.write { database in
                let cards = try CardRecord
                    .filter(Column("missionId") == missionId)
                    .order(Column("stage"))
                    .fetchAll(database)
                for card in cards where card.status != .done && card.status != .canceled {
                    try self.db.transitionCard(
                        database,
                        id: card.id,
                        to: .canceled,
                        eventKind: EventKind.cardCanceled,
                        payload: ["reason": "budget_harvest"]
                    )
                }
            }
            emit(.missionChanged(missionId: missionId))
        } catch {
            let message = String(describing: error)
            db.appendKernelErrorEvent(missionId: missionId, message: message)
            emit(.kernelError(missionId: missionId, message: message))
        }
    }

    public func closeout(_ missionId: String, distillModel: String) async throws {
        try await db.pool.write { database in
            guard var mission = try MissionRecord.fetchOne(database, key: missionId) else {
                throw RecordNotFoundError(table: "mission", id: missionId)
            }
            guard mission.status == .delivering else {
                throw MissionStateError(missionId: missionId, from: mission.status, expected: .delivering)
            }
            let previous = mission.status
            mission.status = .accepted
            try mission.update(database)
            try AppDatabase.appendEvent(database, missionId: missionId, cardId: nil, runId: nil,
                                        kind: EventKind.missionAccepted, payload: .object([:]))
            try AppDatabase.appendEvent(
                database,
                missionId: missionId,
                cardId: nil,
                runId: nil,
                kind: EventKind.missionStatusChanged,
                payload: ["from": .string(previous.rawValue), "to": .string(MissionStatus.accepted.rawValue)]
            )
        }
        emit(.missionChanged(missionId: missionId))
        regenerateExpeditionReport(missionId: missionId)
        try await memoryPromotionSupervisor.enqueueCloseout(
            missionId: missionId,
            model: distillModel
        )
    }

    /// M9：验收后写入确定性远征报告。报告失败只进入内核错误事件，不反向阻塞收营。
    private func regenerateExpeditionReport(missionId: String) {
        do {
            _ = try reportStore.regenerateReport(missionId: missionId)
        } catch {
            let message = "远征报告写入失败：\(String(describing: error))"
            db.appendKernelErrorEvent(missionId: missionId, message: message)
            emit(.kernelError(missionId: missionId, message: message))
        }
    }

    private func handleMemoryPromotionEvent(
        _ event: CampMemoryPromotionEventV1
    ) {
        switch event {
        case .campNoteCreated(let missionId, let noteId):
            emit(.campNoteCreated(missionId: missionId, noteId: noteId))
        case .missionChanged(let missionId):
            emit(.missionChanged(missionId: missionId))
        case .failed(let missionId, let errorType):
            let message =
                "收营记忆任务失败，已保留持久检查点：\(errorType)"
            db.appendKernelErrorEvent(missionId: missionId, message: message)
            emit(.kernelError(missionId: missionId, message: message))
        }
    }

    public func waitUntilIdle() async throws {
        try await planningSupervisor.waitUntilIdle()
        await reconcile()
        await waitUntilLocallyIdle()
        await memoryPromotionSupervisor.waitUntilIdle()
        try await planningSupervisor.waitUntilIdle()
        if !isLocallyIdle {
            await waitUntilLocallyIdle()
        }
        await memoryPromotionSupervisor.waitUntilIdle()
    }

    @discardableResult
    public func shutdown() async -> ShutdownReport {
        startupRecoveryPending = false
        invalidateStartupPlanningRecoveryEligibility()
        dispatchTransitionToken = UUID()
        dispatchPhase = .shuttingDown
        tickTask?.cancel()
        tickTask = nil

        var firstError: (any Error)?
        var firstReport: (code: String, description: String)?
        let cancellationReason = "engine_shutdown"
        for (cardID, var entry) in running {
            entry.cancellationReason = cancellationReason
            running[cardID] = entry
        }
        let runningSnapshot = running

        var runtime: EngineExecutionRuntimeV1?
        do {
            runtime = try engineExecutionRuntime()
        } catch {
            firstError = error
            firstReport = (
                Self.engineLifecycleFailureCode,
                Self.engineLifecycleFailureDescription
            )
        }
        if let runtime {
            for entry in runningSnapshot.values {
                guard let executionID = entry.executionId else { continue }
                do {
                    try await runtime.cancel(
                        executionId: executionID,
                        reason: cancellationReason
                    )
                } catch {
                    if firstError == nil {
                        firstError = error
                        firstReport = (
                            Self.engineLifecycleFailureCode,
                            Self.engineLifecycleFailureDescription
                        )
                    }
                }
            }
        }
        for entry in runningSnapshot.values {
            entry.task.cancel()
        }
        for entry in runningSnapshot.values {
            await entry.task.value
        }
        wakeLocalIdleWaitersIfNeeded()

        var engineRecoveryAccepted = false
        do {
            let recoveryRuntime = try await
                preparedEngineRuntimeForRecovery()
            if runtime == nil {
                runtime = recoveryRuntime
            }
            let summary = try await recoveryRuntime.recover(
                missionId: nil,
                now: Date()
            )
            do {
                try Self.validateEngineRecoverySummaryForLifecycle(summary)
                engineRecoveryAccepted = true
            } catch let pending as EngineRecoveryPendingF2ErrorV1 {
                if firstError == nil {
                    firstError = pending
                    firstReport = (
                        pending.code,
                        pending.errorDescription ?? ""
                    )
                }
            } catch {
                if firstError == nil {
                    firstError = error
                    firstReport = (
                        Self.engineLifecycleFailureCode,
                        Self.engineLifecycleFailureDescription
                    )
                }
            }
        } catch {
            if firstError == nil {
                firstError = error
                firstReport = (
                    Self.engineLifecycleFailureCode,
                    Self.engineLifecycleFailureDescription
                )
            }
        }

        do {
            try await recoverExternalOperationAuthority()
        } catch {
            if firstError == nil {
                firstError = error
                firstReport = (
                    Self.engineLifecycleFailureCode,
                    Self.engineLifecycleFailureDescription
                )
            }
        }

        if engineRecoveryAccepted {
            do {
                try await adoptOrphans()
            } catch {
                if firstError == nil {
                    firstError = error
                    firstReport = (
                        Self.engineLifecycleFailureCode,
                        Self.engineLifecycleFailureDescription
                    )
                }
            }
        }
        do {
            try healOrphanedConfirmedProposals()
        } catch {
            if firstError == nil {
                firstError = error
                firstReport = (
                    Self.engineLifecycleFailureCode,
                    Self.engineLifecycleFailureDescription
                )
            }
        }

        let planningReport = await planningSupervisor.shutdown()
        if !planningReport.uncooperativeWorkIds.isEmpty,
           firstError == nil
        {
            firstError = EngineDispatchConflictErrorV1()
            firstReport = (
                Self.engineLifecycleFailureCode,
                Self.engineLifecycleFailureDescription
            )
        }
        await memoryPromotionSupervisor.shutdown()
        await mcpManager?.stopAll()
        ShellProcessRegistry.shared.terminateAll()
        if !running.isEmpty, firstError == nil {
            firstError = EngineDispatchConflictErrorV1()
            firstReport = (
                Self.engineLifecycleFailureCode,
                Self.engineLifecycleFailureDescription
            )
        }

        if let runtime {
            do {
                try await runtime.closeRuntimeAuthorities()
            } catch {
                if firstError == nil {
                    firstError = error
                    firstReport = (
                        Self.engineLifecycleFailureCode,
                        Self.engineLifecycleFailureDescription
                    )
                }
            }
        }
        if let firstReport {
            persistEngineLifecycleFailure(
                missionId: "",
                code: firstReport.code,
                description: firstReport.description
            )
            _ = firstError
        }
        for (_, continuation) in continuations {
            continuation.finish()
        }
        continuations.removeAll()
        return planningReport
    }

    private func run(
        candidate: DispatchCandidate,
        prepared: EnginePreparedDispatchV1,
        generationID: UUID
    ) async {
        do {
            try Task.checkCancellation()
            guard dispatchPhase.permitsDispatch else {
                throw CancellationError()
            }
            let runtime = try engineExecutionRuntime()
            let receipt = try await runtime.execute(
                prepared,
                onExecutionBound: engineExecutionBindCallback(
                    cardId: candidate.card.id,
                    missionId: candidate.card.missionId,
                    assigneeId: candidate.assigneeId,
                    generationID: generationID
                )
            )
            if receipt.reasonCode == CardRunner.rateLimitReasonCode {
                startRateLimitCooldown(
                    missionId: candidate.card.missionId
                )
            }
        } catch is CancellationError {
        } catch let providerError as ProviderError
            where Self.isRateLimit(providerError)
        {
            startRateLimitCooldown(
                missionId: candidate.card.missionId
            )
            handleEngineExecutionFailure(
                providerError,
                candidate: candidate
            )
        } catch {
            handleEngineExecutionFailure(error, candidate: candidate)
        }
        await runnerFinished(
            cardId: candidate.card.id,
            missionId: candidate.card.missionId,
            generationID: generationID
        )
    }

    private func handleEnginePreflightFailure(
        _ error: any Error,
        candidate: DispatchCandidate
    ) {
        let message: String
        switch error {
        case is EngineContextValidationErrorV1,
             is EngineCardReadyCauseErrorV1:
            message = "Engine execution context preflight failed."
        case is EngineAdapterSelectionErrorV1,
             is CliHelpProbeFailureV1:
            message = "Engine execution adapter preflight failed."
        case is EngineRuntimeAuthorityErrorV1,
             is EngineRuntimeCleanupAggregateErrorV1:
            message = "Engine execution authority preflight failed."
        default:
            message = "Engine execution preflight failed."
        }
        readyCauseSuppression[candidate.card.id] =
            candidate.readyObservation
        db.appendKernelErrorEvent(
            missionId: candidate.card.missionId,
            message: message
        )
        emit(
            .kernelError(
                missionId: candidate.card.missionId,
                message: message
            )
        )
    }

    private func handleEngineExecutionFailure(
        _ error: any Error,
        candidate: DispatchCandidate
    ) {
        let errorType = String(reflecting: type(of: error))
        let message = "Engine execution failed [\(errorType)]."
        db.appendKernelErrorEvent(
            missionId: candidate.card.missionId,
            message: message
        )
        emit(
            .kernelError(
                missionId: candidate.card.missionId,
                message: message
            )
        )
    }

    private func handleCardProviderResolutionFailure(
        _ error: Error,
        candidate: DispatchCandidate
    ) {
        let message = "伙伴「\(candidate.companionName)」的供给线没有可用模型或凭据，卡片已暂停派发"
        do {
            try db.blockCard(
                id: candidate.card.id,
                runId: nil,
                reason: "other",
                detail: message
            )
            db.appendKernelErrorEvent(
                missionId: candidate.card.missionId,
                message: message
            )
            emit(.kernelError(
                missionId: candidate.card.missionId,
                message: message
            ))
            emit(.missionChanged(missionId: candidate.card.missionId))
        } catch {
            // A failed durable transition must not leave an unchanged ready
            // card in the immediate runnerFinished -> reconcile loop.
            contextSuppressedCardIds.insert(candidate.card.id)
            let detail = String(describing: error)
            db.appendKernelErrorEvent(
                missionId: candidate.card.missionId,
                message: detail
            )
            emit(.kernelError(
                missionId: candidate.card.missionId,
                message: detail
            ))
        }
    }

    private func loadUpstreamHandoffs(for card: CardRecord) throws -> [UpstreamHandoff] {
        let dependencyIds = try Self.decodeStringArray(card.dependsOnJson)
        guard !dependencyIds.isEmpty else { return [] }
        let upstreamCards = try db.pool.read { database in
            try CardRecord
                .filter(keys: dependencyIds)
                .order(Column("stage"))
                .fetchAll(database)
        }
        var upstream: [UpstreamHandoff] = []
        for upstreamCard in upstreamCards {
            guard let handoffJson = upstreamCard.handoffJson else {
                throw ProviderError.malformedStream("upstream handoff missing for card \(upstreamCard.id)")
            }
            let handoff = try JSONDecoder().decode(HandoffPayload.self, from: Data(handoffJson.utf8))
            let artifacts = try db.artifacts(cardId: upstreamCard.id)
            upstream.append(
                UpstreamHandoff(
                    cardTitle: upstreamCard.title,
                    handoff: handoff,
                    workspaceRelativePaths: handoff.artifacts.map(\.relativePath),
                    durablePaths: artifacts.map(\.path)
                )
            )
        }
        return upstream
    }

    private func runnerFinished(
        cardId: String,
        missionId: String,
        generationID: UUID? = nil
    ) async {
        if let generationID {
            guard let entry = running[cardId],
                  entry.missionId == missionId,
                  entry.generationID == generationID
            else {
                Self.logger.error(
                    "stale engine runner completion rejected"
                )
                return
            }
        }
        running.removeValue(forKey: cardId)
        wakeLocalIdleWaitersIfNeeded()
        emit(.missionChanged(missionId: missionId))
        await reconcile()
    }

    private func requireDispatchRunning() throws {
        guard dispatchPhase.permitsDispatch else {
            throw KernelHaltedError()
        }
    }

    private func beginTransition(_ phase: DispatchPhase) -> UUID {
        let token = UUID()
        dispatchTransitionToken = token
        dispatchPhase = phase
        return token
    }

    private func invalidateStartupPlanningRecoveryEligibility() {
        planningSupervisorFirstPhaseRetryEligible = false
        planningSupervisorCardRetryEligible = false
    }

    private func setStartupRetryEligibilityAfterFailure() {
        invalidateStartupPlanningRecoveryEligibility()
        guard !haltPersistencePending,
              (try? db.dispatchMode()) == .running
        else {
            return
        }
        if planningSupervisorRecoveryCompleted {
            planningSupervisorCardRetryEligible = true
        } else {
            planningSupervisorFirstPhaseRetryEligible = true
        }
    }

    private func ownsTransition(_ token: UUID, phase: DispatchPhase) -> Bool {
        dispatchTransitionToken == token && dispatchPhase == phase
    }

    private func requireTransition(_ token: UUID, phase: DispatchPhase) throws {
        guard ownsTransition(token, phase: phase) else {
            throw KernelTransitionInProgressError()
        }
    }

    private func reportPlanningCleanupFailure(_ error: Error, prefix: String) {
        let message = "\(prefix)的规划收口失败，已保持停止：\(String(describing: error))"
        Self.logger.error("\(message, privacy: .public)")
        db.appendKernelErrorEvent(missionId: "", message: message)
        emit(.kernelError(missionId: "", message: message))
    }

    private func legacyPlanningProfileModels() throws -> [String: String] {
        let defaults = ProfileScopedDefaults()
        return Dictionary(
            uniqueKeysWithValues: try db.runtimeProfiles().map { profile in
                let planner = defaults.plannerModel(profileID: profile.id)
                let model = planner.isEmpty
                    ? defaults.defaultModel(
                        profileID: profile.id,
                        fallback: KernelDefaults.defaultGuideModel
                    )
                    : planner
                return (profile.id, model)
            }
        )
    }

    private func planningMissionChanged(_ missionId: String) {
        emit(.missionChanged(missionId: missionId))
    }

    private var isLocallyIdle: Bool {
        running.isEmpty && !reconciling
    }

    private func waitUntilLocallyIdle() async {
        while !isLocallyIdle {
            let waiterId = UUID()
            await withCheckedContinuation { continuation in
                if isLocallyIdle {
                    continuation.resume()
                } else {
                    localIdleWaiters[waiterId] = continuation
                }
            }
        }
    }

    private func wakeLocalIdleWaitersIfNeeded() {
        guard isLocallyIdle, !localIdleWaiters.isEmpty else {
            return
        }
        let waiters = Array(localIdleWaiters.values)
        localIdleWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func ensureTickStarted() {
        guard tickTask == nil, let tickInterval else { return }
        tickTask = Task { [tickInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: tickInterval)
                if Task.isCancelled { break }
                await self.reconcile()
            }
        }
    }

    private func observeCommittedEngineEvent(
        cardId: String,
        event: EngineExecutionEvent
    ) async {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(cardId)
            try CanonicalContractCodingV1.validateCanonicalUUID(
                event.executionId
            )
            try CanonicalContractCodingV1.validateNonnegative(event.sequence)
            switch event.payload {
            case .accepted:
                emit(.cardEvent(cardId: cardId, .turnStarted))

            case let .progress(message):
                emit(.cardEvent(cardId: cardId, .textDelta(message)))

            case let .toolActivity(name):
                emit(.cardEvent(cardId: cardId, .toolStarted(name: name)))

            case let .usage(usage):
                try usage.validateNonnegative()
                emit(
                    .cardEvent(
                        cardId: cardId,
                        .turnEnded(
                            usage: Usage(
                                inputTokens: usage.inputTokens,
                                outputTokens: usage.outputTokens,
                                cacheReadTokens: usage.cacheReadTokens
                            )
                        )
                    )
                )

            case .sessionBound:
                break

            case let .terminal(content):
                guard content.executionId == event.executionId,
                      content.sequence == event.sequence,
                      content.cardId == cardId
                else {
                    throw EngineTerminalConflictErrorV1()
                }
                let missionId = try await db.pool.read { database in
                    guard let execution = try EngineExecutionRecord.fetchOne(
                        database,
                        key: event.executionId
                    ), execution.id == event.executionId,
                       execution.cardId == cardId,
                       execution.dispatchState == .terminal,
                       execution.state != .running,
                       execution.redactedAt == nil,
                       let card = try CardRecord.fetchOne(
                           database,
                           key: cardId
                       ), card.id == cardId,
                       let mission = try MissionRecord.fetchOne(
                           database,
                           key: card.missionId
                       ), mission.id == card.missionId
                    else {
                        throw EngineTerminalConflictErrorV1()
                    }
                    return mission.id
                }
                emit(.missionChanged(missionId: missionId))
            }
        } catch {
            Self.logger.error(
                "Committed engine event observation failed after Store commit"
            )
            emit(
                .kernelError(
                    missionId: "",
                    message: "Engine event observation failed."
                )
            )
        }
    }

    private func engineExecutionBindCallback(
        cardId: String,
        missionId: String,
        assigneeId: String,
        generationID: UUID
    ) -> EngineExecutionDidBindV1 {
        { [self] request in
            try await self.bindRunningExecution(
                cardId: cardId,
                missionId: missionId,
                assigneeId: assigneeId,
                generationID: generationID,
                request: request
            )
        }
    }

    private func bindRunningExecution(
        cardId: String,
        missionId: String,
        assigneeId: String,
        generationID: UUID,
        request: EngineExecutionRequest
    ) throws -> EngineExecutionBindDispositionV1 {
        try CanonicalContractCodingV1.validateCanonicalUUID(cardId)
        try CanonicalContractCodingV1.validateCanonicalUUID(missionId)
        try CanonicalContractCodingV1.validateCanonicalUUID(assigneeId)
        try request.validateCanonicalIdentity()
        guard request.cardId == cardId,
              var entry = running[cardId],
              entry.missionId == missionId,
              entry.assigneeId == assigneeId,
              entry.generationID == generationID,
              entry.executionId == nil
        else {
            throw EngineDispatchConflictErrorV1()
        }
        let persistedMissionId = try db.pool.read { database in
            guard let execution = try EngineExecutionRecord.fetchOne(
                database,
                key: request.executionId
            ), execution.id == request.executionId,
               execution.requestHash == request.requestHash,
               execution.runId == request.runId,
               execution.cardId == request.cardId,
               execution.state == .running,
               execution.redactedAt == nil,
               let card = try CardRecord.fetchOne(database, key: cardId),
               card.id == cardId,
               let mission = try MissionRecord.fetchOne(
                   database,
                   key: card.missionId
               ), mission.id == card.missionId
            else {
                throw EngineDispatchConflictErrorV1()
            }
            return mission.id
        }
        guard persistedMissionId == entry.missionId,
              persistedMissionId == missionId
        else {
            throw EngineDispatchConflictErrorV1()
        }
        if let reason = entry.cancellationReason {
            try EngineContractValidationV1.validateReasonCode(reason)
        }
        entry.executionId = request.executionId
        running[cardId] = entry
        if let reason = entry.cancellationReason {
            return .cancel(reason: reason)
        }
        return .dispatch
    }

    private func emit(_ event: KernelEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func emitFromTask(_ event: KernelEvent) {
        emit(event)
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private static func decodeStringArray(_ json: String) throws -> [String] {
        try JSONDecoder().decode([String].self, from: Data(json.utf8))
    }

    private static func runtimeProfileKind(
        for companion: CompanionRecord,
        database: Database
    ) throws -> RuntimeProfileKind {
        let defaultProfile = try RuntimeProfileRecord
            .filter(Column("isDefault") == true)
            .fetchOne(database)
        if let runtimeProfileId = companion.runtimeProfileId,
           let profile = try RuntimeProfileRecord.fetchOne(database, key: runtimeProfileId) {
            return profile.kind
        }
        return defaultProfile?.kind ?? .anthropicAPI
    }

    private struct DispatchCandidate: Sendable {
        let card: CardRecord
        let mission: MissionRecord
        let camp: CampRecord
        let companion: CompanionRecord
        let assigneeId: String
        let companionName: String
        let rolePrompt: String
        let model: String
        let runtimeProfileKind: RuntimeProfileKind
        let toolsJson: String
        let autonomy: MissionAutonomy
        let readyCause: EngineCardReadyCauseV1
        let readyObservation: EngineCardReadyObservationV1
    }

    private struct RunningEntry: Sendable {
        // Single in-memory dispatch authority for M3. The DB transition guard remains the
        // persistence backstop; M5 can revisit crash recovery for this registry.
        let task: Task<Void, Never>
        let assigneeId: String
        let missionId: String
        let generationID: UUID
        var executionId: String?
        var cancellationReason: String?

        init(
            task: Task<Void, Never>,
            assigneeId: String,
            missionId: String,
            generationID: UUID
        ) {
            self.task = task
            self.assigneeId = assigneeId
            self.missionId = missionId
            self.generationID = generationID
            executionId = nil
            cancellationReason = nil
        }
    }

    private struct KernelErrorRecord: Sendable {
        let missionId: String
        let message: String
    }

    private struct ReadyCauseFailure: Sendable {
        let cardId: String
        let missionId: String
        let observation: EngineCardReadyObservationV1
    }

    private struct ReconcilePlan: Sendable {
        let candidates: [DispatchCandidate]
        let kernelErrors: [KernelErrorRecord]
        let readyCauseFailures: [ReadyCauseFailure]
        let budgetExhaustedMissionIds: Set<String>
    }
}

package struct CapturedProposalIdentityMismatchError:
    Error, Sendable, Equatable
{
    package let expectedProposalId: String
    package let actualProposalId: String

    package init(expectedProposalId: String, actualProposalId: String) {
        self.expectedProposalId = expectedProposalId
        self.actualProposalId = actualProposalId
    }
}

@MainActor
package final class PlanningEntryCoordinator {
    private let db: AppDatabase
    private let orchestrator: Orchestrator
    private let makeUUIDString: @MainActor () -> String

    package init(
        db: AppDatabase,
        orchestrator: Orchestrator,
        makeUUIDString: @escaping @MainActor () -> String = {
            UUID().uuidString
        }
    ) {
        self.db = db
        self.orchestrator = orchestrator
        self.makeUUIDString = makeUUIDString
    }

    package func prepareManual(
        snapshot: ManualMissionStartSnapshot,
        pending: PendingManualMissionStart?,
        forceNewCommand: Bool
    ) -> PendingManualMissionStart {
        let mission = snapshot.mission
        let normalizedSnapshot = ManualMissionStartSnapshot(
            mission: PlanningMissionStartArguments(
                goal: mission.goal,
                companionIds: mission.companionIds,
                workspacePath: mission.workspacePath,
                budgetTokens: max(1, mission.budgetTokens),
                campId: mission.campId,
                autonomy: mission.autonomy
            ),
            runtime: snapshot.runtime
        )
        if !forceNewCommand,
           let pending,
           pending.snapshot == normalizedSnapshot {
            return pending
        }
        return PendingManualMissionStart(
            snapshot: normalizedSnapshot,
            idempotencyKey:
                "mission-start:user:\(makeUUIDString()):v1",
            traceId: makeUUIDString()
        )
    }

    package func startManual(
        _ command: PendingManualMissionStart
    ) async throws -> String {
        let mission = command.snapshot.mission
        let runtime = command.snapshot.runtime
        return try await orchestrator.startMission(
            goal: mission.goal,
            companionIds: mission.companionIds,
            workspacePath: mission.workspacePath,
            plannerModel: runtime.plannerModel,
            runtimeProfileId: runtime.runtimeProfileId,
            budgetTokens: mission.budgetTokens,
            campId: mission.campId,
            autonomy: mission.autonomy,
            idempotencyKey: command.idempotencyKey,
            traceId: command.traceId
        )
    }

    package func clearManualAfterSuccess(
        current: PendingManualMissionStart?,
        completed: PendingManualMissionStart
    ) -> PendingManualMissionStart? {
        current == completed ? nil : current
    }

    package func captureCandidate(
        draft: CodingRanchMissionDraft,
        runtime: PlanningEntryRuntimeSelection
    ) -> CapturedCandidateMissionStart {
        CapturedCandidateMissionStart(
            draft: draft,
            runtime: runtime,
            idempotencyKey:
                "mission-start:candidate:\(draft.candidateId):v1",
            traceId: makeUUIDString()
        )
    }

    package func startCandidate(
        _ captured: CapturedCandidateMissionStart,
        goal: String,
        companionId: String,
        workspacePath: String?,
        budgetTokens: Int,
        autonomy: MissionAutonomy
    ) async throws -> String {
        let planningInput = try PlanningWorkInput(
            plannerModel: captured.runtime.plannerModel,
            runtimeProfileId: captured.runtime.runtimeProfileId
        )
        let command = CandidatePlanningStartCommand(
            draft: captured.draft,
            goal: goal,
            companionId: companionId,
            workspacePath: workspacePath,
            budgetTokens: budgetTokens,
            autonomy: autonomy,
            planningInput: planningInput,
            idempotencyKey: captured.idempotencyKey,
            traceId: captured.traceId
        )
        let result = try await orchestrator
            .convertCandidateAndEnqueuePlanning(command)
        return result.missionId
    }

    package func captureConfirmedProposal(
        messageId: String,
        runtime: PlanningEntryRuntimeSelection,
        fallbackBudget: Int,
        autonomy: MissionAutonomy
    ) throws -> CapturedProposalMissionStart {
        let block = try db.pool.read { database in
            guard let message = try ChatMessageRecord.fetchOne(
                database,
                key: messageId
            ),
            let block = message.proposal
            else {
                throw RecordNotFoundError(
                    table: "chat_message(proposal)",
                    id: messageId
                )
            }
            guard block.status == .pending else {
                throw StaleProposalError(messageId: messageId)
            }
            return block
        }
        return CapturedProposalMissionStart(
            messageId: messageId,
            proposalId: block.proposalId,
            runtime: runtime,
            fallbackBudget: max(1, fallbackBudget),
            autonomy: autonomy,
            idempotencyKey:
                "mission-start:proposal:\(block.proposalId):v1",
            traceId: makeUUIDString()
        )
    }

    package func startConfirmedProposal(
        _ captured: CapturedProposalMissionStart
    ) async throws -> String {
        try await orchestrator.confirmSquadProposal(captured)
    }

    package func captureScheduledMission(
        scheduleId: String,
        context: ScheduleSlotContextV1,
        selectRuntime:
            @MainActor () throws -> PlanningEntryRuntimeSelection
    ) throws -> SchedulePlanningStartCommand {
        try captureScheduledMission(
            scheduleId: scheduleId,
            context: context,
            selectRuntime: selectRuntime,
            traceId: makeUUIDString()
        )
    }

    package func captureScheduledMission(
        scheduleId: String,
        context: ScheduleSlotContextV1,
        selectRuntime:
            @MainActor () throws -> PlanningEntryRuntimeSelection,
        traceId: String
    ) throws -> SchedulePlanningStartCommand {
        SchedulePlanningStartCommand(
            scheduleId: scheduleId,
            context: context,
            preparation: try Self.schedulePreparation(
                selectRuntime: selectRuntime
            ),
            traceId: traceId
        )
    }

    package func captureMissedScheduledMission(
        scheduleId: String,
        context: ScheduleSlotContextV1
    ) -> SchedulePlanningStartCommand {
        captureMissedScheduledMission(
            scheduleId: scheduleId,
            context: context,
            traceId: makeUUIDString()
        )
    }

    package func captureMissedScheduledMission(
        scheduleId: String,
        context: ScheduleSlotContextV1,
        traceId: String
    ) -> SchedulePlanningStartCommand {
        SchedulePlanningStartCommand(
            scheduleId: scheduleId,
            context: context,
            preparation: .forcedFailure,
            traceId: traceId
        )
    }

    package func captureScheduleReplay(
        originalFireId: String,
        selectRuntime:
            @MainActor () throws -> PlanningEntryRuntimeSelection
    ) throws -> ScheduleReplayStartCommand {
        try captureScheduleReplay(
            originalFireId: originalFireId,
            selectRuntime: selectRuntime,
            traceId: makeUUIDString()
        )
    }

    package func captureScheduleReplay(
        originalFireId: String,
        selectRuntime:
            @MainActor () throws -> PlanningEntryRuntimeSelection,
        traceId: String
    ) throws -> ScheduleReplayStartCommand {
        guard let original = try db.scheduleFire(id: originalFireId) else {
            throw RecordNotFoundError(
                table: ScheduleFireRecord.databaseTableName,
                id: originalFireId
            )
        }
        guard original.state == .failed,
              original.replayOfFireId == nil
        else {
            throw InvalidScheduleReplaySourceError(
                originalFireId: originalFireId
            )
        }
        guard let schedule = try db.schedule(id: original.scheduleId) else {
            throw RecordNotFoundError(
                table: ScheduleRecord.databaseTableName,
                id: original.scheduleId
            )
        }
        let preparation = try Self.schedulePreparation(
            selectRuntime: selectRuntime
        )
        let payload = try ScheduleReplayPayloadV1(
            originalFire: original,
            effectiveTemplateId: schedule.templateId,
            preparation: preparation
        )
        return ScheduleReplayStartCommand(
            originalFireId: original.id,
            replayIdempotencyKey:
                "schedule-replay:\(makeUUIDString().lowercased())",
            payload: payload,
            replayPayloadHash: try payload.canonicalHash(),
            traceId: traceId
        )
    }

    package func startScheduledMission(
        _ command: SchedulePlanningStartCommand
    ) async throws -> ScheduleFireCommitResult {
        try await orchestrator.commitScheduledMission(command)
    }

    package func replayMissedScheduleFire(
        _ command: ScheduleReplayStartCommand
    ) async throws -> ScheduleFireCommitResult {
        try await orchestrator.replayMissedScheduleFire(command)
    }

    package func wakeScheduledPlanning(
        _ result: ScheduleFireCommitResult
    ) async throws {
        try await orchestrator.wakeScheduledPlanning(result)
    }

    private static func schedulePreparation(
        selectRuntime:
            @MainActor () throws -> PlanningEntryRuntimeSelection
    ) throws -> ScheduleFirePreparation {
        do {
            let runtime = try selectRuntime()
            guard Self.isNonBlank(runtime.runtimeProfileId),
                  Self.isNonBlank(runtime.plannerModel)
            else {
                return .unavailable
            }
            return .selected(
                runtimeProfileId: runtime.runtimeProfileId,
                plannerModel: runtime.plannerModel
            )
        } catch let error as RecordNotFoundError where
            error.table == "runtime_profile(default)"
                && error.id == "default"
        {
            return .unavailable
        } catch {
            throw error
        }
    }

    private static func isNonBlank(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
