/// Batches text deltas and delivers them at most once per `interval`.
///
/// Ordering guarantee: batches are delivered strictly in push order, one at a time.
/// While a `deliver` call is in progress, new pushes only buffer; after `deliver`
/// returns the actor re-drains, so at most one extra interval of latency is added
/// to the final batch.
public actor DeltaCoalescer {
    private var buffer = ""
    private var flusher: Task<Void, Never>?
    private var isDelivering = false
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
        if flusher == nil && !isDelivering {
            flusher = Task {
                try? await Task.sleep(for: interval)
                await self.flush()
            }
        }
        // If isDelivering, the re-drain loop in flush() will pick up this push.
    }

    public func flush() async {
        flusher?.cancel()
        flusher = nil
        // Deliver loop: keeps draining as long as new pushes arrive during delivery.
        while !buffer.isEmpty {
            let output = buffer
            buffer = ""
            isDelivering = true
            await deliver(output)
            isDelivering = false
        }
    }

    public func discard() {
        flusher?.cancel()
        flusher = nil
        buffer = ""
    }
}
