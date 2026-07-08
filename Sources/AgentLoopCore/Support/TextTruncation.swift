import Foundation

/// 字节安全截断（M7 自 WebFetchTool 抽取，shell 输出与网页抓取共用）：
/// 按 UTF-8 字节上限裁剪，再从尾部去掉不完整序列，保证落在合法字符边界。
public enum TextTruncation {
    public static func truncateUTF8(_ text: String, maxBytes: Int, suffix: String) -> String {
        guard text.utf8.count > maxBytes else { return text }
        var data = Data(text.utf8.prefix(maxBytes))
        while !data.isEmpty, String(data: data, encoding: .utf8) == nil {
            data.removeLast()
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        return body + suffix
    }
}
