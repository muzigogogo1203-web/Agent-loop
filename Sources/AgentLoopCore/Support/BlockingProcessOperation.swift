import Foundation

package enum BlockingProcessOperation {
    /// The returned task completes only after the synchronous operation returns.
    /// Cancellation does not abandon it, so blocking work must provide its own
    /// external release or termination mechanism.
    package static func start<Value: Sendable>(
        _ operation: @escaping @Sendable () -> Value
    ) -> Task<Value, Never> {
        Task.detached {
            await withCheckedContinuation {
                (continuation: CheckedContinuation<Value, Never>) in
                let worker = Thread {
                    continuation.resume(returning: operation())
                }
                worker.name = "AgentLoop.process.blocking"
                worker.qualityOfService = .utility
                worker.start()
            }
        }
    }
}
