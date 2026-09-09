import Foundation

package let engineExecutionProtocolVersionV1 = "agentloop.execution.v1"

package enum EngineCapabilitySupportV1: Sendable, Equatable, Codable {
    case supported
    case unsupported
    case conditional(reasonCode: String)
}

package enum EngineExecutionReplayClassV1:
    String, Sendable, Equatable, Codable, CaseIterable
{
    case replaySafe
    case idempotencyKeyed
    case nonReplayable
}

package enum EngineCapabilityV1:
    String, Sendable, Equatable, Codable, CaseIterable, Hashable
{
    case streamingProgress
    case boardTerminal
    case toolBridge
    case cancellation
    case sessionResume
    case usageMetering
    case workspaceRead
    case workspaceWrite
    case network
}

package struct EngineContextValidationErrorV1: Error, Sendable, Equatable {
    package init() {}
}

package struct EngineSessionScopeMismatchError: Error, Sendable, Equatable {
    package init() {}
}

package struct EngineExecutionReplayConflictError: Error, Sendable, Equatable {
    package init() {}
}

package struct EngineDescriptorMismatchErrorV1: Error, Sendable, Equatable {
    package init() {}
}

package struct EngineDispatchConflictErrorV1: Error, Sendable, Equatable {
    package init() {}
}

package struct EngineEventSequenceErrorV1: Error, Sendable, Equatable {
    package init() {}
}

package struct EngineRecoveryPendingF2ErrorV1:
    LocalizedError, Sendable, Equatable
{
    package init() {}

    package var code: String {
        "engine_recovery_pending_f2"
    }

    package var errorDescription: String? {
        "Engine recovery is waiting for sealed deferred cleanup."
    }
}

package enum EngineAdapterSelectionErrorV1: Error, Sendable, Equatable {
    case duplicateProfileKind(RuntimeProfileKind)
    case missingFactory(RuntimeProfileKind)
    case missingHelpSnapshot(RuntimeProfileKind)
    case unsupportedCapability(EngineCapabilityV1)
    case descriptorMismatch
}

private struct EngineExactCodingKeyV1: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

package enum EngineContractValidationV1 {
    package static func requireExactKeys(
        _ decoder: any Decoder,
        _ expected: [String]
    ) throws {
        let values = try decoder.container(keyedBy: EngineExactCodingKeyV1.self)
        guard values.allKeys.count == expected.count,
              Set(values.allKeys.map(\.stringValue)) == Set(expected)
        else {
            throw P1ContractValidationError.invalidKeys
        }
    }

    package static func validateExternalSessionID(_ value: String) throws {
        try validateBoundedNonempty(
            value,
            scalarRange: 1...512,
            byteRange: 1...512
        )
    }

    package static func validateIdempotencyKey(_ value: String) throws {
        try validateBoundedNonempty(
            value,
            scalarRange: 1...256,
            byteRange: 1...256
        )
    }

    package static func validateReasonCode(_ value: String) throws {
        try CanonicalContractCodingV1.validateCode(value)
        guard (1...128).contains(value.unicodeScalars.count),
              (1...128).contains(value.utf8.count)
        else {
            throw P1ContractValidationError.invalidCode
        }
    }

    package static func validateDetail(_ value: String) throws {
        try validateBoundedNonempty(
            value,
            scalarRange: 1...1_000,
            byteRange: 1...4_000
        )
    }

    package static func validateProgress(_ value: String) throws {
        try validateDetail(value)
    }

    package static func validateToolName(_ value: String) throws {
        try validateBoundedNonempty(
            value,
            scalarRange: 1...128,
            byteRange: 1...512
        )
    }

    package static func validateChoiceOption(_ value: String) throws {
        try validateBoundedNonempty(
            value,
            scalarRange: 1...256,
            byteRange: 1...1_024
        )
    }

    package static func validateBoundedNonempty(
        _ value: String,
        scalarRange: ClosedRange<Int>,
        byteRange: ClosedRange<Int>
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(value)
        guard scalarRange.contains(value.unicodeScalars.count),
              byteRange.contains(value.utf8.count)
        else {
            throw P1ContractValidationError.invalidValue
        }
    }
}

package struct ExecutionEngineDescriptor: Sendable {
    package let adapterId: String
    package let adapterVersion: String
    package let profileKind: RuntimeProfileKind
    package let streamingProgress: EngineCapabilitySupportV1
    package let boardTerminal: EngineCapabilitySupportV1
    package let toolBridge: EngineCapabilitySupportV1
    package let cancellation: EngineCapabilitySupportV1
    package let sessionResume: EngineCapabilitySupportV1
    package let usageMetering: EngineCapabilitySupportV1
    package let workspaceRead: EngineCapabilitySupportV1
    package let workspaceWrite: EngineCapabilitySupportV1
    package let network: EngineCapabilitySupportV1

    private let replayClassResolver:
        @Sendable (EngineSessionScopeV1) -> EngineExecutionReplayClassV1

    package init(
        adapterId: String,
        adapterVersion: String,
        profileKind: RuntimeProfileKind,
        streamingProgress: EngineCapabilitySupportV1,
        boardTerminal: EngineCapabilitySupportV1,
        toolBridge: EngineCapabilitySupportV1,
        cancellation: EngineCapabilitySupportV1,
        sessionResume: EngineCapabilitySupportV1,
        usageMetering: EngineCapabilitySupportV1,
        workspaceRead: EngineCapabilitySupportV1,
        workspaceWrite: EngineCapabilitySupportV1,
        network: EngineCapabilitySupportV1,
        replayClassResolver:
            @escaping @Sendable (EngineSessionScopeV1) -> EngineExecutionReplayClassV1
    ) {
        self.adapterId = adapterId
        self.adapterVersion = adapterVersion
        self.profileKind = profileKind
        self.streamingProgress = streamingProgress
        self.boardTerminal = boardTerminal
        self.toolBridge = toolBridge
        self.cancellation = cancellation
        self.sessionResume = sessionResume
        self.usageMetering = usageMetering
        self.workspaceRead = workspaceRead
        self.workspaceWrite = workspaceWrite
        self.network = network
        self.replayClassResolver = replayClassResolver
    }

    package func executionReplayClass(
        for scope: EngineSessionScopeV1
    ) -> EngineExecutionReplayClassV1 {
        replayClassResolver(scope)
    }

    package func support(
        for capability: EngineCapabilityV1
    ) -> EngineCapabilitySupportV1 {
        switch capability {
        case .streamingProgress: streamingProgress
        case .boardTerminal: boardTerminal
        case .toolBridge: toolBridge
        case .cancellation: cancellation
        case .sessionResume: sessionResume
        case .usageMetering: usageMetering
        case .workspaceRead: workspaceRead
        case .workspaceWrite: workspaceWrite
        case .network: network
        }
    }
}

