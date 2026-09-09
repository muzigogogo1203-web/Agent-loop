import CoreFoundation
import CryptoKit
import Darwin
import Foundation
import Security

package typealias EngineCliManagedPolicyValidateV1 =
    @Sendable (
        _ executableAuthority: CliExecutableAuthorityV1
    ) throws -> Void

package enum CliHelpProbeProcessCleanupSourceV1: Sendable, Equatable {
    case terminate
    case stdinClose
    case stdoutReadClose
    case stdoutWriteClose
    case stderrReadClose
    case stderrWriteClose
}

package enum CliHelpProbeFailureV1: Error, Sendable, Equatable {
    case invalidAuthority
    case sourceIdentity
    case signatureIdentity
    case stagedIdentity
    case processImageIdentity
    case deadline
    case stdoutLimit
    case exitStatus
    case unsupportedVersion
    case mechanics
    case cleanup
    case processCleanup([CliHelpProbeProcessCleanupSourceV1])

    fileprivate var isCleanupFailure: Bool {
        switch self {
        case .cleanup, .processCleanup:
            true
        default:
            false
        }
    }
}

package enum CliCleanupFileErrorV1: Error, Sendable, Equatable {
    case invalidAuthority
    case identityMismatch
    case cleanupFailed
}

package struct CliCleanupFileAuthorityV1: Sendable, Equatable {
    package let fileURL: URL
    fileprivate let parentDevice: UInt64
    fileprivate let parentInode: UInt64
    fileprivate let parentUID: UInt32
    fileprivate let basename: String
    fileprivate let fileDevice: UInt64
    fileprivate let fileInode: UInt64
    fileprivate let fileUID: UInt32
    fileprivate let fileMode: UInt16
    fileprivate let fileLinkCount: UInt64

    fileprivate init(
        fileURL: URL,
        parentDevice: UInt64,
        parentInode: UInt64,
        parentUID: UInt32,
        basename: String,
        fileDevice: UInt64,
        fileInode: UInt64,
        fileUID: UInt32,
        fileMode: UInt16,
        fileLinkCount: UInt64
    ) throws {
        guard Self.isCanonicalFileURL(fileURL),
              fileURL.lastPathComponent == basename,
              !basename.isEmpty,
              !basename.contains("/"),
              !basename.utf8.contains(0),
              parentDevice > 0,
              parentInode > 0,
              parentUID == getuid(),
              fileDevice > 0,
              fileInode > 0,
              fileUID == getuid(),
              fileMode == 0o600,
              fileLinkCount == 1
        else {
            throw CliCleanupFileErrorV1.invalidAuthority
        }
        self.fileURL = fileURL
        self.parentDevice = parentDevice
        self.parentInode = parentInode
        self.parentUID = parentUID
        self.basename = basename
        self.fileDevice = fileDevice
        self.fileInode = fileInode
        self.fileUID = fileUID
        self.fileMode = fileMode
        self.fileLinkCount = fileLinkCount
    }

    package static func captureExisting(_ url: URL) throws -> Self {
        guard isCanonicalFileURL(url) else {
            throw CliCleanupFileErrorV1.invalidAuthority
        }
        let parentURL = url.deletingLastPathComponent()
        let parent = parentURL.path.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard parent >= 0 else {
            throw CliCleanupFileErrorV1.invalidAuthority
        }
        var parentOpen = true
        defer { if parentOpen { _ = Darwin.close(parent) } }
        var parentInfo = stat()
        var fileInfo = stat()
        let basename = url.lastPathComponent
        guard Darwin.fstat(parent, &parentInfo) == 0,
              parentInfo.st_mode & S_IFMT == S_IFDIR,
              parentInfo.st_uid == getuid(),
              basename.withCString({
                  Darwin.fstatat(parent, $0, &fileInfo, AT_SYMLINK_NOFOLLOW)
              }) == 0,
              fileInfo.st_mode & S_IFMT == S_IFREG,
              fileInfo.st_uid == getuid(),
              fileInfo.st_mode & mode_t(0o777) == mode_t(0o600),
              fileInfo.st_nlink == 1
        else {
            throw CliCleanupFileErrorV1.invalidAuthority
        }
        guard Darwin.close(parent) == 0 else {
            parentOpen = false
            throw CliCleanupFileErrorV1.invalidAuthority
        }
        parentOpen = false
        return try Self(
            fileURL: url,
            parentDevice: UInt64(parentInfo.st_dev),
            parentInode: UInt64(parentInfo.st_ino),
            parentUID: UInt32(parentInfo.st_uid),
            basename: basename,
            fileDevice: UInt64(fileInfo.st_dev),
            fileInode: UInt64(fileInfo.st_ino),
            fileUID: UInt32(fileInfo.st_uid),
            fileMode: UInt16(fileInfo.st_mode & mode_t(0o777)),
            fileLinkCount: UInt64(fileInfo.st_nlink)
        )
    }

    package func removeExpectedFile() throws {
        let parent = fileURL.deletingLastPathComponent().path.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard parent >= 0 else {
            throw CliCleanupFileErrorV1.cleanupFailed
        }
        var parentOpen = true
        defer { if parentOpen { _ = Darwin.close(parent) } }
        var parentInfo = stat()
        var fileInfo = stat()
        guard Darwin.fstat(parent, &parentInfo) == 0,
              parentInfo.st_mode & S_IFMT == S_IFDIR,
              UInt64(parentInfo.st_dev) == parentDevice,
              UInt64(parentInfo.st_ino) == parentInode,
              UInt32(parentInfo.st_uid) == parentUID,
              basename.withCString({
                  Darwin.fstatat(parent, $0, &fileInfo, AT_SYMLINK_NOFOLLOW)
              }) == 0,
              fileInfo.st_mode & S_IFMT == S_IFREG,
              UInt64(fileInfo.st_dev) == fileDevice,
              UInt64(fileInfo.st_ino) == fileInode,
              UInt32(fileInfo.st_uid) == fileUID,
              UInt16(fileInfo.st_mode & mode_t(0o777)) == fileMode,
              UInt64(fileInfo.st_nlink) == fileLinkCount
        else {
            throw CliCleanupFileErrorV1.identityMismatch
        }
        guard basename.withCString({ Darwin.unlinkat(parent, $0, 0) }) == 0,
              Darwin.fsync(parent) == 0
        else {
            throw CliCleanupFileErrorV1.cleanupFailed
        }
        guard Darwin.close(parent) == 0 else {
            parentOpen = false
            throw CliCleanupFileErrorV1.cleanupFailed
        }
        parentOpen = false
    }

    private static func isCanonicalFileURL(_ url: URL) -> Bool {
        url.isFileURL
            && url.baseURL == nil
            && url.path.hasPrefix("/")
            && url.standardizedFileURL.path == url.path
            && url.deletingLastPathComponent().path != "/"
    }
}

package struct CliExecutableAuthorityV1: Sendable, Equatable {
    package let kind: RuntimeProfileKind
    package let command: String
    package let commandSourcePath: String
    package let commandSourceHash: String
    package let resolvedExecutablePath: String
    package let stagedPath: String
    package let executableHash: String
    package let designatedRequirement: String
    package let teamIdentifier: String
    package let cdHash: String
    package let stagedDevice: UInt64
    package let stagedInode: UInt64

    package init(
        kind: RuntimeProfileKind,
        command: String,
        commandSourcePath: String,
        commandSourceHash: String,
        resolvedExecutablePath: String,
        stagedPath: String,
        executableHash: String,
        designatedRequirement: String,
        teamIdentifier: String,
        cdHash: String,
        stagedDevice: UInt64,
        stagedInode: UInt64
    ) throws {
        guard (kind == .cliCodex && command == "codex")
                || (kind == .cliClaude && command == "claude"),
              Self.isCanonicalAbsolutePath(commandSourcePath),
              Self.isCanonicalAbsolutePath(resolvedExecutablePath),
              Self.isCanonicalAbsolutePath(stagedPath),
              Self.isLowercaseHex(commandSourceHash, count: 64),
              Self.isLowercaseHex(executableHash, count: 64),
              Self.isLowercaseHex(cdHash, count: 40),
              !designatedRequirement.isEmpty,
              !designatedRequirement.utf8.contains(0),
              teamIdentifier == Self.expectedTeamIdentifier(for: kind),
              stagedDevice > 0,
              stagedInode > 0
        else {
            throw EngineContextValidationErrorV1()
        }
        self.kind = kind
        self.command = command
        self.commandSourcePath = commandSourcePath
        self.commandSourceHash = commandSourceHash
        self.resolvedExecutablePath = resolvedExecutablePath
        self.stagedPath = stagedPath
        self.executableHash = executableHash
        self.designatedRequirement = designatedRequirement
        self.teamIdentifier = teamIdentifier
        self.cdHash = cdHash
        self.stagedDevice = stagedDevice
        self.stagedInode = stagedInode
    }

    package func validateCanonical() throws {
        _ = try Self(
            kind: kind,
            command: command,
            commandSourcePath: commandSourcePath,
            commandSourceHash: commandSourceHash,
            resolvedExecutablePath: resolvedExecutablePath,
            stagedPath: stagedPath,
            executableHash: executableHash,
            designatedRequirement: designatedRequirement,
            teamIdentifier: teamIdentifier,
            cdHash: cdHash,
            stagedDevice: stagedDevice,
            stagedInode: stagedInode
        )
    }

    package func revalidateStagedCodeSignature() throws {
        let identity = try CliExecutableIdentityV1.vendorSigningIdentity(
            path: stagedPath,
            kind: kind
        )
        guard identity.designatedRequirement == designatedRequirement,
              identity.teamIdentifier == teamIdentifier,
              identity.cdHash == cdHash
        else {
            throw EngineContextValidationErrorV1()
        }
    }

    fileprivate static func expectedTeamIdentifier(
        for kind: RuntimeProfileKind
    ) -> String {
        switch kind {
        case .cliCodex:
            "2DC432GLL2"
        case .cliClaude:
            "Q6L2SF6YDW"
        case .anthropicAPI, .openAIAPI, .chatGPTOAuth:
            ""
        }
    }

    fileprivate static func isCanonicalAbsolutePath(_ value: String) -> Bool {
        guard !value.isEmpty,
              !value.utf8.contains(0),
              value.hasPrefix("/")
        else { return false }
        return URL(fileURLWithPath: value).standardizedFileURL.path == value
    }

    fileprivate static func isLowercaseHex(
        _ value: String,
        count: Int
    ) -> Bool {
        value.utf8.count == count && value.utf8.allSatisfy { byte in
            (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte)
        }
    }
}

package struct EngineBoardBridgeExecutableAuthorityV1:
    Sendable, Equatable
{
    package let sourcePath: String
    package let stagedPath: String
    package let executableHash: String
    package let designatedRequirement: String
    package let teamIdentifier: String?
    package let cdHash: String
    package let stagedDevice: UInt64
    package let stagedInode: UInt64

    package init(
        sourcePath: String,
        stagedPath: String,
        executableHash: String,
        designatedRequirement: String,
        teamIdentifier: String?,
        cdHash: String,
        stagedDevice: UInt64,
        stagedInode: UInt64
    ) throws {
        guard CliExecutableAuthorityV1.isCanonicalAbsolutePath(sourcePath),
              CliExecutableAuthorityV1.isCanonicalAbsolutePath(stagedPath),
              CliExecutableAuthorityV1.isLowercaseHex(
                  executableHash,
                  count: 64
              ),
              CliExecutableAuthorityV1.isLowercaseHex(cdHash, count: 40),
              !designatedRequirement.isEmpty,
              !designatedRequirement.utf8.contains(0),
              teamIdentifier?.isEmpty != true,
              stagedDevice > 0,
              stagedInode > 0
        else {
            throw EngineContextValidationErrorV1()
        }
        self.sourcePath = sourcePath
        self.stagedPath = stagedPath
        self.executableHash = executableHash
        self.designatedRequirement = designatedRequirement
        self.teamIdentifier = teamIdentifier
        self.cdHash = cdHash
        self.stagedDevice = stagedDevice
        self.stagedInode = stagedInode
    }

    package func validateCanonical() throws {
        _ = try Self(
            sourcePath: sourcePath,
            stagedPath: stagedPath,
            executableHash: executableHash,
            designatedRequirement: designatedRequirement,
            teamIdentifier: teamIdentifier,
            cdHash: cdHash,
            stagedDevice: stagedDevice,
            stagedInode: stagedInode
        )
    }

    package func revalidateStagedCodeSignature() throws {
        let identity = try CliExecutableIdentityV1.bridgeSigningIdentity(
            path: stagedPath
        )
        guard identity.designatedRequirement == designatedRequirement,
              identity.teamIdentifier == teamIdentifier,
              identity.cdHash == cdHash
        else {
            throw EngineContextValidationErrorV1()
        }
    }
}

package struct EngineRuntimeProcessSnapshotV1: Sendable, Equatable {
    package let pid: Int32
    package let processGroupId: Int32
    package let uid: UInt32
    package let startSeconds: UInt64
    package let startMicroseconds: UInt32
    package let executablePath: String
    package let executableDevice: UInt64
    package let executableInode: UInt64
    package let executableHash: String
    package let designatedRequirement: String
    package let cdHash: String

    package init(
        pid: Int32,
        processGroupId: Int32,
        uid: UInt32,
        startSeconds: UInt64,
        startMicroseconds: UInt32,
        executablePath: String,
        executableDevice: UInt64,
        executableInode: UInt64,
        executableHash: String,
        designatedRequirement: String,
        cdHash: String
    ) {
        self.pid = pid
        self.processGroupId = processGroupId
        self.uid = uid
        self.startSeconds = startSeconds
        self.startMicroseconds = startMicroseconds
        self.executablePath = executablePath
        self.executableDevice = executableDevice
        self.executableInode = executableInode
        self.executableHash = executableHash
        self.designatedRequirement = designatedRequirement
        self.cdHash = cdHash
    }
}

package protocol EngineRuntimeProcessInspectingV1: Sendable {
    func snapshots() throws -> [EngineRuntimeProcessSnapshotV1]
    func send(signal: Int32, processGroupId: Int32) throws
    func processGroupExists(_ processGroupId: Int32) throws -> Bool
}

