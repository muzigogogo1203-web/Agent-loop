import SwiftUI
import AgentLoopCore

struct CampfireTheaterView: View {
    let phase: AppStore.MissionPhase
    let cards: [CardRecord]
    let companions: [String: CompanionRecord]
    let states: [String: CompanionAnimState]
    var onSelectCard: (String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var controlActiveState

    private var paused: Bool { reduceMotion || controlActiveState != .key }

    var body: some View {
        Group {
            if case .planning = phase {
                planningScene
            } else if sortedCompanions.count > 10 {
                ScrollView(.horizontal) {
                    HStack(alignment: .center, spacing: 22) {
                        campfire
                        ForEach(sortedCompanions, id: \.id) { companion in
                            companionSeat(companion)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
                }
            } else {
                GeometryReader { proxy in
                    ZStack {
                        campfire
                            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        ForEach(Array(sortedCompanions.enumerated()), id: \.element.id) { index, companion in
                            companionSeat(companion)
                                .position(position(for: index, total: sortedCompanions.count, size: proxy.size))
                        }
                    }
                }
                .frame(minHeight: sortedCompanions.count > 6 ? 360 : 280)
            }
        }
        .background(theaterBackground)
    }

    private var theaterBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .fill(Camp.surface)
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [Camp.ember.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 260
                    )
                )
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .stroke(Camp.line, lineWidth: 1)
        }
    }

    private var sortedCompanions: [CompanionRecord] {
        companions.values.sorted(by: { $0.name < $1.name })
    }

    private var planningScene: some View {
        HStack(spacing: 30) {
            VStack(spacing: 8) {
                CompanionAvatarView(name: "向导", colorName: "amber", state: .thinking, size: 66)
                Text("规划中")
                    .font(.headline)
                Text("摊开地图")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            planningMap
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    private var planningMap: some View {
        TimelineView(.animation(minimumInterval: 0.45, paused: paused)) { context in
            let unfolded = paused || Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
                .frame(width: unfolded ? 150 : 86, height: 96)
                .overlay {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Camp.ember.opacity(0.45), lineWidth: 1)
                        Path { path in
                            path.move(to: CGPoint(x: 24, y: 64))
                            path.addCurve(
                                to: CGPoint(x: unfolded ? 126 : 62, y: 28),
                                control1: CGPoint(x: 54, y: 18),
                                control2: CGPoint(x: 94, y: 84)
                            )
                        }
                        .stroke(Camp.creek.opacity(0.65), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        HStack(spacing: unfolded ? 34 : 10) {
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .fill(index == 1 ? Camp.ember : Camp.moss)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                }
                .shadow(color: .black.opacity(0.06), radius: unfolded ? 8 : 3, y: 2)
        }
        .frame(width: 170, height: 118)
    }

    /// 篝火 v2（M5 资产升级）：三层自绘火焰各自摆动、辉光脉动、火星上升、柴堆与地影。
    /// 10fps ambient、reduceMotion/失焦静态定格。
    private var campfire: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: paused)) { context in
            let t = paused ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                // 地影
                Ellipse()
                    .fill(.black.opacity(0.10))
                    .frame(width: 86, height: 16)
                    .offset(y: 52)
                // 辉光（慢脉动）
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Camp.ember.opacity(0.30), .clear],
                            center: .center, startRadius: 4, endRadius: 62
                        )
                    )
                    .frame(width: 124, height: 110)
                    .scaleEffect(paused ? 1 : 1 + sin(t * 1.6) * 0.06)
                    .offset(y: 8)
                // 柴堆
                Group {
                    Capsule()
                        .fill(LinearGradient(colors: [Color(red: 0.48, green: 0.32, blue: 0.18), Color(red: 0.34, green: 0.22, blue: 0.12)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 62, height: 11)
                        .rotationEffect(.degrees(-14))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(red: 0.54, green: 0.37, blue: 0.21), Color(red: 0.38, green: 0.25, blue: 0.14)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 62, height: 11)
                        .rotationEffect(.degrees(14))
                }
                .offset(y: 44)
                // 三层火焰：外焰/中焰/内焰各自的摆动周期与相位
                flameLayer(t: t, period: 1.9, phase: 0.0, width: 46, height: 66, color: Camp.emberDeep, y: 10)
                flameLayer(t: t, period: 1.3, phase: 1.1, width: 33, height: 50, color: Camp.amber, y: 17)
                flameLayer(t: t, period: 0.9, phase: 2.3, width: 19, height: 32, color: Color(red: 0.99, green: 0.93, blue: 0.78), y: 25)
                // 火星（三粒错相位上升，渐隐）
                ForEach(0..<3, id: \.self) { index in
                    sparkParticle(t: t, index: index)
                }
            }
            .frame(width: 130, height: 130)
        }
        .accessibilityHidden(true)
    }

    private func flameLayer(
        t: TimeInterval, period: Double, phase: Double,
        width: CGFloat, height: CGFloat, color: Color, y: CGFloat
    ) -> some View {
        let sway = paused ? 0 : sin((t / period) * .pi * 2 + phase)
        return FlameShape(sway: sway * 0.6)
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.78)],
                    startPoint: .bottom, endPoint: .top
                )
            )
            .frame(width: width, height: height)
            .scaleEffect(x: 1 + sway * 0.05, y: 1 + (paused ? 0 : sin((t / period) * .pi * 2 + phase + 0.7)) * 0.07, anchor: .bottom)
            .offset(y: -y)
    }

    private func sparkParticle(t: TimeInterval, index: Int) -> some View {
        // 每粒火星周期 2.4s，错开 0.8s；从火焰上方升起并渐隐
        let cycle = 2.4
        let progress = paused
            ? Double(index) * 0.27 + 0.15
            : ((t + Double(index) * 0.8).truncatingRemainder(dividingBy: cycle)) / cycle
        let drift = sin(progress * .pi * 3 + Double(index) * 2.1) * 9
        return Circle()
            .fill(Camp.amber)
            .frame(width: 3.5, height: 3.5)
            .opacity((1 - progress) * 0.9)
            .offset(
                x: CGFloat(drift) + CGFloat(index - 1) * 7,
                y: -34 - CGFloat(progress) * 44
            )
    }

    private func companionSeat(_ companion: CompanionRecord) -> some View {
        let state = states[companion.id] ?? .idle
        let card = selectableCard(for: companion.id)
        return TheaterSeat(
            companion: companion,
            state: state,
            stateLabel: label(for: state),
            clickable: card != nil
        ) {
            if let card { onSelectCard(card.id) }
        }
    }

    private func selectableCard(for companionId: String) -> CardRecord? {
        cards.first { $0.assigneeId == companionId && $0.status == .running }
            ?? cards.first { $0.assigneeId == companionId && $0.status == .blocked }
            ?? cards.last { $0.assigneeId == companionId && $0.status == .done }
    }

    private func label(for state: CompanionAnimState) -> String {
        switch state {
        case .idle: "休整"
        case .thinking: "思考中"
        case .working: "干活中"
        case .asking: "举手提问"
        case .scratching: "卡住了"
        case .celebrating: "刚完成"
        case .napping: "打盹等待"
        }
    }

    private func position(for index: Int, total: Int, size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let firstRingCount = min(total, 6)
        if index < firstRingCount {
            return point(center: center, radius: 115, index: index, total: firstRingCount)
        }
        return point(center: center, radius: 165, index: index - firstRingCount, total: total - firstRingCount)
    }

    private func point(center: CGPoint, radius: CGFloat, index: Int, total: Int) -> CGPoint {
        guard total > 0 else { return center }
        // 1-2 人围火而坐时水平分布（火焰左右），3 人起才用环形
        let start: Double = total <= 2 ? .pi : -.pi / 2
        let angle = start + (Double(index) / Double(total)) * .pi * 2
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }
}


