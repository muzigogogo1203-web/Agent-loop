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

@Test func appendModeAppends() async throws {
    let ws = try makeWorkspace()
    let tools = FileTools(workspaceRoot: ws)
    // 覆盖写建立文件 → 两段 append → 读回全文顺序正确
    _ = await tools.write(input: ["path": "长文.md", "content": "第一段。"])
    _ = await tools.write(input: ["path": "长文.md", "content": "第二段。", "append": true])
    _ = await tools.write(input: ["path": "长文.md", "content": "第三段。", "append": true])
    let read = await tools.read(input: ["path": "长文.md"])
    guard case .result(let content) = read else { Issue.record("read failed"); return }
    #expect(content == "第一段。第二段。第三段。")

    // append 到不存在的文件 = 新建
    let fresh = await tools.write(input: ["path": "新文件.md", "content": "开头", "append": true])
    guard case .result = fresh else { Issue.record("append-to-new should succeed"); return }
    let readFresh = await tools.read(input: ["path": "新文件.md"])
    guard case .result(let freshContent) = readFresh else { return }
    #expect(freshContent == "开头")

    // 不带 append 仍是覆盖语义
    _ = await tools.write(input: ["path": "长文.md", "content": "重来"])
    let overwritten = await tools.read(input: ["path": "长文.md"])
    guard case .result(let final) = overwritten else { return }
    #expect(final == "重来")
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
