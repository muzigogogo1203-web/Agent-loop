import Foundation

public enum ConfigField: String, Sendable, Equatable, CaseIterable {
    case args
    case env
    case secretEnvKeys
}

public enum McpOperationError: Error, Sendable, Equatable {
    case registryRead(serverId: String?)
    case serverMissing(serverId: String)
    case invalidConfig(serverId: String, field: ConfigField)
    case secretMissing(serverId: String)
    case secretRead(serverId: String, osStatus: Int32?)
    case transportStart(serverId: String)
    case toolList(serverId: String)
    case connectionDown(serverId: String)
    case toolCall(serverId: String)
    case serverMaintenance(serverId: String)
}

package enum McpMaintenanceCleanupError: Error, Sendable, Equatable {
    case finishFailed(serverId: String)
    case invalidLease(serverId: String)
}

package enum McpServerDeletionFailure: Error, Sendable, Equatable {
    case credential(McpCredentialDeletionError)
    case maintenance(McpOperationError)
}

package struct McpDeletionCleanupCompositeError:
    Error, Sendable, Equatable
{
    package let primary: McpCredentialDeletionError
    package let cleanup: McpMaintenanceCleanupError

    package init(
        primary: McpCredentialDeletionError,
        cleanup: McpMaintenanceCleanupError
    ) {
        self.primary = primary
        self.cleanup = cleanup
    }
}

public struct McpServerReady: Sendable, Equatable {
    public let serverId: String
    public let toolCount: Int

    public init(serverId: String, toolCount: Int) {
        self.serverId = serverId
        self.toolCount = toolCount
    }
}

public struct McpEnsureResult: Sendable {
    public let serverId: String
    public let result: Result<McpServerReady, McpOperationError>

    public init(
        serverId: String,
        result: Result<McpServerReady, McpOperationError>
    ) {
        self.serverId = serverId
        self.result = result
    }
}

package struct McpMaintenanceLease: Sendable, Equatable {
    package let serverId: String
    fileprivate let nonce: UUID
    fileprivate let generation: Int

    fileprivate init(serverId: String, nonce: UUID, generation: Int) {
        self.serverId = serverId
        self.nonce = nonce
        self.generation = generation
    }
}

package enum McpMaintenanceCompletion: Sendable, Equatable {
    case keepStopped
    case removeHandle
}

#if DEBUG
package struct McpManagerAuditHooks: Sendable {
    package let onStart: @Sendable () -> Void
    package let finishMaintenanceFailure:
        @Sendable (String, McpMaintenanceCompletion)
            -> McpMaintenanceCleanupError?

    package init(
        onStart: @escaping @Sendable () -> Void,
        finishMaintenanceFailure:
            @escaping @Sendable (String, McpMaintenanceCompletion)
                -> McpMaintenanceCleanupError? = { _, _ in nil }
    ) {
        self.onStart = onStart
        self.finishMaintenanceFailure = finishMaintenanceFailure
    }
}
#endif

