import SwiftUI
import AgentLoopCore

struct CodingRanchEmptyState: View {
    let title: String
    let message: String
    var systemImage = "leaf.fill"
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Camp.moss)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(Camp.ink)
            Text(message)
                .font(.callout)
                .foregroundStyle(Camp.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(CampPrimaryButtonStyle(size: .small))
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .campCard()
    }
}

struct CowStatusLabel: View {
    let status: CowStatusViewState

    var body: some View {
        CampChip(text: text, color: color, icon: icon)
            .accessibilityLabel("牛的状态：\(text)")
    }

    private var text: String {
        switch status {
        case .idle: "在营地休息"
        case .planning: "正在规划路线"
        case .working: "正在干活"
        case .waitingForUser: "等你决定"
        case .validating: "正在检查成果"
        case .returning: "带着成果回营"
        case .blocked: "遇到问题"
        case .unavailable: "暂不可用"
        }
    }

    private var color: Color {
        switch status {
        case .idle, .unavailable: Camp.stone
        case .planning, .working: Camp.creek
        case .waitingForUser: Camp.amber
        case .validating, .returning: Camp.moss
        case .blocked: Camp.charcoalRed
        }
    }

    private var icon: String {
        switch status {
        case .idle: "moon.zzz.fill"
        case .planning: "map.fill"
        case .working: "hammer.fill"
        case .waitingForUser: "hand.raised.fill"
        case .validating: "checkmark.seal.fill"
        case .returning: "house.fill"
        case .blocked: "exclamationmark.triangle.fill"
        case .unavailable: "slash.circle"
        }
    }
}

struct CowSummaryCard: View {
    let cow: CowSummaryViewState
    var onOpen: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                CompanionAvatarView(name: cow.name, colorName: cow.colorName, state: animationState, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(cow.name)
                        .font(.headline)
                        .foregroundStyle(Camp.ink)
                    Text(cow.role)
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                }
                Spacer()
                CowStatusLabel(status: cow.status)
            }
            if !cow.specialties.isEmpty {
                FlowLayoutLite(spacing: 6) {
                    ForEach(cow.specialties, id: \.self) { specialty in
                        CampChip(text: specialty, color: Camp.moss)
                    }
                }
            }
            if let lastActivity = cow.lastActivity {
                Text(lastActivity)
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
                    .lineLimit(2)
            }
            if let onOpen {
                Button("查看牛的档案", action: onOpen)
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Camp.ember)
            }
        }
        .campCard()
    }

    private var animationState: CompanionAnimState {
        switch cow.status {
        case .idle, .unavailable: .idle
        case .planning: .thinking
        case .working: .working
        case .waitingForUser: .asking
        case .validating: .scratching
        case .returning: .celebrating
        case .blocked: .scratching
        }
    }
}

struct CodingRanchCommonViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CodingRanchEmptyState(
                title: "先喂基础牛一条信息",
                message: "粘贴一篇文章、一段资料，或者直接写下你的想法。",
                actionTitle: "开始喂牛",
                action: {}
            )
            .padding()
            .background(Camp.canvas)
            .previewDisplayName("空状态")

            CowSummaryCard(cow: CodingRanchPreviewFixtures.workingCow)
                .padding()
                .background(Camp.canvas)
                .previewDisplayName("基础牛")
        }
    }
}
