import SwiftUI
import AgentLoopCore

typealias AvatarState = CompanionAnimState

/// 七色小牛头像：零资产参数化绘制，保留真实状态驱动的表情、徽章与低帧率动效。
/// 动画纪律不变：TimelineView 低帧率、reduceMotion/失焦静态。
struct CompanionAvatarView: View {
    let name: String
    let colorName: String
    var state: AvatarState = .idle
    var size: CGFloat = 26
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var controlActiveState

    static let palette: [String: Color] = [
        "purple": Color(red: 0.45, green: 0.40, blue: 0.80),
        "teal": Color(red: 0.16, green: 0.65, blue: 0.52),
        "coral": Color(red: 0.90, green: 0.45, blue: 0.32),
        "pink": Color(red: 0.88, green: 0.44, blue: 0.58),
        "blue": Color(red: 0.33, green: 0.60, blue: 0.88),
        "green": Color(red: 0.49, green: 0.66, blue: 0.25),
        "amber": Color(red: 0.94, green: 0.66, blue: 0.25),
    ]

    private var base: NSColor {
        NSColor(Self.palette[colorName] ?? .gray)
    }
    private var light: Color { Color(nsColor: base.blended(withFraction: 0.38, of: .white) ?? base) }
    private var deep: Color { Color(nsColor: base.blended(withFraction: 0.42, of: .black) ?? base) }
    private var mid: Color { Color(nsColor: base) }
    private var cream: Color { Color(red: 0.97, green: 0.93, blue: 0.84) }
    private var paused: Bool { reduceMotion || controlActiveState != .key }

    var body: some View {
        TimelineView(.animation(minimumInterval: interval, paused: paused)) { context in
            let t = paused ? 0 : context.date.timeIntervalSinceReferenceDate
            avatarCore(t: t)
                .rotationEffect(bodyRotation(t))
                .offset(y: bodyYOffset(t))
                .scaleEffect(x: bodyScaleX(t), y: bodyScaleY(t))
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            stateBadge
        }
        .accessibilityLabel("\(name)，\(Self.accessibilityState(state))")
    }

    // MARK: - 小牛头部与脸

    private func avatarCore(t: TimeInterval) -> some View {
        ZStack {
            // 耳朵和角放在头部后面；尺寸全部相对头像大小，缩到侧栏仍可辨识。
            Group {
                Capsule()
                    .fill(mid)
                    .frame(width: size * 0.30, height: size * 0.16)
                    .rotationEffect(.degrees(24))
                    .offset(x: -size * 0.39, y: -size * 0.20)
                Capsule()
                    .fill(mid)
                    .frame(width: size * 0.30, height: size * 0.16)
                    .rotationEffect(.degrees(-24))
                    .offset(x: size * 0.39, y: -size * 0.20)
                Capsule()
                    .fill(LinearGradient(colors: [cream, Camp.stone.opacity(0.9)], startPoint: .bottom, endPoint: .top))
                    .frame(width: size * 0.11, height: size * 0.25)
                    .rotationEffect(.degrees(-18))
                    .offset(x: -size * 0.25, y: -size * 0.35)
                Capsule()
                    .fill(LinearGradient(colors: [cream, Camp.stone.opacity(0.9)], startPoint: .bottom, endPoint: .top))
                    .frame(width: size * 0.11, height: size * 0.25)
                    .rotationEffect(.degrees(18))
                    .offset(x: size * 0.25, y: -size * 0.35)
            }

            // 黏土感头部：柔和方圆轮廓、垂直渐变、高光与深色细描边。
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [light, mid],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous).fill(
                        RadialGradient(
                            colors: [.white.opacity(0.42), .clear],
                            center: UnitPoint(x: 0.32, y: 0.22),
                            startRadius: 0, endRadius: size * 0.58
                        )
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                        .strokeBorder(deep.opacity(0.55), lineWidth: max(1, size * 0.035))
                )
                .frame(width: size * 0.86, height: size * 0.78)
                .offset(y: size * 0.035)
                .shadow(color: deep.opacity(0.28), radius: size * 0.07, y: size * 0.05)

            // 白色额前毛与侧斑，延续概念稿中七色小牛的共同身份特征。
            ZStack {
                Circle().fill(cream).frame(width: size * 0.24, height: size * 0.21)
                Circle().fill(cream).frame(width: size * 0.20, height: size * 0.18)
                    .offset(x: -size * 0.13, y: size * 0.03)
                Circle().fill(cream).frame(width: size * 0.18, height: size * 0.16)
                    .offset(x: size * 0.13, y: size * 0.04)
            }
            .offset(y: -size * 0.28)

            Circle()
                .fill(cream.opacity(0.92))
                .frame(width: size * 0.23, height: size * 0.20)
                .offset(x: -size * 0.29, y: size * 0.04)

            // 奶牛口鼻区：粉色胶泥质感 + 两个鼻孔。
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.77, blue: 0.76), Color(red: 0.94, green: 0.61, blue: 0.63)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(Capsule().stroke(deep.opacity(0.22), lineWidth: max(0.7, size * 0.018)))
                .frame(width: size * 0.48, height: size * 0.28)
                .offset(y: size * 0.15)
            HStack(spacing: size * 0.12) {
                Circle().fill(deep.opacity(0.68)).frame(width: size * 0.055, height: size * 0.045)
                Circle().fill(deep.opacity(0.68)).frame(width: size * 0.055, height: size * 0.045)
            }
            .offset(y: size * 0.11)