/// MCP 驿站生命周期：按需启动、一 server 一连接、tools/list 缓存。
/// down 不自动重试；只有显式 restart 可以恢复。
public actor McpServerManager {
    public enum ServerStatus: Sendable, Equatable {
        case stopped
        case starting
        case running(toolCount: Int)
        case down(String)

        public var isRunning: Bool {
            if case .running = self { return true }
            return false
        }
    }

    public struct AssembledTool: Sendable {
        public let def: ToolDef
        public let serverId: String
        public let serverName: String
        public let originalToolName: String
    }

    private struct Handle {
        var record: McpServerRecord
        var client: MiniMcpClient?
        var status: ServerStatus = .stopped
        var tools: [MiniMcpClient.ToolInfo] = []
        var generation = 0
        var maintenance: McpMaintenanceLease?
    }

    private struct ValidatedConfiguration: Sendable {
        let record: McpServerRecord
        let env: [String: String]
        let secretKeys: [String]
    }

    public typealias TransportFactory =
        @Sendable (McpServerRecord, [String: String]) -> any McpTransport
    public typealias SecretProvider =
        @Sendable (String, String) throws -> String?

    private let db: AppDatabase
    private let transportFactory: TransportFactory
    private let secretProvider: SecretProvider
    private let baseEnvironment: @Sendable () async -> [String: String]
    private let initTimeout: Duration
    private let callTimeout: Duration
    private var handles: [String: Handle] = [:]
    private var startTasks: [
        String: Task<Result<McpServerReady, McpOperationError>, Never>
    ] = [:]
    private var lastErrorByServer: [String: McpOperationError] = [:]
#if DEBUG
    private let auditHooks: McpManagerAuditHooks?
#endif

    public init(
        db: AppDatabase,
        transportFactory: @escaping TransportFactory = { record, env in
            StdioProcessTransport(
                command: record.command,
                args: record.args,
                environment: env
            )
        },
        secretProvider: @escaping SecretProvider = { _, _ in nil },
        baseEnvironment: @escaping @Sendable () async -> [String: String] = {
            await LoginShellEnvironment.shared.environment()
        },
        initTimeout: Duration = KernelDefaults.mcpInitTimeout,
        callTimeout: Duration = KernelDefaults.mcpCallTimeout
    ) {
        self.db = db
        self.transportFactory = transportFactory
        self.secretProvider = secretProvider
        self.baseEnvironment = baseEnvironment
        self.initTimeout = initTimeout
        self.callTimeout = callTimeout
#if DEBUG
        auditHooks = nil
#endif
    }

#if DEBUG
    package init(
        db: AppDatabase,
        transportFactory: @escaping TransportFactory,
        secretProvider: @escaping SecretProvider,
        baseEnvironment: @escaping @Sendable () async -> [String: String],
        initTimeout: Duration,
        callTimeout: Duration,
        auditHooks: McpManagerAuditHooks
    ) {
        self.db = db
        self.transportFactory = transportFactory
        self.secretProvider = secretProvider
        self.baseEnvironment = baseEnvironment
        self.initTimeout = initTimeout
        self.callTimeout = callTimeout
        self.auditHooks = auditHooks
    }
#endif

    // MARK: - Lifecycle

    @discardableResult
    public func ensureRunning(
        serverIds: [String]
    ) async -> [McpEnsureResult] {
        var outcomes: [McpEnsureResult] = []
        outcomes.reserveCapacity(serverIds.count)
        for serverId in serverIds {
            outcomes.append(
                McpEnsureResult(
                    serverId: serverId,
                    result: await ensureOne(serverId: serverId)
                )
            )
        }
        return outcomes
    }

    @discardableResult
    public func restart(
        serverId: String
    ) async -> Result<McpServerReady, McpOperationError> {
        if isUnderMaintenance(serverId) {
            return .failure(.serverMaintenance(serverId: serverId))
        }
        if let task = startTasks[serverId] {
            _ = await task.value
        }
        if isUnderMaintenance(serverId) {
            return .failure(.serverMaintenance(serverId: serverId))
        }
        await stopConnection(serverId: serverId)
        if handles[serverId] != nil {
            handles[serverId]?.status = .stopped
        }
        lastErrorByServer[serverId] = nil
        return await startServer(id: serverId)
    }

    public func stop(serverId: String) async {
        if let task = startTasks[serverId] {
            _ = await task.value
        }
        await stopConnection(serverId: serverId)
        if handles[serverId] != nil {
            handles[serverId]?.status = .stopped
        }
    }

    public func stopAll() async {
        for task in startTasks.values {
            _ = await task.value
        }
        for id in Array(handles.keys) {
            await stopConnection(serverId: id)
            if handles[id] != nil {
                handles[id]?.status = .stopped
            }
        }
    }

    public func status(serverId: String) -> ServerStatus {
        handles[serverId]?.status ?? .stopped
    }

    public func statuses() -> [String: ServerStatus] {
        handles.mapValues(\.status)
    }

    package func lastError(serverId: String) -> McpOperationError? {
        lastErrorByServer[serverId]
    }

    // MARK: - Maintenance

    package func acquireMaintenance(
        serverId: String
    ) async -> Result<McpMaintenanceLease, McpOperationError> {
        if isUnderMaintenance(serverId) {
            return .failure(.serverMaintenance(serverId: serverId))
        }

        let record: McpServerRecord
        do {
            guard let loaded = try db.mcpServer(id: serverId) else {
                let error = McpOperationError.serverMissing(serverId: serverId)
                lastErrorByServer[serverId] = error
                return .failure(error)
            }
            record = loaded
        } catch {
            let typed = McpOperationError.registryRead(serverId: serverId)
            lastErrorByServer[serverId] = typed
            return .failure(typed)
        }

        var handle = handles[serverId] ?? Handle(record: record)
        handle.record = record
        handle.generation += 1
        let lease = McpMaintenanceLease(
            serverId: serverId,
            nonce: UUID(),
            generation: handle.generation
        )
        handle.maintenance = lease
        handles[serverId] = handle

        if let task = startTasks[serverId] {
            _ = await task.value
            startTasks[serverId] = nil
        }
        await stopConnectionPreservingGeneration(serverId: serverId)
        handles[serverId]?.status = .stopped
        return .success(lease)
    }

    package func finishMaintenance(
        _ lease: McpMaintenanceLease,
        completion: McpMaintenanceCompletion
    ) async -> Result<Void, McpMaintenanceCleanupError> {
        guard let handle = handles[lease.serverId],
              handle.maintenance == lease,
              handle.generation == lease.generation
        else {
            return .failure(.invalidLease(serverId: lease.serverId))
        }

#if DEBUG
        if let injected = auditHooks?.finishMaintenanceFailure(
            lease.serverId,
            completion
        ) {
            guard case .finishFailed(let injectedID) = injected,
                  injectedID == lease.serverId
            else {
                return .failure(.invalidLease(serverId: lease.serverId))
            }
            return .failure(injected)
        }
#endif

        switch completion {
        case .keepStopped:
            handles[lease.serverId]?.maintenance = nil
            handles[lease.serverId]?.client = nil
            handles[lease.serverId]?.tools = []
            handles[lease.serverId]?.status = .stopped
        case .removeHandle:
            handles[lease.serverId] = nil
            lastErrorByServer[lease.serverId] = nil
        }
        return .success(())
    }

    // MARK: - Tool assembly

    public func assembledTools(campId: String) throws -> [AssembledTool] {
        let records: [McpServerRecord]
        do {
            records = try db.enabledMcpServers(campId: campId)
        } catch {
            throw McpOperationError.registryRead(serverId: nil)
        }
        var used = Set<String>()
        var result: [AssembledTool] = []
        for raw in records {
            if isUnderMaintenance(raw.id) {
                throw McpOperationError.serverMaintenance(serverId: raw.id)
            }
            let validated = try Self.validateConfiguration(raw)
            result.append(contentsOf: assemble(
                server: validated.record,
                used: &used
            ))
        }
        return result
    }

    public func assembledTools(serverId: String) throws -> [AssembledTool] {
        if isUnderMaintenance(serverId) {
            throw McpOperationError.serverMaintenance(serverId: serverId)
        }
        let raw: McpServerRecord
        do {
            guard let loaded = try db.mcpServer(id: serverId) else {
                throw McpOperationError.serverMissing(serverId: serverId)
            }
            raw = loaded
        } catch let typed as McpOperationError {
            throw typed
        } catch {
            throw McpOperationError.registryRead(serverId: serverId)
        }
        let validated = try Self.validateConfiguration(raw)
        var used = Set<String>()
        return assemble(server: validated.record, used: &used)
    }

    private func assemble(
        server: McpServerRecord,
        used: inout Set<String>
    ) -> [AssembledTool] {
        guard let handle = handles[server.id], handle.status.isRunning else {
            return []
        }
        var result: [AssembledTool] = []
        for tool in handle.tools {
            guard let name = McpToolNaming.compose(
                server: server.name,
                tool: tool.name
            ), !used.contains(name) else {
                continue
            }
            used.insert(name)
            result.append(
                AssembledTool(
                    def: ToolDef(
                        name: name,
                        description: TextTruncation.truncateUTF8(
                            tool.description,
                            maxBytes: 600,
                            suffix: "…"
                        ),
                        inputSchema: tool.inputSchema
                    ),
                    serverId: server.id,
                    serverName: server.name,
                    originalToolName: tool.name
                )
            )
        }
        return result
    }

    // MARK: - Calls

    public func call(
        serverId: String,
        toolName: String,
        arguments: JSONValue
    ) async -> Result<MiniMcpClient.CallResult, McpOperationError> {
        if isUnderMaintenance(serverId) {
            return .failure(.serverMaintenance(serverId: serverId))
        }
        guard let handle = handles[serverId],
              let client = handle.client,
              handle.status.isRunning
        else {
            return .failure(.connectionDown(serverId: serverId))
        }
        do {
            let result = try await client.callTool(
                name: toolName,
                arguments: arguments,
                timeout: callTimeout
            )
            if result.isError {
                return .failure(.toolCall(serverId: serverId))
            }
            return .success(result)
        } catch let error as McpClientError {
            if error == .connectionClosed {
                return .failure(.connectionDown(serverId: serverId))
            }
            return .failure(.toolCall(serverId: serverId))
        } catch {
            return .failure(.toolCall(serverId: serverId))
        }
    }

    // MARK: - Start internals

    private func ensureOne(
        serverId: String
    ) async -> Result<McpServerReady, McpOperationError> {
        if isUnderMaintenance(serverId) {
            return .failure(.serverMaintenance(serverId: serverId))
        }
        if let task = startTasks[serverId] {
            let result = await task.value
            if isUnderMaintenance(serverId) {
                return .failure(.serverMaintenance(serverId: serverId))
            }
            return result
        }
        if let handle = handles[serverId] {
            switch handle.status {
            case .running(let toolCount):
                return .success(McpServerReady(
                    serverId: serverId,
                    toolCount: toolCount
                ))
            case .down:
                return .failure(
                    lastErrorByServer[serverId]
                        ?? .connectionDown(serverId: serverId)
                )
            case .starting:
                let error = McpOperationError.transportStart(
                    serverId: serverId
                )
                recordFailure(error, serverId: serverId)
                return .failure(error)
            case .stopped:
                break
            }
        }
        return await startServer(id: serverId)
    }

    private func startServer(
        id: String
    ) async -> Result<McpServerReady, McpOperationError> {
        if isUnderMaintenance(id) {
            return .failure(.serverMaintenance(serverId: id))
        }

        let rawRecord: McpServerRecord
        do {
            guard let loaded = try db.mcpServer(id: id) else {
                let error = McpOperationError.serverMissing(serverId: id)
                lastErrorByServer[id] = error
                return .failure(error)
            }
            rawRecord = loaded
        } catch {
            let error = McpOperationError.registryRead(serverId: id)
            lastErrorByServer[id] = error
            return .failure(error)
        }

        let configuration: ValidatedConfiguration
        do {
            configuration = try Self.validateConfiguration(rawRecord)
        } catch let error as McpOperationError {
            recordFailure(error, serverId: id)
            return .failure(error)
        } catch {
            let typed = McpOperationError.invalidConfig(
                serverId: id,
                field: .args
            )
            recordFailure(typed, serverId: id)
            return .failure(typed)
        }

        var handle = handles[id] ?? Handle(record: configuration.record)
        handle.record = configuration.record
        handle.generation += 1
        handle.status = .starting
        handle.client = nil
        handle.tools = []
        handles[id] = handle
        let generation = handle.generation

        let task = Task {
            await self.performStart(
                configuration: configuration,
                generation: generation
            )
        }
        startTasks[id] = task
        let result = await task.value
        startTasks[id] = nil
        if isUnderMaintenance(id) {
            return .failure(.serverMaintenance(serverId: id))
        }
        return result
    }

    private func performStart(
        configuration: ValidatedConfiguration,
        generation: Int
    ) async -> Result<McpServerReady, McpOperationError> {
        let record = configuration.record
        let serverId = record.id
        var environment = await baseEnvironment()
        guard handles[serverId]?.generation == generation,
              !isUnderMaintenance(serverId)
        else {
            return .failure(.serverMaintenance(serverId: serverId))
        }
        for (key, value) in configuration.env {
            environment[key] = value
        }
        for key in configuration.secretKeys {
            let value: String?
            do {
                value = try secretProvider(serverId, key)
            } catch let error as KeychainError {
                let typed = McpOperationError.secretRead(
                    serverId: serverId,
                    osStatus: Int32(error.status)
                )
                recordFailure(typed, serverId: serverId)
                return .failure(typed)
            } catch {
                let typed = McpOperationError.secretRead(
                    serverId: serverId,
                    osStatus: nil
                )
                recordFailure(typed, serverId: serverId)
                return .failure(typed)
            }
            if let value, !value.isEmpty {
                environment[key] = value
            } else if environment[key]?.isEmpty != false {
                let typed = McpOperationError.secretMissing(
                    serverId: serverId
                )
                recordFailure(typed, serverId: serverId)
                return .failure(typed)
            }
        }

        guard handles[serverId]?.generation == generation,
              !isUnderMaintenance(serverId)
        else {
            return .failure(.serverMaintenance(serverId: serverId))
        }
        let transport = transportFactory(record, environment)
        let client = MiniMcpClient(transport: transport) { [weak self] in
            Task {
                await self?.markDown(
                    serverId: serverId,
                    generation: generation
                )
            }
        }
#if DEBUG
        auditHooks?.onStart()
#endif
        do {
            try await client.connect(timeout: initTimeout)
        } catch {
            await client.close()
            let typed = McpOperationError.transportStart(serverId: serverId)
            recordFailureIfCurrent(
                typed,
                serverId: serverId,
                generation: generation
            )
            return .failure(typed)
        }

        let tools: [MiniMcpClient.ToolInfo]
        do {
            tools = try await client.listTools(timeout: initTimeout)
        } catch {
            await client.close()
            let typed = McpOperationError.toolList(serverId: serverId)
            recordFailureIfCurrent(
                typed,
                serverId: serverId,
                generation: generation
            )
            return .failure(typed)
        }

        guard handles[serverId]?.generation == generation,
              !isUnderMaintenance(serverId)
        else {
            await client.close()
            return .failure(.serverMaintenance(serverId: serverId))
        }
        handles[serverId]?.client = client
        handles[serverId]?.tools = tools
        handles[serverId]?.status = .running(toolCount: tools.count)
        lastErrorByServer[serverId] = nil
        return .success(McpServerReady(
            serverId: serverId,
            toolCount: tools.count
        ))
    }

    private func markDown(serverId: String, generation: Int) {
        guard var handle = handles[serverId],
              handle.generation == generation,
              handle.maintenance == nil,
              handle.status.isRunning || handle.status == .starting
        else {
            return
        }
        handle.client = nil
        handle.tools = []
        handle.status = .down("驿站连接已断开。")
        handles[serverId] = handle
        lastErrorByServer[serverId] = .connectionDown(serverId: serverId)
    }

    private func recordFailureIfCurrent(
        _ error: McpOperationError,
        serverId: String,
        generation: Int
    ) {
        guard handles[serverId]?.generation == generation,
              !isUnderMaintenance(serverId)
        else {
            return
        }
        recordFailure(error, serverId: serverId)
    }

    private func recordFailure(
        _ error: McpOperationError,
        serverId: String
    ) {
        lastErrorByServer[serverId] = error
        guard handles[serverId] != nil else { return }
        handles[serverId]?.client = nil
        handles[serverId]?.tools = []
        handles[serverId]?.status = .down(Self.safeSummary(error))
    }

    private static func safeSummary(_ error: McpOperationError) -> String {
        switch error {
        case .registryRead: return "驿站注册表读取失败。"
        case .serverMissing: return "驿站记录不存在。"
        case .invalidConfig: return "驿站配置无效。"
        case .secretMissing: return "驿站凭据缺失。"
        case .secretRead: return "驿站凭据读取失败。"
        case .transportStart: return "驿站启动失败。"
        case .toolList: return "驿站工具清单读取失败。"
        case .connectionDown: return "驿站连接已断开。"
        case .toolCall: return "驿站工具调用失败。"
        case .serverMaintenance: return "驿站正在维护。"
        }
    }

    private func stopConnection(serverId: String) async {
        guard var handle = handles[serverId] else { return }
        handle.generation += 1
        let client = handle.client
        handle.client = nil
        handle.tools = []
        handles[serverId] = handle
        await client?.close()
    }

    private func stopConnectionPreservingGeneration(
        serverId: String
    ) async {
        guard var handle = handles[serverId] else { return }
        let client = handle.client
        handle.client = nil
        handle.tools = []
        handles[serverId] = handle
        await client?.close()
    }

    private func isUnderMaintenance(_ serverId: String) -> Bool {
        handles[serverId]?.maintenance != nil
    }

    // MARK: - Configuration

    private static func validateConfiguration(
        _ raw: McpServerRecord
    ) throws -> ValidatedConfiguration {
        let decoder = JSONDecoder()
        let args: [String]
        do {
            args = try decoder.decode(
                [String].self,
                from: Data(raw.argsJson.utf8)
            )
        } catch {
            throw McpOperationError.invalidConfig(
                serverId: raw.id,
                field: .args
            )
        }
        let environment: [String: String]
        do {
            environment = try decoder.decode(
                [String: String].self,
                from: Data(raw.envJson.utf8)
            )
        } catch {
            throw McpOperationError.invalidConfig(
                serverId: raw.id,
                field: .env
            )
        }
        let secretKeys: [String]
        do {
            secretKeys = try decoder.decode(
                [String].self,
                from: Data(raw.secretEnvKeysJson.utf8)
            )
        } catch {
            throw McpOperationError.invalidConfig(
                serverId: raw.id,
                field: .secretEnvKeys
            )
        }
        guard Set(secretKeys).count == secretKeys.count,
              secretKeys.allSatisfy(isValidEnvironmentKey)
        else {
            throw McpOperationError.invalidConfig(
                serverId: raw.id,
                field: .secretEnvKeys
            )
        }

        var canonical = raw
        canonical.argsJson = try encodeCanonical(
            args,
            serverId: raw.id,
            field: .args
        )
        canonical.envJson = try encodeCanonical(
            environment,
            serverId: raw.id,
            field: .env
        )
        canonical.secretEnvKeysJson = try encodeCanonical(
            secretKeys,
            serverId: raw.id,
            field: .secretEnvKeys
        )
        return ValidatedConfiguration(
            record: canonical,
            env: environment,
            secretKeys: secretKeys
        )
    }

    private static func encodeCanonical<Value: Encodable>(
        _ value: Value,
        serverId: String,
        field: ConfigField
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return String(
                decoding: try encoder.encode(value),
                as: UTF8.self
            )
        } catch {
            throw McpOperationError.invalidConfig(
                serverId: serverId,
                field: field
            )
        }
    }

    private static func isValidEnvironmentKey(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard (1...128).contains(bytes.count),
              let first = bytes.first,
              isASCIIAlpha(first) || first == 95
        else {
            return false
        }
        return bytes.dropFirst().allSatisfy {
            isASCIIAlpha($0) || (48...57).contains($0) || $0 == 95
        }
    }

    private static func isASCIIAlpha(_ byte: UInt8) -> Bool {
        (65...90).contains(byte) || (97...122).contains(byte)
    }
}
