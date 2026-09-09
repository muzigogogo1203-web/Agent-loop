package enum BlockingProcessOperation {
    package static func start<Value: Sendable>(
        _ operation: @escaping @Sendable () -> Value
    ) -> Task<Value, Never> {
        Task.detached {
            operation()
        }
    }
}
