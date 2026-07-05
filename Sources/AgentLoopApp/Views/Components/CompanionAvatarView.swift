import SwiftUI
import AgentLoopCore

typealias AvatarState = CompanionAnimState

struct CompanionAvatarView: View {
    let name: String
    let colorName: String
    var state: AvatarState = .idle
    var size: CGFloat = 26
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var controlActiveState

    static let palette: [String: Color] = [
        "purple": Color(red: 0.33, green: 0.29, blue: 0.72),
        "teal": Color(red: 0.11, green: 0.62, blue: 0.46),
        "coral": Color(red: 0.85, green: 0.35, blue: 0.19),
        "pink": Color(red: 0.83, green: 0.33, blue: 0.49),
        "blue": Color(red: 0.22, green: 0.54, blue: 0.87),
        "green": Color(red: 0.39, green: 0.60, blue: 0.13),
        "amber": Color(red: 0.94, green: 0.62, blue: 0.15),
    ]

    private var color: Color { Self.palette[colorName] ?? .gray }
    private var paused: Bool { reduceMotion || controlActiveState != .key }

    var body: some View {
        TimelineView(.animation(minimumInterval: interval, paused: paused)) { context in
            let t = paused ? 0 : context.date.timeIntervalSinceReferenceDate
            avatarCore
                .rotationEffect(bodyRotation(t))
                .offset(y: bodyYOffset(t))
                .scaleEffect(bodyScale(t))
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            stateBadge
        }
    }

    private var avatarCore: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.22))
            Circle()
                .stroke(color.opacity(0.55), lineWidth: 1)
            eyes
            Text(String(name.prefix(1)))
                .font(.system(size: size * 0.38, weight: .medium))
                .foregroundStyle(color)
                .offset(y: size * 0.18)
        }
    }

    private var eyes: some View {
        TimelineView(.animation(minimumInterval: interval, paused: paused)) { context in
            let t = paused ? 0 : context.date.timeIntervalSinceReferenceDate
            let blink = !paused && t.truncatingRemainder(dividingBy: 3.0) < 0.15
            let offset = state == .working ? sin(t * 12) * size * 0.04 : 0
            HStack(spacing: size * 0.16) {
                Capsule()
                    .frame(width: size * 0.09, height: blink ? size * 0.02 : size * 0.16)
                Capsule()
                    .frame(width: size * 0.09, height: blink ? size * 0.02 : size * 0.16)
            }
            .foregroundStyle(color)
            .offset(x: offset, y: -size * 0.12)
        }
    }

    @ViewBuilder private var stateBadge: some View {
        switch state {
        case .idle:
            EmptyView()
        case .thinking:
            dotsBadge
        case .working:
            animatedSymbol("hammer.fill", period: 0.3, rotation: 18)
        case .asking:
            animatedSymbol("hand.raised.fill", period: 0.5, y: -size * 0.08)
        case .scratching:
            animatedSymbol("questionmark", period: 0.5, rotation: 12, weight: .bold)
        case .celebrating:
            animatedSymbol("sparkles", period: 0.2, scale: 1.22)
        case .napping:
            nappingBadge
        }
    }

    private var dotsBadge: some View {
        TimelineView(.animation(minimumInterval: 0.25, paused: paused)) { context in
            let phase = paused ? 1 : Int(context.date.timeIntervalSinceReferenceDate * 3) % 3
            HStack(spacing: 1.5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .frame(width: 3, height: 3)
                        .opacity(index <= phase ? 1 : 0.25)
                }
            }
            .foregroundStyle(color)
            .offset(x: size * 0.28, y: -size * 0.12)
        }
    }

    private func animatedSymbol(
        _ systemName: String,
        period: Double,
        rotation: Double = 0,
        y: CGFloat = 0,
        scale: CGFloat = 1,
        weight: Font.Weight = .regular
    ) -> some View {
        TimelineView(.animation(minimumInterval: period / 2, paused: paused)) { context in
            let phase = wave(context.date.timeIntervalSinceReferenceDate, period: period)
            let signed = CGFloat(phase)
            let amount = CGFloat(abs(phase))
            Image(systemName: systemName)
                .font(.caption2.weight(weight))
                .rotationEffect(.degrees(paused ? 0 : phase * rotation))
                .offset(y: paused ? 0 : signed * y)
                .scaleEffect(paused ? 1 : 1 + (scale - 1) * amount)
        }
    }

    private var nappingBadge: some View {
        TimelineView(.animation(minimumInterval: 0.6, paused: paused)) { context in
            let phase = paused ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.6) / 0.6
            Text("Zzz")
                .font(.caption2.weight(.bold))
                .opacity(paused ? 1 : 0.35 + 0.65 * (1 - phase))
                .offset(x: size * 0.18, y: paused ? -size * 0.14 : -size * (0.10 + 0.18 * phase))
        }
    }

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
        case .working:
            return wave(t, period: 0.3) * size * 0.025
        case .asking:
            return -abs(wave(t, period: 0.5)) * size * 0.035
        case .celebrating:
            return -abs(wave(t, period: 0.2)) * size * 0.05
        case .napping:
            return sin(t * .pi * 2 / 0.6) * size * 0.015
        default:
            return 0
        }
    }

    private func bodyScale(_ t: TimeInterval) -> CGFloat {
        guard !paused else { return 1 }
        switch state {
        case .celebrating:
            return 1 + abs(wave(t, period: 0.2)) * 0.04
        default:
            return 1
        }
    }

    private func wave(_ t: TimeInterval, period: Double) -> Double {
        sin((t / period) * .pi * 2)
    }

    private var interval: Double {
        switch state {
        case .idle: 0.4
        case .thinking: 0.25
        case .working: 0.3
        case .asking: 0.5
        case .scratching: 0.5
        case .celebrating: 0.2
        case .napping: 0.6
        }
    }
}