package struct EngineAdapterHelpRequirementV1: Sendable, Equatable {
    package let kind: RuntimeProfileKind
    package let command: String

    package init(kind: RuntimeProfileKind, command: String) throws {
        guard kind == .cliCodex || kind == .cliClaude else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        do {
            try CanonicalContractCodingV1.validateNonempty(command)
        } catch {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        self.kind = kind
        self.command = command
    }

    fileprivate init(builtInKind kind: RuntimeProfileKind, command: String) {
        precondition(kind == .cliCodex || kind == .cliClaude)
        precondition(!command.isEmpty)
        self.kind = kind
        self.command = command
    }
}

package typealias EngineInitialModelLoopProviderResolveV1 =
    @Sendable (
        _ profile: RuntimeProfileRecord,
        _ companionId: String,
        _ companionModel: String,
        _ modelPolicy: CompanionModelPolicy
    ) throws -> EngineModelLoopProviderAuthorityV1

package typealias EngineRecoveryModelLoopProviderResolveV1 =
    @Sendable (
        _ profile: RuntimeProfileRecord,
        _ companionId: String,
        _ persistedModel: String
    ) throws -> EngineModelLoopProviderAuthorityV1

package struct EngineModelLoopProviderAuthorityV1: Sendable {
    package let profileId: String
    package let effectiveModel: String
    package let makeProvider: @Sendable () throws -> any LLMProvider

    package init(
        profileId: String,
        effectiveModel: String,
        makeProvider: @escaping @Sendable () throws -> any LLMProvider
    ) throws {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(profileId)
            try CanonicalContractCodingV1.validateNonempty(effectiveModel)
        } catch {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        guard effectiveModel != "cli-default" else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        self.profileId = profileId
        self.effectiveModel = effectiveModel
        self.makeProvider = makeProvider
    }
}

package struct EngineExecutionTransportSeedV1: Sendable {
    package let context: EnginePreparedContextV1
    package let workspace: EnginePreparedWorkspaceClaimV1
    package let baseRequiredCapabilities: [EngineCapabilityV1]
    package let bridgeExecutableAuthority:
        EngineBoardBridgeExecutableAuthorityV1?
    package let boardSocketDirectoryAuthority:
        EngineBoardSocketDirectoryAuthorityV1?
    package let validateCodexManagedPolicy:
        EngineCliManagedPolicyValidateV1?
    package let validateClaudeManagedPolicy:
        EngineCliManagedPolicyValidateV1?
    package let claudeConfigDirectory: URL
    package let cliExecutableDirectory: URL
    package let resolveInitialModelLoopProvider:
        EngineInitialModelLoopProviderResolveV1
    package let resolveRecoveryModelLoopProvider:
        EngineRecoveryModelLoopProviderResolveV1
    package let makeCliProcessDriver:
        @Sendable () throws -> any CliProcessDrivingV1

    package init(
        context: EnginePreparedContextV1,
        workspace: EnginePreparedWorkspaceClaimV1,
        baseRequiredCapabilities: [EngineCapabilityV1],
        bridgeExecutableAuthority:
            EngineBoardBridgeExecutableAuthorityV1?,
        boardSocketDirectoryAuthority:
            EngineBoardSocketDirectoryAuthorityV1?,
        validateCodexManagedPolicy:
            EngineCliManagedPolicyValidateV1?,
        validateClaudeManagedPolicy:
            EngineCliManagedPolicyValidateV1?,
        claudeConfigDirectory: URL,
        cliExecutableDirectory: URL,
        resolveInitialModelLoopProvider:
            @escaping EngineInitialModelLoopProviderResolveV1,
        resolveRecoveryModelLoopProvider:
            @escaping EngineRecoveryModelLoopProviderResolveV1,
        makeCliProcessDriver:
            @escaping @Sendable () throws -> any CliProcessDrivingV1
    ) {
        self.context = context
        self.workspace = workspace
        self.baseRequiredCapabilities = baseRequiredCapabilities
        self.bridgeExecutableAuthority = bridgeExecutableAuthority
        self.boardSocketDirectoryAuthority = boardSocketDirectoryAuthority
        self.validateCodexManagedPolicy = validateCodexManagedPolicy
        self.validateClaudeManagedPolicy = validateClaudeManagedPolicy
        self.claudeConfigDirectory = claudeConfigDirectory
        self.cliExecutableDirectory = cliExecutableDirectory
        self.resolveInitialModelLoopProvider =
            resolveInitialModelLoopProvider
        self.resolveRecoveryModelLoopProvider =
            resolveRecoveryModelLoopProvider
        self.makeCliProcessDriver = makeCliProcessDriver
    }
}

package struct EngineAdapterPreparedRequestV1: Sendable {
    package let descriptor: ExecutionEngineDescriptor
    package let engineKind: String
    package let model: String
    package let budget: EngineExecutionBudgetV1
    package let context: EnginePreparedContextVariantV1
    package let requiredCapabilities: [EngineCapabilityV1]
    package let makeTransport:
        @Sendable (
            EngineExecutionRequest,
            EngineResolvedContextTransportV1,
            EngineResolvedWorkspaceV1
        ) throws -> EngineExecutionTransportV1

    package init(
        descriptor: ExecutionEngineDescriptor,
        engineKind: String,
        model: String,
        budget: EngineExecutionBudgetV1,
        context: EnginePreparedContextVariantV1,
        requiredCapabilities: [EngineCapabilityV1],
        makeTransport:
            @escaping @Sendable (
                EngineExecutionRequest,
                EngineResolvedContextTransportV1,
                EngineResolvedWorkspaceV1
            ) throws -> EngineExecutionTransportV1
    ) {
        self.descriptor = descriptor
        self.engineKind = engineKind
        self.model = model
        self.budget = budget
        self.context = context
        self.requiredCapabilities = requiredCapabilities
        self.makeTransport = makeTransport
    }
}

package struct EngineAdapterFactoryV1: Sendable {
    package let adapterId: String
    package let adapterVersion: String
    package let profileKinds: Set<RuntimeProfileKind>
    package let helpRequirement: EngineAdapterHelpRequirementV1?
    package let descriptor:
        @Sendable (RuntimeProfileRecord, CliHelpSnapshotV1?) throws
            -> ExecutionEngineDescriptor
    package let prepareRequest:
        @Sendable (
            RuntimeProfileRecord,
            CliHelpSnapshotV1?,
            EngineExecutionTransportSeedV1
        ) throws -> EngineAdapterPreparedRequestV1
    package let makeRecoveryTransport:
        @Sendable (
            RuntimeProfileRecord,
            CliHelpSnapshotV1?,
            EngineExecutionRequest,
            EngineResolvedContextTransportV1,
            EngineResolvedWorkspaceV1,
            EngineExecutionTransportSeedV1
        ) throws -> EngineExecutionTransportV1
    package let makeAdapter:
        @Sendable (RuntimeProfileRecord, EngineAdapterRuntimeV1) throws
            -> any ExecutionEngineAdapter

    package init(
        adapterId: String,
        adapterVersion: String,
        profileKinds: Set<RuntimeProfileKind>,
        helpRequirement: EngineAdapterHelpRequirementV1?,
        descriptor:
            @escaping @Sendable (RuntimeProfileRecord, CliHelpSnapshotV1?) throws
                -> ExecutionEngineDescriptor,
        prepareRequest:
            @escaping @Sendable (
                RuntimeProfileRecord,
                CliHelpSnapshotV1?,
                EngineExecutionTransportSeedV1
            ) throws -> EngineAdapterPreparedRequestV1,
        makeRecoveryTransport:
            @escaping @Sendable (
                RuntimeProfileRecord,
                CliHelpSnapshotV1?,
                EngineExecutionRequest,
                EngineResolvedContextTransportV1,
                EngineResolvedWorkspaceV1,
                EngineExecutionTransportSeedV1
            ) throws -> EngineExecutionTransportV1,
        makeAdapter:
            @escaping @Sendable (RuntimeProfileRecord, EngineAdapterRuntimeV1) throws
                -> any ExecutionEngineAdapter
    ) {
        self.adapterId = adapterId
        self.adapterVersion = adapterVersion
        self.profileKinds = profileKinds
        self.helpRequirement = helpRequirement
        self.descriptor = descriptor
        self.prepareRequest = prepareRequest
        self.makeRecoveryTransport = makeRecoveryTransport
        self.makeAdapter = makeAdapter
    }

    package func validateRegistration(
        helpSnapshot: CliHelpSnapshotV1?,
        validateCodexManagedPolicy: EngineCliManagedPolicyValidateV1?,
        validateClaudeManagedPolicy: EngineCliManagedPolicyValidateV1?
    ) throws {
        guard let requirement = helpRequirement else {
            guard helpSnapshot == nil else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            return
        }
        guard let helpSnapshot,
              helpSnapshot.kind == requirement.kind,
              helpSnapshot.command == requirement.command,
              helpSnapshot.executableAuthority.kind == requirement.kind
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        let validator: EngineCliManagedPolicyValidateV1?
        switch requirement.kind {
        case .cliCodex:
            validator = validateCodexManagedPolicy
        case .cliClaude:
            validator = validateClaudeManagedPolicy
        case .anthropicAPI, .openAIAPI, .chatGPTOAuth:
            validator = nil
        }
        guard let validator else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        do {
            try validator(helpSnapshot.executableAuthority)
        } catch {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
    }

    package static func builtInFactories(
        makeModelLoopAdapter:
            @escaping @Sendable (
                RuntimeProfileRecord, EngineAdapterRuntimeV1
            ) throws -> any ExecutionEngineAdapter,
        makeCodexAdapter:
            @escaping @Sendable (
                RuntimeProfileRecord, EngineAdapterRuntimeV1
            ) throws -> any ExecutionEngineAdapter,
        makeClaudeAdapter:
            @escaping @Sendable (
                RuntimeProfileRecord, EngineAdapterRuntimeV1
            ) throws -> any ExecutionEngineAdapter
    ) -> [EngineAdapterFactoryV1] {
        let model = EngineAdapterFactoryV1(
            adapterId: "agentloop.model-loop",
            adapterVersion: "1",
            profileKinds: [.anthropicAPI, .openAIAPI, .chatGPTOAuth],
            helpRequirement: nil,
            descriptor: { profile, help in
                try builtInDescriptor(
                    profile: profile,
                    help: help,
                    adapterId: "agentloop.model-loop"
                )
            },
            prepareRequest: { profile, help, seed in
                try prepareModelLoop(
                    profile: profile,
                    help: help,
                    seed: seed,
                    recoveryModel: nil
                )
            },
            makeRecoveryTransport: {
                profile, help, request, context, workspace, seed in
                let prepared = try prepareModelLoop(
                    profile: profile,
                    help: help,
                    seed: seed,
                    recoveryModel: request.model
                )
                return try prepared.makeTransport(
                    request,
                    context,
                    workspace
                )
            },
            makeAdapter: makeModelLoopAdapter
        )
        let codexRequirement = EngineAdapterHelpRequirementV1(
            builtInKind: .cliCodex,
            command: "codex"
        )
        let codex = EngineAdapterFactoryV1(
            adapterId: "agentloop.cli.codex",
            adapterVersion: "1",
            profileKinds: [.cliCodex],
            helpRequirement: codexRequirement,
            descriptor: { profile, help in
                try builtInDescriptor(
                    profile: profile,
                    help: help,
                    adapterId: "agentloop.cli.codex"
                )
            },
            prepareRequest: { profile, help, seed in
                try prepareCLI(
                    profile: profile,
                    help: help,
                    requirement: codexRequirement,
                    seed: seed,
                    recoveryModel: nil
                )
            },
            makeRecoveryTransport: {
                profile, help, request, context, workspace, seed in
                let prepared = try prepareCLI(
                    profile: profile,
                    help: help,
                    requirement: codexRequirement,
                    seed: seed,
                    recoveryModel: request.model
                )
                return try prepared.makeTransport(
                    request,
                    context,
                    workspace
                )
            },
            makeAdapter: makeCodexAdapter
        )
        let claudeRequirement = EngineAdapterHelpRequirementV1(
            builtInKind: .cliClaude,
            command: "claude"
        )
        let claude = EngineAdapterFactoryV1(
            adapterId: "agentloop.cli.claude",
            adapterVersion: "1",
            profileKinds: [.cliClaude],
            helpRequirement: claudeRequirement,
            descriptor: { profile, help in
                try builtInDescriptor(
                    profile: profile,
                    help: help,
                    adapterId: "agentloop.cli.claude"
                )
            },
            prepareRequest: { profile, help, seed in
                try prepareCLI(
                    profile: profile,
                    help: help,
                    requirement: claudeRequirement,
                    seed: seed,
                    recoveryModel: nil
                )
            },
            makeRecoveryTransport: {
                profile, help, request, context, workspace, seed in
                let prepared = try prepareCLI(
                    profile: profile,
                    help: help,
                    requirement: claudeRequirement,
                    seed: seed,
                    recoveryModel: request.model
                )
                return try prepared.makeTransport(
                    request,
                    context,
                    workspace
                )
            },
            makeAdapter: makeClaudeAdapter
        )
        return [model, codex, claude]
    }

    private static func prepareModelLoop(
        profile: RuntimeProfileRecord,
        help: CliHelpSnapshotV1?,
        seed: EngineExecutionTransportSeedV1,
        recoveryModel: String?
    ) throws -> EngineAdapterPreparedRequestV1 {
        guard help == nil,
              profile == seed.context.profile,
              !profile.kind.isCLI
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        try validateSeed(seed)
        let providerAuthority: EngineModelLoopProviderAuthorityV1
        if let recoveryModel {
            providerAuthority = try seed.resolveRecoveryModelLoopProvider(
                profile,
                seed.context.companionId,
                recoveryModel
            )
        } else {
            providerAuthority = try seed.resolveInitialModelLoopProvider(
                profile,
                seed.context.companionId,
                seed.context.companionModel,
                seed.context.companionModelPolicy
            )
        }
        guard providerAuthority.profileId == profile.id,
              recoveryModel == nil
                || providerAuthority.effectiveModel == recoveryModel
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        let descriptor = try builtInDescriptor(
            profile: profile,
            help: nil,
            adapterId: "agentloop.model-loop"
        )
        let capabilities = try finalCapabilities(seed)
        let budget = EngineExecutionBudgetV1(
            tokenLimit: seed.context.cardTokenBudget,
            costMicrosLimit: 0,
            wallClockSeconds: 0
        )
        let contextVariant = seed.context.modelLoop
        return EngineAdapterPreparedRequestV1(
            descriptor: descriptor,
            engineKind: descriptor.adapterId,
            model: providerAuthority.effectiveModel,
            budget: budget,
            context: contextVariant,
            requiredCapabilities: capabilities,
            makeTransport: { request, context, workspace in
                try validateTransportInputs(
                    request: request,
                    profile: profile,
                    descriptor: descriptor,
                    model: providerAuthority.effectiveModel,
                    budget: budget,
                    contextVariant: contextVariant,
                    context: context,
                    workspaceClaim: seed.workspace,
                    workspace: workspace,
                    requiredCapabilities: capabilities
                )
                let bound = try seed.context.capabilityTools
                    .makeCapabilityTools(workspace.url)
                try validateBoundCapabilityTools(
                    bound,
                    plan: seed.context.capabilityTools
                )
                let provider = try providerAuthority.makeProvider()
                let runner = CardRunner(
                    provider: provider,
                    capabilityToolsResolver: {
                        receivedRequest,
                        receivedWorkspace in
                        guard receivedRequest.executionId
                                == request.executionId,
                              receivedWorkspace == workspace.url
                        else {
                            throw EngineAdapterSelectionErrorV1
                                .descriptorMismatch
                        }
                        return bound.capabilityTools
                    },
                    maxTurns: seed.context.cardMaxTurns,
                    maxTokensPerTurn: KernelDefaults.maxTokensPerTurn,
                    retryDelays: KernelDefaults.transportRetryDelays,
                    turnTimeout: KernelDefaults.turnTimeout
                )
                return try EngineExecutionTransportV1(
                    contextRequest: contextVariant.request,
                    workspaceRequest: seed.workspace.request,
                    boundCapabilityTools: bound,
                    modelLoopDriver: runner,
                    cliProcessDriver: nil,
                    cliConfiguration: nil
                )
            }
        )
    }

    private static func prepareCLI(
        profile: RuntimeProfileRecord,
        help: CliHelpSnapshotV1?,
        requirement: EngineAdapterHelpRequirementV1,
        seed: EngineExecutionTransportSeedV1,
        recoveryModel: String?
    ) throws -> EngineAdapterPreparedRequestV1 {
        guard profile == seed.context.profile,
              profile.kind == requirement.kind,
              let help,
              help.kind == requirement.kind,
              help.command == requirement.command,
              help.executableAuthority.kind == requirement.kind,
              help.executableAuthority.command == requirement.command,
              let bridgeExecutableAuthority =
                seed.bridgeExecutableAuthority,
              let boardSocketDirectoryAuthority =
                seed.boardSocketDirectoryAuthority
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        try validateSeed(seed)
        let validator: EngineCliManagedPolicyValidateV1?
        let configuredModel: String
        switch requirement.kind {
        case .cliCodex:
            validator = seed.validateCodexManagedPolicy
            configuredModel = KernelDefaults.codexCliDefaultModel
        case .cliClaude:
            validator = seed.validateClaudeManagedPolicy
            configuredModel = KernelDefaults.claudeCliModel
                ?? KernelDefaults.defaultGuideModel
        case .anthropicAPI, .openAIAPI, .chatGPTOAuth:
            validator = nil
            configuredModel = ""
        }
        guard let validator else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        let model = recoveryModel ?? configuredModel
        do {
            try CanonicalContractCodingV1.validateNonempty(model)
        } catch {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        guard model != "cli-default" else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        let descriptor = try builtInDescriptor(
            profile: profile,
            help: help,
            adapterId: requirement.kind == .cliCodex
                ? "agentloop.cli.codex"
                : "agentloop.cli.claude"
        )
        let capabilities = try finalCapabilities(seed)
        let budget = EngineExecutionBudgetV1(
            tokenLimit: seed.context.cardTokenBudget,
            costMicrosLimit: 0,
            wallClockSeconds: 0
        )
        let contextVariant = seed.context.cli
        if requirement.kind == .cliCodex {
            let prompt = try CliEnginePromptV1.render(
                contextVariant.resolved
            )
            try CliEnginePromptV1.validateCodex(prompt)
        }
        let selectedExecutableAuthority = help.executableAuthority
        return EngineAdapterPreparedRequestV1(
            descriptor: descriptor,
            engineKind: descriptor.adapterId,
            model: model,
            budget: budget,
            context: contextVariant,
            requiredCapabilities: capabilities,
            makeTransport: { request, context, workspace in
                try validateTransportInputs(
                    request: request,
                    profile: profile,
                    descriptor: descriptor,
                    model: model,
                    budget: budget,
                    contextVariant: contextVariant,
                    context: context,
                    workspaceClaim: seed.workspace,
                    workspace: workspace,
                    requiredCapabilities: capabilities
                )
                guard selectedExecutableAuthority
                        == help.executableAuthority,
                      selectedExecutableAuthority.kind
                        == requirement.kind
                else {
                    throw EngineAdapterSelectionErrorV1.descriptorMismatch
                }
                if requirement.kind == .cliCodex {
                    try CliWorkspaceManagedPolicyV1.validateCodex(
                        workspaceURL: workspace.url
                    )
                }
                do {
                    try validator(selectedExecutableAuthority)
                } catch {
                    throw EngineAdapterSelectionErrorV1.descriptorMismatch
                }
                let bound = try seed.context.capabilityTools
                    .makeCapabilityTools(workspace.url)
                try validateBoundCapabilityTools(
                    bound,
                    plan: seed.context.capabilityTools
                )
                let driver = try seed.makeCliProcessDriver()
                let configuration = try CliEngineRuntimeConfigurationV1(
                    command: selectedExecutableAuthority.stagedPath,
                    cliExecutableAuthority: selectedExecutableAuthority,
                    sandbox: "read-only",
                    reasoningEffort:
                        KernelDefaults.codexCliReasoningEffort,
                    bridgeExecutableAuthority:
                        bridgeExecutableAuthority,
                    boardSocketDirectoryAuthority:
                        boardSocketDirectoryAuthority,
                    claudeConfigDirectory: seed.claudeConfigDirectory,
                    ranchSessionId: request.executionId
                )
                return try EngineExecutionTransportV1(
                    contextRequest: contextVariant.request,
                    workspaceRequest: seed.workspace.request,
                    boundCapabilityTools: bound,
                    modelLoopDriver: nil,
                    cliProcessDriver: driver,
                    cliConfiguration: configuration
                )
            }
        )
    }

    private static func validateSeed(
        _ seed: EngineExecutionTransportSeedV1
    ) throws {
        let exactBase: [EngineCapabilityV1] = [
            .boardTerminal, .cancellation, .network, .streamingProgress,
            .toolBridge, .usageMetering, .workspaceRead,
        ]
        guard seed.baseRequiredCapabilities == exactBase,
              seed.context.cardMaxTurns > 0,
              seed.context.cardTokenBudget > 0,
              seed.workspace.request.expectedWorkspace
                == seed.workspace.workspace,
              seed.claudeConfigDirectory.isFileURL,
              seed.claudeConfigDirectory.baseURL == nil,
              seed.claudeConfigDirectory.path.hasPrefix("/"),
              seed.cliExecutableDirectory.isFileURL,
              seed.cliExecutableDirectory.baseURL == nil,
              seed.cliExecutableDirectory.path.hasPrefix("/")
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
    }

    private static func finalCapabilities(
        _ seed: EngineExecutionTransportSeedV1
    ) throws -> [EngineCapabilityV1] {
        var result = seed.baseRequiredCapabilities
        if seed.context.capabilityTools.requiresWorkspaceWrite {
            result.append(.workspaceWrite)
        }
        result = Array(Set(result)).sorted { $0.rawValue < $1.rawValue }
        guard result.allSatisfy({ capability in
            capability != .sessionResume
        }) else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        return result
    }

    private static func validateTransportInputs(
        request: EngineExecutionRequest,
        profile: RuntimeProfileRecord,
        descriptor: ExecutionEngineDescriptor,
        model: String,
        budget: EngineExecutionBudgetV1,
        contextVariant: EnginePreparedContextVariantV1,
        context: EngineResolvedContextTransportV1,
        workspaceClaim: EnginePreparedWorkspaceClaimV1,
        workspace: EngineResolvedWorkspaceV1,
        requiredCapabilities: [EngineCapabilityV1]
    ) throws {
        try request.validateCanonicalIdentity()
        guard request.profileId == profile.id,
              request.adapterId == descriptor.adapterId,
              request.adapterVersion == descriptor.adapterVersion,
              request.engineKind == descriptor.adapterId,
              request.model == model,
              request.budget == budget,
              request.contextJson == contextVariant.request.contextJson,
              request.contextHash == contextVariant.request.contextHash,
              context.canonicalEnvelopeJSON
                == contextVariant.resolved.canonicalEnvelopeJSON,
              context.hash == contextVariant.resolved.hash,
              request.workspace == workspaceClaim.workspace,
              workspaceClaim.request.expectedWorkspace
                == workspaceClaim.workspace,
              request.cardId == workspaceClaim.request.cardId,
              request.campId == workspaceClaim.request.campId,
              workspace.identity.campId == request.campId,
              workspace.url.standardizedFileURL.path
                == workspace.identity.workspacePath,
              request.requiredCapabilities == requiredCapabilities,
              request.approvalGrantIds.isEmpty
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
    }

    private static func validateBoundCapabilityTools(
        _ bound: EngineBoundCapabilityToolsV1,
        plan: EngineCapabilityToolPlanV1
    ) throws {
        let boardNames = [
            "complete_card", "block_card", "add_progress_note", "ask_user",
        ]
        let logicalNames = plan.logicalDefinitions.map(\.name)
        guard logicalNames.starts(with: boardNames),
              bound.logicalDefinitions == plan.logicalDefinitions
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        let expectedCapabilityNames = Array(logicalNames.dropFirst(4))
        let actualCapabilityNames = bound.capabilityTools.map(\.def.name)
        guard actualCapabilityNames == expectedCapabilityNames,
              actualCapabilityNames == Array(Set(actualCapabilityNames)).sorted()
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
    }

    private static func builtInDescriptor(
        profile: RuntimeProfileRecord,
        help: CliHelpSnapshotV1?,
        adapterId: String
    ) throws -> ExecutionEngineDescriptor {
        let streamingProgress: EngineCapabilitySupportV1
        let boardTerminal: EngineCapabilitySupportV1
        let sessionResume: EngineCapabilitySupportV1
        let workspaceAccess: EngineCapabilitySupportV1

        switch profile.kind {
        case .anthropicAPI, .openAIAPI, .chatGPTOAuth:
            guard adapterId == "agentloop.model-loop", help == nil else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            streamingProgress = .supported
            boardTerminal = .supported
            sessionResume = .unsupported
            workspaceAccess = .supported

        case .cliCodex:
            guard adapterId == "agentloop.cli.codex",
                  let help,
                  help.kind == .cliCodex,
                  help.command == "codex",
                  help.versionLine == "codex-cli 0.144.5",
                  help.rootExitStatus == 0,
                  help.firstExitStatus == 0,
                  help.resumeExitStatus == 0
            else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            let root = ["-a", "-C", "-s", "-m"]
                .allSatisfy(help.rootFlags.contains)
            let first = [
                "--ignore-user-config", "--ignore-rules",
                "--strict-config", "--skip-git-repo-check", "-c",
            ].allSatisfy(help.firstFlags.contains)
            let resume = [
                "--ignore-user-config", "--ignore-rules",
                "--strict-config", "--skip-git-repo-check", "-c",
            ].allSatisfy(help.resumeFlags.contains)
            streamingProgress = Self.support(
                root && first && help.firstFlags.contains("--json")
            )
            boardTerminal = Self.support(root && first)
            workspaceAccess = Self.support(root)
            sessionResume = Self.support(
                root && resume && help.resumeFlags.contains("--json")
                    && help.subcommands.contains("resume")
            )

        case .cliClaude:
            guard adapterId == "agentloop.cli.claude",
                  let help,
                  help.kind == .cliClaude,
                  help.command == "claude",
                  help.versionLine == "2.1.81 (Claude Code)",
                  help.rootExitStatus == 0,
                  help.firstExitStatus == 0,
                  help.resumeExitStatus == 0
            else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            let exact = [
                "-p", "--input-format", "--output-format", "--verbose",
                "--mcp-config", "--tools", "--setting-sources",
                "--strict-mcp-config", "--allowedTools",
                "--permission-mode", "--disable-slash-commands",
                "--no-chrome", "--session-id", "--model", "--add-dir",
            ].allSatisfy(help.firstFlags.contains)
            let exactResume = [
                "-p", "--input-format", "--output-format", "--verbose",
                "--mcp-config", "--tools", "--setting-sources",
                "--strict-mcp-config", "--allowedTools",
                "--permission-mode", "--disable-slash-commands",
                "--no-chrome", "--resume", "--model", "--add-dir",
            ].allSatisfy(help.resumeFlags.contains)
            streamingProgress = Self.support(exact)
            boardTerminal = Self.support(exact)
            workspaceAccess = Self.support(exact)
            sessionResume = Self.support(
                exact && exactResume
            )
        }

        return ExecutionEngineDescriptor(
            adapterId: adapterId,
            adapterVersion: "1",
            profileKind: profile.kind,
            streamingProgress: streamingProgress,
            boardTerminal: boardTerminal,
            toolBridge: boardTerminal,
            cancellation: .supported,
            sessionResume: sessionResume,
            usageMetering: streamingProgress,
            workspaceRead: workspaceAccess,
            workspaceWrite: workspaceAccess,
            network: boardTerminal,
            replayClassResolver: { _ in .nonReplayable }
        )
    }

    private static func support(_ value: Bool) -> EngineCapabilitySupportV1 {
        value ? .supported : .unsupported
    }
}

package struct EngineAdapterSelectionV1: Sendable {
    package let profile: RuntimeProfileRecord
    package let helpSnapshot: CliHelpSnapshotV1?
    package let descriptor: ExecutionEngineDescriptor
    package let prepareRequest:
        @Sendable (EngineExecutionTransportSeedV1) throws
            -> EngineAdapterPreparedRequestV1
    package let makeRecoveryTransport:
        @Sendable (
            EngineExecutionRequest,
            EngineResolvedContextTransportV1,
            EngineResolvedWorkspaceV1,
            EngineExecutionTransportSeedV1
        ) throws -> EngineExecutionTransportV1
    package let makeAdapter:
        @Sendable (EngineAdapterRuntimeV1) throws -> any ExecutionEngineAdapter

    package init(
        profile: RuntimeProfileRecord,
        helpSnapshot: CliHelpSnapshotV1?,
        descriptor: ExecutionEngineDescriptor,
        prepareRequest:
            @escaping @Sendable (EngineExecutionTransportSeedV1) throws
                -> EngineAdapterPreparedRequestV1,
        makeRecoveryTransport:
            @escaping @Sendable (
                EngineExecutionRequest,
                EngineResolvedContextTransportV1,
                EngineResolvedWorkspaceV1,
                EngineExecutionTransportSeedV1
            ) throws -> EngineExecutionTransportV1,
        makeAdapter:
            @escaping @Sendable (EngineAdapterRuntimeV1) throws
                -> any ExecutionEngineAdapter
    ) {
        self.profile = profile
        self.helpSnapshot = helpSnapshot
        self.descriptor = descriptor
        self.prepareRequest = prepareRequest
        self.makeRecoveryTransport = makeRecoveryTransport
        self.makeAdapter = makeAdapter
    }
}

package struct EngineAdapterRegistryV1: Sendable {
    package let factories: [EngineAdapterFactoryV1]
    package let helpSnapshots: [RuntimeProfileKind: CliHelpSnapshotV1]

    package init(
        factories: [EngineAdapterFactoryV1],
        helpSnapshots: [RuntimeProfileKind: CliHelpSnapshotV1]
    ) throws {
        guard !factories.isEmpty else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        var identities = Set<String>()
        var claimedKinds = Set<RuntimeProfileKind>()
        var requirements = Set<RuntimeProfileKind>()
        for factory in factories {
            do {
                try CanonicalContractCodingV1.validateNonempty(factory.adapterId)
                try CanonicalContractCodingV1.validateNonempty(factory.adapterVersion)
            } catch {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            guard !factory.profileKinds.isEmpty,
                  identities.insert(
                    factory.adapterId + "\u{0}" + factory.adapterVersion
                  ).inserted
            else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            if let requirement = factory.helpRequirement {
                guard factory.profileKinds == [requirement.kind],
                      requirements.insert(requirement.kind).inserted
                else {
                    throw EngineAdapterSelectionErrorV1.descriptorMismatch
                }
            }
            for kind in factory.profileKinds {
                guard claimedKinds.insert(kind).inserted else {
                    throw EngineAdapterSelectionErrorV1
                        .duplicateProfileKind(kind)
                }
            }
        }
        for (kind, snapshot) in helpSnapshots {
            guard requirements.contains(kind),
                  snapshot.kind == kind,
                  factories.contains(where: {
                    $0.helpRequirement?.kind == kind
                        && $0.helpRequirement?.command == snapshot.command
                  })
            else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
        }
        self.factories = factories
        self.helpSnapshots = helpSnapshots
    }

    package func resolve(
        profile: RuntimeProfileRecord,
        requiredCapabilities: [EngineCapabilityV1]
    ) throws -> EngineAdapterSelectionV1 {
        guard let factory = factories.first(where: {
            $0.profileKinds.contains(profile.kind)
        }) else {
            throw EngineAdapterSelectionErrorV1.missingFactory(profile.kind)
        }
        let help: CliHelpSnapshotV1?
        if let requirement = factory.helpRequirement {
            guard requirement.kind == profile.kind,
                  let snapshot = helpSnapshots[requirement.kind],
                  snapshot.kind == requirement.kind,
                  snapshot.command == requirement.command
            else {
                throw EngineAdapterSelectionErrorV1
                    .missingHelpSnapshot(requirement.kind)
            }
            help = snapshot
        } else {
            help = nil
        }

        let descriptor = try factory.descriptor(profile, help)
        guard descriptor.adapterId == factory.adapterId,
              descriptor.adapterVersion == factory.adapterVersion,
              descriptor.profileKind == profile.kind
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        let capabilities = Array(Set(requiredCapabilities)).sorted {
            $0.rawValue < $1.rawValue
        }
        guard requiredCapabilities == capabilities else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        for capability in capabilities {
            guard descriptor.support(for: capability) == .supported else {
                throw EngineAdapterSelectionErrorV1
                    .unsupportedCapability(capability)
            }
        }

        return EngineAdapterSelectionV1(
            profile: profile,
            helpSnapshot: help,
            descriptor: descriptor,
            prepareRequest: { seed in
                let prepared = try factory.prepareRequest(
                    profile,
                    help,
                    seed
                )
                let sortedCapabilities = Array(
                    Set(prepared.requiredCapabilities)
                ).sorted { $0.rawValue < $1.rawValue }
                guard Self.descriptorsMatch(
                    prepared.descriptor,
                    descriptor
                ),
                    prepared.engineKind == descriptor.adapterId,
                    !prepared.model.isEmpty,
                    prepared.requiredCapabilities == sortedCapabilities
                else {
                    throw EngineAdapterSelectionErrorV1.descriptorMismatch
                }
                return prepared
            },
            makeRecoveryTransport: { request, context, workspace, seed in
                try factory.makeRecoveryTransport(
                    profile,
                    help,
                    request,
                    context,
                    workspace,
                    seed
                )
            },
            makeAdapter: { runtime in
                guard Self.descriptorsMatch(runtime.descriptor, descriptor)
                else {
                    throw EngineAdapterSelectionErrorV1.descriptorMismatch
                }
                if let help {
                    guard runtime.cliConfiguration?.command
                            == help.executableAuthority.stagedPath,
                          runtime.cliConfiguration?.cliExecutableAuthority
                            == help.executableAuthority
                    else {
                        throw EngineAdapterSelectionErrorV1
                            .descriptorMismatch
                    }
                } else if runtime.cliConfiguration != nil {
                    throw EngineAdapterSelectionErrorV1.descriptorMismatch
                }
                return try factory.makeAdapter(profile, runtime)
            }
        )
    }

    private static func descriptorsMatch(
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
}

package struct EngineExecutionTransportV1: Sendable {
    package let contextRequest: EngineContextResolveRequestV1
    package let workspaceRequest: EngineWorkspaceResolveRequestV1
    package let boundCapabilityTools: EngineBoundCapabilityToolsV1
    package let modelLoopDriver: (any ModelLoopExecutionDrivingV1)?
    package let cliProcessDriver: (any CliProcessDrivingV1)?
    package let cliConfiguration: CliEngineRuntimeConfigurationV1?

    package init(
        contextRequest: EngineContextResolveRequestV1,
        workspaceRequest: EngineWorkspaceResolveRequestV1,
        boundCapabilityTools: EngineBoundCapabilityToolsV1,
        modelLoopDriver: (any ModelLoopExecutionDrivingV1)?,
        cliProcessDriver: (any CliProcessDrivingV1)?,
        cliConfiguration: CliEngineRuntimeConfigurationV1?
    ) throws {
        let isModelLoopTransport = modelLoopDriver != nil
            && cliProcessDriver == nil
            && cliConfiguration == nil
        let isCLITransport = modelLoopDriver == nil
            && cliProcessDriver != nil
            && cliConfiguration != nil
            && cliProcessDriver?.supportsProcessGroupCancellation == true
        guard isModelLoopTransport || isCLITransport else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        self.contextRequest = contextRequest
        self.workspaceRequest = workspaceRequest
        self.boundCapabilityTools = boundCapabilityTools
        self.modelLoopDriver = modelLoopDriver
        self.cliProcessDriver = cliProcessDriver
        self.cliConfiguration = cliConfiguration
    }
}

package struct EngineAdapterRuntimeV1: Sendable {
    package let descriptor: ExecutionEngineDescriptor
    package let context: EngineResolvedContextTransportV1
    package let workspace: EngineResolvedWorkspaceV1
    package let boundCapabilityTools: EngineBoundCapabilityToolsV1
    package let resolvedSessionRef: EngineSessionReferenceV1?
    package let terminalSink: any EngineTerminalSink
    package let boardTerminalSink: any EngineBoardTerminalSink
    package let progressSink: any EngineProgressSink
    package let modelLoopDriver: (any ModelLoopExecutionDrivingV1)?
    package let cliProcessDriver: (any CliProcessDrivingV1)?
    package let cliConfiguration: CliEngineRuntimeConfigurationV1?

    package init(
        descriptor: ExecutionEngineDescriptor,
        context: EngineResolvedContextTransportV1,
        workspace: EngineResolvedWorkspaceV1,
        boundCapabilityTools: EngineBoundCapabilityToolsV1,
        resolvedSessionRef: EngineSessionReferenceV1?,
        terminalSink: any EngineTerminalSink,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink,
        modelLoopDriver: (any ModelLoopExecutionDrivingV1)?,
        cliProcessDriver: (any CliProcessDrivingV1)?,
        cliConfiguration: CliEngineRuntimeConfigurationV1?
    ) throws {
        let hasModelLoopRuntime = modelLoopDriver != nil
            && cliProcessDriver == nil
            && cliConfiguration == nil
            && resolvedSessionRef == nil
        let hasCLIRuntime = modelLoopDriver == nil
            && cliProcessDriver != nil
            && cliConfiguration != nil
            && cliProcessDriver?.supportsProcessGroupCancellation == true
            && (resolvedSessionRef == nil
                || descriptor.sessionResume == .supported)
        let matchesDescriptor: Bool
        switch descriptor.profileKind {
        case .anthropicAPI, .openAIAPI, .chatGPTOAuth:
            matchesDescriptor = hasModelLoopRuntime
        case .cliCodex, .cliClaude:
            matchesDescriptor = hasCLIRuntime
        }
        guard matchesDescriptor else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        self.descriptor = descriptor
        self.context = context
        self.workspace = workspace
        self.boundCapabilityTools = boundCapabilityTools
        self.resolvedSessionRef = resolvedSessionRef
        self.terminalSink = terminalSink
        self.boardTerminalSink = boardTerminalSink
        self.progressSink = progressSink
        self.modelLoopDriver = modelLoopDriver
        self.cliProcessDriver = cliProcessDriver
        self.cliConfiguration = cliConfiguration
    }
}

package protocol ExecutionEngineAdapter: Sendable {
    func descriptor(profile: RuntimeProfileRecord) throws
        -> ExecutionEngineDescriptor
    func execute(request: EngineExecutionRequest)
        -> AsyncThrowingStream<EngineExecutionEventPayloadV1, Error>
    func cancel(executionId: String) async throws
}

public struct EngineContextReferenceV1:
    Sendable, Equatable, Codable, Hashable
{
    public let type: String
    public let id: String
    public let version: Int
    public let hash: String

    public init(type: String, id: String, version: Int, hash: String) {
        self.type = type
        self.id = id
        self.version = version
        self.hash = hash
    }
}

public struct EngineContextReferencesV1: Sendable, Equatable, Codable {
    public let inputRefs: [EngineContextReferenceV1]
    public let memoryRefs: [EngineContextReferenceV1]
    public let resourceRefs: [EngineContextReferenceV1]
    public let priorHandoffRefs: [EngineContextReferenceV1]
    public let instructionBlocks: [EngineContextReferenceV1]

    public static let empty = EngineContextReferencesV1()

    public init() {
        inputRefs = []
        memoryRefs = []
        resourceRefs = []
        priorHandoffRefs = []
        instructionBlocks = []
    }

    public init(
        inputRefs: [EngineContextReferenceV1],
        memoryRefs: [EngineContextReferenceV1],
        resourceRefs: [EngineContextReferenceV1],
        priorHandoffRefs: [EngineContextReferenceV1],
        instructionBlocks: [EngineContextReferenceV1]
    ) throws {
        let groups: [(String, [EngineContextReferenceV1])] = [
            ("input", inputRefs),
            ("memory", memoryRefs),
            ("resource", resourceRefs),
            ("handoff", priorHandoffRefs),
            ("instruction", instructionBlocks),
        ]
        var coordinates = Set<EngineContextReferenceV1>()
        for (expectedType, references) in groups {
            for reference in references {
                guard reference.type == expectedType else {
                    throw EngineContextValidationErrorV1()
                }
                do {
                    try CanonicalContractCodingV1.validateCanonicalUUID(reference.id)
                    try CanonicalContractCodingV1.validatePositive(reference.version)
                    try CanonicalContractCodingV1.validateLowercaseHash(reference.hash)
                } catch {
                    throw EngineContextValidationErrorV1()
                }
                guard coordinates.insert(reference).inserted else {
                    throw EngineContextValidationErrorV1()
                }
            }
        }

        self.inputRefs = inputRefs.sorted(by: Self.referenceOrder)
        self.memoryRefs = memoryRefs.sorted(by: Self.referenceOrder)
        self.resourceRefs = resourceRefs.sorted(by: Self.referenceOrder)
        self.priorHandoffRefs = priorHandoffRefs.sorted(by: Self.referenceOrder)
        self.instructionBlocks = instructionBlocks.sorted(by: Self.referenceOrder)
    }

    private static func referenceOrder(
        _ lhs: EngineContextReferenceV1,
        _ rhs: EngineContextReferenceV1
    ) -> Bool {
        if lhs.type != rhs.type { return lhs.type < rhs.type }
        if lhs.id != rhs.id { return lhs.id < rhs.id }
        if lhs.version != rhs.version { return lhs.version < rhs.version }
        return lhs.hash < rhs.hash
    }
}

package struct EngineContextScopeV1: Sendable, Equatable {
    package let campId: String
    package let goalId: String?
    package let missionId: String
    package let cardId: String
    package let outcomeContract: OutcomeContractRef

    package init(
        campId: String,
        goalId: String?,
        missionId: String,
        cardId: String,
        outcomeContract: OutcomeContractRef
    ) throws {
        do {
            try CanonicalContractCodingV1.validateCampID(campId)
            if let goalId {
                try CanonicalContractCodingV1.validateCanonicalUUID(goalId)
            }
            try CanonicalContractCodingV1.validateCanonicalUUID(missionId)
            try CanonicalContractCodingV1.validateCanonicalUUID(cardId)
        } catch {
            throw EngineContextValidationErrorV1()
        }
        self.campId = campId
        self.goalId = goalId
        self.missionId = missionId
        self.cardId = cardId
        self.outcomeContract = outcomeContract
    }
}

package struct EngineContextEnvelopeV1: Sendable, Equatable, Codable {
    package let schemaVersion: Int
    package let campId: String
    package let goalId: String?
    package let missionId: String
    package let cardId: String
    package let outcomeContract: OutcomeContractRef
    package let inputRefs: [EngineContextReferenceV1]
    package let memoryRefs: [EngineContextReferenceV1]
    package let resourceRefs: [EngineContextReferenceV1]
    package let priorHandoffRefs: [EngineContextReferenceV1]
    package let instructionBlocks: [EngineContextReferenceV1]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case campId
        case goalId
        case missionId
        case cardId
        case outcomeContract
        case inputRefs
        case memoryRefs
        case resourceRefs
        case priorHandoffRefs
        case instructionBlocks
    }

    private init(
        schemaVersion: Int,
        campId: String,
        goalId: String?,
        missionId: String,
        cardId: String,
        outcomeContract: OutcomeContractRef,
        inputRefs: [EngineContextReferenceV1],
        memoryRefs: [EngineContextReferenceV1],
        resourceRefs: [EngineContextReferenceV1],
        priorHandoffRefs: [EngineContextReferenceV1],
        instructionBlocks: [EngineContextReferenceV1]
    ) {
        self.schemaVersion = schemaVersion
        self.campId = campId
        self.goalId = goalId
        self.missionId = missionId
        self.cardId = cardId
        self.outcomeContract = outcomeContract
        self.inputRefs = inputRefs
        self.memoryRefs = memoryRefs
        self.resourceRefs = resourceRefs
        self.priorHandoffRefs = priorHandoffRefs
        self.instructionBlocks = instructionBlocks
    }

    package static func from(
        packet: ContextPacket,
        scope: EngineContextScopeV1
    ) throws -> EngineContextEnvelopeV1 {
        let references = packet.engineContextReferences
        return EngineContextEnvelopeV1(
            schemaVersion: 1,
            campId: scope.campId,
            goalId: scope.goalId,
            missionId: scope.missionId,
            cardId: scope.cardId,
            outcomeContract: scope.outcomeContract,
            inputRefs: references.inputRefs,
            memoryRefs: references.memoryRefs,
            resourceRefs: references.resourceRefs,
            priorHandoffRefs: references.priorHandoffRefs,
            instructionBlocks: references.instructionBlocks
        )
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(campId, forKey: .campId)
        if let goalId {
            try container.encode(goalId, forKey: .goalId)
        } else {
            try container.encodeNil(forKey: .goalId)
        }
        try container.encode(missionId, forKey: .missionId)
        try container.encode(cardId, forKey: .cardId)
        try container.encode(outcomeContract, forKey: .outcomeContract)
        try container.encode(inputRefs, forKey: .inputRefs)
        try container.encode(memoryRefs, forKey: .memoryRefs)
        try container.encode(resourceRefs, forKey: .resourceRefs)
        try container.encode(priorHandoffRefs, forKey: .priorHandoffRefs)
        try container.encode(instructionBlocks, forKey: .instructionBlocks)
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else {
            throw EngineContextValidationErrorV1()
        }
        let outcomeContract = try container.decode(
            OutcomeContractRef.self,
            forKey: .outcomeContract
        )
        let references = try EngineContextReferencesV1(
            inputRefs: container.decode(
                [EngineContextReferenceV1].self,
                forKey: .inputRefs
            ),
            memoryRefs: container.decode(
                [EngineContextReferenceV1].self,
                forKey: .memoryRefs
            ),
            resourceRefs: container.decode(
                [EngineContextReferenceV1].self,
                forKey: .resourceRefs
            ),
            priorHandoffRefs: container.decode(
                [EngineContextReferenceV1].self,
                forKey: .priorHandoffRefs
            ),
            instructionBlocks: container.decode(
                [EngineContextReferenceV1].self,
                forKey: .instructionBlocks
            )
        )
        let scope = try EngineContextScopeV1(
            campId: container.decode(String.self, forKey: .campId),
            goalId: container.decodeIfPresent(String.self, forKey: .goalId),
            missionId: container.decode(String.self, forKey: .missionId),
            cardId: container.decode(String.self, forKey: .cardId),
            outcomeContract: outcomeContract
        )
        self.init(
            schemaVersion: schemaVersion,
            campId: scope.campId,
            goalId: scope.goalId,
            missionId: scope.missionId,
            cardId: scope.cardId,
            outcomeContract: scope.outcomeContract,
            inputRefs: references.inputRefs,
            memoryRefs: references.memoryRefs,
            resourceRefs: references.resourceRefs,
            priorHandoffRefs: references.priorHandoffRefs,
            instructionBlocks: references.instructionBlocks
        )
    }
}

package struct EngineSessionScopeV1: Sendable, Equatable, Codable {
    package let schemaVersion: Int
    package let campId: String
    package let profileId: String
    package let adapterId: String
    package let adapterVersion: String
    package let engineKind: String
    package let model: String
    package let workspaceHash: String
    package let contractId: String
    package let contractVersion: Int
    package let contractHash: String

    package static func derived(
        campId: String,
        profileId: String,
        descriptor: ExecutionEngineDescriptor,
        engineKind: String,
        model: String,
        workspaceHash: String,
        contract: OutcomeContractRef
    ) throws -> EngineSessionScopeV1 {
        do {
            try CanonicalContractCodingV1.validateCampID(campId)
            try CanonicalContractCodingV1.validateCanonicalUUID(profileId)
            try CanonicalContractCodingV1.validateNonempty(descriptor.adapterId)
            try CanonicalContractCodingV1.validateNonempty(descriptor.adapterVersion)
            try CanonicalContractCodingV1.validateNonempty(engineKind)
            try CanonicalContractCodingV1.validateNonempty(model)
            try CanonicalContractCodingV1.validateLowercaseHash(workspaceHash)
        } catch {
            throw EngineSessionScopeMismatchError()
        }
        return EngineSessionScopeV1(
            schemaVersion: 1,
            campId: campId,
            profileId: profileId,
            adapterId: descriptor.adapterId,
            adapterVersion: descriptor.adapterVersion,
            engineKind: engineKind,
            model: model,
            workspaceHash: workspaceHash,
            contractId: contract.id,
            contractVersion: contract.version,
            contractHash: contract.hash
        )
    }
}

package struct EngineExecutionBudgetV1: Sendable, Equatable, Codable {
    package let tokenLimit: Int
    package let costMicrosLimit: Int
    package let wallClockSeconds: Int

    package init(
        tokenLimit: Int,
        costMicrosLimit: Int,
        wallClockSeconds: Int
    ) {
        self.tokenLimit = tokenLimit
        self.costMicrosLimit = costMicrosLimit
        self.wallClockSeconds = wallClockSeconds
    }
}

package struct EngineWorkspaceRefV1: Sendable, Equatable, Codable {
    package let reference: String
    package let hash: String

    package init(reference: String, hash: String) {
        self.reference = reference
        self.hash = hash
    }
}

package struct EngineSessionSelectionV1: Sendable, Equatable {
    package let sessionId: String

    package init(sessionId: String) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(sessionId)
        self.sessionId = sessionId
    }
}

package struct EngineSessionReferenceV1: Sendable, Equatable, Codable {
    package let sessionId: String
    package let externalSessionId: String

    private enum CodingKeys: String, CodingKey {
        case sessionId
        case externalSessionId
    }

    package init(sessionId: String, externalSessionId: String) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(sessionId)
        try EngineContractValidationV1.validateExternalSessionID(
            externalSessionId
        )
        self.sessionId = sessionId
        self.externalSessionId = externalSessionId
    }

    package init(from decoder: any Decoder) throws {
        try EngineContractValidationV1.requireExactKeys(
            decoder,
            ["externalSessionId", "sessionId"]
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            sessionId: container.decode(String.self, forKey: .sessionId),
            externalSessionId: container.decode(
                String.self,
                forKey: .externalSessionId
            )
        )
    }

    package func encode(to encoder: any Encoder) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(sessionId)
        try EngineContractValidationV1.validateExternalSessionID(
            externalSessionId
        )
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(externalSessionId, forKey: .externalSessionId)
    }
}

package struct EngineExecutionRequestFieldsV1: Sendable, Equatable {
    package let campId: String
    package let cardId: String
    package let contract: OutcomeContractRef
    package let profileId: String
    package let engineKind: String
    package let model: String
    package let contextJson: String
    package let contextHash: String
    package let requiredCapabilities: [EngineCapabilityV1]
    package let approvalGrantIds: [String]
    package let budget: EngineExecutionBudgetV1
    package let workspace: EngineWorkspaceRefV1
    package let sessionSelection: EngineSessionSelectionV1?
    package let predecessorExecutionId: String?
    package let claimedSessionScopeJson: String?
    package let claimedSessionScopeHash: String?

    package init(
        campId: String,
        cardId: String,
        contract: OutcomeContractRef,
        profileId: String,
        engineKind: String,
        model: String,
        contextJson: String,
        contextHash: String,
        requiredCapabilities: [EngineCapabilityV1],
        approvalGrantIds: [String],
        budget: EngineExecutionBudgetV1,
        workspace: EngineWorkspaceRefV1,
        sessionSelection: EngineSessionSelectionV1?,
        predecessorExecutionId: String? = nil,
        claimedSessionScopeJson: String?,
        claimedSessionScopeHash: String?
    ) throws {
        guard Set(requiredCapabilities).count == requiredCapabilities.count,
              Set(approvalGrantIds).count == approvalGrantIds.count,
              sessionSelection == nil || predecessorExecutionId == nil
        else {
            throw EngineContextValidationErrorV1()
        }
        if let predecessorExecutionId {
            try CanonicalContractCodingV1.validateCanonicalUUID(
                predecessorExecutionId
            )
        }
        self.campId = campId
        self.cardId = cardId
        self.contract = contract
        self.profileId = profileId
        self.engineKind = engineKind
        self.model = model
        self.contextJson = contextJson
        self.contextHash = contextHash
        self.requiredCapabilities = requiredCapabilities.sorted {
            $0.rawValue < $1.rawValue
        }
        self.approvalGrantIds = approvalGrantIds.sorted()
        self.budget = budget
        self.workspace = workspace
        self.sessionSelection = sessionSelection
        self.predecessorExecutionId = predecessorExecutionId
        self.claimedSessionScopeJson = claimedSessionScopeJson
        self.claimedSessionScopeHash = claimedSessionScopeHash
    }
}

package struct EngineExecutionRequest: Sendable, Equatable, Codable {
    package let protocolVersion: String
    package let executionId: String
    package let idempotencyKey: String
    package let campId: String
    package let campLifecycleVersion: Int
    package let runId: String
    package let cardId: String
    package let contract: OutcomeContractRef
    package let adapterId: String
    package let adapterVersion: String
    package let profileId: String
    package let engineKind: String
    package let model: String
    package let replayClass: EngineExecutionReplayClassV1
    package let contextJson: String
    package let contextHash: String
    package let sessionScopeJson: String
    package let sessionScopeHash: String
    package let requiredCapabilities: [EngineCapabilityV1]
    package let approvalGrantIds: [String]
    package let budget: EngineExecutionBudgetV1
    package let workspace: EngineWorkspaceRefV1
    package let predecessorExecutionId: String?
    package let sessionRef: EngineSessionReferenceV1?
    package let requestJson: String
    package let requestHash: String

    private enum CodingKeys: String, CodingKey {
        case protocolVersion
        case executionId
        case idempotencyKey
        case campId
        case campLifecycleVersion
        case runId
        case cardId
        case contract
        case adapterId
        case adapterVersion
        case profileId
        case engineKind
        case model
        case replayClass
        case contextJson
        case contextHash
        case sessionScopeJson
        case sessionScopeHash
        case requiredCapabilities
        case approvalGrantIds
        case budget
        case workspace
        case predecessorExecutionId
        case sessionRef
    }

    package init(
        protocolVersion: String,
        executionId: String,
        idempotencyKey: String,
        campId: String,
        campLifecycleVersion: Int,
        runId: String,
        cardId: String,
        contract: OutcomeContractRef,
        adapterId: String,
        adapterVersion: String,
        profileId: String,
        engineKind: String,
        model: String,
        replayClass: EngineExecutionReplayClassV1,
        contextJson: String,
        contextHash: String,
        sessionScopeJson: String,
        sessionScopeHash: String,
        requiredCapabilities: [EngineCapabilityV1],
        approvalGrantIds: [String],
        budget: EngineExecutionBudgetV1,
        workspace: EngineWorkspaceRefV1,
        predecessorExecutionId: String?,
        sessionRef: EngineSessionReferenceV1?,
        requestJson: String,
        requestHash: String
    ) {
        self.protocolVersion = protocolVersion
        self.executionId = executionId
        self.idempotencyKey = idempotencyKey
        self.campId = campId
        self.campLifecycleVersion = campLifecycleVersion
        self.runId = runId
        self.cardId = cardId
        self.contract = contract
        self.adapterId = adapterId
        self.adapterVersion = adapterVersion
        self.profileId = profileId
        self.engineKind = engineKind
        self.model = model
        self.replayClass = replayClass
        self.contextJson = contextJson
        self.contextHash = contextHash
        self.sessionScopeJson = sessionScopeJson
        self.sessionScopeHash = sessionScopeHash
        self.requiredCapabilities = requiredCapabilities.sorted {
            $0.rawValue < $1.rawValue
        }
        self.approvalGrantIds = approvalGrantIds.sorted()
        self.budget = budget
        self.workspace = workspace
        self.predecessorExecutionId = predecessorExecutionId
        self.sessionRef = sessionRef
        self.requestJson = requestJson
        self.requestHash = requestHash
    }

    package static func makeCanonical(
        protocolVersion: String = engineExecutionProtocolVersionV1,
        executionId: String,
        idempotencyKey: String,
        campId: String,
        campLifecycleVersion: Int,
        runId: String,
        cardId: String,
        contract: OutcomeContractRef,
        adapterId: String,
        adapterVersion: String,
        profileId: String,
        engineKind: String,
        model: String,
        replayClass: EngineExecutionReplayClassV1,
        contextJson: String,
        contextHash: String,
        sessionScopeJson: String,
        sessionScopeHash: String,
        requiredCapabilities: [EngineCapabilityV1],
        approvalGrantIds: [String],
        budget: EngineExecutionBudgetV1,
        workspace: EngineWorkspaceRefV1,
        predecessorExecutionId: String? = nil,
        sessionRef: EngineSessionReferenceV1?
    ) throws -> EngineExecutionRequest {
        guard protocolVersion == engineExecutionProtocolVersionV1 else {
            throw EngineExecutionReplayConflictError()
        }
        try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        try EngineContractValidationV1.validateIdempotencyKey(idempotencyKey)
        try CanonicalContractCodingV1.validateCampID(campId)
        try CanonicalContractCodingV1.validatePositive(campLifecycleVersion)
        try CanonicalContractCodingV1.validateCanonicalUUID(runId)
        try CanonicalContractCodingV1.validateCanonicalUUID(cardId)
        try CanonicalContractCodingV1.validateCanonicalUUID(profileId)
        try CanonicalContractCodingV1.validateLowercaseHash(contextHash)
        try CanonicalContractCodingV1.validateLowercaseHash(sessionScopeHash)
        try CanonicalContractCodingV1.validateLowercaseHash(workspace.hash)
        try CanonicalContractCodingV1.validateNonempty(workspace.reference)
        guard Set(requiredCapabilities).count == requiredCapabilities.count,
              Set(approvalGrantIds).count == approvalGrantIds.count,
              budget.tokenLimit >= 0,
              budget.costMicrosLimit >= 0,
              budget.wallClockSeconds >= 0
        else {
            throw EngineContextValidationErrorV1()
        }
        if let sessionRef {
            try CanonicalContractCodingV1.validateCanonicalUUID(
                sessionRef.sessionId
            )
            try EngineContractValidationV1.validateExternalSessionID(
                sessionRef.externalSessionId
            )
        }
        if let predecessorExecutionId {
            try CanonicalContractCodingV1.validateCanonicalUUID(
                predecessorExecutionId
            )
            guard sessionRef != nil else {
                throw EngineSessionScopeMismatchError()
            }
        }
        let provisional = EngineExecutionRequest(
            protocolVersion: protocolVersion,
            executionId: executionId,
            idempotencyKey: idempotencyKey,
            campId: campId,
            campLifecycleVersion: campLifecycleVersion,
            runId: runId,
            cardId: cardId,
            contract: contract,
            adapterId: adapterId,
            adapterVersion: adapterVersion,
            profileId: profileId,
            engineKind: engineKind,
            model: model,
            replayClass: replayClass,
            contextJson: contextJson,
            contextHash: contextHash,
            sessionScopeJson: sessionScopeJson,
            sessionScopeHash: sessionScopeHash,
            requiredCapabilities: requiredCapabilities,
            approvalGrantIds: approvalGrantIds,
            budget: budget,
            workspace: workspace,
            predecessorExecutionId: predecessorExecutionId,
            sessionRef: sessionRef,
            requestJson: "",
            requestHash: ""
        )
        let bytes = try CanonicalJSONV1.encode(provisional)
        return EngineExecutionRequest(
            protocolVersion: protocolVersion,
            executionId: executionId,
            idempotencyKey: idempotencyKey,
            campId: campId,
            campLifecycleVersion: campLifecycleVersion,
            runId: runId,
            cardId: cardId,
            contract: contract,
            adapterId: adapterId,
            adapterVersion: adapterVersion,
            profileId: profileId,
            engineKind: engineKind,
            model: model,
            replayClass: replayClass,
            contextJson: contextJson,
            contextHash: contextHash,
            sessionScopeJson: sessionScopeJson,
            sessionScopeHash: sessionScopeHash,
            requiredCapabilities: requiredCapabilities,
            approvalGrantIds: approvalGrantIds,
            budget: budget,
            workspace: workspace,
            predecessorExecutionId: predecessorExecutionId,
            sessionRef: sessionRef,
            requestJson: String(decoding: bytes, as: UTF8.self),
            requestHash: CanonicalJSONV1.sha256Hex(bytes)
        )
    }

    package func validateCanonicalIdentity() throws {
        let bytes = try CanonicalJSONV1.encode(self)
        guard String(decoding: bytes, as: UTF8.self) == requestJson,
              CanonicalJSONV1.sha256Hex(bytes) == requestHash
        else {
            throw EngineExecutionReplayConflictError()
        }
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(protocolVersion, forKey: .protocolVersion)
        try container.encode(executionId, forKey: .executionId)
        try container.encode(idempotencyKey, forKey: .idempotencyKey)
        try container.encode(campId, forKey: .campId)
        try container.encode(campLifecycleVersion, forKey: .campLifecycleVersion)
        try container.encode(runId, forKey: .runId)
        try container.encode(cardId, forKey: .cardId)
        try container.encode(contract, forKey: .contract)
        try container.encode(adapterId, forKey: .adapterId)
        try container.encode(adapterVersion, forKey: .adapterVersion)
        try container.encode(profileId, forKey: .profileId)
        try container.encode(engineKind, forKey: .engineKind)
        try container.encode(model, forKey: .model)
        try container.encode(replayClass, forKey: .replayClass)
        try container.encode(contextJson, forKey: .contextJson)
        try container.encode(contextHash, forKey: .contextHash)
        try container.encode(sessionScopeJson, forKey: .sessionScopeJson)
        try container.encode(sessionScopeHash, forKey: .sessionScopeHash)
        try container.encode(requiredCapabilities, forKey: .requiredCapabilities)
        try container.encode(approvalGrantIds, forKey: .approvalGrantIds)
        try container.encode(budget, forKey: .budget)
        try container.encode(workspace, forKey: .workspace)
        if let predecessorExecutionId {
            try CanonicalContractCodingV1.validateCanonicalUUID(
                predecessorExecutionId
            )
            try container.encode(
                predecessorExecutionId,
                forKey: .predecessorExecutionId
            )
        } else {
            try container.encodeNil(forKey: .predecessorExecutionId)
        }
        if let sessionRef {
            try container.encode(sessionRef, forKey: .sessionRef)
        } else {
            try container.encodeNil(forKey: .sessionRef)
        }
    }

    package init(from decoder: any Decoder) throws {
        try EngineContractValidationV1.requireExactKeys(
            decoder,
            [
                "adapterId", "adapterVersion", "approvalGrantIds", "budget",
                "campId", "campLifecycleVersion", "cardId", "contextHash",
                "contextJson", "contract", "engineKind", "executionId",
                "idempotencyKey", "model", "profileId", "protocolVersion",
                "predecessorExecutionId", "replayClass",
                "requiredCapabilities", "runId", "sessionRef",
                "sessionScopeHash", "sessionScopeJson", "workspace",
            ]
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let protocolVersion = try container.decode(String.self, forKey: .protocolVersion)
        let executionId = try container.decode(String.self, forKey: .executionId)
        let idempotencyKey = try container.decode(String.self, forKey: .idempotencyKey)
        let campId = try container.decode(String.self, forKey: .campId)
        let campLifecycleVersion = try container.decode(
            Int.self,
            forKey: .campLifecycleVersion
        )
        let runId = try container.decode(String.self, forKey: .runId)
        let cardId = try container.decode(String.self, forKey: .cardId)
        let contract = try container.decode(OutcomeContractRef.self, forKey: .contract)
        let adapterId = try container.decode(String.self, forKey: .adapterId)
        let adapterVersion = try container.decode(String.self, forKey: .adapterVersion)
        let profileId = try container.decode(String.self, forKey: .profileId)
        let engineKind = try container.decode(String.self, forKey: .engineKind)
        let model = try container.decode(String.self, forKey: .model)
        let replayClass = try container.decode(
            EngineExecutionReplayClassV1.self,
            forKey: .replayClass
        )
        let contextJson = try container.decode(String.self, forKey: .contextJson)
        let contextHash = try container.decode(String.self, forKey: .contextHash)
        let sessionScopeJson = try container.decode(
            String.self,
            forKey: .sessionScopeJson
        )
        let sessionScopeHash = try container.decode(
            String.self,
            forKey: .sessionScopeHash
        )
        let requiredCapabilities = try container.decode(
            [EngineCapabilityV1].self,
            forKey: .requiredCapabilities
        )
        let approvalGrantIds = try container.decode(
            [String].self,
            forKey: .approvalGrantIds
        )
        let budget = try container.decode(
            EngineExecutionBudgetV1.self,
            forKey: .budget
        )
        let workspace = try container.decode(
            EngineWorkspaceRefV1.self,
            forKey: .workspace
        )
        let sessionRef = try container.decodeIfPresent(
            EngineSessionReferenceV1.self,
            forKey: .sessionRef
        )
        let predecessorExecutionId = try container.decodeIfPresent(
            String.self,
            forKey: .predecessorExecutionId
        )
        self = try EngineExecutionRequest.makeCanonical(
            protocolVersion: protocolVersion,
            executionId: executionId,
            idempotencyKey: idempotencyKey,
            campId: campId,
            campLifecycleVersion: campLifecycleVersion,
            runId: runId,
            cardId: cardId,
            contract: contract,
            adapterId: adapterId,
            adapterVersion: adapterVersion,
            profileId: profileId,
            engineKind: engineKind,
            model: model,
            replayClass: replayClass,
            contextJson: contextJson,
            contextHash: contextHash,
            sessionScopeJson: sessionScopeJson,
            sessionScopeHash: sessionScopeHash,
            requiredCapabilities: requiredCapabilities,
            approvalGrantIds: approvalGrantIds,
            budget: budget,
            workspace: workspace,
            predecessorExecutionId: predecessorExecutionId,
            sessionRef: sessionRef
        )
    }
}

package struct EngineUsageV1: Sendable, Equatable, Codable {
    package struct UsageOverflowError: Error, Sendable, Equatable {
        package init() {}
    }

    package let inputTokens: Int
    package let outputTokens: Int
    package let cacheReadTokens: Int
    package let costMicros: Int

    package static let zero = EngineUsageV1(
        inputTokens: 0,
        outputTokens: 0,
        cacheReadTokens: 0,
        costMicros: 0
    )

    package init(
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int,
        costMicros: Int
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.costMicros = costMicros
    }

    package func adding(_ other: EngineUsageV1) throws -> EngineUsageV1 {
        func add(_ lhs: Int, _ rhs: Int) throws -> Int {
            let (value, overflow) = lhs.addingReportingOverflow(rhs)
            guard !overflow else { throw UsageOverflowError() }
            return value
        }
        return try EngineUsageV1(
            inputTokens: add(inputTokens, other.inputTokens),
            outputTokens: add(outputTokens, other.outputTokens),
            cacheReadTokens: add(cacheReadTokens, other.cacheReadTokens),
            costMicros: add(costMicros, other.costMicros)
        )
    }

    package func validateNonnegative() throws {
        try CanonicalContractCodingV1.validateNonnegative(inputTokens)
        try CanonicalContractCodingV1.validateNonnegative(outputTokens)
        try CanonicalContractCodingV1.validateNonnegative(cacheReadTokens)
        try CanonicalContractCodingV1.validateNonnegative(costMicros)
    }
}

package enum EngineExecutionEventPayloadV1: Sendable, Equatable, Codable {
    case accepted
    case sessionBound(externalSessionId: String)
    case progress(message: String)
    case toolActivity(name: String)
    case usage(EngineUsageV1)
    case terminal(EngineTerminalProposalContentV1)

    private enum CodingKeys: String, CodingKey {
        case kind
        case externalSessionId
        case message
        case name
        case inputTokens
        case outputTokens
        case cacheReadTokens
        case costMicros
        case proposal
    }

    private enum PayloadKind: String, Codable {
        case accepted
        case sessionBound
        case progress
        case toolActivity
        case usage
        case terminal
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .accepted:
            try container.encode(PayloadKind.accepted, forKey: .kind)
        case let .sessionBound(externalSessionId):
            try EngineContractValidationV1.validateExternalSessionID(
                externalSessionId
            )
            try container.encode(PayloadKind.sessionBound, forKey: .kind)
            try container.encode(externalSessionId, forKey: .externalSessionId)
        case let .progress(message):
            try EngineContractValidationV1.validateProgress(message)
            try container.encode(PayloadKind.progress, forKey: .kind)
            try container.encode(message, forKey: .message)
        case let .toolActivity(name):
            try EngineContractValidationV1.validateToolName(name)
            try container.encode(PayloadKind.toolActivity, forKey: .kind)
            try container.encode(name, forKey: .name)
        case let .usage(usage):
            try usage.validateNonnegative()
            try container.encode(PayloadKind.usage, forKey: .kind)
            try container.encode(usage.inputTokens, forKey: .inputTokens)
            try container.encode(usage.outputTokens, forKey: .outputTokens)
            try container.encode(usage.cacheReadTokens, forKey: .cacheReadTokens)
            try container.encode(usage.costMicros, forKey: .costMicros)
        case let .terminal(proposal):
            try container.encode(PayloadKind.terminal, forKey: .kind)
            try container.encode(proposal, forKey: .proposal)
        }
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(PayloadKind.self, forKey: .kind)
        switch kind {
        case .accepted:
            try EngineContractValidationV1.requireExactKeys(
                decoder,
                ["kind"]
            )
            self = .accepted
        case .sessionBound:
            try EngineContractValidationV1.requireExactKeys(
                decoder,
                ["externalSessionId", "kind"]
            )
            let externalSessionId = try container.decode(
                String.self,
                forKey: .externalSessionId
            )
            try EngineContractValidationV1.validateExternalSessionID(
                externalSessionId
            )
            self = .sessionBound(externalSessionId: externalSessionId)
        case .progress:
            try EngineContractValidationV1.requireExactKeys(
                decoder,
                ["kind", "message"]
            )
            let message = try container.decode(String.self, forKey: .message)
            try EngineContractValidationV1.validateProgress(message)
            self = .progress(message: message)
        case .toolActivity:
            try EngineContractValidationV1.requireExactKeys(
                decoder,
                ["kind", "name"]
            )
            let name = try container.decode(String.self, forKey: .name)
            try EngineContractValidationV1.validateToolName(name)
            self = .toolActivity(name: name)
        case .usage:
            try EngineContractValidationV1.requireExactKeys(
                decoder,
                [
                    "cacheReadTokens", "costMicros", "inputTokens", "kind",
                    "outputTokens",
                ]
            )
            let usage = EngineUsageV1(
                inputTokens: try container.decode(Int.self, forKey: .inputTokens),
                outputTokens: try container.decode(Int.self, forKey: .outputTokens),
                cacheReadTokens: try container.decode(
                    Int.self,
                    forKey: .cacheReadTokens
                ),
                costMicros: try container.decode(Int.self, forKey: .costMicros)
            )
            try usage.validateNonnegative()
            self = .usage(usage)
        case .terminal:
            try EngineContractValidationV1.requireExactKeys(
                decoder,
                ["kind", "proposal"]
            )
            self = .terminal(
                try container.decode(
                    EngineTerminalProposalContentV1.self,
                    forKey: .proposal
                )
            )
        }
    }
}

package struct EngineExecutionEvent: Sendable, Equatable, Codable {
    package let executionId: String
    package let sequence: Int
    package let payload: EngineExecutionEventPayloadV1

    package init(
        executionId: String,
        sequence: Int,
        payload: EngineExecutionEventPayloadV1
    ) {
        self.executionId = executionId
        self.sequence = sequence
        self.payload = payload
    }

    private enum CodingKeys: String, CodingKey {
        case executionId
        case sequence
        case payload
    }

    package func encode(to encoder: any Encoder) throws {
        try validate()
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(executionId, forKey: .executionId)
        try container.encode(sequence, forKey: .sequence)
        try container.encode(payload, forKey: .payload)
    }

    package init(from decoder: any Decoder) throws {
        try EngineContractValidationV1.requireExactKeys(
            decoder,
            ["executionId", "payload", "sequence"]
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let executionId = try container.decode(String.self, forKey: .executionId)
        let sequence = try container.decode(Int.self, forKey: .sequence)
        let payload = try container.decode(
            EngineExecutionEventPayloadV1.self,
            forKey: .payload
        )
        self.init(
            executionId: executionId,
            sequence: sequence,
            payload: payload
        )
        try validate()
    }

    private func validate() throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        try CanonicalContractCodingV1.validateNonnegative(sequence)
        if case let .terminal(proposal) = payload {
            guard proposal.executionId == executionId,
                  proposal.sequence == sequence
            else {
                throw EngineEventSequenceErrorV1()
            }
        }
    }
}

package enum EngineDispatchStartResultV1: Sendable, Equatable {
    case startNow(EngineExecutionRequest)
    case alreadyStarted
}

package enum EngineRouterTerminalStateV1: Sendable, Equatable {
    case open
    case accepted(sequence: Int, terminalIdempotencyKey: String)
}

package struct EngineDuplicateTerminalErrorV1: Error, Sendable, Equatable {
    package let executionId: String

    package init(executionId: String) {
        self.executionId = executionId
    }
}

package actor EngineEventRouterV1 {
    package let executionId: String
    package let runId: String
    package let cardId: String
    package var nextSequence: Int
    package var terminalState: EngineRouterTerminalStateV1
    package var usage: EngineUsageV1

    package init(
        executionId: String,
        runId: String,
        cardId: String,
        nextSequence: Int,
        initialUsage: EngineUsageV1
    ) {
        self.executionId = executionId
        self.runId = runId
        self.cardId = cardId
        self.nextSequence = nextSequence
        terminalState = .open
        usage = initialUsage
    }

    package func route(
        _ payload: EngineExecutionEventPayloadV1
    ) throws -> EngineExecutionEvent {
        try requireOpen()
        let sequence = nextSequence
        let followingSequence = try checkedFollowingSequence(sequence)
        let routedPayload: EngineExecutionEventPayloadV1
        switch payload {
        case .accepted:
            routedPayload = .accepted
        case let .sessionBound(externalSessionId):
            try EngineContractValidationV1.validateExternalSessionID(
                externalSessionId
            )
            routedPayload = payload
        case let .progress(message):
            try EngineContractValidationV1.validateProgress(message)
            routedPayload = payload
        case let .toolActivity(name):
            try EngineContractValidationV1.validateToolName(name)
            routedPayload = payload
        case let .usage(delta):
            try usage.validateNonnegative()
            guard delta.inputTokens >= 0,
                  delta.outputTokens >= 0,
                  delta.cacheReadTokens >= 0,
                  delta.costMicros >= 0
            else {
                throw P1ContractValidationError.invalidValue
            }
            let cumulative = try usage.adding(delta)
            try cumulative.validateNonnegative()
            routedPayload = .usage(cumulative)
            usage = cumulative
        case .terminal:
            throw EngineEventSequenceErrorV1()
        }
        let event = EngineExecutionEvent(
            executionId: executionId,
            sequence: sequence,
            payload: routedPayload
        )
        nextSequence = followingSequence
        return event
    }

    package func routeTerminal(
        _ intent: EngineTerminalIntentV1,
        artifacts: [EngineTerminalArtifactDeclarationV1]
    ) throws -> EngineExecutionEvent {
        try requireOpen()
        let sequence = nextSequence
        let followingSequence = try checkedFollowingSequence(sequence)
        let terminalIdempotencyKey =
            "engine.terminal.v1:\(executionId):\(sequence)"
        let terminalKind: EngineTerminalKindV1
        let terminalSubtype: EngineTerminalSubtypeV1?
        let payload: EngineTerminalPayloadV1
        switch intent {
        case let .completed(handoff):
            terminalKind = .completed
            terminalSubtype = nil
            payload = .completed(handoff: handoff)
        case let .blocked(subtype, reasonCode, detail):
            terminalKind = .blocked
            switch subtype {
            case .ordinary:
                terminalSubtype = .ordinary
            case .engineProtocolError:
                terminalSubtype = .engineProtocolError
            case .externalEffectUnknown:
                terminalSubtype = .externalEffectUnknown
            }
            payload = .blocked(reasonCode: reasonCode, detail: detail)
        case let .needsHumanInput(kind, prompt, options):
            terminalKind = .blocked
            terminalSubtype = .needsHumanInput
            payload = .needsHumanInput(
                kind: kind,
                prompt: prompt,
                options: options
            )
        case let .failed(code, detail):
            terminalKind = .failed
            terminalSubtype = nil
            payload = .failed(code: code, detail: detail)
        case let .canceled(reasonCode, detail):
            terminalKind = .canceled
            terminalSubtype = nil
            payload = .canceled(reasonCode: reasonCode, detail: detail)
        }
        let proposal = try EngineTerminalProposalContentV1(
            protocolVersion: engineExecutionProtocolVersionV1,
            executionId: executionId,
            runId: runId,
            cardId: cardId,
            sequence: sequence,
            terminalIdempotencyKey: terminalIdempotencyKey,
            terminalKind: terminalKind,
            terminalSubtype: terminalSubtype,
            payload: payload,
            artifacts: artifacts
        )
        let event = EngineExecutionEvent(
            executionId: executionId,
            sequence: sequence,
            payload: .terminal(proposal)
        )
        nextSequence = followingSequence
        terminalState = .accepted(
            sequence: sequence,
            terminalIdempotencyKey: terminalIdempotencyKey
        )
        return event
    }

    package func state() throws -> EngineRouterTerminalStateV1 {
        terminalState
    }

    private func requireOpen() throws {
        guard terminalState == .open else {
            throw EngineDuplicateTerminalErrorV1(executionId: executionId)
        }
    }

    private func checkedFollowingSequence(_ sequence: Int) throws -> Int {
        guard sequence >= 0 else { throw EngineEventSequenceErrorV1() }
        let (value, overflow) = sequence.addingReportingOverflow(1)
        guard !overflow else { throw EngineEventSequenceErrorV1() }
        return value
    }
}

package protocol EngineTerminalSink: Sendable {
    func submit(_ intent: EngineTerminalIntentV1) async throws
}

package protocol EngineBoardTerminalSink: Sendable {
    func submit(_ intent: EngineBoardTerminalIntentV1) async throws
}

package protocol EngineProgressSink: Sendable {
    func submit(_ payload: EngineExecutionEventPayloadV1) async throws
}
