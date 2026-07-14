import SwiftUI
import AppKit

// 营地感设计系统（spec §11.1）：温暖色调、圆润几何、暗色 = 篝火夜景。
// 全部颜色为亮/暗动态色；组件统一圆角与阴影语言。
enum Camp {
    // MARK: 画布与表面

    /// 窗口底色：羊皮纸 / 夜营地
    static let canvas = dynamic(light: 0xF7F1E6, dark: 0x1F1813)
    /// 卡片表面
    static let surface = dynamic(light: 0xFFFCF5, dark: 0x2B211A)
    /// 强调表面（输入区、悬浮）
    static let surfaceRaised = dynamic(light: 0xFFFFFF, dark: 0x342821)
    /// 细线
    static let line = dynamic(light: 0xE9DFCC, dark: 0x453A2F)

    // MARK: 文字

    static let ink = dynamic(light: 0x3B3128, dark: 0xF0E6D4)
    static let inkSecondary = dynamic(light: 0x8B7C6A, dark: 0xAE9D87)

    // MARK: 语义色

    /// 篝火橙——主行动色
    static let ember = dynamic(light: 0xDE7738, dark: 0xE8894C)
    static let emberDeep = dynamic(light: 0xC4602A, dark: 0xD0713A)
    /// 苔绿——完成/交付
    static let moss = dynamic(light: 0x6F8F4F, dark: 0x8FAE6D)
    /// 琥珀——等待用户
    static let amber = dynamic(light: 0xDD9F35, dark: 0xE6B04F)
    /// 石灰——排队/停用
    static let stone = dynamic(light: 0xA79B8A, dark: 0x7E7264)
    /// 溪蓝——进行中
    static let creek = dynamic(light: 0x4A7FA6, dark: 0x7FA8C9)
    /// 炭红——错误
    static let charcoalRed = dynamic(light: 0xB9553F, dark: 0xD07B62)

    /// Coding 牧场新增语义面：喂入材料与轻提示，不改变原有 Camp 主色体系。
    static let hay = dynamic(light: 0xEFE2BF, dark: 0x443824)
    static let pasture = dynamic(light: 0xE7EFE0, dark: 0x263424)
    static let skyWash = dynamic(light: 0xE8F0F5, dark: 0x24313A)

    static let cornerRadius: CGFloat = 14
    static let smallRadius: CGFloat = 10

    private static func dynamic(light: Int, dark: Int) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

// MARK: - 响应式布局

/// App 层统一使用的窗口断点。只描述呈现策略，不承载业务状态。
enum CampLayout {
    /// 低于该宽度时优先保证详情可用，主侧栏自动收起。
    static let navigationCollapseWidth: CGFloat = 900
    /// 低于该真实窗口宽度时，复杂页头和工具条改为分行布局。
    static let windowCompactWidth: CGFloat = 1200
    /// 视图自身低于该宽度时使用紧凑布局（sheet 等独立容器使用）。
    static let compactContentWidth: CGFloat = 700
    /// 笔记、动态等辅助面板至少需要的真实窗口宽度。
    static let secondaryPanelWindowWidth: CGFloat = 1180
    static let edgePadding: CGFloat = 16

    static func inspectorSize(in available: CGSize) -> CGSize {
        CGSize(
            width: min(620, max(320, available.width - edgePadding * 2)),
            height: min(640, max(360, available.height - edgePadding * 2))
        )
    }
}

private struct CampWindowSizeKey: EnvironmentKey {
    static let defaultValue = CGSize.zero
}

extension EnvironmentValues {
    var campWindowSize: CGSize {
        get { self[CampWindowSizeKey.self] }
        set { self[CampWindowSizeKey.self] = newValue }
    }
}

/// `NavigationSplitView` 的理想尺寸可能大于真实窗口，单靠 GeometryReader 会读到溢出后的宽度。
/// 这个零尺寸 AppKit 探针读取真实 contentView 尺寸，并在窗口缩放时同步到 SwiftUI 环境。
struct CampWindowSizeReader: NSViewRepresentable {
    @Binding var size: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator(size: $size)
    }

    func makeNSView(context: Context) -> WindowProbeView {
        let view = WindowProbeView(frame: .zero)
        view.onWindowChange = { [weak coordinator = context.coordinator] window in
            coordinator?.observe(window)
        }
        return view
    }

