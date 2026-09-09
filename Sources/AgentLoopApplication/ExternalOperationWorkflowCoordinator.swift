import Foundation
import AgentLoopCore

package enum ExternalOperationWorkflowCheckpointV1:
    String, Sendable, Equatable, CaseIterable
{
    case beforeDispatchIntent
    case afterDispatchIntentBeforeAdapter
    case afterAdapterEffectBeforeAcceptance
    case afterAdapterAcceptedBeforeTerminal
}

package struct ExternalOperationInjectedCrashV1:
    Error, Sendable, Equatable
{
    package let checkpoint: ExternalOperationWorkflowCheckpointV1

    package init(checkpoint: ExternalOperationWorkflowCheckpointV1) {
        self.checkpoint = checkpoint
    }
}

package struct ExternalOperationUserResolutionRequiredV1:
    Error, Sendable, Equatable
{
    package let useId: String

    package init(useId: String) {
        self.useId = useId
    }
}

package struct ExternalOperationAdapterRegistryMissingV1:
    Error, Sendable, Equatable
{
    package let adapterId: String

    package init(adapterId: String) {
        self.adapterId = adapterId
    }
}

package struct ExternalOperationRecoveryUnresolvedV1:
    Error, Sendable, Equatable
{
    package let useId: String

    package init(useId: String) {
        self.useId = useId
    }
}

package struct ExternalOperationWorkflowScopeMismatchV1:
    Error, Sendable, Equatable
{
    package init() {}
}

package actor ExternalOperationWorkflowCoordinator:
    ExternalOperationWorkflowPortV1
{
    private let store: ApprovalGrantStore
    private let clock: @Sendable () -> Date
    private let checkpoint: @Sendable (
        ExternalOperationWorkflowCheckpointV1,
        ApprovalGrantUseSnapshotV1
    ) throws -> Void
    private var adapters: [
        ExternalOperationAdapterDescriptorV1:
            any ExternalOperationAdapterV1
    ]

    package init(
        store: ApprovalGrantStore,
        clock: @escaping @Sendable () -> Date = { Date() },
        registeredAdapters: [any ExternalOperationAdapterV1] = [],
        checkpoint: @escaping @Sendable (
            ExternalOperationWorkflowCheckpointV1,
            ApprovalGrantUseSnapshotV1
        ) throws -> Void = { _, _ in }
    ) {
        self.store = store
        self.clock = clock
        self.checkpoint = checkpoint
        var registry: [
            ExternalOperationAdapterDescriptorV1:
                any ExternalOperationAdapterV1
        ] = [:]
        for adapter in registeredAdapters {
            registry[adapter.descriptor] = adapter
        }
        adapters = registry
    }

    package func execute(
        grantId: String,
        expectedGrantVersion: Int,
        capability: String,
        campId: String,
        cardId: String,
        toolId: String,
        input: JSONValue,
        adapter: any ExternalOperationAdapterV1
    ) async throws -> ExternalOperationSanitizedAcknowledgmentV1 {
        let inputHash = try ApprovalToken.hash(input: input)
        let descriptor = adapter.descriptor
        guard descriptor.toolId == toolId else {
            throw ExternalOperationWorkflowScopeMismatchV1()
        }
        adapters[descriptor] = adapter

        guard let grant = try store.grant(id: grantId),
              grant.capability == capability,
              grant.campId == campId,
              grant.cardId == cardId,
              grant.toolId == toolId,
              grant.approvedInputHash == inputHash,
              grant.adapterReplayClass == descriptor.replayClass
        else {
            throw ExternalOperationWorkflowScopeMismatchV1()
        }

        if let existing = try store.uses(grantId: grantId).last {
            try validateExistingUse(
                existing,
                inputHash: inputHash,
                descriptor: descriptor
            )
            switch existing.state {
            case .succeeded, .failedFinal, .abandonedUnknown:
                return acknowledgment(existing)
            case .crashUnknown:
                throw ExternalOperationUserResolutionRequiredV1(
                    useId: existing.id
                )
            case .dispatching, .accepted:
                return try await recoverUse(existing, adapter: adapter)
            case .reserved:
                return try await executeReserved(
                    existing,
                    input: input,
                    adapter: adapter
                )
            case .released:
                break
            }
        }

        guard grant.version == expectedGrantVersion else {
            throw ApprovalGrantConflictError()
        }
        let useId = try store.nextUseIdentity(grantId: grantId)
        let reserved = try store.reserveUse(ReserveApprovalGrantUseCommandV1(
            envelope: commandEnvelope(key: useId),
            useId: useId,
            grantId: grantId,
            expectedGrantVersion: expectedGrantVersion,
            capability: capability,
            campId: campId,
            cardId: cardId,
            toolId: toolId,
            inputHash: inputHash,
            adapter: descriptor
        ))
        return try await executeReserved(
            reserved,
            input: input,
            adapter: adapter
        )
    }

    package func recoverPending() async throws {
        for use in try store.pendingUses() {
            if use.adapterReplayClass == .nonReplayable {
                _ = try markNonReplayableUnknownIfNeeded(use)
                throw ExternalOperationUserResolutionRequiredV1(useId: use.id)
            }
            let descriptor = try ExternalOperationAdapterDescriptorV1(
                adapterId: use.adapterId,
                toolId: use.toolId,
                replayClass: use.adapterReplayClass
            )
            guard let adapter = adapters[descriptor] else {
                throw ExternalOperationAdapterRegistryMissingV1(
                    adapterId: use.adapterId
                )
            }
            _ = try await recoverUse(use, adapter: adapter)
        }
    }
}

