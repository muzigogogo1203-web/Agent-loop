import Darwin
import Foundation

package struct ManagedExpeditionReportOwnerScopeV1:
    Codable, Sendable, Equatable
{
    package let missionId: String
    package let squadId: String
    package let campId: String

    package init(
        missionId: String,
        squadId: String,
        campId: String
    ) {
        self.missionId = missionId
        self.squadId = squadId
        self.campId = campId
    }
}

package struct ManagedExpeditionReportCursorV1:
    Codable, Sendable, Equatable
{
    package let schemaVersion: Int
    package let missionId: String
    package let campId: String
    package let contentHash: String
    package let byteCount: Int
    package let temporaryName: String
    package let finalName: String

    package init(
        missionId: String,
        campId: String,
        contentHash: String,
        byteCount: Int,
        temporaryName: String,
        finalName: String
    ) {
        self.schemaVersion = 1
        self.missionId = missionId
        self.campId = campId
        self.contentHash = contentHash
        self.byteCount = byteCount
        self.temporaryName = temporaryName
        self.finalName = finalName
    }
}

package enum ManagedExpeditionReportCheckpointV1: Sendable, Equatable {
    case afterTemporaryFileSync
    case afterCursorFileSync
    case afterFinalRename
    case afterReportDirectorySync
}

enum ManagedExpeditionReportStoreErrorV1: Error, Sendable, Equatable {
    case invalidRoot(String)
    case invalidMissionId(String)
    case invalidCursor(String)
    case fileSystem(path: String, operation: String, code: Int32)
    case irregularFile(String)
    case fileChanged(String)
    case missingReport(String)
    case byteCountMismatch(path: String, expected: Int, actual: Int)
    case contentMismatch(path: String, expected: String, actual: String)
    case ownerScopeChanged(String)
}

private struct ManagedExpeditionReportRenderV1 {
    let scope: ManagedExpeditionReportOwnerScopeV1
    let bytes: Data
    let contentHash: String
    let temporaryName: String
    let cursorName: String
    let finalName: String

    var cursor: ManagedExpeditionReportCursorV1 {
        ManagedExpeditionReportCursorV1(
            missionId: scope.missionId,
            campId: scope.campId,
            contentHash: contentHash,
            byteCount: bytes.count,
            temporaryName: temporaryName,
            finalName: finalName
        )
    }
}

