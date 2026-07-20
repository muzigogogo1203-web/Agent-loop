import Darwin

public enum PosixSockets {
    /// SO_NOSIGPIPE: 对端先关时 write 返回 EPIPE 而不是 SIGPIPE 杀进程。
    /// 失败返回 false，errno 留给调用方取用。
    @discardableResult
    public static func disableSIGPIPE(_ fd: Int32) -> Bool {
        var enabled: Int32 = 1
        return setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size)) == 0
    }
}
