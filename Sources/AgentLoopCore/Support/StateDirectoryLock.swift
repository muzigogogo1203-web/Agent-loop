import Darwin
import Foundation

public enum StateDirectoryLockError: Error, Equatable, LocalizedError, Sendable {
    case openFailed(path: String, code: Int32)
    case alreadyLocked(path: String, code: Int32)
    case lockFailed(path: String, code: Int32)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let path, let code):
            return "无法打开 AgentLoop 状态目录锁：\(path)（errno \(code)）"
        case .alreadyLocked(let path, let code):
            return "AgentLoop 状态目录已被另一个进程占用：\(path)（errno \(code)）"
        case .lockFailed(let path, let code):
            return "无法锁定 AgentLoop 状态目录：\(path)（errno \(code)）"
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
    private let descriptor: Int32

    public init(directoryURL: URL) throws {
        lockFileURL = directoryURL.appendingPathComponent(".agentloop.lock", isDirectory: false)
        let path = lockFileURL.path
        let opened = path.withCString {
            Darwin.open($0, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        }
        guard opened >= 0 else {
            throw StateDirectoryLockError.openFailed(path: path, code: errno)
        }

        guard flock(opened, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno
            Darwin.close(opened)
            if code == EACCES || code == EAGAIN {
                throw StateDirectoryLockError.alreadyLocked(path: path, code: code)
            }
            throw StateDirectoryLockError.lockFailed(path: path, code: code)
        }
        descriptor = opened
    }

    deinit {
        _ = flock(descriptor, LOCK_UN)
        Darwin.close(descriptor)
    }
}
