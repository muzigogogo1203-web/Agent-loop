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

@Test func coalescerPreservesOrderUnderReentrancy() async throws {
    // deliver suspends for 5ms — new pushes arriving *during* delivery must not
    // be lost or delivered out-of-order relative to the push sequence.
    let collected = Collected()
    let coalescer = DeltaCoalescer(interval: .milliseconds(1)) { batch in
        // Slow delivery — new pushes can arrive while we're here
        try? await Task.sleep(for: .milliseconds(5))
        await collected.append(batch)
    }
    let pushCount = 100
    // Push in a tight loop; some pushes arrive while deliver is sleeping
    for i in 0..<pushCount {
        await coalescer.push("x\(i) ")
        if i == 10 {
            // Pause briefly so the first flush fires and deliver starts sleeping
            try? await Task.sleep(for: .milliseconds(3))
        }
    }
    // Drain remaining
    try await Task.sleep(for: .milliseconds(200))
    await coalescer.flush()
    try await Task.sleep(for: .milliseconds(50))

    let batches = await collected.values
    let joined = batches.joined()
    let expected = (0..<pushCount).map { "x\($0) " }.joined()
    #expect(joined == expected, "concatenation mismatch — data lost or duplicated")

    // Prefix property: each successive batch must extend the running concatenation
    var runningPrefix = ""
    for (idx, batch) in batches.enumerated() {
        runningPrefix += batch
        #expect(expected.hasPrefix(runningPrefix),
                "batch \(idx) broke strict prefix ordering: \(batch.prefix(20))…")
    }
}

actor Collected {
    var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}
