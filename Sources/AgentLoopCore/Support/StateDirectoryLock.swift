import Darwin
import Foundation

public enum StateDirectoryLockError: Error, Equatable, LocalizedError, Sendable {
    case openFailed(path: String, code: Int32)
    case alreadyLocked(path: String, code: Int32)
    case lockFailed(path: String, code: Int32)
    case invalidDirectory(path: String)
    case invalidLockFile(path: String)
    case duplicateFailed(path: String, code: Int32)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let path, let code):
            return "无法打开 AgentLoop 状态目录锁：\(path)（errno \(code)）"
        case .alreadyLocked(let path, let code):
            return "AgentLoop 状态目录已被另一个进程占用：\(path)（errno \(code)）"
        case .lockFailed(let path, let code):
            return "无法锁定 AgentLoop 状态目录：\(path)（errno \(code)）"
        case .invalidDirectory(let path):
            return "AgentLoop 状态目录不是当前用户持有的真实目录：\(path)"
        case .invalidLockFile(let path):
            return "AgentLoop 状态目录锁的身份或权限无效：\(path)"
        case .duplicateFailed(let path, let code):
            return "无法复制 AgentLoop 状态目录句柄：\(path)（errno \(code)）"
        }
    }
}

/// App 进程对状态目录持有的非阻塞排他锁。
///
/// LaunchServices 的单实例约束只覆盖同一个 bundle id；开发包、分发包和裸二进制
/// 仍可能同时指向同一 SQLite。这个锁以状态目录为真实边界，在数据库初始化前拒绝
/// 第二个 owner，避免另一个 Orchestrator 把活跃 run 当成崩溃孤儿收编。
public final class StateDirectoryLock: @unchecked Sendable {
    public let lockFileURL: URL
    private let directoryDescriptor: Int32
    private let lockDescriptor: Int32

    public init(directoryURL: URL) throws {
        let canonicalDirectoryURL = directoryURL.standardizedFileURL
        guard directoryURL.isFileURL,
              directoryURL.baseURL == nil,
              canonicalDirectoryURL.path == directoryURL.path,
              directoryURL.path.hasPrefix("/")
        else {
            throw StateDirectoryLockError.invalidDirectory(
                path: directoryURL.path
            )
        }
        lockFileURL = directoryURL.appendingPathComponent(
            ".agentloop.lock",
            isDirectory: false
        )
        let directoryPath = directoryURL.path
        let openedDirectory = directoryPath.withCString {
            Darwin.open(
                $0,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard openedDirectory >= 0 else {
            throw StateDirectoryLockError.openFailed(
                path: directoryPath,
                code: errno
            )
        }
        var directoryIsOpen = true
        defer {
            if directoryIsOpen {
                _ = Darwin.close(openedDirectory)
            }
        }
        var directoryInfo = stat()
        guard Darwin.fstat(openedDirectory, &directoryInfo) == 0,
              directoryInfo.st_mode & S_IFMT == S_IFDIR,
              directoryInfo.st_uid == getuid()
        else {
            throw StateDirectoryLockError.invalidDirectory(
                path: directoryPath
            )
        }

        let lockName = ".agentloop.lock"
        let openedLock = lockName.withCString {
            Darwin.openat(
                openedDirectory,
                $0,
                O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW,
                mode_t(0o600)
            )
        }
        guard openedLock >= 0 else {
            throw StateDirectoryLockError.openFailed(
                path: lockFileURL.path,
                code: errno
            )
        }
        var lockIsOpen = true
        defer {
            if lockIsOpen {
                _ = Darwin.close(openedLock)
            }
        }

        var beforeDescriptor = stat()
        var beforePath = stat()
        guard Darwin.fstat(openedLock, &beforeDescriptor) == 0,
              lockName.withCString({
                  Darwin.fstatat(
                      openedDirectory,
                      $0,
                      &beforePath,
                      AT_SYMLINK_NOFOLLOW
                  )
              }) == 0,
              Self.isStrictLockFile(beforeDescriptor),
              Self.isStrictLockFile(beforePath),
              Self.sameStatBytes(beforeDescriptor, beforePath)
        else {
            throw StateDirectoryLockError.invalidLockFile(
                path: lockFileURL.path
            )
        }

        guard flock(openedLock, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno
            if code == EACCES || code == EAGAIN {
                throw StateDirectoryLockError.alreadyLocked(
                    path: lockFileURL.path,
                    code: code
                )
            }
            throw StateDirectoryLockError.lockFailed(
                path: lockFileURL.path,
                code: code
            )
        }

        var afterDescriptor = stat()
        var afterPath = stat()
        guard Darwin.fstat(openedLock, &afterDescriptor) == 0,
              lockName.withCString({
                  Darwin.fstatat(
                      openedDirectory,
                      $0,
                      &afterPath,
                      AT_SYMLINK_NOFOLLOW
                  )
              }) == 0,
              Self.isStrictLockFile(afterDescriptor),
              Self.isStrictLockFile(afterPath),
              Self.sameStatBytes(beforeDescriptor, afterDescriptor),
              Self.sameStatBytes(afterDescriptor, afterPath)
        else {
            _ = flock(openedLock, LOCK_UN)
            throw StateDirectoryLockError.invalidLockFile(
                path: lockFileURL.path
            )
        }

        directoryDescriptor = openedDirectory
        lockDescriptor = openedLock
        directoryIsOpen = false
        lockIsOpen = false
    }

    package func duplicateLockedDirectoryDescriptor() throws -> Int32 {
        let duplicate = Darwin.fcntl(
            directoryDescriptor,
            F_DUPFD_CLOEXEC,
            0
        )
        guard duplicate >= 0 else {
            throw StateDirectoryLockError.duplicateFailed(
                path: lockFileURL.deletingLastPathComponent().path,
                code: errno
            )
        }
        return duplicate
    }

    deinit {
        _ = flock(lockDescriptor, LOCK_UN)
        _ = Darwin.close(lockDescriptor)
        _ = Darwin.close(directoryDescriptor)
    }

    private static func isStrictLockFile(_ info: stat) -> Bool {
        info.st_mode & S_IFMT == S_IFREG
            && info.st_uid == getuid()
            && info.st_mode & mode_t(0o777) == mode_t(0o600)
            && info.st_nlink == 1
    }

    private static func sameStatBytes(_ lhs: stat, _ rhs: stat) -> Bool {
        withUnsafeBytes(of: lhs) { lhsBytes in
            withUnsafeBytes(of: rhs) { rhsBytes in
                lhsBytes.elementsEqual(rhsBytes)
            }
        }
    }
}
