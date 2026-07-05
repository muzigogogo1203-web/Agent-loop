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
                            .stroke(.orange.opacity(0.45), lineWidth: 1)
                        Path { path in
                            path.move(to: CGPoint(x: 24, y: 64))
                            path.addCurve(
                                to: CGPoint(x: unfolded ? 126 : 62, y: 28),
                                control1: CGPoint(x: 54, y: 18),
                                control2: CGPoint(x: 94, y: 84)
                            )
                        }
                        .stroke(.blue.opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        HStack(spacing: unfolded ? 34 : 10) {
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .fill(index == 1 ? Color.orange : Color.green)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                }
                .shadow(color: .black.opacity(0.06), radius: unfolded ? 8 : 3, y: 2)
        }
        .frame(width: 170, height: 118)
    }

    private var campfire: some View {
        VStack(spacing: 8) {
            TimelineView(.animation(minimumInterval: 0.3, paused: paused)) { context in
                let flip = !paused && Int(context.date.timeIntervalSinceReferenceDate * 3) % 2 == 0
                let spark = paused ? 1 : Int(context.date.timeIntervalSinceReferenceDate * 3) % 3
                ZStack(alignment: .top) {
                    Ellipse()
                        .fill(Camp.ember.opacity(0.18))
                        .frame(width: 74, height: 16)
                        .offset(y: 58)
                    Image(systemName: flip ? "flame.fill" : "flame")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(colors: [Camp.amber, Camp.emberDeep], startPoint: .top, endPoint: .bottom)
                        )
                        .padding(.top, 16)
                    HStack(spacing: 7) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Camp.amber.opacity(index == spark ? 0.95 : 0.28))
                                .frame(width: index == spark ? 5 : 4, height: index == spark ? 5 : 4)
                                .offset(y: index == spark && !paused ? -4 : 0)
                        }
                    }
                }
            }
            Text("篝火")
                .font(.caption)
                .foregroundStyle(Camp.inkSecondary)
        }
        .frame(width: 110)
    }

    private func companionSeat(_ companion: CompanionRecord) -> some View {
        let state = states[companion.id] ?? .idle
        let card = selectableCard(for: companion.id)
        return Button {
            if let card { onSelectCard(card.id) }
        } label: {
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
                Text(label(for: state))
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
                    .lineLimit(1)
            }
            .frame(width: 120)
            .padding(10)
            .contentShape(RoundedRectangle(cornerRadius: Camp.smallRadius))
        }
        .buttonStyle(.plain)
        .disabled(card == nil)
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
        let angle = (Double(index) / Double(total)) * .pi * 2 - .pi / 2
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }
}
