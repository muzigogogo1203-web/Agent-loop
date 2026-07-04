import Testing
import Foundation
import AgentLoopCore

private func makeWorkspace() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("ws-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

@Test func writeReadListRoundTrip() async throws {
    let ws = try makeWorkspace()
    let tools = FileTools(workspaceRoot: ws)
    _ = await tools.write(input: ["path": "notes/清单.md", "content": "# 装备"])
    let read = await tools.read(input: ["path": "notes/清单.md"])
    guard case .result(let content) = read else { Issue.record("read failed"); return }
    #expect(content == "# 装备")
    let list = await tools.list(input: ["path": "notes"])
    guard case .result(let listing) = list else { return }
    #expect(listing.contains("清单.md"))
}

@Test func escapeAttemptsRejected() async throws {
    let ws = try makeWorkspace()
    let tools = FileTools(workspaceRoot: ws)
    for path in ["../outside.txt", "a/../../outside.txt", "/etc/passwd"] {
        let out = await tools.write(input: ["path": .string(path), "content": "x"])
        guard case .error(let msg) = out else {
            Issue.record("\(path) should be rejected")
            return
        }
        #expect(msg.contains("工作目录"))
    }
}

@Test func symlinkEscapeRejected() async throws {
    let ws = try makeWorkspace()
    let outside = try makeWorkspace()
    let link = ws.appendingPathComponent("link")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
    let tools = FileTools(workspaceRoot: ws)
    let out = await tools.write(input: ["path": "link/escape.txt", "content": "x"])
    guard case .error = out else {
        Issue.record("symlink escape should be rejected")
        return
    }
}

@Test func missingWorkspaceExplains() async {
    let tools = FileTools(workspaceRoot: nil)
    let out = await tools.read(input: ["path": "a.md"])
    guard case .error(let msg) = out else { return }
    #expect(msg.contains("未绑定工作目录"))
}
