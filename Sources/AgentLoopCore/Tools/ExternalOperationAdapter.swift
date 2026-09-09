import Foundation

package struct ExternalOperationAdapterResultV1: Sendable, Equatable {
    package let acceptance: AdapterAcceptanceAttestationV1
    package let effect: AdapterEffectAttestationV1

    package init(
        acceptance: AdapterAcceptanceAttestationV1,
        effect: AdapterEffectAttestationV1
    ) throws {
        guard acceptance.adapterId == effect.adapterId,
              acceptance.useId == effect.useId,
              acceptance.useIdempotencyKey == effect.useIdempotencyKey,
              effect.operationId == acceptance.operationId
        else {
            throw ExternalOperationAttestationError()
        }
        self.acceptance = acceptance
        self.effect = effect
    }
}

package enum ExternalOperationRecoveryResultV1: Sendable, Equatable {
    case completed(ExternalOperationAdapterResultV1)
    case noEffect(AdapterNoEffectAttestationV1)
    case unresolved(evidenceHash: String)
}

package protocol ExternalOperationAdapterV1: Sendable {
    var descriptor: ExternalOperationAdapterDescriptorV1 { get }

    func execute(
        input: JSONValue,
        useId: String,
        idempotencyKey: String
    ) async throws -> ExternalOperationAdapterResultV1

    func recoverPending(
        useId: String,
        idempotencyKey: String,
        operationId: String?
    ) async throws -> ExternalOperationRecoveryResultV1
}

package struct ExternalOperationSanitizedAcknowledgmentV1:
    Sendable, Equatable
{
    package let useId: String
    package let state: ApprovalGrantUseStateV1
    package let operationId: String?

    package init(
        useId: String,
        state: ApprovalGrantUseStateV1,
        operationId: String?
    ) {
        self.useId = useId
        self.state = state
        self.operationId = operationId
    }
}

package protocol ExternalOperationWorkflowPortV1: Sendable {
    func execute(
        grantId: String,
        expectedGrantVersion: Int,
        capability: String,
        campId: String,
        cardId: String,
        toolId: String,
        input: JSONValue,
        adapter: any ExternalOperationAdapterV1
    ) async throws -> ExternalOperationSanitizedAcknowledgmentV1

    func recoverPending() async throws
}

package struct ExternalOperationWorkflowUnavailableError:
    Error, Sendable, Equatable
{
    package init() {}
}

package actor ToolHandlerExternalOperationAdapterV1:
    ExternalOperationAdapterV1
{
    nonisolated package let descriptor:
        ExternalOperationAdapterDescriptorV1
    private let inner: any ToolHandler
    private var localOutcomes: [String: ToolOutcome] = [:]

    package init(
        toolId: String,
        inner: any ToolHandler
    ) throws {
        descriptor = try ExternalOperationAdapterDescriptorV1(
            adapterId: "tool-handler:v1:\(toolId)",
            toolId: toolId,
            replayClass: .nonReplayable
        )
        self.inner = inner
    }

    package func execute(
        input: JSONValue,
        useId: String,
        idempotencyKey: String
    ) async throws -> ExternalOperationAdapterResultV1 {
        let outcome = await inner.execute(input: input)
        localOutcomes[useId] = outcome
        let operationId = "tool-operation:v1:" + CanonicalJSONV1.sha256Hex(
            Data("\(descriptor.adapterId):\(idempotencyKey)".utf8)
        )
        let material = Self.outcomeMaterial(outcome)
        return try ExternalOperationAdapterResultV1(
            acceptance: AdapterAcceptanceAttestationV1(
                adapterId: descriptor.adapterId,
                useId: useId,
                useIdempotencyKey: idempotencyKey,
                operationId: operationId,
                evidenceHash: CanonicalJSONV1.sha256Hex(
                    Data("accepted:\(operationId)".utf8)
                )
            ),
            effect: AdapterEffectAttestationV1(
                adapterId: descriptor.adapterId,
                useId: useId,
                useIdempotencyKey: idempotencyKey,
                operationId: operationId,
                result: material.result,
                receiptRef: material.receiptRef,
                evidenceHash: CanonicalJSONV1.sha256Hex(material.evidence)
            )
        )
    }

    package func recoverPending(
        useId: String,
        idempotencyKey: String,
        operationId: String?
    ) async throws -> ExternalOperationRecoveryResultV1 {
        .unresolved(
            evidenceHash: CanonicalJSONV1.sha256Hex(
                Data("non-replayable:\(descriptor.adapterId):\(useId)".utf8)
            )
        )
    }

    package func takeLocalOutcome(useId: String) -> ToolOutcome? {
        localOutcomes.removeValue(forKey: useId)
    }

    private nonisolated static func outcomeMaterial(
        _ outcome: ToolOutcome
    ) -> (
        result: ExternalOperationReceiptResultV1,
        receiptRef: String,
        evidence: Data
    ) {
        switch outcome {
        case .result(let text):
            return (
                .succeeded,
                "local-tool-result:v1",
                Data("result:\(text)".utf8)
            )
        case .error(let text):
            return (
                .failedFinal,
                "local-tool-error:v1",
                Data("error:\(text)".utf8)
            )
        case .completed(let payload):
            return (
                .succeeded,
                "local-tool-completed:v1",
                Data("completed:\(String(describing: payload))".utf8)
            )
        case .blocked(let reason, let detail):
            return (
                .succeeded,
                "local-tool-blocked:v1",
                Data("blocked:\(reason):\(detail)".utf8)
            )
        }
    }
}
