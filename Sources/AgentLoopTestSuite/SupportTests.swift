import Testing
import Foundation
import AgentLoopCore

@Test func keychainRoundTrip() throws {
    let store = KeychainStore(service: "com.muzi.agentloop.tests.\(UUID().uuidString)")
    defer { try? store.delete(account: "k") }
    #expect(try store.get(account: "k") == nil)
    try store.set("sk-abc", account: "k")
    #expect(try store.get(account: "k") == "sk-abc")
    try store.set("sk-def", account: "k")
    #expect(try store.get(account: "k") == "sk-def")
}

@Test func coalescerBatchesDeltas() async throws {
    let collected = Collected()
    let coalescer = DeltaCoalescer(interval: .milliseconds(30)) { batch in
        await collected.append(batch)
    }
    for i in 0..<50 {
        await coalescer.push("x\(i) ")
    }
    try await Task.sleep(for: .milliseconds(120))
    await coalescer.flush()
    let batches = await collected.values
    #expect(batches.joined() == (0..<50).map { "x\($0) " }.joined())
    #expect(batches.count < 50)
}

actor Collected {
    var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}