package enum CliWorkspaceManagedPolicyV1 {
    package static func validateCodex(workspaceURL: URL) throws {
        guard workspaceURL.isFileURL,
              workspaceURL.baseURL == nil,
              workspaceURL.standardizedFileURL == workspaceURL,
              workspaceURL.path.hasPrefix("/")
        else {
            throw EngineContextValidationErrorV1()
        }

        try requireExactENOENT(
            workspaceURL.appendingPathComponent("config.toml").path
        )
        var ancestor = workspaceURL
        while true {
            try requireExactENOENT(
                ancestor.appendingPathComponent(".codex", isDirectory: true)
                    .appendingPathComponent("config.toml").path
            )
            if ancestor.path == "/" { break }
            let parent = ancestor.deletingLastPathComponent()
            guard parent.path != ancestor.path else {
                throw EngineContextValidationErrorV1()
            }
            ancestor = parent
        }
    }

    private static func requireExactENOENT(_ path: String) throws {
        let descriptor = path.withCString {
            Darwin.open($0, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        }
        let openError = errno
        if descriptor >= 0 {
            let closeResult = Darwin.close(descriptor)
            guard closeResult == 0 else {
                throw EngineContextValidationErrorV1()
            }
            throw EngineContextValidationErrorV1()
        }
        guard openError == ENOENT else {
            throw EngineContextValidationErrorV1()
        }
    }
}

package enum CliEngineSessionCommandV1: Sendable, Equatable {
    case first(ranchUUID: String)
    case resume(externalID: String)
}

package struct CliEngineRuntimeConfigurationV1: Sendable, Equatable {
    package let command: String
    package let cliExecutableAuthority: CliExecutableAuthorityV1
    package let sandbox: String
    package let reasoningEffort: String
    package let bridgeExecutableAuthority:
        EngineBoardBridgeExecutableAuthorityV1
    package let boardSocketDirectoryAuthority:
        EngineBoardSocketDirectoryAuthorityV1
    package let claudeConfigDirectory: URL
    package let ranchSessionId: String

    package init(
        command: String,
        cliExecutableAuthority: CliExecutableAuthorityV1,
        sandbox: String,
        reasoningEffort: String,
        bridgeExecutableAuthority:
            EngineBoardBridgeExecutableAuthorityV1,
        boardSocketDirectoryAuthority:
            EngineBoardSocketDirectoryAuthorityV1,
        claudeConfigDirectory: URL,
        ranchSessionId: String
    ) throws {
        try cliExecutableAuthority.validateCanonical()
        try bridgeExecutableAuthority.validateCanonical()
        guard command == cliExecutableAuthority.stagedPath,
              sandbox == "read-only",
              Self.validReasoningEfforts.contains(reasoningEffort)
        else {
            throw EngineContextValidationErrorV1()
        }
        guard claudeConfigDirectory.isFileURL,
              claudeConfigDirectory.baseURL == nil,
              claudeConfigDirectory.path.hasPrefix("/"),
              claudeConfigDirectory.standardizedFileURL.path
                == claudeConfigDirectory.path
        else {
            throw EngineContextValidationErrorV1()
        }
        try CanonicalContractCodingV1.validateCanonicalUUID(ranchSessionId)
        self.command = command
        self.cliExecutableAuthority = cliExecutableAuthority
        self.sandbox = sandbox
        self.reasoningEffort = reasoningEffort
        self.bridgeExecutableAuthority = bridgeExecutableAuthority
        self.boardSocketDirectoryAuthority =
            boardSocketDirectoryAuthority
        self.claudeConfigDirectory = claudeConfigDirectory
        self.ranchSessionId = ranchSessionId
    }

    private static let validReasoningEfforts: Set<String> = [
        "minimal", "low", "medium", "high", "xhigh",
    ]
}

package struct CliEngineCommandInputV1: Sendable, Equatable {
    package let command: String
    package let cliExecutableAuthority: CliExecutableAuthorityV1
    package let workspaceURL: URL
    package let sandbox: String
    package let model: String
    package let reasoningEffort: String
    package let prompt: String
    package let bridgeExecutableAuthority:
        EngineBoardBridgeExecutableAuthorityV1
    package let boardSocketURL: URL
    package let boardToken: String
    package let boardCardId: String
    package let toolNames: [String]
    package let claudeConfigURL: URL
    package let session: CliEngineSessionCommandV1

    package init(
        command: String,
        cliExecutableAuthority: CliExecutableAuthorityV1,
        workspaceURL: URL,
        sandbox: String,
        model: String,
        reasoningEffort: String,
        prompt: String,
        bridgeExecutableAuthority:
            EngineBoardBridgeExecutableAuthorityV1,
        boardSocketURL: URL,
        boardToken: String,
        boardCardId: String,
        toolNames: [String],
        claudeConfigURL: URL,
        session: CliEngineSessionCommandV1
    ) throws {
        try cliExecutableAuthority.validateCanonical()
        try bridgeExecutableAuthority.validateCanonical()
        guard command == cliExecutableAuthority.stagedPath,
              sandbox == "read-only"
        else {
            throw EngineContextValidationErrorV1()
        }
        try CanonicalContractCodingV1.validateNonempty(model)
        guard ["minimal", "low", "medium", "high", "xhigh"]
            .contains(reasoningEffort)
        else {
            throw EngineContextValidationErrorV1()
        }
        guard !prompt.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty,
            prompt.unicodeScalars.allSatisfy({ scalar in
                !CharacterSet.controlCharacters.contains(scalar)
                    || scalar.value == 0x09
                    || scalar.value == 0x0A
                    || scalar.value == 0x0D
            })
        else {
            throw EngineContextValidationErrorV1()
        }
        try CanonicalContractCodingV1.validateCanonicalUUID(boardCardId)
        guard workspaceURL.isFileURL, workspaceURL.baseURL == nil,
              workspaceURL.path.hasPrefix("/"),
              workspaceURL.standardizedFileURL.path == workspaceURL.path,
              Self.isCanonicalBoardSocketURL(boardSocketURL),
              claudeConfigURL.isFileURL, claudeConfigURL.baseURL == nil,
              claudeConfigURL.path.hasPrefix("/"),
              claudeConfigURL.standardizedFileURL.path == claudeConfigURL.path,
              boardToken.utf8.count == 64,
              boardToken.utf8.allSatisfy({ byte in
                  (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                      || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte)
              }),
              !toolNames.isEmpty,
              toolNames == Array(Set(toolNames)).sorted(),
              toolNames.allSatisfy({ name in
                  !name.isEmpty
                      && !name.hasPrefix("mcp__")
                      && !name.utf8.contains(0)
              })
        else {
            throw EngineContextValidationErrorV1()
        }
        switch session {
        case let .first(ranchUUID):
            try CanonicalContractCodingV1.validateCanonicalUUID(ranchUUID)
        case let .resume(externalID):
            try EngineContractValidationV1.validateExternalSessionID(externalID)
        }
        self.command = command
        self.cliExecutableAuthority = cliExecutableAuthority
        self.workspaceURL = workspaceURL
        self.sandbox = sandbox
        self.model = model
        self.reasoningEffort = reasoningEffort
        self.prompt = prompt
        self.bridgeExecutableAuthority = bridgeExecutableAuthority
        self.boardSocketURL = boardSocketURL
        self.boardToken = boardToken
        self.boardCardId = boardCardId
        self.toolNames = toolNames
        self.claudeConfigURL = claudeConfigURL
        self.session = session
    }

    package static func isCanonicalBoardSocketURL(_ url: URL) -> Bool {
        let path = url.path
        let components = path.split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        guard url.isFileURL,
              url.baseURL == nil,
              path.hasPrefix("/"),
              !path.contains("//"),
              !path.utf8.contains(0),
              path.utf8.count + 1
                  <= MemoryLayout.size(ofValue: sockaddr_un().sun_path),
              components.first?.isEmpty == true,
              components.dropFirst().allSatisfy({ component in
                  !component.isEmpty
                      && component != "."
                      && component != ".."
              }),
              BoardToolServer.isCanonicalSocketBasename(
                  url.lastPathComponent
              )
        else {
            return false
        }
        return true
    }
}

package struct CliEngineCommandBuilderV1: Sendable {
    package init() {}

    package func buildCodex(
        _ input: CliEngineCommandInputV1
    ) throws -> CliCommandSpec {
        try CliEnginePromptV1.validateCodex(input.prompt)
        guard input.cliExecutableAuthority.kind == .cliCodex,
              input.cliExecutableAuthority.command == "codex",
              input.command == input.cliExecutableAuthority.stagedPath
        else {
            throw EngineContextValidationErrorV1()
        }
        let configPairs = [
            "model_reasoning_effort=\(tomlString(input.reasoningEffort))",
            "approval_policy=\"never\"",
            "web_search=\"disabled\"",
            "tools.web_search=false",
            "features.shell_tool=false",
            "features.apps=false",
            "apps._default.enabled=false",
            "features.browser_use=false",
            "features.browser_use_external=false",
            "features.browser_use_full_cdp_access=false",
            "features.in_app_browser=false",
            "features.computer_use=false",
            "features.image_generation=false",
            "features.code_mode=false",
            "features.code_mode_host=false",
            "features.code_mode_only=false",
            "features.plugins=false",
            "features.plugin_sharing=false",
            "features.remote_plugin=false",
            "features.tool_suggest=false",
            "features.workspace_dependencies=false",
            "features.auth_elicitation=false",
            "features.tool_call_mcp_elicitation=false",
            "features.request_permissions_tool=false",
            "features.hooks=false",
            "features.multi_agent=false",
            "features.goals=false",
            "features.memories=false",
            "features.chronicle=false",
            "features.skill_mcp_dependency_install=false",
            "features.guardian_approval=false",
            "features.unified_exec=false",
            "features.shell_snapshot=false",
            "check_for_update_on_startup=false",
            "project_doc_max_bytes=0",
            "instructions=\"\"",
            "developer_instructions=\"\"",
            "skills.include_instructions=false",
            "skills.bundled.enabled=false",
            "include_environment_context=false",
            "include_permissions_instructions=false",
            "include_apps_instructions=false",
            "include_collaboration_mode_instructions=false",
            "projects.\(tomlString(input.workspaceURL.path)).trust_level=\"untrusted\"",
            ranchMCPTable(input),
        ]
        var arguments = [
            "-a", "never",
            "-C", input.workspaceURL.path,
            "-s", "read-only",
            "-m", input.model,
            "exec",
            "--ignore-user-config",
            "--ignore-rules",
            "--strict-config",
            "--skip-git-repo-check",
        ]
        for pair in configPairs {
            arguments += ["-c", pair]
        }
        arguments.append("--json")
        if case let .resume(externalID) = input.session {
            arguments += ["resume", externalID]
        }
        arguments.append("-")
        return CliCommandSpec(
            command: input.command,
            arguments: arguments,
            environment: [:],
            stdinBytes: Data(input.prompt.utf8),
            cleanupURLs: []
        )
    }

    package func buildClaude(
        _ input: CliEngineCommandInputV1
    ) throws -> CliCommandSpec {
        guard input.cliExecutableAuthority.kind == .cliClaude,
              input.cliExecutableAuthority.command == "claude",
              input.command == input.cliExecutableAuthority.stagedPath,
              input.sandbox == "read-only"
        else {
            throw EngineContextValidationErrorV1()
        }
        let configuration: JSONValue = [
            "mcpServers": [
                "ranchboard": [
                    "command": .string(
                        input.bridgeExecutableAuthority.stagedPath
                    ),
                    "args": ["--board-server"],
                    "env": [
                        "AGENTLOOP_BOARD_SOCKET": .string(
                            input.boardSocketURL.path
                        ),
                        "AGENTLOOP_BOARD_TOKEN": .string(input.boardToken),
                        "AGENTLOOP_BOARD_CARD_ID": .string(
                            input.boardCardId
                        ),
                        "AGENTLOOP_BOARD_TOOLS": .string(
                            input.toolNames.joined(separator: ",")
                        ),
                    ],
                ],
            ],
        ]
        let configurationBytes = try CanonicalJSONV1.encode(configuration)
        let cleanupAuthority = try writeClaudeConfiguration(
            configurationBytes,
            to: input.claudeConfigURL
        )
        var arguments: [String] = [
            "-p",
            "--input-format", "text",
            "--output-format", "stream-json",
            "--verbose",
            "--mcp-config", input.claudeConfigURL.path,
            "--tools", "",
            "--setting-sources", "",
            "--strict-mcp-config",
            "--allowedTools",
        ]
        arguments += input.toolNames.map { "mcp__ranchboard__\($0)" }
        arguments += [
            "--permission-mode", "dontAsk",
            "--disable-slash-commands",
            "--no-chrome",
        ]
        switch input.session {
        case let .first(ranchUUID):
            arguments += ["--session-id", ranchUUID]
        case let .resume(externalID):
            arguments += ["--resume", externalID]
        }
        arguments += [
            "--model", input.model,
            "--add-dir", input.workspaceURL.path,
        ]
        return CliCommandSpec(
            command: input.command,
            arguments: arguments,
            environment: [
                "CLAUDE_CODE_DISABLE_AUTO_MEMORY": "1",
                "CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS": "1",
                "CLAUDE_CODE_SUBPROCESS_ENV_SCRUB": "1",
                "DISABLE_AUTOUPDATER": "1",
                "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
                "DISABLE_TELEMETRY": "1",
                "DISABLE_ERROR_REPORTING": "1",
                "DISABLE_BUG_COMMAND": "1",
            ],
            stdinBytes: Data(input.prompt.utf8),
            cleanupAuthorities: [cleanupAuthority]
        )
    }

    private func ranchMCPTable(_ input: CliEngineCommandInputV1) -> String {
        let envNames = [
            "AGENTLOOP_BOARD_SOCKET",
            "AGENTLOOP_BOARD_TOKEN",
            "AGENTLOOP_BOARD_CARD_ID",
            "AGENTLOOP_BOARD_TOOLS",
        ].map(tomlString).joined(separator: ",")
        let enabled = input.toolNames.map(tomlString).joined(separator: ",")
        return "mcp_servers={ranchboard={command="
            + tomlString(input.bridgeExecutableAuthority.stagedPath)
            + ",args=[\"--board-server\"],env_vars=[\(envNames)]"
            + ",required=true,enabled_tools=[\(enabled)]"
            + ",default_tools_approval_mode=\"approve\"}}"
    }

    private func tomlString(_ value: String) -> String {
        var result = "\""
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x08:
                result += "\\b"
            case 0x09:
                result += "\\t"
            case 0x0A:
                result += "\\n"
            case 0x0C:
                result += "\\f"
            case 0x0D:
                result += "\\r"
            case 0x22:
                result += "\\\""
            case 0x5C:
                result += "\\\\"
            case 0x00...0x1F, 0x7F:
                result += String(format: "\\u%04X", scalar.value)
            default:
                result.unicodeScalars.append(scalar)
            }
        }
        result += "\""
        return result
    }

    private func writeClaudeConfiguration(
        _ data: Data,
        to url: URL
    ) throws -> CliCleanupFileAuthorityV1 {
        guard url.isFileURL,
              url.baseURL == nil,
              url.path.hasPrefix("/"),
              url.standardizedFileURL.path == url.path,
              !url.lastPathComponent.isEmpty,
              !url.lastPathComponent.contains("/"),
              url.deletingLastPathComponent().path != "/"
        else {
            throw EngineContextValidationErrorV1()
        }
        let parent = url.deletingLastPathComponent().path.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard parent >= 0 else {
            throw EngineContextValidationErrorV1()
        }
        var parentOpen = true
        defer { if parentOpen { _ = Darwin.close(parent) } }
        var parentInfo = stat()
        guard Darwin.fstat(parent, &parentInfo) == 0,
              parentInfo.st_mode & S_IFMT == S_IFDIR,
              parentInfo.st_uid == getuid()
        else {
            throw EngineContextValidationErrorV1()
        }
        let basename = url.lastPathComponent
        let descriptor = basename.withCString { name in
            Darwin.openat(
                parent,
                name,
                O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC | O_NOFOLLOW,
                mode_t(0o600)
            )
        }
        guard descriptor >= 0 else {
            throw EngineContextValidationErrorV1()
        }

        var descriptorOpen = true
        var createdInfo = stat()
        var completedAuthority: CliCleanupFileAuthorityV1?
        do {
            guard Darwin.fstat(descriptor, &createdInfo) == 0,
                  createdInfo.st_mode & S_IFMT == S_IFREG,
                  createdInfo.st_uid == getuid(),
                  createdInfo.st_nlink == 1,
                  Darwin.fchmod(descriptor, mode_t(0o600)) == 0,
                  Darwin.fstat(descriptor, &createdInfo) == 0,
                  createdInfo.st_mode & mode_t(0o777) == mode_t(0o600)
            else {
                throw EngineContextValidationErrorV1()
            }
            try writeAll(data, descriptor: descriptor)
            guard Darwin.fsync(descriptor) == 0,
                  Darwin.close(descriptor) == 0
            else {
                descriptorOpen = false
                throw EngineContextValidationErrorV1()
            }
            descriptorOpen = false
            var current = stat()
            guard basename.withCString({
                Darwin.fstatat(parent, $0, &current, AT_SYMLINK_NOFOLLOW)
            }) == 0,
                  current.st_dev == createdInfo.st_dev,
                  current.st_ino == createdInfo.st_ino,
                  current.st_uid == getuid(),
                  current.st_nlink == 1,
                  current.st_mode & S_IFMT == S_IFREG,
                  current.st_mode & mode_t(0o777) == mode_t(0o600),
                  Darwin.fsync(parent) == 0
            else {
                throw EngineContextValidationErrorV1()
            }
            let authority = try CliCleanupFileAuthorityV1(
                fileURL: url,
                parentDevice: UInt64(parentInfo.st_dev),
                parentInode: UInt64(parentInfo.st_ino),
                parentUID: UInt32(parentInfo.st_uid),
                basename: basename,
                fileDevice: UInt64(current.st_dev),
                fileInode: UInt64(current.st_ino),
                fileUID: UInt32(current.st_uid),
                fileMode: UInt16(current.st_mode & mode_t(0o777)),
                fileLinkCount: UInt64(current.st_nlink)
            )
            completedAuthority = authority
            guard Darwin.close(parent) == 0 else {
                parentOpen = false
                throw EngineContextValidationErrorV1()
            }
            parentOpen = false
            return authority
        } catch {
            let original = error
            if !parentOpen, let completedAuthority {
                do {
                    try completedAuthority.removeExpectedFile()
                } catch {
                    throw EngineContextValidationErrorV1()
                }
                throw original
            }
            if createdInfo.st_dev == 0, descriptorOpen {
                guard Darwin.fstat(descriptor, &createdInfo) == 0 else {
                    throw EngineContextValidationErrorV1()
                }
            }
            if descriptorOpen, Darwin.close(descriptor) != 0 {
                descriptorOpen = false
                throw EngineContextValidationErrorV1()
            }
            descriptorOpen = false
            var current = stat()
            guard basename.withCString({
                Darwin.fstatat(parent, $0, &current, AT_SYMLINK_NOFOLLOW)
            }) == 0,
                  current.st_dev == createdInfo.st_dev,
                  current.st_ino == createdInfo.st_ino,
                  current.st_uid == getuid(),
                  current.st_nlink == 1,
                  basename.withCString({ Darwin.unlinkat(parent, $0, 0) }) == 0,
                  Darwin.fsync(parent) == 0
            else {
                throw EngineContextValidationErrorV1()
            }
            guard Darwin.close(parent) == 0 else {
                parentOpen = false
                throw EngineContextValidationErrorV1()
            }
            parentOpen = false
            throw original
        }
    }

    private func writeAll(_ data: Data, descriptor: Int32) throws {
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let written = Darwin.write(
                    descriptor,
                    bytes.baseAddress?.advanced(by: offset),
                    bytes.count - offset
                )
                if written < 0, errno == EINTR { continue }
                guard written > 0 else {
                    throw EngineContextValidationErrorV1()
                }
                offset += written
            }
        }
    }
}

package enum CliEnginePromptV1 {
    package static func render(
        _ context: EngineResolvedContextTransportV1
    ) throws -> String {
        guard context.packet.firstUserMessage.role == .user else {
            throw EngineContextValidationErrorV1()
        }
        var userText: [String] = []
        for block in context.packet.firstUserMessage.content {
            guard case let .text(text) = block else {
                throw EngineContextValidationErrorV1()
            }
            userText.append(text)
        }
        guard !userText.isEmpty else {
            throw EngineContextValidationErrorV1()
        }
        return context.packet.system
            + "\n\n"
            + userText.joined(separator: "\n")
    }

    package static func validateCodex(_ prompt: String) throws {
        let pattern = #"(^|[^A-Za-z0-9_])\$[A-Za-z0-9][A-Za-z0-9_-]{0,63}($|[^A-Za-z0-9_-])"#
        guard prompt.range(of: pattern, options: .regularExpression) == nil
        else {
            throw EngineContextValidationErrorV1()
        }
    }
}

package struct CliHelpSnapshotV1: Sendable, Equatable {
    package let executableAuthority: CliExecutableAuthorityV1
    package let versionLine: String
    package let rootExitStatus: Int32
    package let rootStdoutHash: String
    package let firstExitStatus: Int32
    package let firstStdoutHash: String
    package let resumeExitStatus: Int32
    package let resumeStdoutHash: String
    package let rootFlags: [String]
    package let firstFlags: [String]
    package let resumeFlags: [String]
    package let subcommands: [String]

    package var kind: RuntimeProfileKind { executableAuthority.kind }
    package var command: String { executableAuthority.command }

    package init(
        executableAuthority: CliExecutableAuthorityV1,
        versionLine: String,
        rootExitStatus: Int32,
        rootStdoutHash: String,
        firstExitStatus: Int32,
        firstStdoutHash: String,
        resumeExitStatus: Int32,
        resumeStdoutHash: String,
        rootFlags: [String],
        firstFlags: [String],
        resumeFlags: [String],
        subcommands: [String]
    ) throws {
        try executableAuthority.validateCanonical()
        guard !versionLine.isEmpty,
              !versionLine.utf8.contains(0),
              rootFlags == Array(Set(rootFlags)).sorted(),
              firstFlags == Array(Set(firstFlags)).sorted(),
              resumeFlags == Array(Set(resumeFlags)).sorted(),
              subcommands == Array(Set(subcommands)).sorted()
        else {
            throw EngineContextValidationErrorV1()
        }
        try CanonicalContractCodingV1.validateLowercaseHash(rootStdoutHash)
        try CanonicalContractCodingV1.validateLowercaseHash(firstStdoutHash)
        try CanonicalContractCodingV1.validateLowercaseHash(resumeStdoutHash)
        self.executableAuthority = executableAuthority
        self.versionLine = versionLine
        self.rootExitStatus = rootExitStatus
        self.rootStdoutHash = rootStdoutHash
        self.firstExitStatus = firstExitStatus
        self.firstStdoutHash = firstStdoutHash
        self.resumeExitStatus = resumeExitStatus
        self.resumeStdoutHash = resumeStdoutHash
        self.rootFlags = rootFlags
        self.firstFlags = firstFlags
        self.resumeFlags = resumeFlags
        self.subcommands = subcommands
    }
}

