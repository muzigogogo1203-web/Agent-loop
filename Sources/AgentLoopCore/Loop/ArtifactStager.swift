import CryptoKit
import Darwin
import Foundation

package enum ArtifactPreparationCheckpointV1: Sendable, Equatable {
    case afterTemporaryCreate
    case afterTemporaryFileSync
    case afterBlobRename
    case afterBlobDirectorySync
    case beforeDatabaseMutation
    case afterBlobUpsert
    case afterProposalArtifactCAS
}

package enum ArtifactManifestBuildErrorV1: Error, Sendable, Equatable {
    case tooManyArtifacts
    case duplicatePath(ordinal: Int)
    case invalidPath(ordinal: Int)
    case missing(ordinal: Int)
    case symbolicLink(ordinal: Int)
    case notRegularFile(ordinal: Int)
    case changedDuringRead(ordinal: Int)
    case readFailed(ordinal: Int)
}

package final class ArtifactStager: @unchecked Sendable {
    private let database: AppDatabase
    private let blobStore: ArtifactBlobStore
    private let checkpoint:
        (@Sendable (ArtifactPreparationCheckpointV1) throws -> Void)?

    package init(
        database: AppDatabase,
        blobStore: ArtifactBlobStore,
        checkpoint:
            (@Sendable (ArtifactPreparationCheckpointV1) throws -> Void)? = nil
    ) {
        self.database = database
        self.blobStore = blobStore
        self.checkpoint = checkpoint
    }

    package func prepare(
        proposalId: String,
        workspaceRoot: URL,
        expectedWorkspaceHash: String
    ) throws -> [PreparedArtifactV1] {
        _ = database
        return try blobStore.prepareArtifacts(
            proposalId: proposalId,
            workspaceRoot: workspaceRoot,
            expectedWorkspaceHash: expectedWorkspaceHash,
            checkpoint: checkpoint
        )
    }

    package func recoverPreparation(
        proposalId: String,
        workspaceRoot: URL,
        expectedWorkspaceHash: String
    ) throws -> [PreparedArtifactV1] {
        _ = database
        return try blobStore.prepareArtifacts(
            proposalId: proposalId,
            workspaceRoot: workspaceRoot,
            expectedWorkspaceHash: expectedWorkspaceHash,
            checkpoint: checkpoint
        )
    }

    package func cleanOrphanedStaging() throws {
        _ = database
        try blobStore.cleanOrphanedStagingFiles()
    }

    package func buildManifest(
        workspaceRoot: URL,
        handoff: HandoffPayload
    ) throws -> [EngineTerminalArtifactDeclarationV1] {
        guard handoff.artifacts.count <= 256 else {
            throw ArtifactManifestBuildErrorV1.tooManyArtifacts
        }
        guard !handoff.artifacts.isEmpty else { return [] }

        var paths = Set<String>()
        var componentsByOrdinal: [[String]] = []
        componentsByOrdinal.reserveCapacity(handoff.artifacts.count)
        for (ordinal, artifact) in handoff.artifacts.enumerated() {
            let components = try Self.validatedComponents(
                artifact.relativePath,
                ordinal: ordinal
            )
            guard paths.insert(artifact.relativePath).inserted else {
                throw ArtifactManifestBuildErrorV1.duplicatePath(
                    ordinal: ordinal
                )
            }
            componentsByOrdinal.append(components)
        }

        let rootDescriptor = try Self.openWorkspaceRoot(
            workspaceRoot,
            ordinal: 0
        )
        defer { Darwin.close(rootDescriptor) }

        return try zip(handoff.artifacts, componentsByOrdinal)
            .enumerated()
            .map { ordinal, pair in
                let (artifact, components) = pair
                let measured = try Self.measureRegularFile(
                    rootDescriptor: rootDescriptor,
                    components: components,
                    ordinal: ordinal
                )
                return EngineTerminalArtifactDeclarationV1(
                    ordinal: ordinal,
                    sourceRelativePath: artifact.relativePath,
                    kind: artifact.kind,
                    label: artifact.label,
                    byteCount: measured.byteCount,
                    contentHash: measured.contentHash
                )
            }
    }

    private struct MeasuredFile {
        let byteCount: Int
        let contentHash: String
    }

    private static func validatedComponents(
        _ path: String,
        ordinal: Int
    ) throws -> [String] {
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.hasSuffix("/"),
              !path.contains("\\"),
              !path.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              })
        else {
            throw ArtifactManifestBuildErrorV1.invalidPath(ordinal: ordinal)
        }
        let components = path.split(
            separator: "/",
            omittingEmptySubsequences: false
        ).map(String.init)
        guard components.allSatisfy({ component in
            !component.isEmpty && component != "." && component != ".."
        }) else {
            throw ArtifactManifestBuildErrorV1.invalidPath(ordinal: ordinal)
        }
        return components
    }

    private static func openWorkspaceRoot(
        _ root: URL,
        ordinal: Int
    ) throws -> Int32 {
        guard root.isFileURL, root.path.hasPrefix("/") else {
            throw ArtifactManifestBuildErrorV1.invalidPath(ordinal: ordinal)
        }
        var pathStatus = stat()
        guard Darwin.lstat(root.path, &pathStatus) == 0 else {
            throw mappedOpenError(errno, ordinal: ordinal)
        }
        if isSymbolicLink(pathStatus) {
            throw ArtifactManifestBuildErrorV1.symbolicLink(ordinal: ordinal)
        }
        guard isDirectory(pathStatus) else {
            throw ArtifactManifestBuildErrorV1.notRegularFile(ordinal: ordinal)
        }

        let descriptor = Darwin.open(
            root.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else {
            throw mappedOpenError(errno, ordinal: ordinal)
        }
        var openedStatus = stat()
        guard Darwin.fstat(descriptor, &openedStatus) == 0 else {
            Darwin.close(descriptor)
            throw ArtifactManifestBuildErrorV1.readFailed(ordinal: ordinal)
        }
        guard isDirectory(openedStatus) else {
            Darwin.close(descriptor)
            throw ArtifactManifestBuildErrorV1.notRegularFile(ordinal: ordinal)
        }
        guard sameIdentity(pathStatus, openedStatus) else {
            Darwin.close(descriptor)
            throw ArtifactManifestBuildErrorV1.changedDuringRead(
                ordinal: ordinal
            )
        }
        return descriptor
    }

    private static func measureRegularFile(
        rootDescriptor: Int32,
        components: [String],
        ordinal: Int
    ) throws -> MeasuredFile {
        let duplicatedRoot = Darwin.fcntl(
            rootDescriptor,
            F_DUPFD_CLOEXEC,
            0
        )
        guard duplicatedRoot >= 0 else {
            throw ArtifactManifestBuildErrorV1.readFailed(ordinal: ordinal)
        }
        var directoryDescriptor = duplicatedRoot
        defer { Darwin.close(directoryDescriptor) }

        for component in components.dropLast() {
            var pathStatus = stat()
            let statusResult = component.withCString { name in
                Darwin.fstatat(
                    directoryDescriptor,
                    name,
                    &pathStatus,
                    AT_SYMLINK_NOFOLLOW
                )
            }
            guard statusResult == 0 else {
                throw mappedOpenError(errno, ordinal: ordinal)
            }
            if isSymbolicLink(pathStatus) {
                throw ArtifactManifestBuildErrorV1.symbolicLink(
                    ordinal: ordinal
                )
            }
            guard isDirectory(pathStatus) else {
                throw ArtifactManifestBuildErrorV1.notRegularFile(
                    ordinal: ordinal
                )
            }
            let nextDescriptor = component.withCString { name in
                Darwin.openat(
                    directoryDescriptor,
                    name,
                    O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
                )
            }
            guard nextDescriptor >= 0 else {
                throw mappedOpenError(errno, ordinal: ordinal)
            }
            var openedStatus = stat()
            guard Darwin.fstat(nextDescriptor, &openedStatus) == 0 else {
                Darwin.close(nextDescriptor)
                throw ArtifactManifestBuildErrorV1.readFailed(
                    ordinal: ordinal
                )
            }
            guard isDirectory(openedStatus) else {
                Darwin.close(nextDescriptor)
                throw ArtifactManifestBuildErrorV1.notRegularFile(
                    ordinal: ordinal
                )
            }
            guard sameIdentity(pathStatus, openedStatus) else {
                Darwin.close(nextDescriptor)
                throw ArtifactManifestBuildErrorV1.changedDuringRead(
                    ordinal: ordinal
                )
            }
            Darwin.close(directoryDescriptor)
            directoryDescriptor = nextDescriptor
        }

        guard let finalComponent = components.last else {
            throw ArtifactManifestBuildErrorV1.invalidPath(ordinal: ordinal)
        }
        var pathStatus = stat()
        let statusResult = finalComponent.withCString { name in
            Darwin.fstatat(
                directoryDescriptor,
                name,
                &pathStatus,
                AT_SYMLINK_NOFOLLOW
            )
        }
        guard statusResult == 0 else {
            throw mappedOpenError(errno, ordinal: ordinal)
        }
        if isSymbolicLink(pathStatus) {
            throw ArtifactManifestBuildErrorV1.symbolicLink(ordinal: ordinal)
        }
        guard isRegularFile(pathStatus) else {
            throw ArtifactManifestBuildErrorV1.notRegularFile(ordinal: ordinal)
        }

        let fileDescriptor = finalComponent.withCString { name in
            Darwin.openat(
                directoryDescriptor,
                name,
                O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard fileDescriptor >= 0 else {
            throw mappedOpenError(errno, ordinal: ordinal)
        }
        defer { Darwin.close(fileDescriptor) }

        var before = stat()
        guard Darwin.fstat(fileDescriptor, &before) == 0 else {
            throw ArtifactManifestBuildErrorV1.readFailed(ordinal: ordinal)
        }
        guard isRegularFile(before) else {
            throw ArtifactManifestBuildErrorV1.notRegularFile(ordinal: ordinal)
        }
        guard sameIdentity(pathStatus, before) else {
            throw ArtifactManifestBuildErrorV1.changedDuringRead(
                ordinal: ordinal
            )
        }

        let measured = try hash(
            fileDescriptor: fileDescriptor,
            ordinal: ordinal
        )
        var after = stat()
        guard Darwin.fstat(fileDescriptor, &after) == 0 else {
            throw ArtifactManifestBuildErrorV1.readFailed(ordinal: ordinal)
        }
        guard before.st_size >= 0,
              UInt64(before.st_size) <= UInt64(Int.max)
        else {
            throw ArtifactManifestBuildErrorV1.readFailed(ordinal: ordinal)
        }
        guard sameSnapshot(before, after),
              measured.byteCount == Int(before.st_size)
        else {
            throw ArtifactManifestBuildErrorV1.changedDuringRead(
                ordinal: ordinal
            )
        }

        var finalPathStatus = stat()
        let finalStatusResult = finalComponent.withCString { name in
            Darwin.fstatat(
                directoryDescriptor,
                name,
                &finalPathStatus,
                AT_SYMLINK_NOFOLLOW
            )
        }
        guard finalStatusResult == 0,
              isRegularFile(finalPathStatus),
              sameSnapshot(after, finalPathStatus)
        else {
            throw ArtifactManifestBuildErrorV1.changedDuringRead(
                ordinal: ordinal
            )
        }
        return measured
    }

    private static func hash(
        fileDescriptor: Int32,
        ordinal: Int
    ) throws -> MeasuredFile {
        var hasher = SHA256()
        var byteCount = 0
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let readCount = buffer.withUnsafeMutableBytes { bytes -> Int in
                while true {
                    let result = Darwin.read(
                        fileDescriptor,
                        bytes.baseAddress,
                        bytes.count
                    )
                    if result < 0, errno == EINTR { continue }
                    return result
                }
            }
            guard readCount >= 0 else {
                throw ArtifactManifestBuildErrorV1.readFailed(ordinal: ordinal)
            }
            if readCount == 0 { break }
            let (nextByteCount, overflow) = byteCount.addingReportingOverflow(
                readCount
            )
            guard !overflow else {
                throw ArtifactManifestBuildErrorV1.readFailed(ordinal: ordinal)
            }
            byteCount = nextByteCount
            hasher.update(data: Data(buffer.prefix(readCount)))
        }
        return MeasuredFile(
            byteCount: byteCount,
            contentHash: lowercaseHex(hasher.finalize())
        )
    }

    private static func mappedOpenError(
        _ code: Int32,
        ordinal: Int
    ) -> ArtifactManifestBuildErrorV1 {
        switch code {
        case ENOENT:
            return .missing(ordinal: ordinal)
        case ELOOP:
            return .symbolicLink(ordinal: ordinal)
        case ENOTDIR:
            return .notRegularFile(ordinal: ordinal)
        default:
            return .readFailed(ordinal: ordinal)
        }
    }

    private static func isDirectory(_ value: stat) -> Bool {
        value.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR)
    }

    private static func isRegularFile(_ value: stat) -> Bool {
        value.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG)
    }

    private static func isSymbolicLink(_ value: stat) -> Bool {
        value.st_mode & mode_t(S_IFMT) == mode_t(S_IFLNK)
    }

    private static func sameIdentity(_ lhs: stat, _ rhs: stat) -> Bool {
        lhs.st_dev == rhs.st_dev && lhs.st_ino == rhs.st_ino
    }

    private static func sameSnapshot(_ lhs: stat, _ rhs: stat) -> Bool {
        sameIdentity(lhs, rhs)
            && lhs.st_size == rhs.st_size
            && lhs.st_mtimespec.tv_sec == rhs.st_mtimespec.tv_sec
            && lhs.st_mtimespec.tv_nsec == rhs.st_mtimespec.tv_nsec
    }

    private static func lowercaseHex<D: Sequence>(_ digest: D) -> String
    where D.Element == UInt8 {
        let alphabet = Array("0123456789abcdef".utf8)
        var result: [UInt8] = []
        result.reserveCapacity(64)
        for byte in digest {
            result.append(alphabet[Int(byte >> 4)])
            result.append(alphabet[Int(byte & 0x0f)])
        }
        return String(decoding: result, as: UTF8.self)
    }
}