extension ExternalOperationWorkflowCoordinator {
    private func executeReserved(
        _ reserved: ApprovalGrantUseSnapshotV1,
        input: JSONValue,
        adapter: any ExternalOperationAdapterV1
    ) async throws -> ExternalOperationSanitizedAcknowledgmentV1 {
        try checkpoint(.beforeDispatchIntent, reserved)
        guard let grant = try store.grant(id: reserved.grantId) else {
            throw ApprovalGrantConflictError()
        }
        let dispatched = try store.commitDispatchIntent(
            ApprovalGrantUseTransitionCommandV1(
                envelope: commandEnvelope(
                    key: transitionKey(reserved, "dispatch-intent")
                ),
                useId: reserved.id,
                expectedUseVersion: reserved.version,
                expectedGrantVersion: grant.version
            )
        )
        try checkpoint(.afterDispatchIntentBeforeAdapter, dispatched.use)

        let adapterResult: ExternalOperationAdapterResultV1
        do {
            adapterResult = try await adapter.execute(
                input: input,
                useId: dispatched.use.id,
                idempotencyKey: dispatched.use.idempotencyKey
            )
        } catch {
            if error is ExternalOperationInjectedCrashV1 { throw error }
            return try await recoverAfterAdapterFailure(
                dispatched.use,
                adapter: adapter
            )
        }
        try checkpoint(
            .afterAdapterEffectBeforeAcceptance,
            dispatched.use
        )

        let accepted = try store.recordAdapterAccepted(
            ApprovalGrantUseTransitionCommandV1(
                envelope: commandEnvelope(
                    key: transitionKey(dispatched.use, "adapter-accepted")
                ),
                useId: dispatched.use.id,
                expectedUseVersion: dispatched.use.version
            ),
            attestation: adapterResult.acceptance
        )
        try checkpoint(
            .afterAdapterAcceptedBeforeTerminal,
            accepted.use
        )
        let terminal = try store.recordEffect(
            ApprovalGrantUseTransitionCommandV1(
                envelope: commandEnvelope(
                    key: transitionKey(accepted.use, "effect-confirmed")
                ),
                useId: accepted.use.id,
                expectedUseVersion: accepted.use.version
            ),
            attestation: adapterResult.effect
        )
        return acknowledgment(terminal.use)
    }

    private func recoverAfterAdapterFailure(
        _ use: ApprovalGrantUseSnapshotV1,
        adapter: any ExternalOperationAdapterV1
    ) async throws -> ExternalOperationSanitizedAcknowledgmentV1 {
        if use.adapterReplayClass == .nonReplayable {
            _ = try markNonReplayableUnknownIfNeeded(use)
            throw ExternalOperationUserResolutionRequiredV1(useId: use.id)
        }
        return try await recoverUse(use, adapter: adapter)
    }

