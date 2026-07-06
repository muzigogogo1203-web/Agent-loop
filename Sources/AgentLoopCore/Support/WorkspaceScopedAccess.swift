import Foundation

/// 安全作用域工作目录访问（M5-1，spec §13）：沙箱下重启后凭书签恢复目录权限。
/// 书签优先（stale/损坏时静默降级），path 兜底；`stop()` 收尾释放。
/// 非沙箱构建下书签解析同样工作，startAccessing 为 no-op 语义——行为向前兼容。
public struct WorkspaceScopedAccess: Sendable {
    public let url: URL?
    private let accessing: Bool

    public init(workspacePath: String?, bookmark: Data?) {
        if let bookmark {
            var stale = false
            if let resolved = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                url = resolved
                accessing = resolved.startAccessingSecurityScopedResource()
                return
            }
        }
        url = workspacePath.map { URL(fileURLWithPath: $0) }
        accessing = false
    }

    public func stop() {
        if accessing {
            url?.stopAccessingSecurityScopedResource()
        }
    }

    /// 选定工作目录时捕获书签（需当前对该目录有访问权，如 NSOpenPanel 授权在场时）。
    /// 捕获失败返回 nil——行为退化为纯 path（与既有语义一致）。
    public static func captureBookmark(forPath path: String?) -> Data? {
        guard let path else { return nil }
        let url = URL(fileURLWithPath: path)
        return try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
}
