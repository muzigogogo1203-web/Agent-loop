import Foundation

/// 注入用笔记摘要（plan D2）：置顶全文单条 ≤800 字（超出截断加省略号），
/// 「最近 3」每条 ≤150 字；渲染顺序 置顶(createdAt ASC) → 最近(DESC)；无时间戳。
public struct NoteSnippet: Sendable, Equatable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }

    public static let pinnedBodyLimit = 800
    public static let recentBodyLimit = 150

    package static func truncated(_ text: String, limit: Int) -> String {
        text.count <= limit ? text : String(text.prefix(limit)) + "…"
    }

    // MARK: - 从记录构造（排序责任在查询侧：pinned ASC + recent DESC）

    public static func from(pinned: [CampNoteRecord], recent: [CampNoteRecord]) -> [NoteSnippet] {
        pinned.map { .init(title: $0.title, body: truncated($0.bodyMd, limit: pinnedBodyLimit)) }
            + recent.map { .init(title: $0.title, body: truncated($0.bodyMd, limit: recentBodyLimit)) }
    }

    public static func from(pinned: [CompanionNoteRecord], recent: [CompanionNoteRecord]) -> [NoteSnippet] {
        pinned.map { .init(title: $0.title, body: truncated($0.bodyMd, limit: pinnedBodyLimit)) }
            + recent.map { .init(title: $0.title, body: truncated($0.bodyMd, limit: recentBodyLimit)) }
    }

    // MARK: - 渲染

    /// 渲染为提示段；空列表返回 nil（整段省略）。
    public static func renderSection(header: String, snippets: [NoteSnippet]) -> String? {
        guard !snippets.isEmpty else { return nil }
        var lines: [String] = ["# \(header)"]
        for snippet in snippets {
            lines.append("## \(snippet.title)")
            lines.append(snippet.body)
        }
        return lines.joined(separator: "\n")
    }
}