    private func recoverUse(
        _ suppliedUse: ApprovalGrantUseSnapshotV1,
        adapter: any ExternalOperationAdapterV1
    ) async throws -> ExternalOperationSanitizedAcknowledgmentV1 {
        guard let current = try store.use(id: suppliedUse.id) else {
            throw ApprovalGrantConflictError()
        }
        try validateExistingUse(
            current,
            inputHash: current.inputHash,
            descriptor: adapter.descriptor
        )
        if current.adapterReplayClass == .nonReplayable {
            _ = try markNonReplayableUnknownIfNeeded(current)
            throw ExternalOperationUserResolutionRequiredV1(useId: current.id)
        }
        if current.state == .succeeded || current.state == .failedFinal
            || current.state == .abandonedUnknown
        {
            return acknowledgment(current)
        }
        guard current.state == .dispatching || current.state == .accepted else {
            throw ApprovalGrantTransitionError()
        }

        let recovery: ExternalOperationRecoveryResultV1
        do {
            recovery = try await adapter.recoverPending(
                useId: current.id,
                idempotencyKey: current.idempotencyKey,
                operationId: current.adapterOperationId
            )
        } catch {
            try recordUnresolvedRecovery(
                current,
                adapterId: adapter.descriptor.adapterId,
                evidenceHash: CanonicalJSONV1.sha256Hex(
                    Data(String(reflecting: type(of: error)).utf8)
                )
            )
            throw ExternalOperationRecoveryUnresolvedV1(useId: current.id)
        }

        switch recovery {
        case let .completed(result):
            var use = current
            if use.state == .dispatching {
                use = try store.recordAdapterAccepted(
                    ApprovalGrantUseTransitionCommandV1(
                        envelope: commandEnvelope(
                            key: transitionKey(use, "recovered-accepted")
                        ),
                        useId: use.id,
                        expectedUseVersion: use.version
                    ),
                    attestation: result.acceptance
                ).use
            }
            let terminal = try store.recordEffect(
                ApprovalGrantUseTransitionCommandV1(
                    envelope: commandEnvelope(
                        key: transitionKey(use, "recovered-effect")
                    ),
                    useId: use.id,
                    expectedUseVersion: use.version
                ),
                attestation: result.effect
            )
            return acknowledgment(terminal.use)

        case let .noEffect(attestation):
            guard let grant = try store.grant(id: current.grantId) else {
                throw ApprovalGrantConflictError()
            }
            let released = try store.confirmAdapterNoEffect(
                ApprovalGrantUseTransitionCommandV1(
                    envelope: commandEnvelope(
                        key: transitionKey(current, "recovered-no-effect")
                    ),
                    useId: current.id,
                    expectedUseVersion: current.version,
                    expectedGrantVersion: grant.version
                ),
                attestation: attestation
            )
            return acknowledgment(released.use)

        case let .unresolved(evidenceHash):
            try recordUnresolvedRecovery(
                current,
                adapterId: adapter.descriptor.adapterId,
                evidenceHash: evidenceHash
            )
            throw ExternalOperationRecoveryUnresolvedV1(useId: current.id)
        }
    }

    private func recordUnresolvedRecovery(
        _ use: ApprovalGrantUseSnapshotV1,
        adapterId: String,
        evidenceHash: String
    ) throws {
        _ = try store.recordReconciliationFailure(
            ApprovalGrantUseTransitionCommandV1(
                envelope: commandEnvelope(
                    key: transitionKey(use, "reconciliation-failed")
                ),
                useId: use.id,
                expectedUseVersion: use.version
            ),
            adapterId: adapterId,
            evidenceHash: evidenceHash
        )
    }

    private func markNonReplayableUnknownIfNeeded(
        _ use: ApprovalGrantUseSnapshotV1
    ) throws -> ApprovalGrantUseSnapshotV1 {
        if use.state == .crashUnknown { return use }
        guard use.state == .dispatching || use.state == .accepted else {
            throw ApprovalGrantTransitionError()
        }
        return try store.markCrashUnknown(
            ApprovalGrantUseTransitionCommandV1(
                envelope: commandEnvelope(
                    key: transitionKey(use, "crash-unknown")
                ),
                useId: use.id,
                expectedUseVersion: use.version
            )
        )
    }

    private func validateExistingUse(
        _ use: ApprovalGrantUseSnapshotV1,
        inputHash: String,
        descriptor: ExternalOperationAdapterDescriptorV1
    ) throws {
        guard use.toolId == descriptor.toolId,
              use.inputHash == inputHash,
              use.adapterId == descriptor.adapterId,
              use.adapterReplayClass == descriptor.replayClass
        else {
            throw ExternalOperationWorkflowScopeMismatchV1()
        }
    }

    private func commandEnvelope(key: String) throws -> CommandEnvelopeV1 {
        try CommandEnvelopeV1(
            idempotencyKey: key,
            actorType: .system,
            actorId: P1DActorID.externalOperation,
            deviceId: nil,
            correlationId: "external-operation:\(key)",
            causationId: nil,
            occurredAt: try P1DTimestampV1.canonical(clock())
        )
    }

    private func transitionKey(
        _ use: ApprovalGrantUseSnapshotV1,
        _ action: String
    ) -> String {
        "external-operation:v1:\(use.id):\(action):v\(use.version)"
    }

    private func acknowledgment(
        _ use: ApprovalGrantUseSnapshotV1
    ) -> ExternalOperationSanitizedAcknowledgmentV1 {
        ExternalOperationSanitizedAcknowledgmentV1(
            useId: use.id,
            state: use.state,
            operationId: use.adapterOperationId
        )
    }
}
