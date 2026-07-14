import SwiftUI
import AgentLoopCore

struct CampfireTheaterView: View {
    let phase: AppStore.MissionPhase
    let cards: [CardRecord]
    let companions: [String: CompanionRecord]
    let states: [String: CompanionAnimState]
    let campMemoryCount: Int
    var onSelectCard: (String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var controlActiveState

    private var paused: Bool { reduceMotion || controlActiveState != .key }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            theaterHeader
            if sortedCompanions.count > 8 {
                denseTheater
            } else {
                radialTheater
            }
            loopStageRail
        }
        .padding(16)
        .background(theaterBackground)
    }

    private var theaterBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .fill(Camp.surface)
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [Camp.ember.opacity(0.14), Camp.creek.opacity(0.05), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 360
                    )
                )
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .stroke(Camp.line, lineWidth: 1)
        }
    }

    private var theaterHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Coding 草原")
                    .font(.headline)
                    .foregroundStyle(Camp.ink)
                Text("牛群正在按真实工作卡推进任务")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }
            Spacer()
            CampChip(text: "\(sortedCompanions.count) 只牛", color: Camp.creek, icon: "person.2.fill")
            CampChip(text: "营地知识 \(campMemoryCount)", color: Camp.amber, icon: "book.closed.fill")
        }
    }

    private var radialTheater: some View {
        GeometryReader { proxy in
            ZStack {
                loopOrbit(in: proxy.size)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                stageMarkers(in: proxy.size)
                coreCluster
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                ForEach(Array(sortedCompanions.enumerated()), id: \.element.id) { index, companion in
                    agentSeat(companion)
                        .position(seatPosition(for: index, total: sortedCompanions.count, size: proxy.size))
                }
                if sortedCompanions.isEmpty {
                    emptySeatHint
                        .position(x: proxy.size.width / 2, y: proxy.size.height * 0.76)
                }
            }
        }
        .frame(minHeight: sortedCompanions.count > 5 ? 430 : 360)
    }

    private var denseTheater: some View {
        VStack(spacing: 14) {
            GeometryReader { proxy in
                ZStack {
                    loopOrbit(in: proxy.size)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    stageMarkers(in: proxy.size)
                    coreCluster
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
            }
            .frame(height: 260)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(sortedCompanions, id: \.id) { companion in
                        agentSeat(companion)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func loopOrbit(in size: CGSize) -> some View {
        let ring = ringSize(in: size)
        return ZStack {
            Circle()
                .stroke(Camp.line.opacity(0.8), lineWidth: 1)
                .frame(width: ring.width, height: ring.height)
            Circle()
                .trim(from: 0.03, to: 0.92)
                .stroke(
                    AngularGradient(
                        colors: [
                            Camp.ember.opacity(0.25),
                            Camp.creek.opacity(0.65),
                            Camp.moss.opacity(0.45),
                            Camp.amber.opacity(0.75),
                            Camp.ember.opacity(0.25),
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [14, 11])
                )
                .frame(width: ring.width, height: ring.height)
                .rotationEffect(.degrees(paused ? 0 : orbitRotationDegrees))
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Camp.ember)
                .padding(7)
                .background(Camp.surfaceRaised, in: Circle())
                .overlay(Circle().stroke(Camp.line, lineWidth: 1))
                .offset(x: ring.width * 0.38, y: -ring.height * 0.22)
        }
        .frame(width: ring.width + 60, height: ring.height + 60)
    }

    private var orbitRotationDegrees: Double {
        Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 12) * 360 / 12
    }

    private func stageMarkers(in size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let ring = ringSize(in: size)
        return ZStack {
            ForEach(Array(LoopStage.allCases.enumerated()), id: \.element) { index, stage in
                stageMarker(stage, compact: true)
                    .position(stagePosition(center: center, ring: ring, index: index, total: LoopStage.allCases.count))
            }
        }
    }

    private var coreCluster: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Camp.ember.opacity(0.11))
                    .frame(width: 138, height: 138)
                Circle()
                    .stroke(Camp.ember.opacity(0.25), lineWidth: 1)
                    .frame(width: 120, height: 120)
                campfire
            }
            memoryStack
        }
        .frame(width: 190)
    }

    /// 篝火 v2（M5 资产升级）：三层自绘火焰各自摆动、辉光脉动、火星上升、柴堆与地影。
    private var campfire: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: paused)) { context in
            let t = paused ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                Ellipse()
                    .fill(.black.opacity(0.10))
                    .frame(width: 86, height: 16)
                    .offset(y: 52)
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
                flameLayer(t: t, period: 1.9, phase: 0.0, width: 46, height: 66, color: Camp.emberDeep, y: 10)
                flameLayer(t: t, period: 1.3, phase: 1.1, width: 33, height: 50, color: Camp.amber, y: 17)
                flameLayer(t: t, period: 0.9, phase: 2.3, width: 19, height: 32, color: Color(red: 0.99, green: 0.93, blue: 0.78), y: 25)
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

    private var memoryStack: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "book.closed.fill")
                    .foregroundStyle(Camp.amber)
                Text("营地知识")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                Text("\(campMemoryCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Camp.ember, in: Capsule())
            }
            HStack(spacing: -4) {
                ForEach(0..<memoryChipCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(index == 0 ? Camp.amber.opacity(0.22) : Camp.surfaceRaised)
                        .frame(width: 34, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Camp.amber.opacity(index == 0 ? 0.42 : 0.22), lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Camp.surfaceRaised.opacity(0.92), in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                .stroke(Camp.line, lineWidth: 1)
        )
    }

    private var memoryChipCount: Int {
        max(1, min(4, campMemoryCount == 0 ? 1 : campMemoryCount))
    }

    private var loopStageRail: some View {
        HStack(spacing: 0) {
            ForEach(LoopStage.allCases, id: \.self) { stage in
                stageMarker(stage, compact: false)
                    .frame(maxWidth: .infinity)
                if stage != LoopStage.allCases.last {
                    Image(systemName: stage == .review ? "arrow.uturn.forward" : "arrow.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(stage == activeStage ? activeStage.color.opacity(0.85) : Camp.inkSecondary.opacity(0.55))
                        .frame(width: 22)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Camp.surfaceRaised.opacity(0.86), in: RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .stroke(Camp.line, lineWidth: 1)
        )
    }

    private func stageMarker(_ stage: LoopStage, compact: Bool) -> some View {
        let active = stage == activeStage
        return TimelineView(.animation(minimumInterval: 0.12, paused: paused || !active)) { context in
            let lift = active && !paused ? sin(context.date.timeIntervalSinceReferenceDate * 7) * 2.5 : 0
            VStack(spacing: compact ? 4 : 6) {
                Image(systemName: stage.icon)
                    .font(.system(size: compact ? 16 : 19, weight: .semibold))
                    .foregroundStyle(active ? .white : stage.color)
                    .frame(width: compact ? 34 : 42, height: compact ? 34 : 42)
                    .background(active ? stage.color : stage.color.opacity(0.13), in: Circle())
                    .overlay(Circle().stroke(active ? Color.white.opacity(0.7) : stage.color.opacity(0.28), lineWidth: active ? 1.4 : 1))
                    .shadow(color: active ? stage.color.opacity(0.48) : .clear, radius: active ? 12 : 0, y: 2)
                Text(compact ? stage.shortTitle : stage.title)
                    .font(compact ? .caption2.weight(active ? .semibold : .regular) : .caption.weight(active ? .semibold : .regular))
                    .foregroundStyle(active ? stage.color : Camp.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .offset(y: lift)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: activeStage)
        }
    }

    private func agentSeat(_ companion: CompanionRecord) -> some View {
        let state = states[companion.id] ?? .idle
        let card = selectableCard(for: companion.id)
        return Button {
            if let card { onSelectCard(card.id) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    CompanionAvatarView(
                        name: companion.name,
                        colorName: companion.color,
                        state: state,
                        size: 42
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(companion.name)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Camp.ink)
                            .lineLimit(1)
                        statusCapsule(for: state)
                    }
                }
                HStack(spacing: 6) {
                    ForEach(seatSymbols(for: state), id: \.self) { symbol in
                        Image(systemName: symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(seatAccent(for: state))
                            .frame(width: 23, height: 23)
                            .background(seatAccent(for: state).opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
                Text(card?.title ?? "等待分派")
                    .font(.caption)
                    .foregroundStyle(card == nil ? Camp.inkSecondary : Camp.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 146, alignment: .leading)
            .padding(10)
            .background(Camp.surfaceRaised.opacity(0.94), in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                    .stroke(seatAccent(for: state).opacity(card == nil ? 0.28 : 0.72), lineWidth: card == nil ? 1 : 1.4)
            )
            .shadow(color: seatAccent(for: state).opacity(card == nil ? 0 : 0.14), radius: 8, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(card == nil)
        .help(card == nil ? "这只牛当前没有可查看的工作卡" : "查看这只牛的工作卡")
    }

    private func statusCapsule(for state: CompanionAnimState) -> some View {
        Text(label(for: state))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(seatAccent(for: state))
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(seatAccent(for: state).opacity(0.13), in: Capsule())
    }

    private var emptySeatHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.clock")
                .foregroundStyle(Camp.inkSecondary)
            Text("等待牛群开工")
                .font(.caption)
                .foregroundStyle(Camp.inkSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Camp.surfaceRaised, in: Capsule())
        .overlay(Capsule().stroke(Camp.line, lineWidth: 1))
    }

    private var sortedCompanions: [CompanionRecord] {
        companions.values.sorted(by: { $0.name < $1.name })
    }

    private var activeStage: LoopStage {
        switch phase {
        case .idle, .planning:
            return .goal
        case .executing:
            if cards.contains(where: { $0.status == .blocked }) {
                return .review
            }
            if cards.contains(where: { $0.status == .running }) {
                return .work
            }
            if cards.contains(where: { $0.status == .ready }) && cards.contains(where: { $0.status == .done }) {
                return .cycle
            }
            if cards.contains(where: { $0.status == .done }) {
                return .handoff
            }
            return .work
        case .delivering:
            return .review
        case .accepted:
            return .memory
        case .failed, .error:
            return .review
        }
    }

    private func selectableCard(for companionId: String) -> CardRecord? {
        cards.first { $0.assigneeId == companionId && $0.status == .running }
            ?? cards.first { $0.assigneeId == companionId && $0.status == .blocked }
            ?? cards.first { $0.assigneeId == companionId && $0.status == .ready }
            ?? cards.last { $0.assigneeId == companionId && $0.status == .done }
    }

    private func label(for state: CompanionAnimState) -> String {
        switch state {
        case .idle: "在营地休息"
        case .thinking: "思考中"
        case .working: "正在干活"
        case .asking: "等你决定"
        case .scratching: "复检中"
        case .celebrating: "刚完成"
        case .napping: "等待中"
        }
    }

    private func seatSymbols(for state: CompanionAnimState) -> [String] {
        switch state {
        case .idle: ["circle.dashed", "tray", "clock"]
        case .thinking: ["brain.head.profile", "map", "sparkles"]
        case .working: ["hammer.fill", "doc.text", "terminal"]
        case .asking: ["hand.raised.fill", "questionmark.bubble", "hourglass"]
        case .scratching: ["magnifyingglass", "exclamationmark.triangle", "arrow.uturn.forward"]
        case .celebrating: ["checkmark.seal.fill", "shippingbox.fill", "sparkles"]
        case .napping: ["moon.zzz.fill", "clock", "circle.dotted"]
        }
    }

    private func seatAccent(for state: CompanionAnimState) -> Color {
        switch state {
        case .idle, .napping: Camp.stone
        case .thinking, .working: Camp.creek
        case .asking: Camp.amber
        case .scratching: Camp.charcoalRed
        case .celebrating: Camp.moss
        }
    }

    private func ringSize(in size: CGSize) -> CGSize {
        let width = min(size.width * 0.58, 560)
        let height = min(size.height * 0.46, 250)
        return CGSize(width: max(width, 280), height: max(height, 190))
    }

    private func stagePosition(center: CGPoint, ring: CGSize, index: Int, total: Int) -> CGPoint {
        let angle = (Double(index) / Double(total)) * .pi * 2 - .pi / 2
        return CGPoint(
            x: center.x + cos(angle) * ring.width * 0.5,
            y: center.y + sin(angle) * ring.height * 0.5
        )
    }

    private func seatPosition(for index: Int, total: Int, size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        guard total > 0 else { return center }
        if total == 1 {
            return CGPoint(x: center.x + min(size.width * 0.28, 230), y: center.y)
        }
        if total == 2 {
            let xOffset = min(size.width * 0.31, 260)
            return CGPoint(x: center.x + (index == 0 ? -xOffset : xOffset), y: center.y + 8)
        }
        let angle = (Double(index) / Double(total)) * .pi * 2 - .pi / 2
        let radiusX = min(size.width * 0.38, total > 5 ? 335 : 285)
        let radiusY = min(size.height * 0.34, total > 5 ? 165 : 140)
        return CGPoint(
            x: center.x + cos(angle) * radiusX,
            y: center.y + sin(angle) * radiusY
        )
    }
}

private enum LoopStage: CaseIterable, Hashable {
    case goal
    case work
    case handoff
    case review
    case cycle
    case memory

    var title: String {
        switch self {
        case .goal: "接收目标"
        case .work: "开始工作"
        case .handoff: "产出交接"
        case .review: "复检判断"
        case .cycle: "继续循环"
        case .memory: "回营沉淀"
        }
    }

    var shortTitle: String {
        switch self {
        case .goal: "目标"
        case .work: "工作中"
        case .handoff: "交接"
        case .review: "复检"
        case .cycle: "循环中"
        case .memory: "沉淀"
        }
    }

    var icon: String {
        switch self {
        case .goal: "flag.fill"
        case .work: "hammer.fill"
        case .handoff: "envelope.fill"
        case .review: "checkmark.seal.fill"
        case .cycle: "arrow.triangle.2.circlepath"
        case .memory: "book.closed.fill"
        }
    }

    var color: Color {
        switch self {
        case .goal: Camp.amber
        case .work: Camp.creek
        case .handoff: Color(red: 0.48, green: 0.38, blue: 0.78)
        case .review: Camp.moss
        case .cycle: Camp.ember
        case .memory: Camp.amber
        }
    }
}

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
