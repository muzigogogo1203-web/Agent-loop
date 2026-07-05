import Foundation

public struct FileTools: Sendable {
    let workspaceRoot: URL?

    public init(workspaceRoot: URL?) {
        self.workspaceRoot = workspaceRoot
    }

    func resolve(_ relative: String, forWrite: Bool) -> Result<URL, String> {
        guard let root = workspaceRoot else {
            return .failure("未绑定工作目录。请在任务设置里选择一个工作目录后重试。")
        }
        guard !relative.hasPrefix("/") else {
            return .failure("只允许工作目录内的相对路径，不接受绝对路径。")
        }

        let rootResolved = root.standardizedFileURL.resolvingSymlinksInPath()
        let candidate = rootResolved
            .appendingPathComponent(relative)
            .standardizedFileURL

        var probe = candidate
        while !FileManager.default.fileExists(atPath: probe.path),
              probe.pathComponents.count > rootResolved.pathComponents.count {
            probe = probe.deletingLastPathComponent()
        }

        let resolvedProbe = probe.resolvingSymlinksInPath()
        guard resolvedProbe.path == rootResolved.path
            || resolvedProbe.path.hasPrefix(rootResolved.path + "/") else {
            return .failure("路径越出了工作目录边界，被拒绝。请使用工作目录内的相对路径。")
        }

        _ = forWrite
        return .success(candidate)
    }

    public func list(input: JSONValue) async -> ToolOutcome {
        let relative = input["path"]?.stringValue ?? ""
        switch resolve(relative.isEmpty ? "." : relative, forWrite: false) {
        case .failure(let message):
            return .error(message)
        case .success(let url):
            do {
                let items = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey]
                )
                let lines = items.map { item in
                    let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    return (isDirectory ? "[dir] " : "[file] ") + item.lastPathComponent
                }
                return .result(lines.isEmpty ? "(空目录)" : lines.sorted().joined(separator: "\n"))
            } catch {
                return .error("列目录失败：\(error.localizedDescription)")
            }
        }
    }

    public func read(input: JSONValue) async -> ToolOutcome {
        guard let relative = input["path"]?.stringValue else {
            return .error("缺少 path 参数")
        }
        switch resolve(relative, forWrite: false) {
        case .failure(let message):
            return .error(message)
        case .success(let url):
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                if text.count > 100_000 {
                    return .result(String(text.prefix(100_000)) + "\n...(截断)")
                }
                return .result(text)
            } catch {
                return .error("读取失败：\(error.localizedDescription)")
            }
        }
    }

    public func write(input: JSONValue) async -> ToolOutcome {
        guard let relative = input["path"]?.stringValue,
              let content = input["content"]?.stringValue else {
            return .error("需要 path 与 content 两个参数")
        }
        let append = input["append"]?.boolValue ?? false
        switch resolve(relative, forWrite: true) {
        case .failure(let message):
            return .error(message)
        case .success(let url):
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if append, FileManager.default.fileExists(atPath: url.path) {
                    let handle = try FileHandle(forWritingTo: url)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: Data(content.utf8))
                    return .result("已追加到 \(relative)（+\(content.utf8.count) 字节）")
                }
                try content.write(to: url, atomically: true, encoding: .utf8)
                return .result("已写入 \(relative)（\(content.utf8.count) 字节）")
            } catch {
                return .error("写入失败：\(error.localizedDescription)")
            }
        }
    }
}

public struct FileToolHandler: ToolHandler {
    public enum Op: Sendable {
        case list
        case read
        case write
    }

    let tools: FileTools
    let op: Op

    public init(tools: FileTools, op: Op) {
        self.tools = tools
        self.op = op
    }

    public func execute(input: JSONValue) async -> ToolOutcome {
        switch op {
        case .list:
            return await tools.list(input: input)
        case .read:
            return await tools.read(input: input)
        case .write:
            return await tools.write(input: input)
        }
    }
}
