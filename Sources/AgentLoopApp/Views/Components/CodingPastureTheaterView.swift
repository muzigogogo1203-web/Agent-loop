import SwiftUI
import AgentLoopCore

/// 行动中的动态 Coding 草原。
///
/// 视觉来自已定稿的黏土牧场基座，但牛的状态、工作卡和阶段仍完全由真实事件流驱动。
struct CodingPastureTheaterView: View {
    let phase: AppStore.MissionPhase
    let cards: [CardRecord]
    let companions: [String: CompanionRecord]
    let states: [String: CompanionAnimState]
    let campMemoryCount: Int
    var onSelectCard: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.colorScheme) private var colorScheme

    private var paused: Bool { reduceMotion || controlActiveState != .key }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            pastureHeader
            if sortedCompanions.count > 8 {
                densePasture
            } else {
                pastureStage
            }
            loopStageRail
        }
        .padding(16)
        .background(pastureBackground)
    }

    private var pastureBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .fill(Camp.surface)
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Camp.moss.opacity(colorScheme == .dark ? 0.10 : 0.08),
                            Camp.amber.opacity(colorScheme == .dark ? 0.06 : 0.10),
                            .clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .stroke(Camp.line, lineWidth: 1)
        }
    }

    private var pastureHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Coding 草原")
                    .font(.headline)
                    .foregroundStyle(Camp.ink)
                Text("每只牛都在按真实工作卡放牧")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }
            Spacer()
            CampChip(text: "\(sortedCompanions.count) 只牛", color: Camp.moss, icon: "pawprint.fill")
            CampChip(text: "营地知识 \(campMemoryCount)", color: Camp.amber, icon: "book.closed.fill")
        }
    }

    private var pastureStage: some View {
        AspectFitStageLayout(aspectRatio: 1.5, maxHeight: 440) {
            GeometryReader { proxy in
                ZStack {
                    RanchArtView(kind: .base, layout: .fit(maxWidth: nil))
                        .frame(width: proxy.size.width, height: proxy.size.height)

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    colorScheme == .dark ? .black.opacity(0.05) : .white.opacity(0.03),
                                    .clear,
                                    .black.opacity(colorScheme == .dark ? 0.22 : 0.08),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .allowsHitTesting(false)

                    if sortedCompanions.isEmpty {
                        emptyPastureHint
                            .position(x: proxy.size.width * 0.62, y: proxy.size.height * 0.58)
                    } else {
                        ForEach(Array(sortedCompanions.enumerated()), id: \.element.id) { index, companion in
                            agentSpot(
                                companion,
                                index: index,
                                compact: proxy.size.width < 760 || sortedCompanions.count > 5
                            )
                            .position(
                                pasturePosition(
                                    for: index,
                                    total: sortedCompanions.count,
                                    size: proxy.size
                                )
                            )
                        }
                    }

                    memoryTrough
                        .position(
                            x: max(88, min(proxy.size.width * 0.17, 150)),
                            y: max(42, proxy.size.height - 48)
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Camp.moss.opacity(colorScheme == .dark ? 0.34 : 0.28), lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var densePasture: some View {
        VStack(spacing: 12) {
            AspectFitStageLayout(aspectRatio: 1.5, maxHeight: 200) {
                GeometryReader { proxy in
                    ZStack(alignment: .bottomLeading) {
                        RanchArtView(kind: .base, layout: .fit(maxWidth: nil))
                            .frame(width: proxy.size.width, height: proxy.size.height)
                        LinearGradient(
                            colors: [.clear, .black.opacity(colorScheme == .dark ? 0.32 : 0.14)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .allowsHitTesting(false)

                        HStack(alignment: .bottom) {
                            memoryTrough
                            Spacer()
                            Text("牛群较多，沿草场横向查看")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.30), in: Capsule())
                        }
                        .padding(14)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Camp.moss.opacity(0.30), lineWidth: 1)
                    )
                }
            }
            .frame(maxWidth: .infinity)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(Array(sortedCompanions.enumerated()), id: \.element.id) { index, companion in
                        denseAgentCard(companion, index: index)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder private func agentSpot(
        _ companion: CompanionRecord,
        index: Int,
        compact: Bool
    ) -> some View {
        if RanchArtView.spriteImage(colorName: companion.color) != nil {
            spriteAgentSpot(companion, index: index, compact: compact)
        } else {
            legacyAgentSpot(companion, compact: compact)
        }
    }

    private func spriteAgentSpot(
        _ companion: CompanionRecord,
        index: Int,
        compact: Bool
    ) -> some View {
        let state = states[companion.id] ?? .idle
        let card = selectableCard(for: companion.id)
        let accent = seatAccent(for: state)

        return Button {
            if let card { onSelectCard(card.id) }
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .bottomTrailing) {
                    RanchCowSpriteView(
                        colorName: companion.color,
                        height: compact ? 74 : 96,
                        flipped: index % 2 == 1
                    )
                    Image(systemName: seatSymbols(for: state).first ?? "circle")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(accent, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.86), lineWidth: 1))
                        .offset(x: 2, y: 1)
                }

                Text("\(companion.name) · \(label(for: state))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Camp.surfaceRaised.opacity(0.90), in: Capsule())
                    .overlay(Capsule().stroke(accent.opacity(0.40), lineWidth: 1))
                    .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(card == nil)
        .help(card.map { "查看工作卡：\($0.title)" } ?? "这只牛当前没有可查看的工作卡")
    }

    private func legacyAgentSpot(_ companion: CompanionRecord, compact: Bool) -> some View {
        let state = states[companion.id] ?? .idle
        let card = selectableCard(for: companion.id)
        let accent = seatAccent(for: state)
        let avatarSize: CGFloat = compact ? 50 : 62
        let spotWidth: CGFloat = compact ? 112 : 132

        return Button {
            if let card { onSelectCard(card.id) }
        } label: {
            VStack(spacing: compact ? 4 : 6) {
                ZStack(alignment: .bottomTrailing) {
                    CompanionAvatarView(
                        name: companion.name,
                        colorName: companion.color,
                        state: state,
                        size: avatarSize
                    )
                    Image(systemName: seatSymbols(for: state).first ?? "circle")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 23, height: 23)
                        .background(accent, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.86), lineWidth: 1))
                        .offset(x: 2, y: 1)
                }

                Text(companion.name)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                    .lineLimit(1)

                statusCapsule(for: state)

                Text(card?.title ?? "等待分派")
                    .font(.caption2.weight(card == nil ? .regular : .medium))
                    .foregroundStyle(card == nil ? Camp.inkSecondary : Camp.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: compact ? 14 : 28, alignment: .top)
            }
            .frame(width: spotWidth)
            .padding(.horizontal, compact ? 7 : 9)
            .padding(.vertical, compact ? 7 : 9)
            .background(
                Camp.surfaceRaised.opacity(colorScheme == .dark ? 0.93 : 0.90),
                in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                    .stroke(accent.opacity(card == nil ? 0.34 : 0.80), lineWidth: card == nil ? 1 : 1.5)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.32 : 0.16), radius: 7, y: 3)
            .contentShape(RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(card == nil)
        .help(card.map { "查看工作卡：\($0.title)" } ?? "这只牛当前没有可查看的工作卡")
    }

    private func denseAgentCard(_ companion: CompanionRecord, index: Int) -> some View {
        let state = states[companion.id] ?? .idle
        let card = selectableCard(for: companion.id)
        let accent = seatAccent(for: state)

        return Button {
            if let card { onSelectCard(card.id) }
        } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .bottomTrailing) {
                    if RanchArtView.spriteImage(colorName: companion.color) != nil {
                        RanchCowSpriteView(
                            colorName: companion.color,
                            height: 56,
                            flipped: index % 2 == 1
                        )
                    } else {
                        CompanionAvatarView(
                            name: companion.name,
                            colorName: companion.color,
                            state: state,
                            size: 50
                        )
                    }
                    Image(systemName: seatSymbols(for: state).first ?? "circle")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(accent, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.86), lineWidth: 1))
                }
                Text(companion.name)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                    .lineLimit(1)
                statusCapsule(for: state)
                Text(card?.title ?? "等待分派")
                    .font(.caption2.weight(card == nil ? .regular : .medium))
                    .foregroundStyle(card == nil ? Camp.inkSecondary : Camp.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 28, alignment: .top)
            }
            .frame(width: 118)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(
                Camp.surfaceRaised.opacity(colorScheme == .dark ? 0.93 : 0.90),
                in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                    .stroke(accent.opacity(card == nil ? 0.34 : 0.80), lineWidth: card == nil ? 1 : 1.5)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.32 : 0.16), radius: 7, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(card == nil)
        .help(card.map { "查看工作卡：\($0.title)" } ?? "这只牛当前没有可查看的工作卡")
    }

    private var memoryTrough: some View {
        HStack(spacing: 7) {
            Image(systemName: "books.vertical.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Camp.amber)
            VStack(alignment: .leading, spacing: 1) {
                Text("反刍知识")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                Text("\(campMemoryCount) 份")
                    .font(.caption2)
                    .foregroundStyle(Camp.inkSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Camp.surfaceRaised.opacity(colorScheme == .dark ? 0.94 : 0.90),
            in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                .stroke(Camp.amber.opacity(0.38), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
    }

    private var loopStageRail: some View {
        HStack(spacing: 0) {
            ForEach(LoopStage.allCases, id: \.self) { stage in
                stageMarker(stage)
                    .frame(maxWidth: .infinity)
                if stage != LoopStage.allCases.last {
                    Image(systemName: stage == .review ? "arrow.uturn.forward" : "arrow.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(
                            stage == activeStage
                                ? activeStage.color.opacity(0.85)
                                : Camp.inkSecondary.opacity(0.55)
                        )
                        .frame(width: 22)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Camp.surfaceRaised.opacity(0.86),
            in: RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .stroke(Camp.line, lineWidth: 1)
        )
    }

    private func stageMarker(_ stage: LoopStage) -> some View {
        let active = stage == activeStage
        return TimelineView(.animation(minimumInterval: 0.12, paused: paused || !active)) { context in
            let lift = active && !paused
                ? sin(context.date.timeIntervalSinceReferenceDate * 7) * 2.5
                : 0
            VStack(spacing: 6) {
                Image(systemName: stage.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(active ? .white : stage.color)
                    .frame(width: 42, height: 42)
                    .background(active ? stage.color : stage.color.opacity(0.13), in: Circle())
                    .overlay(
                        Circle().stroke(
                            active ? Color.white.opacity(0.7) : stage.color.opacity(0.28),
                            lineWidth: active ? 1.4 : 1
                        )
                    )
                    .shadow(color: active ? stage.color.opacity(0.48) : .clear, radius: active ? 12 : 0, y: 2)
                Text(stage.title)
                    .font(.caption.weight(active ? .semibold : .regular))
                    .foregroundStyle(active ? stage.color : Camp.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .offset(y: lift)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: activeStage)
        }
    }

    private func statusCapsule(for state: CompanionAnimState) -> some View {
        Text(label(for: state))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(seatAccent(for: state))
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(seatAccent(for: state).opacity(0.13), in: Capsule())
    }

    private var emptyPastureHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "pawprint.fill")
                .foregroundStyle(Camp.moss)
            Text("等待牛群入场")
                .font(.caption.weight(.medium))
                .foregroundStyle(Camp.ink)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(Camp.surfaceRaised.opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(Camp.moss.opacity(0.36), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
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
            if cards.contains(where: { $0.status == .ready })
                && cards.contains(where: { $0.status == .done }) {
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
        case .idle: "悠闲待命"
        case .thinking: "正在琢磨"
        case .working: "正在干活"
        case .asking: "等你决定"
        case .scratching: "回头复检"
        case .celebrating: "刚完成"
        case .napping: "打盹等待"
        }
    }

    private func seatSymbols(for state: CompanionAnimState) -> [String] {
        switch state {
        case .idle: ["leaf.fill", "clock"]
        case .thinking: ["brain.head.profile", "sparkles"]
        case .working: ["hammer.fill", "terminal"]
        case .asking: ["hand.raised.fill", "questionmark.bubble"]
        case .scratching: ["magnifyingglass", "arrow.uturn.forward"]
        case .celebrating: ["checkmark.seal.fill", "sparkles"]
        case .napping: ["moon.zzz.fill", "clock"]
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

    private func pasturePosition(for index: Int, total: Int, size: CGSize) -> CGPoint {
        let normalized: CGPoint
        switch total {
        case 0:
            normalized = CGPoint(x: 0.62, y: 0.58)
        case 1:
            normalized = CGPoint(x: 0.60, y: 0.62)
        case 2:
            normalized = index == 0
                ? CGPoint(x: 0.38, y: 0.66)
                : CGPoint(x: 0.68, y: 0.52)
        case 3:
            let slots = [
                CGPoint(x: 0.30, y: 0.64),
                CGPoint(x: 0.56, y: 0.72),
                CGPoint(x: 0.74, y: 0.50),
            ]
            normalized = slots[index]
        default:
            let slots = [
                CGPoint(x: 0.24, y: 0.60),
                CGPoint(x: 0.44, y: 0.74),
                CGPoint(x: 0.64, y: 0.68),
                CGPoint(x: 0.80, y: 0.52),
                CGPoint(x: 0.52, y: 0.44),
                CGPoint(x: 0.34, y: 0.46),
                CGPoint(x: 0.16, y: 0.42),
                CGPoint(x: 0.86, y: 0.70),
            ]
            normalized = slots[index % slots.count]
        }

        let horizontalInset: CGFloat = 56
        let verticalInset: CGFloat = 60
        return CGPoint(
            x: min(max(size.width * normalized.x, horizontalInset), size.width - horizontalInset),
            y: min(max(size.height * normalized.y, verticalInset), size.height - verticalInset)
        )
    }
}

/// 给无固有尺寸的 GeometryReader 一个确定的 3:2 proposal，避免 VStack 采用 10pt 理想尺寸。
private struct AspectFitStageLayout: Layout {
    let aspectRatio: CGFloat
    let maxHeight: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let maximumWidth = maxHeight * aspectRatio
        let proposedWidth = proposal.width ?? maximumWidth
        // VStack 会用 10pt 高度询问 ideal size；高度应由宽高比反推，而不是被这次探测压扁。
        let width = max(0, min(proposedWidth, maximumWidth))
        return CGSize(width: width, height: width / aspectRatio)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else { return }
        subview.place(
            at: CGPoint(x: bounds.midX, y: bounds.midY),
            anchor: .center,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
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