    func updateNSView(_ nsView: WindowProbeView, context: Context) {
        if context.coordinator.window !== nsView.window {
            context.coordinator.observe(nsView.window)
        }
    }

    static func dismantleNSView(_ nsView: WindowProbeView, coordinator: Coordinator) {
        nsView.onWindowChange = nil
        coordinator.stopObserving()
    }

    @MainActor
    final class Coordinator: NSObject {
        private let size: Binding<CGSize>
        weak var window: NSWindow?

        init(size: Binding<CGSize>) {
            self.size = size
        }

        func observe(_ window: NSWindow?) {
            guard self.window !== window else { return }
            stopObserving()
            self.window = window
            if let window {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(windowDidResize(_:)),
                    name: NSWindow.didResizeNotification,
                    object: window
                )
                publishSize()
            }
        }

        func stopObserving() {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: window)
            window = nil
        }

        @objc private func windowDidResize(_ notification: Notification) {
            publishSize()
        }

        private func publishSize() {
            guard let next = window?.frame.size, next != size.wrappedValue else { return }
            size.wrappedValue = next
        }
    }
}

@MainActor
final class WindowProbeView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}

// MARK: - 卡片容器

struct CampCard: ViewModifier {
    var padding: CGFloat = 14
    var highlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Camp.surface, in: RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                    .stroke(highlighted ? Camp.amber.opacity(0.75) : Camp.line, lineWidth: highlighted ? 1.5 : 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
    }
}

extension View {
    func campCard(padding: CGFloat = 14, highlighted: Bool = false) -> some View {
        modifier(CampCard(padding: padding, highlighted: highlighted))
    }
}

// MARK: - 状态小签

struct CampChip: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3.5)
        .foregroundStyle(color)
        .background(color.opacity(0.14), in: Capsule())
    }
}

// MARK: - Coding 牧场状态容器

struct CampStatusPanel: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                    .stroke(color.opacity(0.32), lineWidth: 1)
            )
    }
}

extension View {
    func campStatusPanel(_ color: Color) -> some View {
        modifier(CampStatusPanel(color: color))
    }
}

// MARK: - 主按钮（篝火色）

struct CampPrimaryButtonStyle: ButtonStyle {
    var size: ControlSize = .large

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size == .large ? .body.weight(.semibold) : .callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, size == .large ? 22 : 14)
            .padding(.vertical, size == .large ? 10 : 6)
            .background(
                LinearGradient(colors: [Camp.ember, Camp.emberDeep], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct CampSecondaryButtonStyle: ButtonStyle {
    var tint: Color = Camp.inkSecondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 5.5)
            .background(Camp.surface, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                    .stroke(Camp.line, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// MARK: - 分区标题

struct CampSectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Camp.inkSecondary)
    }
}

// MARK: - 状态语义映射（卡片/行动共用）

enum CampStatusStyle {
    static func cardColor(_ status: CardStatusLike) -> Color {
        switch status {
        case .done: Camp.moss
        case .running: Camp.creek
        case .blocked: Camp.amber
        case .canceled: Camp.stone
        case .todo, .ready: Camp.stone
        }
    }

    enum CardStatusLike {
        case todo, ready, running, done, blocked, canceled
    }
}

// MARK: - 底部 toast（知识层沉淀/提案反馈用）

struct CampToast: ViewModifier {
    let message: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Camp.canvas)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Camp.ink.opacity(0.92), in: Capsule())
                    .padding(.bottom, 18)
                    .transition(.opacity)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: message)
            }
        }
    }
}

extension View {
    func campToast(_ message: String?) -> some View {
        modifier(CampToast(message: message))
    }
}

// MARK: - 受阻原因人话化（原始网关/工具错误不直接见人）

enum CampCopy {
    /// blockedReason detail 里可能是原始错误串（JSON/英文堆栈）；界面上收敛为短句，完整原文进详情面板。
    static func humanizeBlockedDetail(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let looksRaw = trimmed.contains("{") || trimmed.contains("tool_use")
            || trimmed.lowercased().contains("error") || trimmed.count > 100
        guard looksRaw else { return trimmed }
        if trimmed.contains("超时") || trimmed.lowercased().contains("timed out") {
            return "网络响应超时，可点重试"
        }
        if trimmed.contains("中断") || trimmed.lowercased().contains("stream") {
            return "网关响应中断，可点重试（详情见小目标面板）"
        }
        return "执行出错，可点重试（详情见小目标面板）"
    }
}
