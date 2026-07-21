import SwiftUI
import AgentLoopCore

/// 行动中的动态 Coding 草原。
///
/// 视觉来自已定稿的像素牧场基座，但牛的状态、工作卡和阶段仍完全由真实事件流驱动。
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
    private static let sparsePastureSlots = [
        CGPoint(x: 0.45, y: 0.42),
        CGPoint(x: 0.62, y: 0.50),
        CGPoint(x: 0.32, y: 0.52),
    ]
    private static let crowdedPastureSlots = [
        CGPoint(x: 0.30, y: 0.44),
        CGPoint(x: 0.46, y: 0.54),
        CGPoint(x: 0.60, y: 0.40),
        CGPoint(x: 0.72, y: 0.50),
        CGPoint(x: 0.40, y: 0.34),
        CGPoint(x: 0.56, y: 0.32),
        CGPoint(x: 0.22, y: 0.56),
        CGPoint(x: 0.84, y: 0.40),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            pastureHeader
            if sortedCompanions.count > 8 {
                densePasture
            } else {
                pastureStage
            }
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
        AspectFitStageLayout(aspectRatio: 2.3333, maxHeight: 520) {
            GeometryReader { proxy in
                TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: paused)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate

                    ZStack {
                        RanchArtView(kind: .panorama, layout: .fit(maxWidth: nil))
                            .frame(width: proxy.size.width, height: proxy.size.height)

                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        colorScheme == .dark ? .black.opacity(0.025) : .white.opacity(0.015),
                                        .clear,
                                        .black.opacity(colorScheme == .dark ? 0.11 : 0.04),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .allowsHitTesting(false)

                        if sortedCompanions.isEmpty {
                            emptyPastureHint
                                .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.45)
                        } else {
                            ForEach(Array(sortedCompanions.enumerated()), id: \.element.id) { index, companion in
                                let position = pasturePosition(
                                    for: index,
                                    total: sortedCompanions.count,
                                    size: proxy.size
                                )
                                let motion = pastureMotion(
                                    for: companion,
                                    index: index,
                                    size: proxy.size,
                                    time: time
                                )

                                agentSpot(
                                    companion,
                                    index: index,
                                    compact: proxy.size.width < 760 || sortedCompanions.count > 5,
                                    flipped: motion.flipped
                                )
                                .position(position)
                                .offset(x: motion.dx, y: motion.dy + motion.bob)
                                .zIndex(Double(position.y + motion.dy))
                            }
                        }

                        pastureProgressBanner(width: min(proxy.size.width * 0.72, 640))
                            .padding(.top, 12)
                            .frame(
                                width: proxy.size.width,
                                height: proxy.size.height,
                                alignment: .top
                            )
                            .allowsHitTesting(false)
                            .zIndex(6_000)

                        memoryTrough
                            .position(
                                x: proxy.size.width * 0.87,
                                y: proxy.size.height * 0.86
                            )
                            .zIndex(10_000)
                    }
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
                        RanchArtView(kind: .panorama, layout: .fit(maxWidth: nil))
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
        compact: Bool,
        flipped: Bool
    ) -> some View {
        if RanchArtView.spriteImage(colorName: companion.color) != nil {
            spriteAgentSpot(companion, compact: compact, flipped: flipped)
        } else {
            legacyAgentSpot(companion, compact: compact)
        }
    }

    private func spriteAgentSpot(
        _ companion: CompanionRecord,
        compact: Bool,
        flipped: Bool
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
                        flipped: flipped
                    )
                    .animation(.easeInOut(duration: 0.3), value: flipped)
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
                    .truncationMode(.tail)
                    .help("\(companion.name) · \(label(for: state))")
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Camp.surfaceRaised.opacity(0.90), in: Capsule())
                    .overlay(Capsule().stroke(accent.opacity(0.40), lineWidth: 1))
                    .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
            }
            .frame(maxWidth: 132)
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

    private func pastureProgressBanner(width: CGFloat) -> some View {
        ViewThatFits(in: .horizontal) {
            progressBannerStages(compact: false)
            progressBannerStages(compact: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: width)
        .background(
            colorScheme == .dark
                ? Camp.surfaceRaised.opacity(0.90)
                : Camp.hay.opacity(0.92),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Camp.line, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 6, y: 2)
    }

    private func progressBannerStages(compact: Bool) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(LoopStage.allCases.enumerated()), id: \.element) { index, stage in
                if index > 0 {
                    Image(systemName: index == LoopStage.allCases.count - 1
                        ? "arrow.uturn.forward"
                        : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Camp.inkSecondary.opacity(0.5))
                }
                progressBannerStage(stage, compact: compact)
            }
        }
    }

    private func progressBannerStage(_ stage: LoopStage, compact: Bool) -> some View {
        let active = stage == activeStage
        return TimelineView(.animation(minimumInterval: 0.12, paused: paused || !active)) { context in
            let lift = active && !paused
                ? sin(context.date.timeIntervalSinceReferenceDate * 7) * 2.5
                : 0
            HStack(spacing: 3) {
                Image(systemName: stage.icon)
                if active || !compact {
                    Text(stage.title)
                        .lineLimit(1)
                }
            }
            .font(active ? .caption2.bold() : .caption2)
            .foregroundStyle(active ? Color.white : Camp.inkSecondary)
            .padding(.horizontal, active ? 7 : 0)
            .padding(.vertical, active ? 3 : 0)
            .background(
                active ? stage.color : Color.clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
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
            normalized = CGPoint(x: 0.5, y: 0.45)
        case 1...3:
            normalized = Self.sparsePastureSlots[index]
        default:
            normalized = Self.crowdedPastureSlots[index % Self.crowdedPastureSlots.count]
        }

        let horizontalInset: CGFloat = 56
        let verticalInset: CGFloat = 60
        return CGPoint(
            x: min(max(size.width * normalized.x, horizontalInset), size.width - horizontalInset),
            y: min(max(size.height * normalized.y, verticalInset), size.height - verticalInset)
        )
    }

    private func pastureMotion(
        for companion: CompanionRecord,
        index: Int,
        size: CGSize,
        time: TimeInterval
    ) -> PastureMotion {
        let hash = fnv1a(companion.id)
        let mask: UInt64 = (1 << 21) - 1
        let denominator = Double(mask)
        let phase1 = Double(hash & mask) / denominator * 2 * Double.pi
        let speedJitter = 0.85 + Double((hash >> 42) & mask) / denominator * 0.30
        let state = states[companion.id] ?? .idle

        switch state {
        case .idle, .thinking, .celebrating:
            let slot = pasturePosition(for: index, total: sortedCompanions.count, size: size)
            let waypoints = pastureWaypoints(for: companion, slot: slot, size: size)
            let legs = pastureLegs(for: companion, waypoints: waypoints, speedJitter: speedJitter)
            let duration = legs.reduce(0) { $0 + $1.walkDuration + $1.pauseDuration }
            let phaseSeed = fnv1a("\(companion.id):phase")
            let phaseOffset = unitRandom(from: phaseSeed, segment: 0) * duration
            var elapsed = (time + phaseOffset).truncatingRemainder(dividingBy: duration)
            if elapsed < 0 { elapsed += duration }

            for leg in legs {
                if elapsed < leg.walkDuration {
                    let progress = elapsed / leg.walkDuration
                    let eased = progress * progress * (3 - 2 * progress)
                    let position = CGPoint(
                        x: leg.start.x + (leg.end.x - leg.start.x) * CGFloat(eased),
                        y: leg.start.y + (leg.end.y - leg.start.y) * CGFloat(eased)
                    )
                    return PastureMotion(
                        dx: position.x - slot.x,
                        dy: position.y - slot.y,
                        bob: -2.0 * CGFloat(abs(sin(time * 7 * speedJitter))),
                        flipped: leg.flipped
                    )
                }

                elapsed -= leg.walkDuration
                if elapsed < leg.pauseDuration {
                    return PastureMotion(
                        dx: leg.end.x - slot.x,
                        dy: leg.end.y - slot.y,
                        bob: 0,
                        flipped: leg.flipped
                    )
                }
                elapsed -= leg.pauseDuration
            }

            return PastureMotion(dx: 0, dy: 0, bob: 0, flipped: false)
        case .asking, .scratching:
            return PastureMotion(
                dx: 1.5 * CGFloat(sin(time * 0.8 + phase1)),
                dy: 0,
                bob: 0,
                flipped: true
            )
        case .working:
            return PastureMotion(
                dx: 0,
                dy: 1.4 * CGFloat(sin(time * 1.7 + phase1)),
                bob: 0,
                flipped: true
            )
        case .napping:
            return PastureMotion(dx: 0, dy: 0, bob: 0, flipped: true)
        }
    }

    private func pastureWaypoints(
        for companion: CompanionRecord,
        slot: CGPoint,
        size: CGSize
    ) -> [CGPoint] {
        let angleSeed = fnv1a(companion.id)
        let horizontalInset: CGFloat = 56
        let verticalInset: CGFloat = 60

        return (0..<4).map { index in
            let angleRandom = unitRandom(from: angleSeed, segment: index)
            let angle = Double(index) * Double.pi / 2 + (angleRandom - 0.5)
            let radius = 0.06 * size.width
            return CGPoint(
                x: min(
                    max(slot.x + radius * CGFloat(cos(angle)), horizontalInset),
                    size.width - horizontalInset
                ),
                y: min(
                    max(slot.y + radius * 0.55 * CGFloat(sin(angle)), verticalInset),
                    size.height - verticalInset
                )
            )
        }
    }

    private func pastureLegs(
        for companion: CompanionRecord,
        waypoints: [CGPoint],
        speedJitter: Double
    ) -> [PastureLeg] {
        let pauseSeed = fnv1a("\(companion.id):pause")
        let speed = 9.0 * speedJitter

        return waypoints.indices.map { index in
            let nextIndex = (index + 1) % waypoints.count
            let start = waypoints[index]
            let end = waypoints[nextIndex]
            let distance = hypot(end.x - start.x, end.y - start.y)
            return PastureLeg(
                start: start,
                end: end,
                walkDuration: Double(distance) / speed,
                pauseDuration: 4 + 6 * unitRandom(from: pauseSeed, segment: index),
                flipped: pastureFlipped(for: index, waypoints: waypoints)
            )
        }
    }

    private func pastureFlipped(for index: Int, waypoints: [CGPoint]) -> Bool {
        for offset in 0..<waypoints.count {
            let legIndex = (index - offset + waypoints.count) % waypoints.count
            let nextIndex = (legIndex + 1) % waypoints.count
            let dx = waypoints[nextIndex].x - waypoints[legIndex].x
            if abs(dx) >= 1 {
                return dx > 0
            }
        }
        return false
    }

    private func unitRandom(from seed: UInt64, segment: Int) -> Double {
        let mask = UInt64(UInt16.max)
        return Double((seed >> (segment * 16)) & mask) / Double(mask)
    }

    private func fnv1a(_ value: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}

private struct PastureMotion {
    let dx: CGFloat
    let dy: CGFloat
    let bob: CGFloat
    let flipped: Bool
}

private struct PastureLeg {
    let start: CGPoint
    let end: CGPoint
    let walkDuration: TimeInterval
    let pauseDuration: TimeInterval
    let flipped: Bool
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
        case .handoff: Camp.lavender
        case .review: Camp.moss
        case .cycle: Camp.ember
        case .memory: Camp.amber
        }
    }
}