            face(t: t)

            // 颈牌保留首字母身份锚，避免同色伙伴失去可辨识度。
            Text(String(name.prefix(1)))
                .font(.system(size: size * 0.20, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, size * 0.10)
                .padding(.vertical, size * 0.02)
                .background(deep.opacity(0.55), in: Capsule())
                .offset(y: size * 0.42)
        }
    }

    @ViewBuilder private func face(t: TimeInterval) -> some View {
        // 按名字散列错开眨眼相位，避免全场同时眨眼
        let phase = Double(name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 17) * 0.2
        let blink = !paused && (t + phase).truncatingRemainder(dividingBy: 3.4) < 0.14
        let dart = state == .working ? sin(t * 10) * size * 0.035 : 0
        let closed = state == .napping

        // 眉毛（按状态起落/皱起）
        HStack(spacing: size * 0.20) {
            browShape(mirror: false)
            browShape(mirror: true)
        }
        .offset(x: dart * 0.6, y: -size * 0.18 + browLift)

        // 眼睛 + 高光
        HStack(spacing: size * 0.19) {
            eye(blink: blink || closed)
            eye(blink: blink || closed)
        }
        .offset(x: dart, y: -size * 0.04)

        // 腮红
        HStack(spacing: size * 0.46) {
            Ellipse().fill(deep.opacity(0.20))
                .frame(width: size * 0.14, height: size * 0.08)
            Ellipse().fill(deep.opacity(0.20))
                .frame(width: size * 0.14, height: size * 0.08)
        }
        .offset(y: size * 0.045)

        mouth
            .offset(x: state == .working ? dart * 0.4 : 0, y: size * 0.22)
    }

    private func eye(blink: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            Capsule()
                .fill(Color(nsColor: NSColor(deep).blended(withFraction: 0.45, of: .black) ?? NSColor(deep)))
                .frame(width: size * 0.105, height: blink ? size * 0.028 : size * 0.17)
            if !blink {
                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: size * 0.038, height: size * 0.038)
                    .offset(x: -size * 0.008, y: size * 0.018)
            }
        }
        .frame(height: size * 0.17, alignment: .center)
    }

    private func browShape(mirror: Bool) -> some View {
        Capsule()
            .fill(deep.opacity(0.75))
            .frame(width: size * 0.14, height: max(1, size * 0.032))
            .rotationEffect(.degrees((mirror ? -1 : 1) * browAngle))
    }

    private var browAngle: Double {
        switch state {
        case .asking: -12          // 扬眉
        case .scratching: 14       // 皱眉
        case .celebrating: -8
        default: 0
        }
    }

    private var browLift: CGFloat {
        switch state {
        case .asking, .celebrating: -size * 0.02
        case .scratching: size * 0.012
        default: 0
        }
    }

    @ViewBuilder private var mouth: some View {
        let stroke = StrokeStyle(lineWidth: max(1, size * 0.045), lineCap: .round)
        let mouthColor = Color(nsColor: NSColor(deep).blended(withFraction: 0.3, of: .black) ?? NSColor(deep))
        switch state {
        case .idle:
            MouthArc(openness: 0.32)
                .stroke(mouthColor, style: stroke)
                .frame(width: size * 0.22, height: size * 0.09)
        case .thinking:
            Circle()
                .fill(mouthColor)
                .frame(width: size * 0.075, height: size * 0.075)
        case .working:
            Capsule()
                .fill(mouthColor)
                .frame(width: size * 0.16, height: max(1, size * 0.04))
        case .asking:
            Ellipse()
                .fill(mouthColor)
                .frame(width: size * 0.11, height: size * 0.13)
        case .scratching:
            SquiggleMouth()
                .stroke(mouthColor, style: stroke)
                .frame(width: size * 0.22, height: size * 0.07)
        case .celebrating:
            MouthArc(openness: 1)
                .fill(mouthColor)
                .frame(width: size * 0.26, height: size * 0.14)
        case .napping:
            MouthArc(openness: 0.2)
                .stroke(mouthColor.opacity(0.7), style: stroke)
                .frame(width: size * 0.16, height: size * 0.06)
        }
    }

    // MARK: - 状态徽章（彩色小圆片 + 符号）

    @ViewBuilder private var stateBadge: some View {
        switch state {
        case .idle:
            EmptyView()
        case .thinking:
            badgeChip(color: Camp.creek) { dots }
        case .working:
            badgeChip(color: Camp.creek) {
                animatedSymbol("hammer.fill", period: 0.3, rotation: 20)
            }
        case .asking:
            badgeChip(color: Camp.amber) {
                animatedSymbol("hand.raised.fill", period: 0.5, y: -size * 0.05)
            }
        case .scratching:
            badgeChip(color: Camp.charcoalRed) {
                animatedSymbol("questionmark", period: 0.5, rotation: 12, weight: .bold)
            }
        case .celebrating:
            badgeChip(color: Camp.moss) {
                animatedSymbol("sparkles", period: 0.2, scale: 1.25)
            }
        case .napping:
            nappingBadge
        }
    }

    private func badgeChip<Content: View>(color: Color, @ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.system(size: size * 0.20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size * 0.40, height: size * 0.40)
            .background(color, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: max(0.8, size * 0.022)))
            .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
            .offset(x: size * 0.10, y: -size * 0.10)
    }

    private var dots: some View {
        TimelineView(.animation(minimumInterval: 0.25, paused: paused)) { context in
            let phase = paused ? 1 : Int(context.date.timeIntervalSinceReferenceDate * 3) % 3
            HStack(spacing: size * 0.028) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .frame(width: size * 0.055, height: size * 0.055)
                        .opacity(index <= phase ? 1 : 0.35)
                }
            }
        }
    }

    private func animatedSymbol(
        _ systemName: String,
        period: Double,
        rotation: Double = 0,
        y: CGFloat = 0,
        scale: CGFloat = 1,
        weight: Font.Weight = .semibold
    ) -> some View {
        TimelineView(.animation(minimumInterval: period / 2, paused: paused)) { context in
            let phase = wave(context.date.timeIntervalSinceReferenceDate, period: period)
            let signed = CGFloat(phase)
            let amount = CGFloat(abs(phase))
            Image(systemName: systemName)
                .fontWeight(weight)
                .rotationEffect(.degrees(paused ? 0 : phase * rotation))
                .offset(y: paused ? 0 : signed * y)
                .scaleEffect(paused ? 1 : 1 + (scale - 1) * amount)
        }
    }

    private var nappingBadge: some View {
        TimelineView(.animation(minimumInterval: 0.6, paused: paused)) { context in
            let phase = paused ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.6) / 0.6
            Text("Zzz")
                .font(.system(size: size * 0.20, weight: .bold, design: .rounded))
                .foregroundStyle(Camp.inkSecondary)
                .opacity(paused ? 1 : 0.35 + 0.65 * (1 - phase))
                .offset(x: size * 0.16, y: paused ? -size * 0.12 : -size * (0.08 + 0.16 * phase))
        }
    }

    // MARK: - 身体动效（演真实状态）

    private func bodyRotation(_ t: TimeInterval) -> Angle {
        guard !paused else { return .zero }
        switch state {
        case .scratching:
            return .degrees(wave(t, period: 0.5) * 4)
        case .celebrating:
            return .degrees(wave(t, period: 0.2) * 5)
        default:
            return .zero
        }
    }

    private func bodyYOffset(_ t: TimeInterval) -> CGFloat {
        guard !paused else { return 0 }
        switch state {
        case .idle:
            return sin(t * .pi * 2 / 3.2) * size * 0.012 // 呼吸
        case .working:
            return wave(t, period: 0.3) * size * 0.025
        case .asking:
            return -abs(wave(t, period: 0.5)) * size * 0.035
        case .celebrating:
            return -abs(wave(t, period: 0.2)) * size * 0.06
        case .napping:
            return sin(t * .pi * 2 / 0.6) * size * 0.015
        default:
            return 0
        }
    }

    private func bodyScaleX(_ t: TimeInterval) -> CGFloat {
        guard !paused, state == .celebrating else { return 1 }
        // 挤压拉伸：跳起时瘦高，落地时矮胖
        return 1 - wave(t, period: 0.2) * 0.035
    }

    private func bodyScaleY(_ t: TimeInterval) -> CGFloat {
        guard !paused else { return 1 }
        switch state {
        case .idle:
            return 1 + sin(t * .pi * 2 / 3.2) * 0.01
        case .celebrating:
            return 1 + wave(t, period: 0.2) * 0.045
        default:
            return 1
        }
    }

    private func wave(_ t: TimeInterval, period: Double) -> Double {
        sin((t / period) * .pi * 2)
    }

    private var interval: Double {
        switch state {
        case .idle: 0.3
        case .thinking: 0.25
        case .working: 0.3
        case .asking: 0.5
        case .scratching: 0.5
        case .celebrating: 0.2
        case .napping: 0.6
        }
    }

    private static func accessibilityState(_ state: AvatarState) -> String {
        switch state {
        case .idle: "空闲"
        case .thinking: "思考中"
        case .working: "工作中"
        case .asking: "在提问"
        case .scratching: "遇到困难"
        case .celebrating: "刚完成"
        case .napping: "打盹中"
        }
    }
}

// MARK: - 嘴型 Shape

/// 上弯微笑弧；openness 0…1 控制张开程度（1 = 填充的开口笑）。
private struct MouthArc: Shape {
    var openness: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * (0.8 + openness * 1.2))
        )
        if openness >= 0.9 {
            path.closeSubpath()
        }
        return path
    }
}

/// 卡住时的波浪嘴。
private struct SquiggleMouth: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.midY),
            control1: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY),
            control2: CGPoint(x: rect.midX - rect.width * 0.1, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: CGPoint(x: rect.midX + rect.width * 0.1, y: rect.minY),
            control2: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.maxY)
        )
        return path
    }
}
