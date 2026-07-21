import SwiftUI

struct CodingRanchHomeView: View {
    @Environment(\.campWindowSize) private var windowSize
    let state: CampDashboardViewState
    let modelConnection: ModelConnectionViewState
    var onSubmitFeed: (FeedDraft, Bool) async throws -> FeedSubmissionResult
    var onSubmitDuplicate: (FeedDraft, Bool) async throws -> FeedSubmissionResult
    var onSaveFeedDraft: (FeedDraft) -> Void = { _ in }
    var onOpenInbox: () -> Void = {}
    var onOpenRumination: (String) -> Void = { _ in }
    var onOpenMission: (String) -> Void = { _ in }
    var onOpenNote: (String) -> Void = { _ in }
    var onOpenCowRoster: () -> Void = {}
    var onStartMission: () -> Void = {}
    var onOpenGuide: () -> Void = {}
    var onOpenNotes: () -> Void = {}
    var onOpenSettings: () -> Void = {}

    @State private var quickText = ""
    @State private var showFeedComposer = false

    var body: some View {
        GeometryReader { proxy in
            let windowWidth = windowSize.width > 0 ? windowSize.width : proxy.size.width
            let wide = windowWidth >= CampLayout.secondaryPanelWindowWidth
            let compact = windowWidth < CampLayout.windowCompactWidth
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    campHeader(compact: compact)
                    feedHero
                    if wide {
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 14) {
                                attentionSection
                                missionSection
                            }
                            .frame(maxWidth: .infinity)
                            VStack(spacing: 14) {
                                cowSection
                                newcomerSection
                                notesSection
                            }
                            .frame(width: min(360, proxy.size.width * 0.36))
                        }
                    } else {
                        attentionSection
                        cowSection
                        newcomerSection
                        missionSection
                        notesSection
                    }
                }
                .padding(16)
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Camp.canvas)
        .sheet(isPresented: $showFeedComposer) {
            FeedComposerView(
                draft: FeedDraft(body: quickText, campId: state.campId),
                campName: state.campName,
                modelConnection: modelConnection,
                onSaveDraft: onSaveFeedDraft,
                onSubmit: onSubmitFeed,
                onSubmitDuplicate: onSubmitDuplicate,
                onCancel: {
                    quickText = ""
                    showFeedComposer = false
                }
            )
            .frame(
                minWidth: 520,
                idealWidth: 720,
                maxWidth: 760,
                minHeight: 560,
                idealHeight: 680,
                maxHeight: 760
            )
        }
    }

    @ViewBuilder private func campHeader(compact: Bool) -> some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 10) {
                    campHeaderIdentity
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        campHeaderActions
                    }
                }
            } else {
                HStack(spacing: 12) {
                    campHeaderIdentity
                    Spacer(minLength: 8)
                    campHeaderActions
                }
            }
        }
        .campCard(padding: 12)
    }

    private var campHeaderIdentity: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "tent.fill")
                    .foregroundStyle(Camp.ember)
                Text(state.campName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Camp.ink)
                    .lineLimit(2)
            }
            Text(headerSubtitle)
                .font(.caption)
                .foregroundStyle(Camp.inkSecondary)
        }
    }

    @ViewBuilder private var campHeaderActions: some View {
        if state.pendingConfirmationCount > 0 {
            CampChip(text: "\(state.pendingConfirmationCount) 项等你确认", color: Camp.amber, icon: "hand.raised.fill")
        }
        Button("管家与工具", action: onOpenGuide)
            .buttonStyle(CampSecondaryButtonStyle())
            .help("打开管家聊天、日程、营地驿站和往期任务")
        Button("笔记", action: onOpenNotes)
            .buttonStyle(CampSecondaryButtonStyle())
        Button("牛棚", action: onOpenCowRoster)
            .buttonStyle(CampSecondaryButtonStyle())
        Button("驿站设置", action: onOpenSettings)
            .buttonStyle(CampSecondaryButtonStyle())
    }

    private var feedHero: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("把文章、资料或想法喂给基础牛")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Camp.ink)
                    Text("它会先反刍成可检查的知识和任务建议，不会直接替你做决定。")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                }
                Spacer()
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(Camp.moss)
                    .accessibilityHidden(true)
            }
            TextField("粘贴一段内容，或者直接写下你的想法…", text: $quickText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(4...9)
                .padding(12)
                .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Camp.smallRadius).stroke(Camp.line))
                .onSubmit {
                    if !quickText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        showFeedComposer = true
                    }
                }
            HStack {
                Button("试试示例：做一个三人喝水打卡页") {
                    quickText = "我想给三个人做一个七天喝水打卡页，记录每天喝水次数和连续打卡天数，明天发给同事试用。"
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(Camp.creek)
                Spacer()
                Button {
                    showFeedComposer = true
                } label: {
                    Label("继续填写并喂牛", systemImage: "arrow.right")
                }
                .buttonStyle(CampPrimaryButtonStyle(size: .small))
                .disabled(quickText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Camp.hay.opacity(0.72), Camp.surface], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: Camp.cornerRadius).stroke(Camp.ember.opacity(0.25)))
    }

    @ViewBuilder private var attentionSection: some View {
        let pending = state.pendingItems
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CampSectionTitle("待你处理")
                Spacer()
                if state.pendingRuminationCount > 0 {
                    Button("查看全部 \(state.pendingRuminationCount)", action: onOpenInbox)
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Camp.ember)
                }
            }
            if pending.isEmpty && state.pendingReturnCount == 0 {
                Label("现在没有需要你处理的事情", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(Camp.moss)
            } else {
                ForEach(pending.prefix(3)) { item in
                    Button { onOpenRumination(item.id) } label: {
                        HStack(spacing: 9) {
                            Image(systemName: item.status == .needsReview ? "hand.raised.fill" : "arrow.triangle.2.circlepath")
                                .foregroundStyle(item.status == .needsReview ? Camp.amber : Camp.creek)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(Camp.ink)
                                Text(item.resultCountText)
                                    .font(.caption)
                                    .foregroundStyle(Camp.inkSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Camp.stone)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if state.pendingReturnCount > 0 {
                    Label("\(state.pendingReturnCount) 个任务等待回营验收", systemImage: "house.and.flag.fill")
                        .font(.callout)
                        .foregroundStyle(Camp.moss)
                }
            }
        }
        .campCard()
    }

    @ViewBuilder private var cowSection: some View {
        if let cow = state.activeCow {
            CowSummaryCard(cow: cow, onOpen: onOpenCowRoster)
        }
    }

    private var newcomerSection: some View {
        NewcomerTaskCard(progress: state.newcomerProgress, onOpenRoster: onOpenCowRoster)
    }

    @ViewBuilder private var missionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CampSectionTitle("Coding 草原")
                Spacer()
                Button("开始一项任务", action: onStartMission)
                    .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
            }
            if state.activeMissions.isEmpty {
                RanchArtView(kind: .base, layout: .fit(maxWidth: 640))
                    .frame(maxWidth: .infinity)
                Text("基础牛现在空闲。确认反刍结果后，可以把一个真实任务交给它。")
                    .font(.callout)
                    .foregroundStyle(Camp.inkSecondary)
            } else {
                ForEach(state.activeMissions) { mission in
                    Button { onOpenMission(mission.id) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: mission.pendingUserAction == nil ? "bolt.fill" : "hand.raised.fill")
                                .foregroundStyle(mission.pendingUserAction == nil ? Camp.creek : Camp.amber)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(mission.title)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(Camp.ink)
                                Text(mission.phaseText)
                                    .font(.caption)
                                    .foregroundStyle(Camp.inkSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Camp.stone)
                        }
                        .padding(10)
                        .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .campCard()
    }

    @ViewBuilder private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            CampSectionTitle("最近的营地笔记")
            if state.recentNotes.isEmpty {
                Text("反刍确认和回营经验会沉淀在这里。")
                    .font(.callout)
                    .foregroundStyle(Camp.inkSecondary)
            } else {
                ForEach(state.recentNotes.prefix(3)) { note in
                    Button { onOpenNote(note.id) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(note.title)
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(Camp.ink)
                                    .lineLimit(1)
                                if note.pinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(Camp.amber) }
                            }
                            Text(note.sourceLabel)
                                .font(.caption)
                                .foregroundStyle(Camp.inkSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .campCard()
    }

    private var headerSubtitle: String {
        if let cow = state.activeCow {
            switch cow.status {
            case .idle: "基础牛在营地，随时可以开始。"
            case .working: "基础牛正在 Coding 草原干活。"
            case .waitingForUser: "基础牛停下来等你决定。"
            default: cow.lastActivity ?? "看看营地今天发生了什么。"
            }
        } else {
            "看看营地今天发生了什么。"
        }
    }
}

struct NewcomerTaskCard: View {
    let progress: NewcomerProgressViewState
    var onOpenRoster: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("新手任务")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Camp.ink)
                    Text(progress.isUnlocked ? "第一条学习路径已完成" : "完成一次从喂牛到回营的任务")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                }
                Spacer()
                CampChip(text: "\(completedCount)/\(progress.steps.count)", color: progress.canUnlock ? Camp.moss : Camp.ember)
            }
            ForEach(progress.steps) { step in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: step.status == .completed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(step.status == .completed ? Camp.moss : Camp.stone)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Camp.ink)
                        if let evidence = step.evidenceText {
                            Text(evidence)
                                .font(.caption2)
                                .foregroundStyle(Camp.inkSecondary)
                        }
                    }
                }
            }
            if progress.canUnlock || progress.isUnlocked {
                Button(progress.isUnlocked ? "去牛棚看看" : "测试牛可以领回营地", action: onOpenRoster)
                    .buttonStyle(CampPrimaryButtonStyle(size: .small))
            }
        }
        .campCard(highlighted: progress.canUnlock)
    }

    private var completedCount: Int {
        progress.steps.filter { $0.status == .completed }.count
    }
}

struct CodingRanchHomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CodingRanchHomeView(
                state: CodingRanchPreviewFixtures.activeCamp,
                modelConnection: .configured,
                onSubmitFeed: { _, _ in .saved(ingestionId: "preview", startsRumination: true) },
                onSubmitDuplicate: { _, _ in .saved(ingestionId: "preview", startsRumination: true) }
            )
            .frame(width: 1180, height: 760)
            .previewDisplayName("营地首页 · 宽")

            CodingRanchHomeView(
                state: CodingRanchPreviewFixtures.emptyCamp,
                modelConnection: .missing,
                onSubmitFeed: { _, _ in .saved(ingestionId: "preview", startsRumination: false) },
                onSubmitDuplicate: { _, _ in .saved(ingestionId: "preview", startsRumination: false) }
            )
            .frame(width: 640, height: 760)
            .previewDisplayName("营地首页 · 640")
        }
    }
}