package struct CliHelpProbeRunResultV1: Sendable {
    package let status: Int32
    package let stdout: Data

    package init(status: Int32, stdout: Data) {
        self.status = status
        self.stdout = stdout
    }
}

package struct CliHelpProbeV1: Sendable {
    package typealias SynchronousRunner = @Sendable (
        CliExecutableAuthorityV1, [String]
    ) throws -> CliHelpProbeRunResultV1

    private static let maximumStdoutBytes = 256 * 1_024
    private static let deadline: Duration = .seconds(5)
    private static let terminationGrace: Duration = .seconds(1)
    private let processInspector: any EngineRuntimeProcessInspectingV1
    private let injectedRunner: SynchronousRunner?

    package init(
        processInspector: any EngineRuntimeProcessInspectingV1
    ) {
        self.processInspector = processInspector
        injectedRunner = nil
    }

    package init(
        processInspector: any EngineRuntimeProcessInspectingV1,
        synchronousRunner: @escaping SynchronousRunner
    ) {
        self.processInspector = processInspector
        injectedRunner = synchronousRunner
    }

    package func snapshot(
        for kind: RuntimeProfileKind,
        authority: CliExecutableAuthorityV1
    ) async throws -> CliHelpSnapshotV1 {
        let operation = BlockingProcessOperation.start { [self] in
            Result<CliHelpSnapshotV1, any Error> {
                try snapshotSynchronously(
                    for: kind,
                    authority: authority
                )
            }
        }
        let result = await operation.value
        return try result.get()
    }

    private func snapshotSynchronously(
        for kind: RuntimeProfileKind,
        authority: CliExecutableAuthorityV1
    ) throws -> CliHelpSnapshotV1 {
        do {
            try authority.validateCanonical()
        } catch {
            throw CliHelpProbeFailureV1.invalidAuthority
        }
        guard kind == authority.kind else {
            throw CliHelpProbeFailureV1.invalidAuthority
        }
        do {
            try Self.validateStagedAuthority(authority)
        } catch {
            throw CliHelpProbeFailureV1.stagedIdentity
        }
        let version = try runSynchronously(
            authority,
            arguments: ["--version"]
        )
        let root = try runSynchronously(authority, arguments: ["--help"])
        let first: ProbeResult
        let resume: ProbeResult
        switch kind {
        case .cliCodex:
            first = try runSynchronously(
                authority, arguments: ["exec", "--help"]
            )
            resume = try runSynchronously(
                authority,
                arguments: ["exec", "resume", "--help"]
            )
        case .cliClaude:
            first = root
            resume = root
        case .anthropicAPI, .openAIAPI, .chatGPTOAuth:
            throw CliHelpProbeFailureV1.invalidAuthority
        }
        guard version.status == 0,
              root.status == 0,
              first.status == 0,
              resume.status == 0
        else {
            throw CliHelpProbeFailureV1.exitStatus
        }
        let versionLine = String(decoding: version.stdout, as: UTF8.self)
            .trimmingCharacters(in: .newlines)
        guard (kind == .cliCodex && versionLine == "codex-cli 0.144.5")
                || (kind == .cliClaude
                    && versionLine == "2.1.81 (Claude Code)")
        else {
            throw CliHelpProbeFailureV1.unsupportedVersion
        }
        let rootTokens = standaloneTokens(root.stdout)
        let firstTokens = standaloneTokens(first.stdout)
        let resumeTokens = standaloneTokens(resume.stdout)
        let subcommands: [String]
        if kind == .cliCodex,
           firstTokens.contains("resume") || resumeTokens.contains("resume")
        {
            subcommands = ["resume"]
        } else {
            subcommands = []
        }
        return try CliHelpSnapshotV1(
            executableAuthority: authority,
            versionLine: versionLine,
            rootExitStatus: root.status,
            rootStdoutHash: CanonicalJSONV1.sha256Hex(root.stdout),
            firstExitStatus: first.status,
            firstStdoutHash: CanonicalJSONV1.sha256Hex(first.stdout),
            resumeExitStatus: resume.status,
            resumeStdoutHash: CanonicalJSONV1.sha256Hex(resume.stdout),
            rootFlags: standaloneFlags(rootTokens),
            firstFlags: standaloneFlags(firstTokens),
            resumeFlags: standaloneFlags(resumeTokens),
            subcommands: subcommands
        )
    }

    private struct ProbeResult {
        let status: Int32
        let stdout: Data
    }

    private func runSynchronously(
        _ authority: CliExecutableAuthorityV1,
        arguments: [String]
    ) throws -> ProbeResult {
        guard let injectedRunner else {
            return try run(authority, arguments: arguments)
        }
        let result = try injectedRunner(authority, arguments)
        return ProbeResult(status: result.status, stdout: result.stdout)
    }

    package func identifyAndStage(
        for kind: RuntimeProfileKind,
        command: String,
        stagingDirectory: URL
    ) throws -> CliExecutableAuthorityV1 {
        guard (kind == .cliCodex && command == "codex")
                || (kind == .cliClaude && command == "claude")
        else {
            throw CliHelpProbeFailureV1.sourceIdentity
        }
        let commandSource: String
        let commandSourceIdentity: CliExecutableIdentityV1.FileIdentity
        do {
            commandSource = try CliExecutableIdentityV1.resolveCommand(
                command
            )
            commandSourceIdentity = try CliExecutableIdentityV1.fileIdentity(
                commandSource,
                requireExecutable: true
            )
        } catch {
            throw CliHelpProbeFailureV1.sourceIdentity
        }
        let resolvedExecutable: String
        do {
            if try CliExecutableIdentityV1.isMachO(commandSource) {
                resolvedExecutable = commandSource
            } else if kind == .cliCodex,
                      try CliExecutableIdentityV1.isOfficialCodexWrapper(
                          commandSource
                      )
            {
                resolvedExecutable = try CliExecutableIdentityV1
                    .codexNativeTarget(forWrapper: commandSource)
            } else {
                throw CliHelpProbeFailureV1.sourceIdentity
            }
        } catch let failure as CliHelpProbeFailureV1 {
            throw failure
        } catch {
            throw CliHelpProbeFailureV1.sourceIdentity
        }
        let sourceExecutableIdentity: CliExecutableIdentityV1.FileIdentity
        do {
            sourceExecutableIdentity = try CliExecutableIdentityV1
                .fileIdentity(resolvedExecutable, requireExecutable: true)
        } catch {
            throw CliHelpProbeFailureV1.sourceIdentity
        }
        let signing: CliExecutableIdentityV1.SigningIdentity
        do {
            signing = try CliExecutableIdentityV1.vendorSigningIdentity(
                path: resolvedExecutable,
                kind: kind
            )
        } catch {
            throw CliHelpProbeFailureV1.signatureIdentity
        }
        let staged: CliExecutableIdentityV1.FileIdentity
        do {
            staged = try CliExecutableIdentityV1.stageExecutable(
                sourcePath: resolvedExecutable,
                stagingDirectory: stagingDirectory,
                childName: "\(kind.rawValue)-\(sourceExecutableIdentity.hash)"
            )
        } catch let failure as CliHelpProbeFailureV1 {
            throw failure
        } catch {
            throw CliHelpProbeFailureV1.stagedIdentity
        }
        do {
            let stagedSigning: CliExecutableIdentityV1.SigningIdentity
            do {
                stagedSigning = try CliExecutableIdentityV1
                    .vendorSigningIdentity(path: staged.path, kind: kind)
            } catch {
                throw CliHelpProbeFailureV1.signatureIdentity
            }
            let commandSourceAfter = try CliExecutableIdentityV1.fileIdentity(
                commandSource,
                requireExecutable: true
            )
            guard commandSourceAfter == commandSourceIdentity,
                  staged.hash == sourceExecutableIdentity.hash,
                  stagedSigning == signing
            else {
                throw CliHelpProbeFailureV1.stagedIdentity
            }
            guard let teamIdentifier = signing.teamIdentifier else {
                throw CliHelpProbeFailureV1.signatureIdentity
            }
            return try CliExecutableAuthorityV1(
                kind: kind,
                command: command,
                commandSourcePath: commandSource,
                commandSourceHash: commandSourceIdentity.hash,
                resolvedExecutablePath: resolvedExecutable,
                stagedPath: staged.path,
                executableHash: staged.hash,
                designatedRequirement: signing.designatedRequirement,
                teamIdentifier: teamIdentifier,
                cdHash: signing.cdHash,
                stagedDevice: staged.device,
                stagedInode: staged.inode
            )
        } catch {
            let original = error
            do {
                try CliExecutableIdentityV1.removeStagedFile(staged)
            } catch {
                throw CliHelpProbeFailureV1.cleanup
            }
            if let failure = original as? CliHelpProbeFailureV1 {
                throw failure
            }
            throw CliHelpProbeFailureV1.stagedIdentity
        }
    }

    package func identifyAndStageBoardBridge(
        sourcePath: String,
        stagingDirectory: URL
    ) throws -> EngineBoardBridgeExecutableAuthorityV1 {
        let canonicalSource = try CliExecutableIdentityV1.canonicalPath(
            sourcePath
        )
        let source = try CliExecutableIdentityV1.fileIdentity(
            canonicalSource,
            requireExecutable: true
        )
        let signing = try CliExecutableIdentityV1.bridgeSigningIdentity(
            path: canonicalSource
        )
        let staged = try CliExecutableIdentityV1.stageExecutable(
            sourcePath: canonicalSource,
            stagingDirectory: stagingDirectory,
            childName: "board-bridge-\(source.hash)"
        )
        do {
            let stagedSigning = try CliExecutableIdentityV1
                .bridgeSigningIdentity(path: staged.path)
            guard staged.hash == source.hash,
                  stagedSigning == signing
            else {
                throw EngineContextValidationErrorV1()
            }
            return try EngineBoardBridgeExecutableAuthorityV1(
                sourcePath: canonicalSource,
                stagedPath: staged.path,
                executableHash: staged.hash,
                designatedRequirement: signing.designatedRequirement,
                teamIdentifier: signing.teamIdentifier,
                cdHash: signing.cdHash,
                stagedDevice: staged.device,
                stagedInode: staged.inode
            )
        } catch {
            let original = error
            do {
                try CliExecutableIdentityV1.removeStagedFile(staged)
            } catch {
                throw CliHelpProbeFailureV1.cleanup
            }
            throw original
        }
    }

    package func removeStagedAuthority(
        _ authority: CliExecutableAuthorityV1
    ) throws {
        do {
            try authority.validateCanonical()
            try Self.validateStagedAuthority(authority)
        } catch {
            throw CliHelpProbeFailureV1.stagedIdentity
        }
        let expected = CliExecutableIdentityV1.FileIdentity(
            path: authority.stagedPath,
            hash: authority.executableHash,
            device: authority.stagedDevice,
            inode: authority.stagedInode,
            size: 0,
            modifiedSeconds: 0,
            modifiedNanoseconds: 0
        )
        do {
            try CliExecutableIdentityV1.removeStagedFile(expected)
        } catch {
            throw CliHelpProbeFailureV1.cleanup
        }
    }

    private func run(
        _ authority: CliExecutableAuthorityV1,
        arguments: [String]
    ) throws -> ProbeResult {
        do {
            try Self.validateStagedAuthority(authority)
        } catch {
            throw CliHelpProbeFailureV1.stagedIdentity
        }
        var stdoutRead: Int32 = -1
        var stdoutWrite: Int32 = -1
        var stderrRead: Int32 = -1
        var stderrWrite: Int32 = -1
        var nullInput: Int32 = -1
        var pid: pid_t = 0
        var processGroupId: pid_t = 0
        var spawned = false

        do {
            (stdoutRead, stdoutWrite) = try Self.makeProbePipe()
            (stderrRead, stderrWrite) = try Self.makeProbePipe()
            nullInput = Darwin.open("/dev/null", O_RDONLY | O_CLOEXEC)
            guard nullInput >= 0 else {
                throw EngineContextValidationErrorV1()
            }
            try CliAuxiliaryDescriptorV1.normalizeOwned(&stdoutRead)
            try CliAuxiliaryDescriptorV1.normalizeOwned(&stdoutWrite)
            try CliAuxiliaryDescriptorV1.normalizeOwned(&stderrRead)
            try CliAuxiliaryDescriptorV1.normalizeOwned(&stderrWrite)
            try CliAuxiliaryDescriptorV1.normalizeOwned(&nullInput)

            var fileActions: posix_spawn_file_actions_t?
            var code = posix_spawn_file_actions_init(&fileActions)
            guard code == 0 else {
                throw EngineContextValidationErrorV1()
            }
            defer { posix_spawn_file_actions_destroy(&fileActions) }
            for result in [
                posix_spawn_file_actions_adddup2(
                    &fileActions,
                    nullInput,
                    STDIN_FILENO
                ),
                posix_spawn_file_actions_adddup2(
                    &fileActions,
                    stdoutWrite,
                    STDOUT_FILENO
                ),
                posix_spawn_file_actions_adddup2(
                    &fileActions,
                    stderrWrite,
                    STDERR_FILENO
                ),
            ] {
                guard result == 0 else {
                    throw EngineContextValidationErrorV1()
                }
            }
            for descriptor in [
                nullInput, stdoutRead, stdoutWrite, stderrRead, stderrWrite,
            ] {
                guard posix_spawn_file_actions_addclose(
                    &fileActions,
                    descriptor
                ) == 0 else {
                    throw EngineContextValidationErrorV1()
                }
            }

            var attributes: posix_spawnattr_t?
            code = posix_spawnattr_init(&attributes)
            guard code == 0 else {
                throw EngineContextValidationErrorV1()
            }
            defer { posix_spawnattr_destroy(&attributes) }
            guard posix_spawnattr_setflags(
                &attributes,
                Int16(
                    POSIX_SPAWN_SETPGROUP
                        | POSIX_SPAWN_CLOEXEC_DEFAULT
                        | POSIX_SPAWN_START_SUSPENDED
                )
            ) == 0,
                posix_spawnattr_setpgroup(&attributes, 0) == 0
            else {
                throw EngineContextValidationErrorV1()
            }

            var argv = try Self.makeCStringVector(
                [authority.stagedPath] + arguments
            )
            defer { Self.freeCStringVector(argv) }
            code = authority.stagedPath.withCString { path in
                argv.withUnsafeMutableBufferPointer { buffer in
                    posix_spawn(
                        &pid,
                        path,
                        &fileActions,
                        &attributes,
                        buffer.baseAddress,
                        environ
                    )
                }
            }
            guard code == 0 else {
                throw EngineContextValidationErrorV1()
            }
            spawned = true
            processGroupId = pid
            try Self.checkedClose(&nullInput)
            try Self.checkedClose(&stdoutWrite)
            try Self.checkedClose(&stderrWrite)
            try Self.setProbeNonblocking(stdoutRead)
            try Self.setProbeNonblocking(stderrRead)

            let image = try processInspector.snapshots().first {
                $0.pid == pid
            }
            guard let image,
                  image.pid == pid,
                  image.processGroupId == pid,
                  image.uid == getuid(),
                  image.startSeconds > 0,
                  image.executablePath == authority.stagedPath,
                  image.executableDevice == authority.stagedDevice,
                  image.executableInode == authority.stagedInode,
                  image.executableHash == authority.executableHash,
                  image.designatedRequirement
                    == authority.designatedRequirement,
                  image.cdHash == authority.cdHash
            else {
                throw CliHelpProbeFailureV1.processImageIdentity
            }
            try processInspector.send(
                signal: SIGCONT,
                processGroupId: processGroupId
            )
            let result = try collectProbe(
                pid: pid,
                processGroupId: processGroupId,
                stdoutRead: stdoutRead,
                stderrRead: stderrRead
            )
            stdoutRead = -1
            stderrRead = -1
            spawned = false
            return result
        } catch {
            let primary = error
            var cleanupFailures: [CliHelpProbeProcessCleanupSourceV1] = []
            if spawned {
                do {
                    try terminateProbe(
                        pid: pid,
                        processGroupId: processGroupId
                    )
                } catch {
                    cleanupFailures.append(.terminate)
                }
            }
            for (source, descriptor) in [
                (CliHelpProbeProcessCleanupSourceV1.stdinClose, nullInput),
                (.stdoutReadClose, stdoutRead),
                (.stdoutWriteClose, stdoutWrite),
                (.stderrReadClose, stderrRead),
                (.stderrWriteClose, stderrWrite),
            ] where descriptor >= 0 {
                if Darwin.close(descriptor) != 0 {
                    cleanupFailures.append(source)
                }
            }
            if !cleanupFailures.isEmpty {
                throw CliHelpProbeFailureV1.processCleanup(cleanupFailures)
            }
            if let failure = primary as? CliHelpProbeFailureV1 {
                throw failure
            }
            throw CliHelpProbeFailureV1.mechanics
        }
    }

    private func collectProbe(
        pid: pid_t,
        processGroupId: pid_t,
        stdoutRead: Int32,
        stderrRead: Int32
    ) throws -> ProbeResult {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: Self.deadline)
        var stdout = Data()
        var sawStderr = false
        var stdoutEOF = false
        var stderrEOF = false
        var rawStatus: Int32 = 0
        var reaped = false
        var readBuffer = [UInt8](repeating: 0, count: 16 * 1_024)

        func drain(
            _ descriptor: Int32,
            capture: Bool,
            eof: inout Bool
        ) throws {
            while !eof {
                let count = readBuffer.withUnsafeMutableBytes {
                    Darwin.read(descriptor, $0.baseAddress, $0.count)
                }
                if count > 0 {
                    if capture {
                        guard stdout.count + count
                                <= Self.maximumStdoutBytes
                        else {
                            throw CliHelpProbeFailureV1.stdoutLimit
                        }
                        stdout.append(contentsOf: readBuffer[0..<count])
                    } else {
                        sawStderr = true
                    }
                    guard clock.now < deadline else {
                        throw CliHelpProbeFailureV1.deadline
                    }
                    continue
                }
                if count == 0 {
                    eof = true
                    return
                }
                if errno == EINTR { continue }
                if errno == EAGAIN || errno == EWOULDBLOCK { return }
                throw EngineContextValidationErrorV1()
            }
        }

        while !reaped || !stdoutEOF || !stderrEOF {
            guard clock.now < deadline else {
                throw CliHelpProbeFailureV1.deadline
            }
            var descriptors = [
                pollfd(
                    fd: stdoutRead,
                    events: Int16(POLLIN | POLLHUP),
                    revents: 0
                ),
                pollfd(
                    fd: stderrRead,
                    events: Int16(POLLIN | POLLHUP),
                    revents: 0
                ),
            ]
            let pollResult = descriptors.withUnsafeMutableBufferPointer {
                Darwin.poll($0.baseAddress, nfds_t($0.count), 25)
            }
            if pollResult < 0, errno == EINTR { continue }
            guard pollResult >= 0 else {
                throw EngineContextValidationErrorV1()
            }
            try drain(stdoutRead, capture: true, eof: &stdoutEOF)
            try drain(stderrRead, capture: false, eof: &stderrEOF)
            if !reaped {
                let waitResult = waitpid(pid, &rawStatus, WNOHANG)
                if waitResult == pid {
                    reaped = true
                } else if waitResult < 0, errno != EINTR {
                    throw EngineContextValidationErrorV1()
                }
            }
        }
        guard !sawStderr,
              !(try processInspector.processGroupExists(processGroupId))
        else {
            throw EngineContextValidationErrorV1()
        }
        var stdoutDescriptor = stdoutRead
        var stderrDescriptor = stderrRead
        try Self.checkedClose(&stdoutDescriptor)
        try Self.checkedClose(&stderrDescriptor)
        return ProbeResult(
            status: Self.decodeWaitStatus(rawStatus),
            stdout: stdout
        )
    }

    private func terminateProbe(
        pid: pid_t,
        processGroupId: pid_t
    ) throws {
        if try processInspector.processGroupExists(processGroupId) {
            try processInspector.send(
                signal: SIGTERM,
                processGroupId: processGroupId
            )
        }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: Self.terminationGrace)
        while clock.now < deadline,
              try processInspector.processGroupExists(processGroupId)
        {
            usleep(10_000)
        }
        if try processInspector.processGroupExists(processGroupId) {
            try processInspector.send(
                signal: SIGKILL,
                processGroupId: processGroupId
            )
        }
        var status: Int32 = 0
        while waitpid(pid, &status, 0) < 0 {
            if errno == EINTR { continue }
            if errno == ECHILD { break }
            throw EngineContextValidationErrorV1()
        }
        let absenceDeadline = clock.now.advanced(by: Self.terminationGrace)
        while clock.now < absenceDeadline,
              try processInspector.processGroupExists(processGroupId)
        {
            usleep(10_000)
        }
        guard !(try processInspector.processGroupExists(processGroupId)) else {
            throw EngineContextValidationErrorV1()
        }
    }

    private static func validateStagedAuthority(
        _ authority: CliExecutableAuthorityV1
    ) throws {
        let current = try CliExecutableIdentityV1.fileIdentity(
            authority.stagedPath,
            requireExecutable: true
        )
        guard current.device == authority.stagedDevice,
              current.inode == authority.stagedInode,
              current.hash == authority.executableHash
        else {
            throw EngineContextValidationErrorV1()
        }
    }

    private static func makeProbePipe() throws -> (Int32, Int32) {
        var descriptors = [Int32](repeating: -1, count: 2)
        guard descriptors.withUnsafeMutableBufferPointer({
            Darwin.pipe($0.baseAddress!)
        }) == 0,
            fcntl(descriptors[0], F_SETFD, FD_CLOEXEC) == 0,
            fcntl(descriptors[1], F_SETFD, FD_CLOEXEC) == 0
        else {
            if descriptors[0] >= 0 { _ = Darwin.close(descriptors[0]) }
            if descriptors[1] >= 0 { _ = Darwin.close(descriptors[1]) }
            throw EngineContextValidationErrorV1()
        }
        return (descriptors[0], descriptors[1])
    }

    private static func setProbeNonblocking(_ descriptor: Int32) throws {
        let flags = fcntl(descriptor, F_GETFL)
        guard flags >= 0,
              fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0
        else {
            throw EngineContextValidationErrorV1()
        }
    }

    private static func checkedClose(_ descriptor: inout Int32) throws {
        guard descriptor >= 0 else { return }
        let value = descriptor
        descriptor = -1
        guard Darwin.close(value) == 0 else {
            throw EngineContextValidationErrorV1()
        }
    }

    private static func makeCStringVector(
        _ strings: [String]
    ) throws -> [UnsafeMutablePointer<CChar>?] {
        var result: [UnsafeMutablePointer<CChar>?] = []
        for string in strings {
            guard !string.utf8.contains(0),
                  let pointer = strdup(string)
            else {
                freeCStringVector(result)
                throw EngineContextValidationErrorV1()
            }
            result.append(pointer)
        }
        result.append(nil)
        return result
    }

    private static func freeCStringVector(
        _ vector: [UnsafeMutablePointer<CChar>?]
    ) {
        for case let pointer? in vector { free(pointer) }
    }

    private static func decodeWaitStatus(_ raw: Int32) -> Int32 {
        let signal = raw & 0x7f
        return signal == 0 ? (raw >> 8) & 0xff : 128 + signal
    }

    private func standaloneTokens(_ data: Data) -> [String] {
        String(decoding: data, as: UTF8.self)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    private func standaloneFlags(_ tokens: [String]) -> [String] {
        Array(Set(tokens.filter(isStandaloneFlag))).sorted()
    }

    private func isStandaloneFlag(_ token: String) -> Bool {
        let bytes = Array(token.utf8)
        guard bytes.count >= 2, bytes[0] == UInt8(ascii: "-") else {
            return false
        }
        let start: Int
        if bytes[1] == UInt8(ascii: "-") {
            guard bytes.count >= 3 else { return false }
            start = 2
        } else {
            start = 1
        }
        guard isAlphaNumeric(bytes[start]) else { return false }
        return bytes[start...].allSatisfy { byte in
            isAlphaNumeric(byte) || byte == UInt8(ascii: "-")
        }
    }

    private func isAlphaNumeric(_ byte: UInt8) -> Bool {
        (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
            || (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte)
            || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
    }
}

private enum CliExecutableIdentityV1 {
    struct FileIdentity: Equatable {
        let path: String
        let hash: String
        let device: UInt64
        let inode: UInt64
        let size: Int64
        let modifiedSeconds: Int64
        let modifiedNanoseconds: Int64
    }

    struct SigningIdentity: Equatable {
        let designatedRequirement: String
        let teamIdentifier: String?
        let cdHash: String
    }

    static func canonicalPath(_ path: String) throws -> String {
        guard path.hasPrefix("/"), !path.utf8.contains(0) else {
            throw EngineContextValidationErrorV1()
        }
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard path.withCString({ source in
            realpath(source, &buffer)
        }) != nil else {
            throw EngineContextValidationErrorV1()
        }
        let result = String(
            decoding: buffer.prefix { $0 != 0 }
                .map { UInt8(bitPattern: $0) },
            as: UTF8.self
        )
        guard CliExecutableAuthorityV1.isCanonicalAbsolutePath(result) else {
            throw EngineContextValidationErrorV1()
        }
        return result
    }

    static func resolveCommand(_ command: String) throws -> String {
        guard !command.isEmpty,
              !command.utf8.contains(0)
        else {
            throw EngineContextValidationErrorV1()
        }
        if command.contains("/") {
            return try canonicalPath(command)
        }
        guard let path = ProcessInfo.processInfo.environment["PATH"] else {
            throw EngineContextValidationErrorV1()
        }
        for component in path.split(
            separator: ":",
            omittingEmptySubsequences: false
        ) {
            guard !component.isEmpty else { continue }
            let candidate = URL(
                fileURLWithPath: String(component),
                isDirectory: true
            ).appendingPathComponent(command).path
            if candidate.withCString({ access($0, X_OK) }) == 0 {
                return try canonicalPath(candidate)
            }
        }
        throw EngineContextValidationErrorV1()
    }

    static func fileIdentity(
        _ path: String,
        requireExecutable: Bool
    ) throws -> FileIdentity {
        guard CliExecutableAuthorityV1.isCanonicalAbsolutePath(path) else {
            throw EngineContextValidationErrorV1()
        }
        let descriptor = path.withCString {
            Darwin.open($0, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard descriptor >= 0 else {
            throw EngineContextValidationErrorV1()
        }
        var descriptorOpen = true
        defer { if descriptorOpen { Darwin.close(descriptor) } }
        let identity = try fileIdentity(
            descriptor: descriptor,
            path: path,
            requireExecutable: requireExecutable
        )
        guard Darwin.close(descriptor) == 0 else {
            descriptorOpen = false
            throw EngineContextValidationErrorV1()
        }
        descriptorOpen = false
        return identity
    }

    static func fileIdentity(
        descriptor: Int32,
        path: String,
        requireExecutable: Bool
    ) throws -> FileIdentity {
        var before = stat()
        guard Darwin.fstat(descriptor, &before) == 0,
              before.st_mode & S_IFMT == S_IFREG,
              before.st_nlink == 1,
              before.st_uid == getuid(),
              !requireExecutable || before.st_mode & S_IXUSR != 0
        else {
            throw EngineContextValidationErrorV1()
        }
        var hasher = SHA256()
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
        var total: Int64 = 0
        while true {
            let count = buffer.withUnsafeMutableBytes {
                Darwin.read(descriptor, $0.baseAddress, $0.count)
            }
            if count > 0 {
                hasher.update(data: Data(buffer[0..<count]))
                total += Int64(count)
                continue
            }
            if count == 0 { break }
            if errno == EINTR { continue }
            throw EngineContextValidationErrorV1()
        }
        var after = stat()
        guard Darwin.fstat(descriptor, &after) == 0,
              Self.sameStableFile(before, after),
              total == before.st_size
        else {
            throw EngineContextValidationErrorV1()
        }
        return FileIdentity(
            path: path,
            hash: hasher.finalize().map {
                String(format: "%02x", $0)
            }.joined(),
            device: UInt64(before.st_dev),
            inode: UInt64(before.st_ino),
            size: before.st_size,
            modifiedSeconds: Int64(before.st_mtimespec.tv_sec),
            modifiedNanoseconds: Int64(before.st_mtimespec.tv_nsec)
        )
    }

    static func isMachO(_ path: String) throws -> Bool {
        let bytes = try readPrefix(path, count: 4)
        guard bytes.count == 4 else { return false }
        let value = bytes.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }
        return [
            UInt32(MH_MAGIC), UInt32(MH_CIGAM), UInt32(MH_MAGIC_64),
            UInt32(MH_CIGAM_64), UInt32(FAT_MAGIC), UInt32(FAT_CIGAM),
        ].contains(value)
    }

    static func isOfficialCodexWrapper(_ path: String) throws -> Bool {
        guard path.hasSuffix("/@openai/codex/bin/codex.js") else {
            return false
        }
        let prefix = try readPrefix(path, count: 20)
        return prefix.starts(with: Data("#!/usr/bin/env node\n".utf8))
    }

    static func codexNativeTarget(forWrapper path: String) throws -> String {
        let packageRoot = URL(fileURLWithPath: path)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        #if arch(arm64)
        let package = "codex-darwin-arm64"
        let platform = "aarch64-apple-darwin"
        #elseif arch(x86_64)
        let package = "codex-darwin-x64"
        let platform = "x86_64-apple-darwin"
        #else
        throw EngineContextValidationErrorV1()
        #endif
        let candidate = packageRoot
            .appendingPathComponent("node_modules/@openai")
            .appendingPathComponent(package)
            .appendingPathComponent("vendor/\(platform)/bin/codex")
            .standardizedFileURL.path
        let canonical = try canonicalPath(candidate)
        guard canonical == candidate else {
            throw EngineContextValidationErrorV1()
        }
        return canonical
    }

    static func vendorSigningIdentity(
        path: String,
        kind: RuntimeProfileKind
    ) throws -> SigningIdentity {
        let identifier: String
        switch kind {
        case .cliCodex:
            identifier = "codex"
        case .cliClaude:
            identifier = "com.anthropic.claude-code"
        case .anthropicAPI, .openAIAPI, .chatGPTOAuth:
            throw EngineContextValidationErrorV1()
        }
        let team = CliExecutableAuthorityV1.expectedTeamIdentifier(for: kind)
        let requirement = "anchor apple generic and identifier "
            + "\"\(identifier)\" and certificate leaf[subject.OU] = "
            + "\"\(team)\""
        let result = try signingIdentity(
            path: path,
            validatingRequirement: requirement
        )
        guard result.teamIdentifier == team else {
            throw EngineContextValidationErrorV1()
        }
        return result
    }

    static func bridgeSigningIdentity(
        path: String
    ) throws -> SigningIdentity {
        try signingIdentity(
            path: path,
            validatingRequirement:
                "identifier \"com.muzi.agentloop.board-bridge\""
        )
    }

    static func stageExecutable(
        sourcePath: String,
        stagingDirectory: URL,
        childName: String
    ) throws -> FileIdentity {
        guard stagingDirectory.isFileURL,
              stagingDirectory.baseURL == nil,
              stagingDirectory.path.hasPrefix("/"),
              stagingDirectory.standardizedFileURL.path
                == stagingDirectory.path,
              !childName.isEmpty,
              !childName.contains("/"),
              !childName.utf8.contains(0)
        else {
            throw EngineContextValidationErrorV1()
        }
        var parent = stagingDirectory.path.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard parent >= 0 else {
            throw EngineContextValidationErrorV1()
        }
        var parentInfo = stat()
        var child: Int32 = -1
        var source: Int32 = -1
        var target: Int32 = -1
        var childInfo: stat?
        var targetInfo: stat?
        var createdDirectory = false
        let childPath = stagingDirectory
            .appendingPathComponent(childName, isDirectory: true).path
        let targetPath = URL(fileURLWithPath: childPath, isDirectory: true)
            .appendingPathComponent("executable").path
        do {
            guard Darwin.fstat(parent, &parentInfo) == 0,
                  parentInfo.st_mode & S_IFMT == S_IFDIR,
                  parentInfo.st_uid == getuid(),
                  childName.withCString({ mkdirat(parent, $0, 0o700) }) == 0
            else {
                throw EngineContextValidationErrorV1()
            }
            createdDirectory = true
            var createdChild = stat()
            guard childName.withCString({
                Darwin.fstatat(parent, $0, &createdChild, AT_SYMLINK_NOFOLLOW)
            }) == 0,
                  createdChild.st_mode & S_IFMT == S_IFDIR,
                  createdChild.st_uid == getuid(),
                  Darwin.fsync(parent) == 0
            else {
                throw EngineContextValidationErrorV1()
            }
            childInfo = createdChild
            child = childName.withCString {
                Darwin.openat(
                    parent,
                    $0,
                    O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
                )
            }
            var openedChild = stat()
            guard child >= 0,
                  Darwin.fstat(child, &openedChild) == 0,
                  sameEntry(createdChild, openedChild)
            else {
                throw EngineContextValidationErrorV1()
            }
            let sourceBefore = try fileIdentity(
                sourcePath,
                requireExecutable: true
            )
            source = sourcePath.withCString {
                Darwin.open($0, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
            }
            guard source >= 0 else {
                throw EngineContextValidationErrorV1()
            }
            target = "executable".withCString {
                Darwin.openat(
                    child,
                    $0,
                    O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC | O_NOFOLLOW,
                    mode_t(0o500)
                )
            }
            var createdTarget = stat()
            guard target >= 0,
                  Darwin.fstat(target, &createdTarget) == 0,
                  createdTarget.st_mode & S_IFMT == S_IFREG,
                  createdTarget.st_uid == getuid(),
                  createdTarget.st_nlink == 1
            else {
                throw EngineContextValidationErrorV1()
            }
            targetInfo = createdTarget
            var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
            while true {
                let count = buffer.withUnsafeMutableBytes {
                    Darwin.read(source, $0.baseAddress, $0.count)
                }
                if count == 0 { break }
                if count < 0, errno == EINTR { continue }
                guard count > 0 else {
                    throw EngineContextValidationErrorV1()
                }
                var offset = 0
                while offset < count {
                    let written = buffer.withUnsafeBytes {
                        Darwin.write(
                            target,
                            $0.baseAddress?.advanced(by: offset),
                            count - offset
                        )
                    }
                    if written < 0, errno == EINTR { continue }
                    guard written > 0 else {
                        throw EngineContextValidationErrorV1()
                    }
                    offset += written
                }
            }
            guard Darwin.fchmod(target, mode_t(0o500)) == 0,
                  Darwin.fsync(target) == 0
            else {
                throw EngineContextValidationErrorV1()
            }
            let sourceAfter = try fileIdentity(
                sourcePath,
                requireExecutable: true
            )
            let staged = try fileIdentity(
                targetPath,
                requireExecutable: true
            )
            var currentTarget = stat()
            guard sourceAfter == sourceBefore,
                  staged.hash == sourceBefore.hash,
                  staged.size == sourceBefore.size,
                  staged.device == UInt64(createdTarget.st_dev),
                  staged.inode == UInt64(createdTarget.st_ino),
                  "executable".withCString({
                      Darwin.fstatat(
                          child,
                          $0,
                          &currentTarget,
                          AT_SYMLINK_NOFOLLOW
                      )
                  }) == 0,
                  sameEntry(createdTarget, currentTarget),
                  currentTarget.st_mode & mode_t(0o777) == mode_t(0o500),
                  Darwin.fsync(child) == 0,
                  Darwin.fchmod(child, mode_t(0o500)) == 0,
                  Darwin.fsync(parent) == 0
            else {
                throw EngineContextValidationErrorV1()
            }
            try closeDescriptor(&target)
            try closeDescriptor(&source)
            try closeDescriptor(&child)
            try closeDescriptor(&parent)
            return staged
        } catch {
            let primary = error
            var cleanupFailed = false
            if createdDirectory {
                do {
                    try rollbackCreatedStage(
                        parentPath: stagingDirectory.path,
                        parentDescriptor: &parent,
                        expectedParent: parentInfo,
                        childDescriptor: &child,
                        childName: childName,
                        expectedChild: childInfo,
                        targetDescriptor: &target,
                        expectedTarget: targetInfo
                    )
                } catch {
                    cleanupFailed = true
                }
            }
            do { try closeDescriptor(&target) } catch {
                cleanupFailed = true
            }
            do { try closeDescriptor(&source) } catch {
                cleanupFailed = true
            }
            do { try closeDescriptor(&child) } catch {
                cleanupFailed = true
            }
            do { try closeDescriptor(&parent) } catch {
                cleanupFailed = true
            }
            if cleanupFailed { throw CliHelpProbeFailureV1.cleanup }
            throw primary
        }
    }

    static func removeStagedFile(_ expected: FileIdentity) throws {
        let stagedURL = URL(fileURLWithPath: expected.path)
        guard stagedURL.lastPathComponent == "executable",
              stagedURL.deletingLastPathComponent().path != "/"
        else {
            throw EngineContextValidationErrorV1()
        }
        let authorityDirectory = stagedURL.deletingLastPathComponent()
        let parentURL = authorityDirectory.deletingLastPathComponent()
        let parent = parentURL.path.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard parent >= 0 else {
            throw EngineContextValidationErrorV1()
        }
        var parentOpen = true
        defer { if parentOpen { _ = Darwin.close(parent) } }
        let childName = authorityDirectory.lastPathComponent
        let child = childName.withCString {
            Darwin.openat(
                parent,
                $0,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard child >= 0 else {
            throw EngineContextValidationErrorV1()
        }
        var childOpen = true
        defer { if childOpen { Darwin.close(child) } }
        var childInfo = stat()
        let target = "executable".withCString {
            Darwin.openat(child, $0, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard target >= 0 else {
            throw EngineContextValidationErrorV1()
        }
        var targetOpen = true
        defer { if targetOpen { _ = Darwin.close(target) } }
        let current = try fileIdentity(
            descriptor: target,
            path: expected.path,
            requireExecutable: true
        )
        var executableInfo = stat()
        guard Darwin.fstat(child, &childInfo) == 0,
              childInfo.st_mode & S_IFMT == S_IFDIR,
              childInfo.st_uid == getuid(),
              "executable".withCString({
                  fstatat(child, $0, &executableInfo, AT_SYMLINK_NOFOLLOW)
              }) == 0,
              executableInfo.st_mode & S_IFMT == S_IFREG,
              executableInfo.st_uid == getuid(),
              executableInfo.st_nlink == 1,
              executableInfo.st_mode & mode_t(0o777) == mode_t(0o500),
              current.device == expected.device,
              current.inode == expected.inode,
              current.hash == expected.hash,
              UInt64(executableInfo.st_dev) == expected.device,
              UInt64(executableInfo.st_ino) == expected.inode,
              Darwin.fchmod(child, mode_t(0o700)) == 0,
              "executable".withCString({ unlinkat(child, $0, 0) }) == 0,
              Darwin.fsync(child) == 0
        else {
            throw EngineContextValidationErrorV1()
        }
        guard Darwin.close(target) == 0 else {
            targetOpen = false
            throw EngineContextValidationErrorV1()
        }
        targetOpen = false
        guard Darwin.close(child) == 0 else {
            childOpen = false
            throw EngineContextValidationErrorV1()
        }
        childOpen = false
        var currentChild = stat()
        guard childName.withCString({
            Darwin.fstatat(parent, $0, &currentChild, AT_SYMLINK_NOFOLLOW)
        }) == 0,
            sameEntry(childInfo, currentChild),
            childName.withCString({
            unlinkat(parent, $0, AT_REMOVEDIR)
        }) == 0,
            Darwin.fsync(parent) == 0
        else {
            throw EngineContextValidationErrorV1()
        }
        guard Darwin.close(parent) == 0 else {
            parentOpen = false
            throw EngineContextValidationErrorV1()
        }
        parentOpen = false
    }

    private static func rollbackCreatedStage(
        parentPath: String,
        parentDescriptor: inout Int32,
        expectedParent: stat,
        childDescriptor: inout Int32,
        childName: String,
        expectedChild: stat?,
        targetDescriptor: inout Int32,
        expectedTarget: stat?
    ) throws {
        if parentDescriptor < 0 {
            parentDescriptor = parentPath.withCString {
                Darwin.open(
                    $0,
                    O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
                )
            }
        }
        var currentParent = stat()
        guard parentDescriptor >= 0,
              Darwin.fstat(parentDescriptor, &currentParent) == 0,
              sameEntry(expectedParent, currentParent)
        else {
            throw EngineContextValidationErrorV1()
        }
        if childDescriptor < 0 {
            childDescriptor = childName.withCString {
                Darwin.openat(
                    parentDescriptor,
                    $0,
                    O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
                )
            }
        }
        var currentChild = stat()
        let resolvedChild: stat
        if let expectedChild {
            resolvedChild = expectedChild
        } else {
            guard childDescriptor >= 0,
                  Darwin.fstat(childDescriptor, &currentChild) == 0,
                  currentChild.st_mode & S_IFMT == S_IFDIR,
                  currentChild.st_uid == getuid()
            else {
                throw EngineContextValidationErrorV1()
            }
            resolvedChild = currentChild
        }
        guard childDescriptor >= 0,
              Darwin.fstat(childDescriptor, &currentChild) == 0,
              sameEntry(resolvedChild, currentChild),
              Darwin.fchmod(childDescriptor, mode_t(0o700)) == 0
        else {
            throw EngineContextValidationErrorV1()
        }
        var resolvedTarget = expectedTarget
        if case nil = resolvedTarget, targetDescriptor >= 0 {
            var openedTarget = stat()
            guard Darwin.fstat(targetDescriptor, &openedTarget) == 0,
                  openedTarget.st_mode & S_IFMT == S_IFREG,
                  openedTarget.st_uid == getuid(),
                  openedTarget.st_nlink == 1
            else {
                throw EngineContextValidationErrorV1()
            }
            resolvedTarget = openedTarget
        }
        if let resolvedTarget {
            if targetDescriptor < 0 {
                targetDescriptor = "executable".withCString {
                    Darwin.openat(
                        childDescriptor,
                        $0,
                        O_RDONLY | O_CLOEXEC | O_NOFOLLOW
                    )
                }
            }
            var openedTarget = stat()
            var currentTarget = stat()
            guard targetDescriptor >= 0,
                  Darwin.fstat(targetDescriptor, &openedTarget) == 0,
                  sameEntry(resolvedTarget, openedTarget),
                  "executable".withCString({
                      Darwin.fstatat(
                          childDescriptor,
                          $0,
                          &currentTarget,
                          AT_SYMLINK_NOFOLLOW
                      )
                  }) == 0,
                  sameEntry(resolvedTarget, currentTarget),
                  "executable".withCString({
                      Darwin.unlinkat(childDescriptor, $0, 0)
                  }) == 0
            else {
                throw EngineContextValidationErrorV1()
            }
        } else {
            var unexpected = stat()
            let result = "executable".withCString {
                Darwin.fstatat(
                    childDescriptor,
                    $0,
                    &unexpected,
                    AT_SYMLINK_NOFOLLOW
                )
            }
            guard result != 0, errno == ENOENT else {
                throw EngineContextValidationErrorV1()
            }
        }
        guard Darwin.fsync(childDescriptor) == 0 else {
            throw EngineContextValidationErrorV1()
        }
        try closeDescriptor(&targetDescriptor)
        try closeDescriptor(&childDescriptor)
        var parentChild = stat()
        guard childName.withCString({
            Darwin.fstatat(
                parentDescriptor,
                $0,
                &parentChild,
                AT_SYMLINK_NOFOLLOW
            )
        }) == 0,
              sameEntry(resolvedChild, parentChild),
              childName.withCString({
                  Darwin.unlinkat(parentDescriptor, $0, AT_REMOVEDIR)
              }) == 0,
              Darwin.fsync(parentDescriptor) == 0
        else {
            throw EngineContextValidationErrorV1()
        }
    }

    private static func closeDescriptor(_ descriptor: inout Int32) throws {
        guard descriptor >= 0 else { return }
        let value = descriptor
        descriptor = -1
        guard Darwin.close(value) == 0 else {
            throw EngineContextValidationErrorV1()
        }
    }

    private static func sameEntry(_ lhs: stat, _ rhs: stat) -> Bool {
        lhs.st_dev == rhs.st_dev
            && lhs.st_ino == rhs.st_ino
            && (lhs.st_mode & S_IFMT) == (rhs.st_mode & S_IFMT)
            && lhs.st_uid == rhs.st_uid
    }

    private static func readPrefix(
        _ path: String,
        count: Int
    ) throws -> Data {
        let descriptor = path.withCString {
            Darwin.open($0, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard descriptor >= 0 else {
            throw EngineContextValidationErrorV1()
        }
        defer { Darwin.close(descriptor) }
        var buffer = [UInt8](repeating: 0, count: count)
        var offset = 0
        while offset < count {
            let amount = buffer.withUnsafeMutableBytes {
                Darwin.read(
                    descriptor,
                    $0.baseAddress?.advanced(by: offset),
                    count - offset
                )
            }
            if amount > 0 {
                offset += amount
                continue
            }
            if amount == 0 { break }
            if errno == EINTR { continue }
            throw EngineContextValidationErrorV1()
        }
        return Data(buffer.prefix(offset))
    }

    private static func signingIdentity(
        path: String,
        validatingRequirement requirementText: String
    ) throws -> SigningIdentity {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(
            URL(fileURLWithPath: path) as CFURL,
            SecCSFlags(),
            &staticCode
        ) == errSecSuccess,
            let staticCode
        else {
            throw EngineContextValidationErrorV1()
        }
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(
            requirementText as CFString,
            SecCSFlags(),
            &requirement
        ) == errSecSuccess,
            let requirement,
            SecStaticCodeCheckValidity(
                staticCode,
                SecCSFlags(rawValue: kSecCSStrictValidate),
                requirement
            ) == errSecSuccess
        else {
            throw EngineContextValidationErrorV1()
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
            throw EngineContextValidationErrorV1()
        }
        var designated: SecRequirement?
        var designatedText: CFString?
        guard SecCodeCopyDesignatedRequirement(
            staticCode,
            SecCSFlags(),
            &designated
        ) == errSecSuccess,
            let designated,
            SecRequirementCopyString(
                designated,
                SecCSFlags(),
                &designatedText
            ) == errSecSuccess,
            let designatedText
        else {
            throw EngineContextValidationErrorV1()
        }
        let normalizedRequirement = (designatedText as String)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        let team = dictionary[kSecCodeInfoTeamIdentifier] as? String
        return SigningIdentity(
            designatedRequirement: normalizedRequirement,
            teamIdentifier: team,
            cdHash: cdHashData.map { String(format: "%02x", $0) }.joined()
        )
    }

    private static func sameStableFile(_ lhs: stat, _ rhs: stat) -> Bool {
        lhs.st_dev == rhs.st_dev
            && lhs.st_ino == rhs.st_ino
            && lhs.st_mode == rhs.st_mode
            && lhs.st_uid == rhs.st_uid
            && lhs.st_nlink == rhs.st_nlink
            && lhs.st_size == rhs.st_size
            && lhs.st_mtimespec.tv_sec == rhs.st_mtimespec.tv_sec
            && lhs.st_mtimespec.tv_nsec == rhs.st_mtimespec.tv_nsec
    }
}

package actor CliHelpSnapshotCacheV1 {
    private struct Key: Hashable, Sendable {
        let kind: RuntimeProfileKind
        let commandSourcePath: String
        let commandSourceHash: String
        let resolvedExecutablePath: String
        let executableHash: String
    }

    private struct Flight: Sendable {
        let id: UInt64
        let task: Task<CliHelpSnapshotV1, Error>
    }

    private let probe: CliHelpProbeV1
    private var successful: [Key: CliHelpSnapshotV1] = [:]
    private var inFlight: [Key: Flight] = [:]
    private var nextFlightID: UInt64 = 0

    package init(probe: CliHelpProbeV1) {
        self.probe = probe
    }

    package func snapshot(
        for authority: CliExecutableAuthorityV1
    ) async throws -> CliHelpSnapshotV1 {
        try authority.validateCanonical()
        let key = Key(
            kind: authority.kind,
            commandSourcePath: authority.commandSourcePath,
            commandSourceHash: authority.commandSourceHash,
            resolvedExecutablePath: authority.resolvedExecutablePath,
            executableHash: authority.executableHash
        )
        if let cached = successful[key] { return cached }
        let flight: Flight
        if let existing = inFlight[key] {
            flight = existing
        } else {
            let probe = self.probe
            guard nextFlightID < UInt64.max else {
                throw CliHelpProbeFailureV1.mechanics
            }
            nextFlightID += 1
            let id = nextFlightID
            let task = Task.detached {
                do {
                    return try await probe.snapshot(
                        for: authority.kind,
                        authority: authority
                    )
                } catch {
                    let primary = error
                    do {
                        try probe.removeStagedAuthority(authority)
                    } catch {
                        throw CliHelpProbeFailureV1.cleanup
                    }
                    throw primary
                }
            }
            flight = Flight(id: id, task: task)
            inFlight[key] = flight
        }
        do {
            let value = try await flight.task.value
            guard value.executableAuthority == authority else {
                throw CliHelpProbeFailureV1.stagedIdentity
            }
            successful[key] = value
            if inFlight[key]?.id == flight.id {
                inFlight[key] = nil
            }
            return value
        } catch {
            if (error as? CliHelpProbeFailureV1)?.isCleanupFailure != true {
                if inFlight[key]?.id == flight.id {
                    inFlight[key] = nil
                }
            }
            throw error
        }
    }
}

package enum CliProviderEventV1: Sendable, Equatable {
    case sessionBound(externalSessionId: String)
    case progress(message: String)
    case toolActivity(name: String)
    case usage(EngineUsageV1)
    case providerError
    case result
}

package struct CodexCliEventParserV1: Sendable {
    package init() {}

    package func parse(line: String) throws -> [CliProviderEventV1] {
        do {
            let object = try CliStrictJSONV1.object(line)
            let type = try CliStrictJSONV1.string(object, "type")
            switch type {
            case "thread.started":
                try CliStrictJSONV1.requireKeys(
                    object,
                    ["thread_id", "type"]
                )
                let threadID = try CliStrictJSONV1.nonemptyString(
                    object,
                    "thread_id"
                )
                try EngineContractValidationV1.validateExternalSessionID(
                    threadID
                )
                return [.sessionBound(externalSessionId: threadID)]
            case "turn.started":
                try CliStrictJSONV1.requireKeys(object, ["type"])
                return []
            case "item.completed":
                try CliStrictJSONV1.requireKeys(object, ["item", "type"])
                let item = try CliStrictJSONV1.object(object, "item")
                let itemType = try CliStrictJSONV1.string(item, "type")
                switch itemType {
                case "agent_message":
                    try CliStrictJSONV1.requireKeys(
                        item,
                        ["id", "text", "type"]
                    )
                    _ = try CliStrictJSONV1.nonemptyString(item, "id")
                    let text = try CliStrictJSONV1.nonemptyString(
                        item,
                        "text"
                    )
                    try EngineContractValidationV1.validateProgress(text)
                    return [.progress(message: text)]
                case "mcp_tool_call":
                    try CliStrictJSONV1.requireKeys(
                        item,
                        ["id", "server", "status", "tool", "type"]
                    )
                    _ = try CliStrictJSONV1.nonemptyString(item, "id")
                    let server = try CliStrictJSONV1.nonemptyString(
                        item,
                        "server"
                    )
                    let tool = try CliStrictJSONV1.nonemptyString(
                        item,
                        "tool"
                    )
                    _ = try CliStrictJSONV1.nonemptyString(item, "status")
                    let name = "\(server).\(tool)"
                    try EngineContractValidationV1.validateToolName(name)
                    return [.toolActivity(name: name)]
                default:
                    throw EngineContextValidationErrorV1()
                }
            case "turn.completed":
                try CliStrictJSONV1.requireKeys(object, ["type", "usage"])
                let usage = try CliStrictJSONV1.object(object, "usage")
                try CliStrictJSONV1.requireKeys(
                    usage,
                    [
                        "cached_input_tokens", "input_tokens",
                        "output_tokens",
                    ]
                )
                return [
                    .usage(
                        EngineUsageV1(
                            inputTokens: try CliStrictJSONV1.nonnegativeInt(
                                usage,
                                "input_tokens"
                            ),
                            outputTokens: try CliStrictJSONV1.nonnegativeInt(
                                usage,
                                "output_tokens"
                            ),
                            cacheReadTokens: try CliStrictJSONV1.nonnegativeInt(
                                usage,
                                "cached_input_tokens"
                            ),
                            costMicros: 0
                        )
                    ),
                ]
            case "error":
                try CliStrictJSONV1.requireKeys(object, ["message", "type"])
                _ = try CliStrictJSONV1.string(object, "message")
                return [.providerError]
            default:
                throw EngineContextValidationErrorV1()
            }
        } catch is EngineContextValidationErrorV1 {
            throw EngineContextValidationErrorV1()
        } catch {
            throw EngineContextValidationErrorV1()
        }
    }
}

package struct ClaudeCliEventParserV1: Sendable {
    package let expectedSessionId: String

    package init(expectedSessionId: String) throws {
        try EngineContractValidationV1.validateExternalSessionID(
            expectedSessionId
        )
        self.expectedSessionId = expectedSessionId
    }

    package func parse(line: String) throws -> [CliProviderEventV1] {
        do {
            let object = try CliStrictJSONV1.object(line)
            let type = try CliStrictJSONV1.string(object, "type")
            switch type {
            case "system":
                try CliStrictJSONV1.requireKeys(
                    object,
                    ["session_id", "subtype", "type"]
                )
                guard try CliStrictJSONV1.string(object, "subtype") == "init"
                else {
                    throw EngineContextValidationErrorV1()
                }
                try requireExpectedSession(object)
                return [.sessionBound(externalSessionId: expectedSessionId)]
            case "assistant":
                try CliStrictJSONV1.requireKeys(
                    object,
                    ["message", "session_id", "type"]
                )
                try requireExpectedSession(object)
                let message = try CliStrictJSONV1.object(object, "message")
                try CliStrictJSONV1.requireKeys(
                    message,
                    ["content", "role", "usage"]
                )
                guard try CliStrictJSONV1.string(message, "role")
                        == "assistant"
                else {
                    throw EngineContextValidationErrorV1()
                }
                let content = try CliStrictJSONV1.array(message, "content")
                guard content.count == 1,
                      let textBlock = content[0] as? [String: Any]
                else {
                    throw EngineContextValidationErrorV1()
                }
                try CliStrictJSONV1.requireKeys(
                    textBlock,
                    ["text", "type"]
                )
                guard try CliStrictJSONV1.string(textBlock, "type") == "text"
                else {
                    throw EngineContextValidationErrorV1()
                }
                let text = try CliStrictJSONV1.nonemptyString(
                    textBlock,
                    "text"
                )
                try EngineContractValidationV1.validateProgress(text)
                let usage = try parseUsage(
                    CliStrictJSONV1.object(message, "usage"),
                    costMicros: 0
                )
                return [.progress(message: text), .usage(usage)]
            case "result":
                try CliStrictJSONV1.requireKeys(
                    object,
                    [
                        "is_error", "result", "session_id", "subtype",
                        "total_cost_usd", "type", "usage",
                    ]
                )
                try requireExpectedSession(object)
                let subtype = try CliStrictJSONV1.string(object, "subtype")
                let isError = try CliStrictJSONV1.bool(object, "is_error")
                _ = try CliStrictJSONV1.string(object, "result")
                let costMicros = try CliStrictJSONV1.costMicros(
                    object,
                    "total_cost_usd"
                )
                let usage = try parseUsage(
                    CliStrictJSONV1.object(object, "usage"),
                    costMicros: costMicros
                )
                switch (subtype, isError) {
                case ("success", false):
                    return [.usage(usage), .result]
                case ("error", true):
                    return [.providerError]
                default:
                    throw EngineContextValidationErrorV1()
                }
            default:
                throw EngineContextValidationErrorV1()
            }
        } catch is EngineContextValidationErrorV1 {
            throw EngineContextValidationErrorV1()
        } catch {
            throw EngineContextValidationErrorV1()
        }
    }

    private func requireExpectedSession(
        _ object: [String: Any]
    ) throws {
        guard try CliStrictJSONV1.string(object, "session_id")
            .utf8.elementsEqual(expectedSessionId.utf8)
        else {
            throw EngineContextValidationErrorV1()
        }
    }

    private func parseUsage(
        _ object: [String: Any],
        costMicros: Int
    ) throws -> EngineUsageV1 {
        try CliStrictJSONV1.requireKeys(
            object,
            [
                "cache_read_input_tokens", "input_tokens", "output_tokens",
            ]
        )
        return EngineUsageV1(
            inputTokens: try CliStrictJSONV1.nonnegativeInt(
                object,
                "input_tokens"
            ),
            outputTokens: try CliStrictJSONV1.nonnegativeInt(
                object,
                "output_tokens"
            ),
            cacheReadTokens: try CliStrictJSONV1.nonnegativeInt(
                object,
                "cache_read_input_tokens"
            ),
            costMicros: costMicros
        )
    }
}

private enum CliStrictJSONV1 {
    private static let integerNumberTypes = Set("cCsSiIlLqQ".utf8)

    static func object(_ line: String) throws -> [String: Any] {
        guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw EngineContextValidationErrorV1()
        }
        let value = try JSONSerialization.jsonObject(
            with: Data(line.utf8),
            options: []
        )
        guard let object = value as? [String: Any] else {
            throw EngineContextValidationErrorV1()
        }
        return object
    }

    static func object(
        _ object: [String: Any],
        _ key: String
    ) throws -> [String: Any] {
        guard let value = object[key] as? [String: Any] else {
            throw EngineContextValidationErrorV1()
        }
        return value
    }

    static func array(
        _ object: [String: Any],
        _ key: String
    ) throws -> [Any] {
        guard let value = object[key] as? [Any] else {
            throw EngineContextValidationErrorV1()
        }
        return value
    }

    static func string(
        _ object: [String: Any],
        _ key: String
    ) throws -> String {
        guard let value = object[key] as? String else {
            throw EngineContextValidationErrorV1()
        }
        return value
    }

    static func nonemptyString(
        _ object: [String: Any],
        _ key: String
    ) throws -> String {
        let value = try string(object, key)
        try CanonicalContractCodingV1.validateNonempty(value)
        return value
    }

    static func bool(
        _ object: [String: Any],
        _ key: String
    ) throws -> Bool {
        guard let number = object[key] as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID()
        else {
            throw EngineContextValidationErrorV1()
        }
        return number.boolValue
    }

    static func nonnegativeInt(
        _ object: [String: Any],
        _ key: String
    ) throws -> Int {
        guard let number = object[key] as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              integerNumberTypes.contains(
                  UInt8(bitPattern: number.objCType.pointee)
              ),
              let value = Int(number.stringValue),
              value >= 0
        else {
            throw EngineContextValidationErrorV1()
        }
        return value
    }

    static func costMicros(
        _ object: [String: Any],
        _ key: String
    ) throws -> Int {
        guard let number = object[key] as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number != NSDecimalNumber.notANumber,
              number.doubleValue.isFinite
        else {
            throw EngineContextValidationErrorV1()
        }
        let dollars = number.decimalValue
        guard dollars >= 0
        else {
            throw EngineContextValidationErrorV1()
        }
        var scaled = dollars * Decimal(1_000_000)
        var integral = Decimal()
        NSDecimalRound(&integral, &scaled, 0, .plain)
        guard scaled == integral,
              let value = Int(
                  NSDecimalNumber(decimal: integral).stringValue
              ),
              value >= 0
        else {
            throw EngineContextValidationErrorV1()
        }
        return value
    }

    static func requireKeys(
        _ object: [String: Any],
        _ keys: Set<String>
    ) throws {
        guard Set(object.keys) == keys else {
            throw EngineContextValidationErrorV1()
        }
    }
}

package typealias ClaudeCliEventParserFactoryV1 =
    @Sendable (_ expectedSessionId: String) throws -> ClaudeCliEventParserV1

package enum CliEngineFailureReasonV1: Sendable, Equatable {
    case protocolViolation
    case capabilityUnsupported
    case processOutcomeUnknown
    case providerFailure
    case provenCancellation
}

package struct CliEngineSanitizedFailureV1: Sendable, Equatable {
    package let reason: CliEngineFailureReasonV1
    package let traceLabel: String
    package let intent: EngineTerminalIntentV1

    package init(
        reason: CliEngineFailureReasonV1,
        traceLabel: String
    ) throws {
        guard traceLabel.utf8.count == 16,
              traceLabel.utf8.allSatisfy({ byte in
                  (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                      || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte)
              })
        else {
            throw EngineContextValidationErrorV1()
        }
        self.reason = reason
        self.traceLabel = traceLabel
        switch reason {
        case .protocolViolation:
            intent = .blocked(
                subtype: .engineProtocolError,
                reasonCode: "engine_protocol_error",
                detail: "Engine protocol failure. trace=\(traceLabel)"
            )
        case .capabilityUnsupported:
            intent = .blocked(
                subtype: .engineProtocolError,
                reasonCode: "engine_capability_unsupported",
                detail: "Engine capability unavailable. trace=\(traceLabel)"
            )
        case .processOutcomeUnknown:
            intent = .blocked(
                subtype: .externalEffectUnknown,
                reasonCode: "engine_external_effect_unknown",
                detail: "Engine process outcome unknown. trace=\(traceLabel)"
            )
        case .providerFailure:
            intent = .failed(
                code: "engine_provider_error",
                detail: "Engine provider failed. trace=\(traceLabel)"
            )
        case .provenCancellation:
            intent = .canceled(
                reasonCode: "engine_canceled",
                detail: "Engine execution canceled. trace=\(traceLabel)"
            )
        }
    }
}

package struct CliEngineSecretSanitizerV1: Sendable {
    package init() {}

    package func failure(
        reason: CliEngineFailureReasonV1,
        executionId: String
    ) throws -> CliEngineSanitizedFailureV1 {
        try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        var traceBytes = Data("engine-trace.v1".utf8)
        traceBytes.append(0)
        traceBytes.append(contentsOf: executionId.utf8)
        let traceLabel = String(
            CanonicalJSONV1.sha256Hex(traceBytes).prefix(16)
        )
        return try CliEngineSanitizedFailureV1(
            reason: reason,
            traceLabel: traceLabel
        )
    }
}

private final class CliEngineAdapterPublicationGateV1: @unchecked Sendable {
    private let lock = NSLock()
    private var opened = false
    private var waiter: CheckedContinuation<Void, Never>?

    func waitUntilOpened() async {
        if lock.withLock({ opened }) { return }
        await withCheckedContinuation { continuation in
            let resumeNow = lock.withLock { () -> Bool in
                if opened { return true }
                precondition(waiter == nil, "duplicate CLI start waiter")
                waiter = continuation
                return false
            }
            if resumeNow { continuation.resume() }
        }
    }

    func open() {
        let current = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            precondition(!opened, "duplicate CLI start open")
            opened = true
            let current = waiter
            waiter = nil
            return current
        }
        current?.resume()
    }
}

package enum CliEngineAdapterCancellationLifecycleEventV1:
    Sendable,
    Equatable
{
    case beforeOuterTaskLoad
    case outcomePublished
    case outerTaskLoaded(Bool)
    case cancellationOwnerSettled
}

private final class CliEngineAdapterGenerationV1: @unchecked Sendable {
    enum CancellationAuthority: Sendable {
        case cleanupOwner
        case terminalWinner
    }

    enum LaunchResolution: Sendable {
        case launchReturned
        case unlaunched
    }

    enum LaunchPreparation: @unchecked Sendable {
        case launch
        case abortUnlaunched(Result<Void, any Error>)
    }

    enum PrelaunchCancellationDecision: @unchecked Sendable {
        case retryAfterLaunch
        case abortUnlaunched(Result<Void, any Error>)
    }

    enum LaunchPhase: Sendable, Equatable {
        case prelaunch
        case launching
        case launchReturned
        case unlaunched
        case terminal
    }

    private enum TerminalAuthority {
        case open
        case cancellation
        case terminal
    }

    private enum CancellationOwnerState: @unchecked Sendable {
        case none
        case running(
            token: EngineAdapterCancellationOwnerTokenV1,
            task: Task<Void, Error>
        )
        case settled(
            token: EngineAdapterCancellationOwnerTokenV1,
            result: Result<Void, any Error>
        )
    }

    struct CancellationOwnerJoin: Sendable {
        let token: EngineAdapterCancellationOwnerTokenV1
        let task: Task<Void, Error>
        let startOwner: @Sendable () -> Void
    }

    let executionId: String
    let token = EngineAdapterCancellationGenerationTokenV1()

    private let lock = NSLock()
    private var phase: LaunchPhase = .prelaunch
    private var launchWaiters: [
        CheckedContinuation<LaunchResolution, Never>
    ] = []
    private var prelaunchDecision: PrelaunchCancellationDecision?
    private var preparationWaiters: [
        CheckedContinuation<LaunchPreparation, Never>
    ] = []
    private var outerTask: Task<Void, Error>?
    private var outerTaskLoadedForCancellation = false
    private var outerTaskSettledForCancellation = false
    private var outerTaskSettlementWaiters: [
        CheckedContinuation<Void, Never>
    ] = []
    private var outerTaskWaiters: [
        CheckedContinuation<Task<Void, Error>?, Never>
    ] = []
    private var outcome: Result<Void, any Error>?
    private var outcomeWaiters: [
        CheckedContinuation<Result<Void, any Error>, Never>
    ] = []
    private var authority: TerminalAuthority = .open
    private var cancellationOwner: CancellationOwnerState = .none
    private var failureBeforeOuterCancellation: (any Error)?

    init(executionId: String) {
        self.executionId = executionId
    }

    func attach(_ task: Task<Void, Error>) throws {
        let waiters = try lock.withLock {
            () throws -> [
                CheckedContinuation<Task<Void, Error>?, Never>
            ] in
            guard outerTask == nil, outcome == nil else {
                throw EngineDispatchConflictErrorV1()
            }
            outerTask = task
            let waiters = outerTaskWaiters
            outerTaskWaiters.removeAll()
            if !waiters.isEmpty { outerTaskLoadedForCancellation = true }
            return waiters
        }
        waiters.forEach { $0.resume(returning: task) }
    }

    func waitForOuterTask() async -> Task<Void, Error>? {
        await withCheckedContinuation { continuation in
            let immediate = lock.withLock {
                () -> (resolved: Bool, task: Task<Void, Error>?) in
                if let outerTask {
                    outerTaskLoadedForCancellation = true
                    if outcome != nil { self.outerTask = nil }
                    return (true, outerTask)
                }
                if outcome != nil { return (true, nil) }
                outerTaskWaiters.append(continuation)
                return (false, nil)
            }
            if immediate.resolved {
                continuation.resume(returning: immediate.task)
            }
        }
    }

    func prepareLaunch() async -> LaunchPreparation {
        await withCheckedContinuation { continuation in
            let immediate = lock.withLock { () -> LaunchPreparation? in
                guard phase == .prelaunch else {
                    preconditionFailure("invalid duplicate CLI launch")
                }
                switch authority {
                case .open:
                    phase = .launching
                    return .launch
                case .terminal:
                    preconditionFailure("terminal CLI generation cannot launch")
                case .cancellation:
                    guard let prelaunchDecision else {
                        precondition(
                            preparationWaiters.isEmpty,
                            "duplicate CLI launch preparation waiter"
                        )
                        preparationWaiters.append(continuation)
                        return nil
                    }
                    switch prelaunchDecision {
                    case .retryAfterLaunch:
                        phase = .launching
                        return .launch
                    case let .abortUnlaunched(result):
                        return .abortUnlaunched(result)
                    }
                }
            }
            if let immediate {
                continuation.resume(returning: immediate)
            }
        }
    }

    func publishPrelaunchDecision(
        _ decision: PrelaunchCancellationDecision
    ) -> Bool {
        let waiters = lock.withLock { () -> (
            published: Bool,
            waiters: [CheckedContinuation<LaunchPreparation, Never>],
            preparation: LaunchPreparation?
        ) in
            guard phase == .prelaunch, outcome == nil else {
                return (false, [], nil)
            }
            guard prelaunchDecision == nil else {
                preconditionFailure("duplicate CLI prelaunch decision")
            }
            prelaunchDecision = decision
            let preparation: LaunchPreparation
            switch decision {
            case .retryAfterLaunch:
                preparation = .launch
                if !preparationWaiters.isEmpty { phase = .launching }
            case let .abortUnlaunched(result):
                preparation = .abortUnlaunched(result)
            }
            let waiters = preparationWaiters
            preparationWaiters.removeAll()
            return (true, waiters, preparation)
        }
        if let preparation = waiters.preparation {
            waiters.waiters.forEach {
                $0.resume(returning: preparation)
            }
        }
        return waiters.published
    }

    func publishLaunchReturned() {
        let waiters = lock.withLock {
            () -> [CheckedContinuation<LaunchResolution, Never>] in
            guard phase == .launching else {
                preconditionFailure("CLI launch returned from invalid phase")
            }
            phase = .launchReturned
            let waiters = launchWaiters
            launchWaiters.removeAll()
            return waiters
        }
        waiters.forEach { $0.resume(returning: .launchReturned) }
    }

    func snapshotLaunchPhase() -> LaunchPhase {
        lock.withLock { phase }
    }

    func waitUntilLaunchResolved() async -> LaunchResolution {
        await withCheckedContinuation { continuation in
            let immediate = lock.withLock { () -> LaunchResolution? in
                switch phase {
                case .prelaunch, .launching:
                    launchWaiters.append(continuation)
                    return nil
                case .launchReturned:
                    return .launchReturned
                case .unlaunched:
                    return .unlaunched
                case .terminal:
                    return .launchReturned
                }
            }
            if let immediate {
                continuation.resume(returning: immediate)
            }
        }
    }

    func recordFailureBeforeOuterCancellation(_ error: any Error) {
        guard !(error is CancellationError) else { return }
        lock.withLock {
            guard case .cancellation = authority,
                  outcome == nil,
                  failureBeforeOuterCancellation == nil
            else { return }
            failureBeforeOuterCancellation = error
        }
    }

    func publishOutcome(
        _ result: Result<Void, any Error>,
        outerTaskIsCancelled: Bool
    ) -> Result<Void, any Error> {
        let waiters = lock.withLock { () -> (
            launch: [CheckedContinuation<LaunchResolution, Never>],
            task: [CheckedContinuation<Task<Void, Error>?, Never>],
            outcome: [
                CheckedContinuation<Result<Void, any Error>, Never>
            ],
            launchResolution: LaunchResolution,
            result: Result<Void, any Error>
        ) in
            guard outcome == nil else {
                preconditionFailure("duplicate CLI generation outcome")
            }
            let launchResolution: LaunchResolution
            switch phase {
            case .prelaunch:
                launchResolution = .unlaunched
            case .launchReturned:
                launchResolution = .launchReturned
            case .launching:
                preconditionFailure("CLI outcome published during launch")
            case .unlaunched, .terminal:
                preconditionFailure("duplicate CLI terminal phase")
            }
            switch launchResolution {
            case .launchReturned: phase = .terminal
            case .unlaunched: phase = .unlaunched
            }
            let selectedResult: Result<Void, any Error>
            if case let .failure(error) = result,
               error is CancellationError,
               outerTaskIsCancelled,
               let failureBeforeOuterCancellation
            {
                selectedResult = .failure(failureBeforeOuterCancellation)
            } else {
                selectedResult = result
            }
            outcome = selectedResult
            self.failureBeforeOuterCancellation = nil
            if !hasCancellationOwnerLocked()
                || outerTaskLoadedForCancellation
            {
                outerTask = nil
            }
            let launch = launchWaiters
            launchWaiters.removeAll()
            let task = outerTaskWaiters
            outerTaskWaiters.removeAll()
            let outcome = outcomeWaiters
            outcomeWaiters.removeAll()
            return (
                launch,
                task,
                outcome,
                launchResolution,
                selectedResult
            )
        }
        waiters.launch.forEach {
            $0.resume(returning: waiters.launchResolution)
        }
        waiters.task.forEach { $0.resume(returning: nil) }
        waiters.outcome.forEach { $0.resume(returning: waiters.result) }
        return waiters.result
    }

    func snapshotOutcome() -> Result<Void, any Error>? {
        lock.withLock { outcome }
    }

    func waitForOutcome() async -> Result<Void, any Error> {
        await withCheckedContinuation { continuation in
            let immediate = lock.withLock {
                () -> Result<Void, any Error>? in
                if let outcome { return outcome }
                outcomeWaiters.append(continuation)
                return nil
            }
            if let immediate { continuation.resume(returning: immediate) }
        }
    }

    func markOuterTaskSettledForCancellation() {
        let waiters = lock.withLock { ()
            -> [CheckedContinuation<Void, Never>] in
            precondition(outcome != nil, "CLI outer Task settled before outcome")
            guard !outerTaskSettledForCancellation else { return [] }
            outerTaskSettledForCancellation = true
            outerTask = nil
            let waiters = outerTaskSettlementWaiters
            outerTaskSettlementWaiters.removeAll()
            return waiters
        }
        waiters.forEach { $0.resume() }
    }

    func isOuterTaskSettledForCancellation() -> Bool {
        lock.withLock { outerTaskSettledForCancellation }
    }

    func waitUntilOuterTaskSettledForCancellation() async {
        if lock.withLock({ outerTaskSettledForCancellation }) { return }
        await withCheckedContinuation { continuation in
            let resumeNow = lock.withLock { () -> Bool in
                if outerTaskSettledForCancellation { return true }
                outerTaskSettlementWaiters.append(continuation)
                return false
            }
            if resumeNow { continuation.resume() }
        }
    }

    func claimTerminalAuthority() -> Bool {
        lock.withLock {
            switch authority {
            case .open:
                authority = .terminal
                return true
            case .cancellation, .terminal:
                return false
            }
        }
    }

    func cancellationOwnsTerminal() -> Bool {
        lock.withLock {
            if case .cancellation = authority { return true }
            return false
        }
    }

    func startOrJoinCancellation(
        operation: @escaping @Sendable (
            CliEngineAdapterGenerationV1,
            CancellationAuthority
        ) async throws -> Void,
        onComplete: @escaping @Sendable (
            CliEngineAdapterGenerationV1,
            EngineAdapterCancellationOwnerTokenV1
        ) -> Void
    ) -> CancellationOwnerJoin {
        let installed = lock.withLock { () -> (
            token: EngineAdapterCancellationOwnerTokenV1,
            task: Task<Void, Error>,
            gate: CliEngineAdapterPublicationGateV1?
        ) in
            switch cancellationOwner {
            case let .running(token, task):
                return (
                    token,
                    task,
                    nil
                )
            case let .settled(token, result):
                return (
                    token,
                    Task { try result.get() },
                    nil
                )
            case .none:
                break
            }
            let cancellationAuthority: CancellationAuthority
            if outcome != nil {
                cancellationAuthority = .terminalWinner
            } else {
                switch authority {
                case .open:
                    authority = .cancellation
                    cancellationAuthority = .cleanupOwner
                case .cancellation:
                    preconditionFailure("missing CLI cancellation owner")
                case .terminal:
                    cancellationAuthority = .terminalWinner
                }
            }
            let token = EngineAdapterCancellationOwnerTokenV1()
            let gate = CliEngineAdapterPublicationGateV1()
            let generation = self
            let task = Task {
                await gate.waitUntilOpened()
                let result: Result<Void, any Error>
                do {
                    try await operation(generation, cancellationAuthority)
                    result = .success(())
                } catch {
                    result = .failure(error)
                }
                generation.settleCancellationOwner(token, result: result)
                onComplete(generation, token)
                try result.get()
            }
            cancellationOwner = .running(token: token, task: task)
            return (token, task, gate)
        }
        return CancellationOwnerJoin(
            token: installed.token,
            task: installed.task,
            startOwner: { installed.gate?.open() }
        )
    }

    func hasCancellationOwner() -> Bool {
        lock.withLock { hasCancellationOwnerLocked() }
    }

    func matchesCancellationOwner(
        _ ownerToken: EngineAdapterCancellationOwnerTokenV1
    ) -> Bool {
        lock.withLock {
            switch cancellationOwner {
            case let .running(token, _), let .settled(token, _):
                return token === ownerToken
            case .none:
                return false
            }
        }
    }

    func isCancellationOwnerSettled(
        _ ownerToken: EngineAdapterCancellationOwnerTokenV1
    ) -> Bool {
        lock.withLock {
            guard case let .settled(token, _) = cancellationOwner else {
                return false
            }
            return token === ownerToken
        }
    }

    private func settleCancellationOwner(
        _ ownerToken: EngineAdapterCancellationOwnerTokenV1,
        result: Result<Void, any Error>
    ) {
        lock.withLock {
            guard case let .running(token, _) = cancellationOwner,
                  token === ownerToken
            else {
                preconditionFailure("stale CLI cancellation owner settlement")
            }
            cancellationOwner = .settled(token: token, result: result)
        }
    }

    private func hasCancellationOwnerLocked() -> Bool {
        switch cancellationOwner {
        case .none:
            return false
        case .running, .settled:
            return true
        }
    }
}

private final class CliEngineAdapterTaskRegistryV1: @unchecked Sendable {
    typealias CancellationOperation = @Sendable (
        CliEngineAdapterGenerationV1,
        CliEngineAdapterGenerationV1.CancellationAuthority
    ) async throws -> Void

    private final class Entry: @unchecked Sendable {
        let generation: CliEngineAdapterGenerationV1
        let cancellation: CancellationOperation
        let cancellationOwnerSettled: @Sendable () -> Void
        var publicClaimTokens: [
            ObjectIdentifier: EngineAdapterCancellationClaimTokenV1
        ] = [:]
        var outstandingLiveClaimTokens: Set<ObjectIdentifier> = []
        var productionHandoffRequired = false
        var productionHandoffStarted = false
        var productionHandoffAcknowledged = false
        var ownerSettlementPublished = false

        init(
            generation: CliEngineAdapterGenerationV1,
            cancellation: @escaping CancellationOperation,
            cancellationOwnerSettled: @escaping @Sendable () -> Void
        ) {
            self.generation = generation
            self.cancellation = cancellation
            self.cancellationOwnerSettled = cancellationOwnerSettled
        }
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]

    func reserve(
        executionId: String,
        cancellation: @escaping CancellationOperation,
        cancellationOwnerSettled: @escaping @Sendable () -> Void
    ) throws -> CliEngineAdapterGenerationV1 {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        } catch {
            throw EngineDispatchConflictErrorV1()
        }
        let generation = CliEngineAdapterGenerationV1(
            executionId: executionId
        )
        try lock.withLock {
            guard entries[executionId] == nil else {
                throw EngineDispatchConflictErrorV1()
            }
            entries[executionId] = Entry(
                generation: generation,
                cancellation: cancellation,
                cancellationOwnerSettled: cancellationOwnerSettled
            )
        }
        return generation
    }

    func attach(
        _ task: Task<Void, Error>,
        executionId: String,
        generation: CliEngineAdapterGenerationV1
    ) throws {
        try lock.withLock {
            guard entries[executionId]?.generation === generation else {
                throw EngineDispatchConflictErrorV1()
            }
            try generation.attach(task)
        }
        Task { [weak self] in
            _ = await task.result
            self?.markOuterTaskSettled(
                executionId: executionId,
                generation: generation
            )
        }
    }

    func publishOutcome(
        executionId: String,
        generation: CliEngineAdapterGenerationV1,
        result: Result<Void, any Error>,
        outerTaskIsCancelled: Bool
    ) -> Result<Void, any Error> {
        let selectedResult = generation.publishOutcome(
            result,
            outerTaskIsCancelled: outerTaskIsCancelled
        )
        lock.withLock {
            guard let entry = entries[executionId],
                  entry.generation === generation
            else { return }
            retireIfEligibleLocked(executionId: executionId, entry: entry)
        }
        return selectedResult
    }

    func claimCancellation(
        executionId: String
    ) throws -> EngineAdapterCancellationClaimV1 {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        } catch {
            throw EngineDispatchConflictErrorV1()
        }
        let installed = try lock.withLock { () throws -> (
            claim: EngineAdapterCancellationClaimV1,
            startOwner: @Sendable () -> Void
        ) in
            guard let entry = entries[executionId] else {
                throw EngineDispatchConflictErrorV1()
            }
            entry.productionHandoffRequired = true
            entry.productionHandoffStarted = true
            let owner = startOrJoinCancellationLocked(entry)
            let claimToken = EngineAdapterCancellationClaimTokenV1()
            let claimIdentifier = ObjectIdentifier(claimToken)
            entry.publicClaimTokens[claimIdentifier] = claimToken
            if !entry.generation.isCancellationOwnerSettled(owner.token) {
                entry.outstandingLiveClaimTokens.insert(claimIdentifier)
            }
            return (
                EngineAdapterCancellationClaimV1(
                    executionId: executionId,
                    generationToken: entry.generation.token,
                    ownerToken: owner.token,
                    claimToken: claimToken,
                    task: owner.task
                ),
                owner.startOwner
            )
        }
        installed.startOwner()
        return installed.claim
    }

    func signalCancellation(
        executionId: String,
        generation: CliEngineAdapterGenerationV1
    ) {
        let startOwner = lock.withLock { ()
            -> (@Sendable () -> Void)? in
            guard let entry = entries[executionId],
                  entry.generation === generation
            else { return nil }
            entry.productionHandoffRequired = true
            guard !entry.productionHandoffStarted else { return nil }
            entry.productionHandoffStarted = true
            return startOrJoinCancellationLocked(entry).startOwner
        }
        startOwner?()
    }

    private func startOrJoinCancellationLocked(
        _ entry: Entry
    ) -> CliEngineAdapterGenerationV1.CancellationOwnerJoin {
        entry.generation.startOrJoinCancellation(
            operation: entry.cancellation,
            onComplete: { [weak self] generation, ownerToken in
                self?.completeCancellation(
                    generation: generation,
                    ownerToken: ownerToken
                )
            }
        )
    }

    func acknowledgeCancellation(
        _ claim: EngineAdapterCancellationClaimV1
    ) {
        lock.withLock {
            guard let entry = entries[claim.executionId],
                  entry.generation.token === claim.generationToken,
                  entry.generation.matchesCancellationOwner(
                      claim.ownerToken
                  ),
                  entry.publicClaimTokens.removeValue(
                      forKey: ObjectIdentifier(claim.claimToken)
                  ) === claim.claimToken
            else { return }
            entry.outstandingLiveClaimTokens.remove(
                ObjectIdentifier(claim.claimToken)
            )
            entry.productionHandoffAcknowledged = true
            retireIfEligibleLocked(
                executionId: claim.executionId,
                entry: entry
            )
        }
    }

    private func completeCancellation(
        generation: CliEngineAdapterGenerationV1,
        ownerToken: EngineAdapterCancellationOwnerTokenV1
    ) {
        let observer = lock.withLock { ()
            -> (@Sendable () -> Void)? in
            guard let entry = entries[generation.executionId],
                  entry.generation === generation,
                  entry.generation.token === generation.token,
                  generation.matchesCancellationOwner(ownerToken),
                  generation.isCancellationOwnerSettled(ownerToken),
                  !entry.ownerSettlementPublished
            else { return nil }
            entry.outstandingLiveClaimTokens.removeAll()
            return entry.cancellationOwnerSettled
        }
        observer?()
        lock.withLock {
            guard let entry = entries[generation.executionId],
                  entry.generation === generation,
                  generation.matchesCancellationOwner(ownerToken),
                  generation.isCancellationOwnerSettled(ownerToken)
            else { return }
            entry.ownerSettlementPublished = true
            retireIfEligibleLocked(
                executionId: generation.executionId,
                entry: entry
            )
        }
    }

    private func markOuterTaskSettled(
        executionId: String,
        generation: CliEngineAdapterGenerationV1
    ) {
        generation.markOuterTaskSettledForCancellation()
        lock.withLock {
            guard let entry = entries[executionId],
                  entry.generation === generation
            else { return }
            retireIfEligibleLocked(executionId: executionId, entry: entry)
        }
    }

    private func retireIfEligibleLocked(
        executionId: String,
        entry: Entry
    ) {
        guard entries[executionId] === entry,
              entry.generation.snapshotOutcome() != nil,
              entry.generation.isOuterTaskSettledForCancellation(),
              entry.outstandingLiveClaimTokens.isEmpty
        else { return }

        if entry.generation.hasCancellationOwner() {
            guard entry.ownerSettlementPublished,
                  entry.productionHandoffRequired,
                  entry.productionHandoffAcknowledged
            else { return }
        } else {
            guard !entry.productionHandoffRequired,
                  entry.publicClaimTokens.isEmpty
            else { return }
        }
        entries[executionId] = nil
    }
}

private enum CliEngineAdapterRegistryNamespaceV1 {
    static let shared = CliEngineAdapterTaskRegistryV1()
}

package struct CliEngineAdapter: ExecutionEngineAdapter {
    package let profile: RuntimeProfileRecord
    package let descriptor: ExecutionEngineDescriptor
    package let processDriver: any CliProcessDrivingV1
    package let configuration: CliEngineRuntimeConfigurationV1
    package let commandBuilder: CliEngineCommandBuilderV1
    package let codexParser: CodexCliEventParserV1
    package let claudeParserFactory: ClaudeCliEventParserFactoryV1
    package let sanitizer: CliEngineSecretSanitizerV1
    package let context: EngineResolvedContextTransportV1
    package let workspace: EngineResolvedWorkspaceV1
    package let boundCapabilityTools: EngineBoundCapabilityToolsV1
    package let resolvedSessionRef: EngineSessionReferenceV1?
    package let terminalSink: any EngineTerminalSink
    package let boardTerminalSink: any EngineBoardTerminalSink
    package let progressSink: any EngineProgressSink
    package let cancellationLifecycleObserver: @Sendable (
        CliEngineAdapterCancellationLifecycleEventV1
    ) -> Void
    private var taskRegistry: CliEngineAdapterTaskRegistryV1 {
        CliEngineAdapterRegistryNamespaceV1.shared
    }

    package init(
        profile: RuntimeProfileRecord,
        descriptor: ExecutionEngineDescriptor,
        processDriver: any CliProcessDrivingV1,
        configuration: CliEngineRuntimeConfigurationV1,
        commandBuilder: CliEngineCommandBuilderV1,
        codexParser: CodexCliEventParserV1,
        claudeParserFactory: @escaping ClaudeCliEventParserFactoryV1,
        sanitizer: CliEngineSecretSanitizerV1,
        context: EngineResolvedContextTransportV1,
        workspace: EngineResolvedWorkspaceV1,
        boundCapabilityTools: EngineBoundCapabilityToolsV1,
        resolvedSessionRef: EngineSessionReferenceV1?,
        terminalSink: any EngineTerminalSink,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink,
        cancellationLifecycleObserver: @escaping @Sendable (
            CliEngineAdapterCancellationLifecycleEventV1
        ) -> Void = { _ in }
    ) {
        self.profile = profile
        self.descriptor = descriptor
        self.processDriver = processDriver
        self.configuration = configuration
        self.commandBuilder = commandBuilder
        self.codexParser = codexParser
        self.claudeParserFactory = claudeParserFactory
        self.sanitizer = sanitizer
        self.context = context
        self.workspace = workspace
        self.boundCapabilityTools = boundCapabilityTools
        self.resolvedSessionRef = resolvedSessionRef
        self.terminalSink = terminalSink
        self.boardTerminalSink = boardTerminalSink
        self.progressSink = progressSink
        self.cancellationLifecycleObserver = cancellationLifecycleObserver
    }

    package func descriptor(
        profile: RuntimeProfileRecord
    ) throws -> ExecutionEngineDescriptor {
        guard profile.id == self.profile.id,
              profile.kind == self.profile.kind,
              descriptor.profileKind == self.profile.kind,
              descriptor.adapterId == expectedAdapterID(for: self.profile.kind),
              descriptor.adapterVersion == "1"
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        return descriptor
    }

    package func execute(
        request: EngineExecutionRequest
    ) -> AsyncThrowingStream<EngineExecutionEventPayloadV1, Error> {
        AsyncThrowingStream { continuation in
            let generation: CliEngineAdapterGenerationV1
            do {
                generation = try taskRegistry.reserve(
                    executionId: request.executionId,
                    cancellation: { generation, cancellationAuthority in
                        try await resolveCancellation(
                            generation: generation,
                            cancellationAuthority: cancellationAuthority
                        )
                    },
                    cancellationOwnerSettled: {
                        cancellationLifecycleObserver(
                            .cancellationOwnerSettled
                        )
                    }
                )
            } catch {
                continuation.finish(throwing: error)
                return
            }
            let gate = CliEngineAdapterPublicationGateV1()
            let task = Task {
                await gate.waitUntilOpened()
                let rawResult: Result<Void, any Error>
                do {
                    let effectiveSessionRef = try effectiveSessionReference(
                        for: request
                    )
                    try await executeTask(
                        request,
                        effectiveSessionRef: effectiveSessionRef,
                        generation: generation,
                        continuation: continuation
                    )
                    rawResult = .success(())
                } catch {
                    rawResult = .failure(error)
                }
                let result = taskRegistry.publishOutcome(
                    executionId: request.executionId,
                    generation: generation,
                    result: rawResult,
                    outerTaskIsCancelled: Task.isCancelled
                )
                cancellationLifecycleObserver(.outcomePublished)
                if case let .failure(error) = result {
                    continuation.finish(throwing: error)
                }
                try result.get()
            }
            do {
                try taskRegistry.attach(
                    task,
                    executionId: request.executionId,
                    generation: generation
                )
            } catch {
                task.cancel()
                gate.open()
                continuation.finish(throwing: error)
                return
            }
            continuation.onTermination = { termination in
                guard case .cancelled = termination else { return }
                taskRegistry.signalCancellation(
                    executionId: request.executionId,
                    generation: generation
                )
            }
            gate.open()
        }
    }

    package func claimCancellation(
        executionId: String
    ) async throws -> EngineAdapterCancellationClaimV1 {
        try taskRegistry.claimCancellation(executionId: executionId)
    }

    package func acknowledgeCancellation(
        _ claim: EngineAdapterCancellationClaimV1
    ) {
        taskRegistry.acknowledgeCancellation(claim)
    }

    package func cancel(executionId: String) async throws {
        let claim = try await claimCancellation(executionId: executionId)
        defer { acknowledgeCancellation(claim) }
        do {
            try await claim.wait()
        } catch is CancellationError {
        }
    }

    private func resolveCancellation(
        generation: CliEngineAdapterGenerationV1,
        cancellationAuthority:
            CliEngineAdapterGenerationV1.CancellationAuthority
    ) async throws {
        cancellationLifecycleObserver(.beforeOuterTaskLoad)
        let outerTask = await generation.waitForOuterTask()
        cancellationLifecycleObserver(.outerTaskLoaded(outerTask != nil))
        var firstError: (any Error)?
        if case .cleanupOwner = cancellationAuthority,
           generation.snapshotOutcome() == nil
        {
            do {
                try await cancelProcess(generation: generation)
            } catch {
                firstError = error
            }
            if let firstError {
                generation.recordFailureBeforeOuterCancellation(firstError)
            }
            outerTask?.cancel()
        }

        let outcome = await generation.waitForOutcome()
        if let outerTask {
            _ = await outerTask.result
            generation.markOuterTaskSettledForCancellation()
        } else {
            await generation.waitUntilOuterTaskSettledForCancellation()
        }
        if let firstError { throw firstError }
        if case let .failure(error) = outcome,
           !(error is CancellationError)
        {
            throw error
        }
    }

    private func cancelProcess(
        generation: CliEngineAdapterGenerationV1
    ) async throws {
        switch generation.snapshotLaunchPhase() {
        case .unlaunched, .terminal:
            return
        case .launchReturned:
            do {
                try await cancelRegisteredProcess(
                    executionId: generation.executionId
                )
            } catch {
                guard isExactProcessNotRegistered(
                    error,
                    executionId: generation.executionId
                ) else { throw error }
            }
        case .prelaunch:
            do {
                try await cancelRegisteredProcess(
                    executionId: generation.executionId
                )
                _ = generation.publishPrelaunchDecision(
                    .abortUnlaunched(.success(()))
                )
                return
            } catch {
                if !isExactProcessNotRegistered(
                    error,
                    executionId: generation.executionId
                ) {
                    _ = generation.publishPrelaunchDecision(
                        .abortUnlaunched(.failure(error))
                    )
                    throw error
                }
            }
            guard generation.publishPrelaunchDecision(.retryAfterLaunch)
            else { return }
            guard case .launchReturned =
                await generation.waitUntilLaunchResolved()
            else { return }
            do {
                try await cancelRegisteredProcess(
                    executionId: generation.executionId
                )
            } catch {
                guard isExactProcessNotRegistered(
                    error,
                    executionId: generation.executionId
                ) else { throw error }
            }
        case .launching:
            do {
                try await cancelRegisteredProcess(
                    executionId: generation.executionId
                )
                return
            } catch {
                guard isExactProcessNotRegistered(
                    error,
                    executionId: generation.executionId
                ) else { throw error }
            }
            guard case .launchReturned =
                await generation.waitUntilLaunchResolved()
            else { return }
            do {
                try await cancelRegisteredProcess(
                    executionId: generation.executionId
                )
            } catch {
                guard isExactProcessNotRegistered(
                    error,
                    executionId: generation.executionId
                ) else { throw error }
            }
        }
    }

    private func cancelRegisteredProcess(
        executionId: String
    ) async throws {
        let evidence = try await processDriver.cancel(
            executionId: executionId
        )
        try validateCancellationEvidence(evidence)
    }

    private func isExactProcessNotRegistered(
        _ error: any Error,
        executionId: String
    ) -> Bool {
        guard let backendError = error as? CliProcessBackendError,
              case let .processNotRegistered(registeredID) = backendError
        else { return false }
        return stringsAreByteEqual(registeredID, executionId)
    }

    private enum ProviderParserV1: Sendable {
        case codex(CodexCliEventParserV1)
        case claude(ClaudeCliEventParserV1)

        func parse(_ line: String) throws -> [CliProviderEventV1] {
            switch self {
            case let .codex(parser):
                try parser.parse(line: line)
            case let .claude(parser):
                try parser.parse(line: line)
            }
        }
    }

    private func executeTask(
        _ request: EngineExecutionRequest,
        effectiveSessionRef: EngineSessionReferenceV1?,
        generation: CliEngineAdapterGenerationV1,
        continuation:
            AsyncThrowingStream<EngineExecutionEventPayloadV1, Error>
                .Continuation
    ) async throws {
        do {
            try Task.checkCancellation()
            try validateRequest(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled || generation.cancellationOwnsTerminal() {
                throw error
            }
            let finished = await submitFailure(
                reason: .capabilityUnsupported,
                executionId: request.executionId,
                generation: generation,
                continuation: continuation
            )
            if !finished { continuation.finish() }
            return
        }

        let session: CliEngineSessionCommandV1
        let expectedClaudeSessionID: String
        if let sessionRef = effectiveSessionRef {
            session = .resume(externalID: sessionRef.externalSessionId)
            expectedClaudeSessionID = sessionRef.externalSessionId
        } else {
            session = .first(ranchUUID: configuration.ranchSessionId)
            expectedClaudeSessionID = configuration.ranchSessionId
        }

        let parser: ProviderParserV1
        do {
            try Task.checkCancellation()
            switch profile.kind {
            case .cliCodex:
                parser = .codex(codexParser)
            case .cliClaude:
                parser = .claude(
                    try claudeParserFactory(expectedClaudeSessionID)
                )
            case .anthropicAPI, .openAIAPI, .chatGPTOAuth:
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled || generation.cancellationOwnsTerminal() {
                throw error
            }
            let finished = await submitFailure(
                reason: .protocolViolation,
                executionId: request.executionId,
                generation: generation,
                continuation: continuation
            )
            if !finished { continuation.finish() }
            return
        }

        let boardSocketURL: URL
        let boardToken: String
        let boardCardID = request.cardId
        let spec: CliCommandSpec
        do {
            try Task.checkCancellation()
            boardSocketURL = try BoardToolServer.makeSocketURL(
                directoryAuthority:
                    configuration.boardSocketDirectoryAuthority,
                executionId: request.executionId
            )
            boardToken = BoardToolServer.makeToken()
            let toolNames = boundCapabilityTools.logicalDefinitions
                .map(\.name).sorted()
            let claudeConfigURL = configuration.claudeConfigDirectory
                .appendingPathComponent(
                    "agentloop-\(request.executionId).mcp.json"
                )
            let input = try CliEngineCommandInputV1(
                command: configuration.command,
                cliExecutableAuthority:
                    configuration.cliExecutableAuthority,
                workspaceURL: workspace.url,
                sandbox: configuration.sandbox,
                model: request.model,
                reasoningEffort: configuration.reasoningEffort,
                prompt: try prompt(),
                bridgeExecutableAuthority:
                    configuration.bridgeExecutableAuthority,
                boardSocketURL: boardSocketURL,
                boardToken: boardToken,
                boardCardId: boardCardID,
                toolNames: toolNames,
                claudeConfigURL: claudeConfigURL,
                session: session
            )
            try Task.checkCancellation()
            switch profile.kind {
            case .cliCodex:
                spec = try commandBuilder.buildCodex(input)
            case .cliClaude:
                spec = try commandBuilder.buildClaude(input)
            case .anthropicAPI, .openAIAPI, .chatGPTOAuth:
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled || generation.cancellationOwnsTerminal() {
                throw error
            }
            let finished = await submitFailure(
                reason: .processOutcomeUnknown,
                executionId: request.executionId,
                generation: generation,
                continuation: continuation
            )
            if !finished { continuation.finish() }
            return
        }

        let launchRequest: CliProcessLaunchRequestV1
        do {
            try Task.checkCancellation()
            launchRequest = try CliProcessLaunchRequestV1(
                executionId: request.executionId,
                spec: spec,
                cliExecutableAuthority:
                    configuration.cliExecutableAuthority,
                workspaceURL: workspace.url,
                boundCapabilityTools: boundCapabilityTools,
                bridgeExecutableAuthority:
                    configuration.bridgeExecutableAuthority,
                boardSocketDirectoryAuthority:
                    configuration.boardSocketDirectoryAuthority,
                boardSocketBasename: boardSocketURL.lastPathComponent,
                boardToken: boardToken,
                boardCardId: boardCardID,
                boardTerminalSink: boardTerminalSink,
                progressSink: progressSink
            )
        } catch is CancellationError {
            try removeUnlaunchedCleanupFiles(spec.cleanupAuthorities)
            throw CancellationError()
        } catch {
            let launchError = error
            do {
                try removeUnlaunchedCleanupFiles(
                    spec.cleanupAuthorities
                )
            } catch {
                if Task.isCancelled
                    || generation.cancellationOwnsTerminal()
                {
                    throw error
                }
                let finished = await submitFailure(
                    reason: .processOutcomeUnknown,
                    executionId: request.executionId,
                    generation: generation,
                    continuation: continuation
                )
                if !finished { continuation.finish() }
                return
            }
            if Task.isCancelled || generation.cancellationOwnsTerminal() {
                throw launchError
            }
            let finished = await submitFailure(
                reason: .processOutcomeUnknown,
                executionId: request.executionId,
                generation: generation,
                continuation: continuation
            )
            if !finished { continuation.finish() }
            return
        }

        var adapterTerminalSubmitted = false
        var continuationFinished = false
        var exitStatus: Int32?
        var sawProviderResult = false
        do {
            try Task.checkCancellation()
            switch await generation.prepareLaunch() {
            case .launch:
                break
            case let .abortUnlaunched(result):
                try removeUnlaunchedCleanupFiles(spec.cleanupAuthorities)
                do {
                    try result.get()
                    continuation.finish()
                    return
                } catch {
                    throw error
                }
            }
            let stream = processDriver.launch(launchRequest)
            generation.publishLaunchReturned()
            try Task.checkCancellation()
            for try await frame in stream {
                try Task.checkCancellation()
                if adapterTerminalSubmitted { continue }
                switch frame {
                case let .stdoutLine(line):
                    let events: [CliProviderEventV1]
                    do {
                        events = try parser.parse(line)
                    } catch {
                        if generation.cancellationOwnsTerminal() {
                            throw error
                        }
                        adapterTerminalSubmitted = true
                        continuationFinished = await submitFailure(
                            reason: .protocolViolation,
                            executionId: request.executionId,
                            generation: generation,
                            continuation: continuation
                        )
                        continue
                    }
                    for event in events {
                        switch event {
                        case let .sessionBound(externalSessionId):
                            if let effectiveSessionRef,
                               !stringsAreByteEqual(
                                   externalSessionId,
                                   effectiveSessionRef.externalSessionId
                               )
                            {
                                adapterTerminalSubmitted = true
                                continuationFinished = await submitFailure(
                                    reason: .protocolViolation,
                                    executionId: request.executionId,
                                    generation: generation,
                                    continuation: continuation
                                )
                            } else {
                                continuation.yield(
                                    .sessionBound(
                                        externalSessionId: externalSessionId
                                    )
                                )
                            }
                        case let .progress(message):
                            continuation.yield(.progress(message: message))
                        case let .toolActivity(name):
                            continuation.yield(.toolActivity(name: name))
                        case let .usage(usage):
                            continuation.yield(.usage(usage))
                        case .providerError:
                            adapterTerminalSubmitted = true
                            continuationFinished = await submitFailure(
                                reason: .providerFailure,
                                executionId: request.executionId,
                                generation: generation,
                                continuation: continuation
                            )
                        case .result:
                            sawProviderResult = true
                        }
                        if adapterTerminalSubmitted { break }
                    }
                case .stderr:
                    break
                case let .exited(status):
                    exitStatus = status
                }
            }
            try Task.checkCancellation()
            if generation.cancellationOwnsTerminal() {
                if !continuationFinished { continuation.finish() }
                return
            }
            if !adapterTerminalSubmitted {
                let reason: CliEngineFailureReasonV1
                if sawProviderResult {
                    reason = .protocolViolation
                } else if exitStatus == nil {
                    reason = .processOutcomeUnknown
                } else if exitStatus.map({ $0 != 0 }) == true {
                    reason = .processOutcomeUnknown
                } else {
                    reason = .protocolViolation
                }
                continuationFinished = await submitFailure(
                    reason: reason,
                    executionId: request.executionId,
                    generation: generation,
                    continuation: continuation
                )
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled || generation.cancellationOwnsTerminal() {
                throw error
            }
            if !adapterTerminalSubmitted {
                continuationFinished = await submitFailure(
                    reason: .processOutcomeUnknown,
                    executionId: request.executionId,
                    generation: generation,
                    continuation: continuation
                )
            }
        }
        if !continuationFinished { continuation.finish() }
    }

    private func effectiveSessionReference(
        for request: EngineExecutionRequest
    ) throws -> EngineSessionReferenceV1? {
        let effective: EngineSessionReferenceV1?
        switch (request.sessionRef, resolvedSessionRef) {
        case (nil, nil):
            effective = nil
        case let (.some(requestReference), nil):
            effective = requestReference
        case let (nil, .some(resolvedReference)):
            effective = resolvedReference
        case let (.some(requestReference), .some(resolvedReference)):
            guard sessionReferencesAreByteEqual(
                requestReference,
                resolvedReference
            ) else {
                throw EngineSessionScopeMismatchError()
            }
            effective = requestReference
        }
        guard effective != nil else { return nil }
        guard profile.kind.isCLI,
              descriptor.profileKind == profile.kind,
              descriptor.adapterId == expectedAdapterID(for: profile.kind),
              descriptor.adapterVersion == "1",
              descriptor.sessionResume == .supported
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        return effective
    }

    private func sessionReferencesAreByteEqual(
        _ lhs: EngineSessionReferenceV1,
        _ rhs: EngineSessionReferenceV1
    ) -> Bool {
        stringsAreByteEqual(lhs.sessionId, rhs.sessionId)
            && stringsAreByteEqual(
                lhs.externalSessionId,
                rhs.externalSessionId
            )
    }

    private func stringsAreByteEqual(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.elementsEqual(rhs.utf8)
    }

    private func validateCancellationEvidence(
        _ evidence: CliProcessExitEvidenceV1
    ) throws {
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
    }

    private func validateRequest(_ request: EngineExecutionRequest) throws {
        try request.validateCanonicalIdentity()
        guard profile.kind == .cliCodex || profile.kind == .cliClaude,
              request.profileId == profile.id,
              request.engineKind == descriptor.adapterId,
              request.adapterId == descriptor.adapterId,
              request.adapterVersion == descriptor.adapterVersion,
              descriptor.adapterId == expectedAdapterID(for: profile.kind),
              descriptor.adapterVersion == "1",
              descriptor.profileKind == profile.kind,
              request.contextJson == context.canonicalEnvelopeJSON,
              request.contextHash == context.hash,
              request.campId == workspace.identity.campId,
              request.workspace.reference
                == "squad-workspace.v1:\(workspace.identity.squadId)",
              processDriver.supportsProcessGroupCancellation,
              request.requiredCapabilities.allSatisfy({ capability in
                  descriptor.support(for: capability) == .supported
              })
        else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        try CanonicalContractCodingV1.validateNonempty(request.model)
    }

    private func prompt() throws -> String {
        try CliEnginePromptV1.render(context)
    }

    private func expectedAdapterID(
        for kind: RuntimeProfileKind
    ) -> String? {
        switch kind {
        case .cliCodex:
            "agentloop.cli.codex"
        case .cliClaude:
            "agentloop.cli.claude"
        case .anthropicAPI, .openAIAPI, .chatGPTOAuth:
            nil
        }
    }

    private func submitFailure(
        reason: CliEngineFailureReasonV1,
        executionId: String
    ) async throws {
        let failure = try sanitizer.failure(
            reason: reason,
            executionId: executionId
        )
        try await terminalSink.submit(failure.intent)
    }

    private func submitFailure(
        reason: CliEngineFailureReasonV1,
        executionId: String,
        generation: CliEngineAdapterGenerationV1,
        continuation:
            AsyncThrowingStream<EngineExecutionEventPayloadV1, Error>
                .Continuation
    ) async -> Bool {
        guard generation.claimTerminalAuthority() else { return false }
        do {
            try await submitFailure(
                reason: reason,
                executionId: executionId
            )
            return false
        } catch let duplicate as EngineDuplicateTerminalErrorV1 {
            continuation.finish(throwing: duplicate)
            return true
        } catch {
            continuation.finish(throwing: EngineContextValidationErrorV1())
            return true
        }
    }

    private func removeUnlaunchedCleanupFiles(
        _ authorities: [CliCleanupFileAuthorityV1]
    ) throws {
        for authority in authorities {
            do {
                try authority.removeExpectedFile()
            } catch {
                throw EngineContextValidationErrorV1()
            }
        }
    }
}