// MARK: - 座位（hover 反馈 + 可点击提示）

private struct TheaterSeat: View {
    let companion: CompanionRecord
    let state: CompanionAnimState
    let stateLabel: String
    let clickable: Bool
    var onTap: () -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                CompanionAvatarView(
                    name: companion.name,
                    colorName: companion.color,
                    state: state,
                    size: 58
                )
                Text(companion.name)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                Text(hovering && clickable ? "看看小目标" : stateLabel)
                    .font(.caption)
                    .foregroundStyle(hovering && clickable ? Camp.ember : Camp.inkSecondary)
                    .lineLimit(1)
            }
            .frame(width: 120)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                    .fill(Camp.ember.opacity(hovering && clickable ? 0.08 : 0))
            )
            .contentShape(RoundedRectangle(cornerRadius: Camp.smallRadius))
            .scaleEffect(hovering && clickable && !reduceMotion ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!clickable)
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : .snappy(duration: 0.15), value: hovering)
        .help(clickable ? "查看这位伙伴的小目标" : "这位伙伴当前没有可查看的小目标")
    }
}

// MARK: - 火焰 Shape（泪滴形，sway 控制火尖偏摆）

private struct FlameShape: Shape {
    var sway: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tip = CGPoint(x: rect.midX + rect.width * 0.22 * sway, y: rect.minY)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)
        path.move(to: bottom)
        path.addQuadCurve(
            to: tip,
            control: CGPoint(x: rect.maxX + rect.width * 0.10 * sway, y: rect.height * 0.42)
        )
        path.addQuadCurve(
            to: bottom,
            control: CGPoint(x: rect.minX + rect.width * 0.10 * sway, y: rect.height * 0.42)
        )
        path.closeSubpath()
        return path
    }
}
