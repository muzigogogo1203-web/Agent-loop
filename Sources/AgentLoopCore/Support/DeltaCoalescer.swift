public actor DeltaCoalescer {
    private var buffer = ""
    private var flusher: Task<Void, Never>?
    private let interval: Duration
    private let deliver: @Sendable (String) async -> Void

    public init(
        interval: Duration = .milliseconds(40),
        deliver: @escaping @Sendable (String) async -> Void
    ) {
        self.interval = interval
        self.deliver = deliver
    }

    public func push(_ delta: String) {
        buffer += delta
        if flusher == nil {
            flusher = Task {
                try? await Task.sleep(for: interval)
                await self.flush()
            }
        }
    }

    public func flush() async {
        flusher?.cancel()
        flusher = nil
        guard !buffer.isEmpty else {
            return
        }
        let output = buffer
        buffer = ""
        await deliver(output)
    }
}
