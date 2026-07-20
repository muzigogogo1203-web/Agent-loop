import Testing
import Foundation
import AgentLoopCore
import Darwin

@Test func keychainRoundTrip() throws {
    let store = KeychainStore(service: "com.muzi.agentloop.tests.\(UUID().uuidString)")
    defer { try? store.delete(account: "k") }
    #expect(try store.get(account: "k") == nil)
    #expect(try store.get(account: "k", interactionPolicy: .failIfInteractionRequired) == nil)
    try store.set("sk-abc", account: "k")
    #expect(try store.get(account: "k") == "sk-abc")
    #expect(try store.get(account: "k", interactionPolicy: .failIfInteractionRequired) == "sk-abc")
    try store.set("sk-def", account: "k")
    #expect(try store.get(account: "k") == "sk-def")
}

@Test func stateDirectoryLockRejectsSecondFileDescriptionAndReleases() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    var first: StateDirectoryLock? = try StateDirectoryLock(directoryURL: directory)
    let expectedPath = try #require(first?.lockFileURL.path)
    do {
        _ = try StateDirectoryLock(directoryURL: directory)
        Issue.record("第二个独立 file description 不应取得同一状态目录锁")
    } catch let error as StateDirectoryLockError {
        guard case .alreadyLocked(let path, let code) = error else {
            Issue.record("应报告 alreadyLocked，实际为 \(error)")
            return
        }
        #expect(path == expectedPath)
        #expect(code == EWOULDBLOCK || code == EAGAIN || code == EACCES)
    } catch {
        Issue.record("应报告 StateDirectoryLockError，实际为 \(error)")
    }

    first = nil
    let replacement = try StateDirectoryLock(directoryURL: directory)
    #expect(replacement.lockFileURL.path == expectedPath)
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

@Test func coalescerDiscardDropsPendingDeltas() async throws {
    let collected = Collected()
    let coalescer = DeltaCoalescer(interval: .milliseconds(50)) { batch in
        await collected.append(batch)
    }

    await coalescer.push("stale")
    await coalescer.discard()
    try await Task.sleep(for: .milliseconds(120))
    #expect(await collected.values.isEmpty)

    await coalescer.push("fresh")
    await coalescer.flush()
    #expect(await collected.values == ["fresh"])
}

actor Collected {
    var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}