package final class ManagedExpeditionReportStore: @unchecked Sendable {
    private let database: AppDatabase
    private let reportStoreRoot: URL
    private let checkpoint:
        (@Sendable (ManagedExpeditionReportCheckpointV1) throws -> Void)?
    private let rootWalkCheckpoint: (@Sendable (String) throws -> Void)?
    private let bootstrapLock = NSLock()

    package init(
        database: AppDatabase,
        reportStoreRoot: URL,
        checkpoint:
            (@Sendable (ManagedExpeditionReportCheckpointV1) throws -> Void)?
            = nil,
        rootWalkCheckpoint: (@Sendable (String) throws -> Void)? = nil
    ) {
        self.database = database
        self.reportStoreRoot = reportStoreRoot.standardizedFileURL
        self.checkpoint = checkpoint
        self.rootWalkCheckpoint = rootWalkCheckpoint
    }

    package func ensureReport(missionId: String) throws -> URL {
        let initial = try render(missionId: missionId)
        return try withReportDirectory { directoryFD in
            try withCampLock(
                campId: initial.scope.campId,
                directoryFD: directoryFD
            ) {
                let current = try render(missionId: missionId)
                try requireStableOwner(initial.scope, current.scope)
                try recover(current, directoryFD: directoryFD)
                if try regularFileExists(
                    current.finalName,
                    directoryFD: directoryFD
                ) {
                    try validateFile(
                        current.finalName,
                        expected: current,
                        directoryFD: directoryFD
                    )
                } else {
                    try write(current, directoryFD: directoryFD)
                }
                return managedURL(for: current)
            }
        }
    }

    package func regenerateReport(missionId: String) throws -> URL {
        let initial = try render(missionId: missionId)
        return try withReportDirectory { directoryFD in
            try withCampLock(
                campId: initial.scope.campId,
                directoryFD: directoryFD
            ) {
                let current = try render(missionId: missionId)
                try requireStableOwner(initial.scope, current.scope)
                try recover(current, directoryFD: directoryFD)
                try write(current, directoryFD: directoryFD)
                return managedURL(for: current)
            }
        }
    }

    package func recoverPendingWrites() throws {
        try withReportDirectory { directoryFD in
            for missionId in try pendingMissionIds(directoryFD: directoryFD) {
                let initial = try render(missionId: missionId)
                try withCampLock(
                    campId: initial.scope.campId,
                    directoryFD: directoryFD
                ) {
                    let current = try render(missionId: missionId)
                    try requireStableOwner(initial.scope, current.scope)
                    try recover(current, directoryFD: directoryFD)
                }
            }
        }
    }

    package func reportURL(missionId: String) throws -> URL {
        let initial = try render(missionId: missionId)
        return try withReportDirectory { directoryFD in
            try withCampLock(
                campId: initial.scope.campId,
                directoryFD: directoryFD
            ) {
                let current = try render(missionId: missionId)
                try requireStableOwner(initial.scope, current.scope)
                guard !(try pathExists(
                    current.temporaryName,
                    directoryFD: directoryFD
                )), !(try pathExists(
                    current.cursorName,
                    directoryFD: directoryFD
                )) else {
                    throw ManagedExpeditionReportStoreErrorV1.invalidCursor(
                        current.scope.missionId
                    )
                }
                guard try regularFileExists(
                    current.finalName,
                    directoryFD: directoryFD
                ) else {
                    throw ManagedExpeditionReportStoreErrorV1.missingReport(
                        current.finalName
                    )
                }
                try validateFile(
                    current.finalName,
                    expected: current,
                    directoryFD: directoryFD
                )
                return managedURL(for: current)
            }
        }
    }

    private func render(
        missionId: String
    ) throws -> ManagedExpeditionReportRenderV1 {
        try validateMissionId(missionId)
        let input = try database.expeditionReportInput(missionId: missionId)
        guard input.mission.id == missionId,
              input.mission.squadId == input.squad.id,
              input.squad.campId == input.camp.id
        else {
            throw ManagedExpeditionReportStoreErrorV1.ownerScopeChanged(
                missionId
            )
        }
        let bytes = Data(ExpeditionReport.markdown(input).utf8)
        return ManagedExpeditionReportRenderV1(
            scope: ManagedExpeditionReportOwnerScopeV1(
                missionId: missionId,
                squadId: input.squad.id,
                campId: input.camp.id
            ),
            bytes: bytes,
            contentHash: CanonicalJSONV1.sha256Hex(bytes),
            temporaryName: ".\(missionId).report.tmp",
            cursorName: ".\(missionId).report.cursor.json",
            finalName: "\(missionId).md"
        )
    }

    private func requireStableOwner(
        _ initial: ManagedExpeditionReportOwnerScopeV1,
        _ current: ManagedExpeditionReportOwnerScopeV1
    ) throws {
        guard initial == current else {
            throw ManagedExpeditionReportStoreErrorV1.ownerScopeChanged(
                initial.missionId
            )
        }
    }

    private func managedURL(
        for render: ManagedExpeditionReportRenderV1
    ) -> URL {
        reportStoreRoot.appendingPathComponent(
            render.finalName,
            isDirectory: false
        )
    }

    private func validateMissionId(_ missionId: String) throws {
        try validatePathComponent(missionId, identity: missionId)
        guard !missionId.hasPrefix(".") else {
            throw ManagedExpeditionReportStoreErrorV1.invalidMissionId(
                missionId
            )
        }
    }

    private func withCampLock<T>(
        campId: String,
        directoryFD: Int32,
        _ body: () throws -> T
    ) throws -> T {
        let lockHash = CanonicalJSONV1.sha256Hex(Data(campId.utf8))
        let lockName = ".camp-\(lockHash).report.lock"
        let descriptor = lockName.withCString { name in
            Darwin.openat(
                directoryFD,
                name,
                O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW,
                S_IRUSR | S_IWUSR
            )
        }
        guard descriptor >= 0 else {
            throw fileSystemError(lockName, "openat")
        }
        defer { Darwin.close(descriptor) }
        var information = stat()
        guard Darwin.fstat(descriptor, &information) == 0 else {
            throw fileSystemError(lockName, "fstat")
        }
        guard information.st_mode & S_IFMT == S_IFREG,
              information.st_nlink == 1
        else {
            throw ManagedExpeditionReportStoreErrorV1.irregularFile(lockName)
        }
        while flock(descriptor, LOCK_EX) != 0 {
            if errno == EINTR { continue }
            throw fileSystemError(lockName, "flock")
        }
        defer { _ = flock(descriptor, LOCK_UN) }
        try requireLockedPathIdentity(
            descriptor,
            name: lockName,
            directoryFD: directoryFD
        )
        return try body()
    }

    private func write(
        _ render: ManagedExpeditionReportRenderV1,
        directoryFD: Int32
    ) throws {
        guard !(try pathExists(
            render.temporaryName,
            directoryFD: directoryFD
        )), !(try pathExists(
            render.cursorName,
            directoryFD: directoryFD
        )) else {
            throw ManagedExpeditionReportStoreErrorV1.invalidCursor(
                render.scope.missionId
            )
        }

        try writeNewRegularFile(
            render.bytes,
            name: render.temporaryName,
            directoryFD: directoryFD
        )
        try checkpoint?(.afterTemporaryFileSync)

        try writeNewRegularFile(
            try CanonicalJSONV1.encode(render.cursor),
            name: render.cursorName,
            directoryFD: directoryFD
        )
        try checkpoint?(.afterCursorFileSync)

        try requireReplaceableFinal(
            render.finalName,
            directoryFD: directoryFD
        )
        let renamed = render.temporaryName.withCString { temporary in
            render.finalName.withCString { final in
                Darwin.renameat(directoryFD, temporary, directoryFD, final)
            }
        }
        guard renamed == 0 else {
            throw fileSystemError(render.temporaryName, "renameat")
        }
        try checkpoint?(.afterFinalRename)

        try syncDirectory(directoryFD, path: reportStoreRoot.path)
        try checkpoint?(.afterReportDirectorySync)

        try unlink(
            render.cursorName,
            directoryFD: directoryFD,
            allowMissing: false
        )
        try syncDirectory(directoryFD, path: reportStoreRoot.path)
        try validateFile(
            render.finalName,
            expected: render,
            directoryFD: directoryFD
        )
    }

    private func recover(
        _ render: ManagedExpeditionReportRenderV1,
        directoryFD: Int32
    ) throws {
        let temporaryExists = try pathExists(
            render.temporaryName,
            directoryFD: directoryFD
        )
        let cursorExists = try pathExists(
            render.cursorName,
            directoryFD: directoryFD
        )
        guard temporaryExists || cursorExists else { return }

        if cursorExists {
            let cursorBytes = try readRegularFile(
                render.cursorName,
                directoryFD: directoryFD
            )
            do {
                try CanonicalJSONV1.validateCanonical(rawUTF8: cursorBytes)
            } catch {
                throw ManagedExpeditionReportStoreErrorV1.invalidCursor(
                    render.cursorName
                )
            }
            let decoded: ManagedExpeditionReportCursorV1
            do {
                decoded = try JSONDecoder().decode(
                    ManagedExpeditionReportCursorV1.self,
                    from: cursorBytes
                )
            } catch {
                throw ManagedExpeditionReportStoreErrorV1.invalidCursor(
                    render.cursorName
                )
            }
            let canonical = try CanonicalJSONV1.encode(decoded)
            guard canonical == cursorBytes,
                  decoded.schemaVersion == 1,
                  decoded == render.cursor,
                  decoded.temporaryName == render.temporaryName,
                  decoded.finalName == render.finalName
            else {
                throw ManagedExpeditionReportStoreErrorV1.invalidCursor(
                    render.cursorName
                )
            }
        }

        if temporaryExists {
            try validateFile(
                render.temporaryName,
                expected: render,
                directoryFD: directoryFD
            )
        }

        if temporaryExists, !cursorExists {
            try writeNewRegularFile(
                try CanonicalJSONV1.encode(render.cursor),
                name: render.cursorName,
                directoryFD: directoryFD
            )
        }

        if temporaryExists {
            if try regularFileExists(
                render.finalName,
                directoryFD: directoryFD
            ) {
                try validateFile(
                    render.finalName,
                    expected: render,
                    directoryFD: directoryFD
                )
            }
            try requireReplaceableFinal(
                render.finalName,
                directoryFD: directoryFD
            )
            let renamed = render.temporaryName.withCString { temporary in
                render.finalName.withCString { final in
                    Darwin.renameat(
                        directoryFD,
                        temporary,
                        directoryFD,
                        final
                    )
                }
            }
            guard renamed == 0 else {
                throw fileSystemError(render.temporaryName, "renameat")
            }
        } else {
            guard try regularFileExists(
                render.finalName,
                directoryFD: directoryFD
            ) else {
                throw ManagedExpeditionReportStoreErrorV1.missingReport(
                    render.finalName
                )
            }
            try validateFile(
                render.finalName,
                expected: render,
                directoryFD: directoryFD
            )
        }

        try syncDirectory(directoryFD, path: reportStoreRoot.path)
        try unlink(
            render.cursorName,
            directoryFD: directoryFD,
            allowMissing: false
        )
        try syncDirectory(directoryFD, path: reportStoreRoot.path)
        try validateFile(
            render.finalName,
            expected: render,
            directoryFD: directoryFD
        )
    }

    private func pendingMissionIds(
        directoryFD: Int32
    ) throws -> [String] {
        let duplicated = Darwin.dup(directoryFD)
        guard duplicated >= 0 else {
            throw fileSystemError(reportStoreRoot.path, "dup")
        }
        guard let stream = Darwin.fdopendir(duplicated) else {
            Darwin.close(duplicated)
            throw fileSystemError(reportStoreRoot.path, "fdopendir")
        }
        defer { Darwin.closedir(stream) }

        var missionIds = Set<String>()
        errno = 0
        while let entry = Darwin.readdir(stream) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(
                    to: CChar.self,
                    capacity: Int(MAXNAMLEN) + 1
                ) { String(cString: $0) }
            }
            if let missionId = missionId(
                from: name,
                suffix: ".report.tmp"
            ) {
                try validateMissionId(missionId)
                missionIds.insert(missionId)
            } else if let missionId = missionId(
                from: name,
                suffix: ".report.cursor.json"
            ) {
                try validateMissionId(missionId)
                missionIds.insert(missionId)
            }
            errno = 0
        }
        guard errno == 0 else {
            throw fileSystemError(reportStoreRoot.path, "readdir")
        }
        return missionIds.sorted()
    }

    private func missionId(from name: String, suffix: String) -> String? {
        guard name.hasPrefix("."), name.hasSuffix(suffix) else { return nil }
        let start = name.index(after: name.startIndex)
        let end = name.index(name.endIndex, offsetBy: -suffix.count)
        guard start < end else { return nil }
        return String(name[start..<end])
    }

    private func withReportDirectory<T>(
        _ body: (Int32) throws -> T
    ) throws -> T {
        bootstrapLock.lock()
        let descriptor: Int32
        do {
            descriptor = try bootstrapReportDirectory()
        } catch {
            bootstrapLock.unlock()
            throw error
        }
        bootstrapLock.unlock()
        defer { Darwin.close(descriptor) }
        return try body(descriptor)
    }

    private func bootstrapReportDirectory() throws -> Int32 {
        let rootPath = reportStoreRoot.path
        guard reportStoreRoot.isFileURL,
              rootPath.hasPrefix("/"),
              rootPath != "/"
        else {
            throw ManagedExpeditionReportStoreErrorV1.invalidRoot(rootPath)
        }
        let components = rootPath.split(
            separator: "/",
            omittingEmptySubsequences: true
        ).map(String.init)
        guard !components.isEmpty else {
            throw ManagedExpeditionReportStoreErrorV1.invalidRoot(rootPath)
        }
        var directoryFD = Darwin.open(
            "/",
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard directoryFD >= 0 else {
            throw fileSystemError("/", "open")
        }
        for (index, component) in components.enumerated() {
            do {
                try validateRootComponent(component, rootPath: rootPath)
                var information = stat()
                let status = component.withCString { pointer in
                    Darwin.fstatat(
                        directoryFD,
                        pointer,
                        &information,
                        AT_SYMLINK_NOFOLLOW
                    )
                }
                if status == 0 {
                    try rootWalkCheckpoint?(component)
                }
                let next: Int32
                if status == 0 {
                    switch information.st_mode & S_IFMT {
                    case S_IFDIR:
                        next = try openDirectoryComponent(
                            component,
                            parentFD: directoryFD,
                            expected: information
                        )
                    case S_IFLNK where index == 0:
                        next = try openTrustedSystemDirectoryAlias(
                            component,
                            parentFD: directoryFD,
                            information: information
                        )
                    default:
                        throw ManagedExpeditionReportStoreErrorV1.irregularFile(
                            rootPath
                        )
                    }
                } else if errno == ENOENT {
                    let created = component.withCString { pointer in
                        Darwin.mkdirat(directoryFD, pointer, S_IRWXU)
                    }
                    if created != 0, errno != EEXIST {
                        throw fileSystemError(component, "mkdirat")
                    }
                    if created == 0 {
                        try syncDirectory(directoryFD, path: component)
                    }
                    var createdInformation = stat()
                    let createdStatus = component.withCString { pointer in
                        Darwin.fstatat(
                            directoryFD,
                            pointer,
                            &createdInformation,
                            AT_SYMLINK_NOFOLLOW
                        )
                    }
                    guard createdStatus == 0 else {
                        throw fileSystemError(component, "fstatat")
                    }
                    next = try openDirectoryComponent(
                        component,
                        parentFD: directoryFD,
                        expected: createdInformation
                    )
                } else {
                    throw fileSystemError(component, "fstatat")
                }
                Darwin.close(directoryFD)
                directoryFD = next
            } catch {
                Darwin.close(directoryFD)
                throw error
            }
        }
        return directoryFD
    }

    private func openTrustedSystemDirectoryAlias(
        _ name: String,
        parentFD: Int32,
        information: stat
    ) throws -> Int32 {
        guard name == "var" || name == "tmp",
              information.st_mode & S_IFMT == S_IFLNK,
              information.st_uid == 0
        else {
            throw ManagedExpeditionReportStoreErrorV1.irregularFile(name)
        }
        try requireTrustedSystemAliasIdentity(
            name,
            parentFD: parentFD,
            expected: information
        )
        var storage = [UInt8](repeating: 0, count: Int(PATH_MAX))
        let count = name.withCString { pointer in
            storage.withUnsafeMutableBytes { buffer in
                Darwin.readlinkat(
                    parentFD,
                    pointer,
                    buffer.baseAddress?.assumingMemoryBound(to: CChar.self),
                    buffer.count
                )
            }
        }
        guard count >= 0, count < storage.count else {
            throw fileSystemError(name, "readlinkat")
        }
        let target = String(decoding: storage[0..<count], as: UTF8.self)
        guard target == "private/\(name)" else {
            throw ManagedExpeditionReportStoreErrorV1.irregularFile(name)
        }
        try requireTrustedSystemAliasIdentity(
            name,
            parentFD: parentFD,
            expected: information
        )
        let privateFD = try openExistingDirectoryComponent(
            "private",
            parentFD: parentFD
        )
        do {
            let targetFD = try openExistingDirectoryComponent(
                name,
                parentFD: privateFD
            )
            do {
                try requireTrustedSystemAliasIdentity(
                    name,
                    parentFD: parentFD,
                    expected: information
                )
            } catch {
                Darwin.close(targetFD)
                throw error
            }
            Darwin.close(privateFD)
            return targetFD
        } catch {
            Darwin.close(privateFD)
            throw error
        }
    }

    private func openDirectoryComponent(
        _ name: String,
        parentFD: Int32,
        expected: stat
    ) throws -> Int32 {
        guard expected.st_mode & S_IFMT == S_IFDIR else {
            throw ManagedExpeditionReportStoreErrorV1.irregularFile(name)
        }
        let descriptor = name.withCString { pointer in
            Darwin.openat(
                parentFD,
                pointer,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard descriptor >= 0 else {
            throw fileSystemError(name, "openat")
        }
        var opened = stat()
        guard Darwin.fstat(descriptor, &opened) == 0 else {
            let error = fileSystemError(name, "fstat")
            Darwin.close(descriptor)
            throw error
        }
        var pathSnapshot = stat()
        let pathStatus = name.withCString { pointer in
            Darwin.fstatat(
                parentFD,
                pointer,
                &pathSnapshot,
                AT_SYMLINK_NOFOLLOW
            )
        }
        guard pathStatus == 0 else {
            let error = fileSystemError(name, "fstatat")
            Darwin.close(descriptor)
            throw error
        }
        guard opened.st_mode & S_IFMT == S_IFDIR,
              pathSnapshot.st_mode & S_IFMT == S_IFDIR,
              sameFileIdentity(expected, opened),
              sameFileIdentity(opened, pathSnapshot)
        else {
            Darwin.close(descriptor)
            throw ManagedExpeditionReportStoreErrorV1.fileChanged(name)
        }
        return descriptor
    }

    private func openExistingDirectoryComponent(
        _ name: String,
        parentFD: Int32
    ) throws -> Int32 {
        var information = stat()
        let status = name.withCString { pointer in
            Darwin.fstatat(
                parentFD,
                pointer,
                &information,
                AT_SYMLINK_NOFOLLOW
            )
        }
        guard status == 0 else {
            throw fileSystemError(name, "fstatat")
        }
        return try openDirectoryComponent(
            name,
            parentFD: parentFD,
            expected: information
        )
    }

    private func requireTrustedSystemAliasIdentity(
        _ name: String,
        parentFD: Int32,
        expected: stat
    ) throws {
        var current = stat()
        let status = name.withCString { pointer in
            Darwin.fstatat(
                parentFD,
                pointer,
                &current,
                AT_SYMLINK_NOFOLLOW
            )
        }
        guard status == 0 else {
            throw fileSystemError(name, "fstatat")
        }
        guard current.st_mode & S_IFMT == S_IFLNK,
              current.st_uid == 0,
              sameFileIdentity(expected, current)
        else {
            throw ManagedExpeditionReportStoreErrorV1.fileChanged(name)
        }
    }

    private func writeNewRegularFile(
        _ data: Data,
        name: String,
        directoryFD: Int32
    ) throws {
        let descriptor = name.withCString { pointer in
            Darwin.openat(
                directoryFD,
                pointer,
                O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC | O_NOFOLLOW,
                S_IRUSR | S_IWUSR
            )
        }
        guard descriptor >= 0 else {
            throw fileSystemError(name, "openat")
        }
        do {
            var information = stat()
            guard Darwin.fstat(descriptor, &information) == 0 else {
                throw fileSystemError(name, "fstat")
            }
            guard information.st_mode & S_IFMT == S_IFREG,
                  information.st_nlink == 1
            else {
                throw ManagedExpeditionReportStoreErrorV1.irregularFile(name)
            }
            try writeAll(data, descriptor: descriptor, path: name)
            guard Darwin.fsync(descriptor) == 0 else {
                throw fileSystemError(name, "fsync")
            }
        } catch {
            Darwin.close(descriptor)
            throw error
        }
        Darwin.close(descriptor)
    }

    private func writeAll(
        _ data: Data,
        descriptor: Int32,
        path: String
    ) throws {
        try data.withUnsafeBytes { rawBuffer in
            var offset = 0
            while offset < rawBuffer.count {
                var count = 0
                while true {
                    count = Darwin.write(
                        descriptor,
                        rawBuffer.baseAddress?.advanced(by: offset),
                        rawBuffer.count - offset
                    )
                    if count < 0, errno == EINTR { continue }
                    break
                }
                guard count > 0 else {
                    throw fileSystemError(path, "write")
                }
                offset += count
            }
        }
    }

    private func validateFile(
        _ name: String,
        expected: ManagedExpeditionReportRenderV1,
        directoryFD: Int32
    ) throws {
        let data = try readRegularFile(name, directoryFD: directoryFD)
        guard data.count == expected.bytes.count else {
            throw ManagedExpeditionReportStoreErrorV1.byteCountMismatch(
                path: name,
                expected: expected.bytes.count,
                actual: data.count
            )
        }
        let actualHash = CanonicalJSONV1.sha256Hex(data)
        guard actualHash == expected.contentHash, data == expected.bytes else {
            throw ManagedExpeditionReportStoreErrorV1.contentMismatch(
                path: name,
                expected: expected.contentHash,
                actual: actualHash
            )
        }
    }

    private func readRegularFile(
        _ name: String,
        directoryFD: Int32
    ) throws -> Data {
        let descriptor = name.withCString { pointer in
            Darwin.openat(
                directoryFD,
                pointer,
                O_RDONLY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard descriptor >= 0 else {
            throw fileSystemError(name, "openat")
        }
        defer { Darwin.close(descriptor) }

        var before = stat()
        guard Darwin.fstat(descriptor, &before) == 0 else {
            throw fileSystemError(name, "fstat")
        }
        guard before.st_mode & S_IFMT == S_IFREG,
              before.st_nlink == 1
        else {
            throw ManagedExpeditionReportStoreErrorV1.irregularFile(name)
        }
        guard before.st_size >= 0, before.st_size <= Int64(Int.max) else {
            throw ManagedExpeditionReportStoreErrorV1.byteCountMismatch(
                path: name,
                expected: 0,
                actual: -1
            )
        }
        let size = Int(before.st_size)
        var data = Data()
        data.reserveCapacity(size)
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = buffer.withUnsafeMutableBytes { rawBuffer -> Int in
                while true {
                    let value = Darwin.read(
                        descriptor,
                        rawBuffer.baseAddress,
                        rawBuffer.count
                    )
                    if value < 0, errno == EINTR { continue }
                    return value
                }
            }
            guard count >= 0 else {
                throw fileSystemError(name, "read")
            }
            if count == 0 { break }
            data.append(contentsOf: buffer[0..<count])
            guard data.count <= size else {
                throw ManagedExpeditionReportStoreErrorV1.fileChanged(name)
            }
        }
        guard data.count == size else {
            throw ManagedExpeditionReportStoreErrorV1.fileChanged(name)
        }

        var after = stat()
        guard Darwin.fstat(descriptor, &after) == 0 else {
            throw fileSystemError(name, "fstat")
        }
        guard sameSnapshot(before, after) else {
            throw ManagedExpeditionReportStoreErrorV1.fileChanged(name)
        }
        var pathSnapshot = stat()
        let status = name.withCString { pointer in
            Darwin.fstatat(
                directoryFD,
                pointer,
                &pathSnapshot,
                AT_SYMLINK_NOFOLLOW
            )
        }
        guard status == 0 else {
            throw fileSystemError(name, "fstatat")
        }
        guard pathSnapshot.st_mode & S_IFMT == S_IFREG,
              pathSnapshot.st_nlink == 1,
              sameSnapshot(after, pathSnapshot)
        else {
            throw ManagedExpeditionReportStoreErrorV1.fileChanged(name)
        }
        return data
    }

    private func sameSnapshot(_ lhs: stat, _ rhs: stat) -> Bool {
        lhs.st_dev == rhs.st_dev
            && lhs.st_ino == rhs.st_ino
            && lhs.st_mode == rhs.st_mode
            && lhs.st_nlink == rhs.st_nlink
            && lhs.st_size == rhs.st_size
            && lhs.st_mtimespec.tv_sec == rhs.st_mtimespec.tv_sec
            && lhs.st_mtimespec.tv_nsec == rhs.st_mtimespec.tv_nsec
    }

    private func sameFileIdentity(_ lhs: stat, _ rhs: stat) -> Bool {
        lhs.st_dev == rhs.st_dev && lhs.st_ino == rhs.st_ino
    }

    private func requireLockedPathIdentity(
        _ descriptor: Int32,
        name: String,
        directoryFD: Int32
    ) throws {
        var opened = stat()
        guard Darwin.fstat(descriptor, &opened) == 0 else {
            throw fileSystemError(name, "fstat")
        }
        var pathSnapshot = stat()
        let status = name.withCString { pointer in
            Darwin.fstatat(
                directoryFD,
                pointer,
                &pathSnapshot,
                AT_SYMLINK_NOFOLLOW
            )
        }
        if status != 0 {
            if errno == ENOENT {
                throw ManagedExpeditionReportStoreErrorV1.fileChanged(name)
            }
            throw fileSystemError(name, "fstatat")
        }
        guard opened.st_mode & S_IFMT == S_IFREG,
              pathSnapshot.st_mode & S_IFMT == S_IFREG,
              opened.st_nlink == 1,
              pathSnapshot.st_nlink == 1,
              sameFileIdentity(opened, pathSnapshot)
        else {
            throw ManagedExpeditionReportStoreErrorV1.fileChanged(name)
        }
    }

    private func requireReplaceableFinal(
        _ name: String,
        directoryFD: Int32
    ) throws {
        var information = stat()
        let result = name.withCString { pointer in
            Darwin.fstatat(
                directoryFD,
                pointer,
                &information,
                AT_SYMLINK_NOFOLLOW
            )
        }
        if result != 0 {
            if errno == ENOENT { return }
            throw fileSystemError(name, "fstatat")
        }
        guard information.st_mode & S_IFMT == S_IFREG,
              information.st_nlink == 1
        else {
            throw ManagedExpeditionReportStoreErrorV1.irregularFile(name)
        }
    }

    private func pathExists(
        _ name: String,
        directoryFD: Int32
    ) throws -> Bool {
        var information = stat()
        let result = name.withCString { pointer in
            Darwin.fstatat(
                directoryFD,
                pointer,
                &information,
                AT_SYMLINK_NOFOLLOW
            )
        }
        if result == 0 { return true }
        if errno == ENOENT { return false }
        throw fileSystemError(name, "fstatat")
    }

    private func regularFileExists(
        _ name: String,
        directoryFD: Int32
    ) throws -> Bool {
        var information = stat()
        let result = name.withCString { pointer in
            Darwin.fstatat(
                directoryFD,
                pointer,
                &information,
                AT_SYMLINK_NOFOLLOW
            )
        }
        if result != 0 {
            if errno == ENOENT { return false }
            throw fileSystemError(name, "fstatat")
        }
        guard information.st_mode & S_IFMT == S_IFREG,
              information.st_nlink == 1
        else {
            throw ManagedExpeditionReportStoreErrorV1.irregularFile(name)
        }
        return true
    }

    private func unlink(
        _ name: String,
        directoryFD: Int32,
        allowMissing: Bool
    ) throws {
        let result = name.withCString { pointer in
            Darwin.unlinkat(directoryFD, pointer, 0)
        }
        if result != 0 {
            if allowMissing, errno == ENOENT { return }
            throw fileSystemError(name, "unlinkat")
        }
    }

    private func validatePathComponent(
        _ component: String,
        identity: String
    ) throws {
        guard !component.isEmpty,
              component != ".",
              component != "..",
              !component.contains("/"),
              !component.contains("\\"),
              !component.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              })
        else {
            throw ManagedExpeditionReportStoreErrorV1.invalidMissionId(
                identity
            )
        }
    }

    private func validateRootComponent(
        _ component: String,
        rootPath: String
    ) throws {
        guard !component.isEmpty,
              component != ".",
              component != "..",
              !component.contains("/"),
              !component.contains("\\"),
              !component.utf8.contains(0),
              !component.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              })
        else {
            throw ManagedExpeditionReportStoreErrorV1.invalidRoot(rootPath)
        }
    }

    private func syncDirectory(_ descriptor: Int32, path: String) throws {
        guard Darwin.fsync(descriptor) == 0 else {
            throw fileSystemError(path, "fsync")
        }
    }

    private func fileSystemError(
        _ path: String,
        _ operation: String
    ) -> ManagedExpeditionReportStoreErrorV1 {
        ManagedExpeditionReportStoreErrorV1.fileSystem(
            path: path,
            operation: operation,
            code: errno
        )
    }
}
