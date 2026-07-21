import SwiftUI

struct RuminationInboxView: View {
    let state: RuminationInboxViewState
    var onOpen: (String) -> Void
    var onStart: (String) async -> Void = { _ in }
    var onRetry: (String) async -> Void = { _ in }
    var onRestore: (String) -> Void = { _ in }
    var onClose: (() -> Void)?
    var onFeed: (() -> Void)?
    var actionError: String? = nil
    var onClearActionError: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Camp.line)
            if let actionError {
                RuminationActionErrorPanel(message: actionError, onDismiss: onClearActionError)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }
            content
        }
        .background(Camp.canvas)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.headline)
                .foregroundStyle(Camp.ember)
                .frame(width: 34, height: 34)
                .background(Camp.ember.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text("待反刍")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Camp.ink)
                Text("你主动喂入的材料都在这里，失败也不会丢失原文。")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }
            Spacer()
            if !state.items.isEmpty {
                CampChip(text: "\(state.items.count) 条", color: Camp.amber, icon: "tray.full.fill")
            }
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Camp.inkSecondary)
                .background(Camp.surfaceRaised, in: Circle())
                .help("关闭")
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Camp.surface)
    }

    @ViewBuilder private var content: some View {
        switch state.loadState {
        case .idle, .loading:
            ProgressView("正在查看牛吃了什么…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            CodingRanchEmptyState(
                title: "待反刍暂时打不开",
                message: message,
                systemImage: "exclamationmark.triangle.fill"
            )
            .padding(20)
        case .loaded:
            if state.items.isEmpty {
                inboxEmptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(state.items) { item in
                            RuminationInboxCard(
                                item: item,
                                onOpen: { onOpen(item.id) },
                                onStart: { Task { await onStart(item.id) } },
                                onRetry: { Task { await onRetry(item.id) } },
                                onRestore: { onRestore(item.id) }
                            )
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 880)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var inboxEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Camp.moss)
                .frame(width: 64, height: 64)
                .background(Camp.pasture, in: Circle())
            Text("还没有待反刍的内容")
                .font(.headline)
                .foregroundStyle(Camp.ink)
            Text("喂入文章、资料或想法后，它们会在这里等待检查。原文始终保留。")
                .font(.callout)
                .foregroundStyle(Camp.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let onFeed {
                Button(action: onFeed) {
                    Label("喂牛一条资料", systemImage: "plus")
                }
                .buttonStyle(CampPrimaryButtonStyle(size: .small))
                .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RuminationActionErrorPanel: View {
    let message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Camp.charcoalRed)
            Text(message)
                .font(.callout)
                .foregroundStyle(Camp.charcoalRed)
            Spacer(minLength: 8)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Camp.charcoalRed)
            .accessibilityLabel("清除反刍错误")
        }
        .campStatusPanel(Camp.charcoalRed)
    }
}

private struct RuminationInboxCard: View {
    let item: RuminationInboxItemViewState
    var onOpen: () -> Void
    var onStart: () -> Void
    var onRetry: () -> Void
    var onRestore: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: sourceIcon)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 32, height: 32)
                .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Camp.ink)
                        .lineLimit(2)
                    statusChip
                    if item.isPossibleDuplicate {
                        CampChip(text: "可能重复", color: Camp.amber, icon: "doc.on.doc")
                    }
                }
                Text("\(item.campName) · \(item.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(item.resultCountText)")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
                if let error = item.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Camp.charcoalRed)
                }
            }
            Spacer(minLength: 12)
            actions
        }
        .campCard(padding: 12, highlighted: item.status == .needsReview)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var actions: some View {
        switch item.status {
        case .queued:
            Button("开始反刍", action: onStart)
                .buttonStyle(CampPrimaryButtonStyle(size: .small))
        case .ruminating:
            Button("查看进度", action: onOpen)
                .buttonStyle(CampSecondaryButtonStyle(tint: Camp.creek))
        case .needsReview:
            Button("检查结果", action: onOpen)
                .buttonStyle(CampPrimaryButtonStyle(size: .small))
        case .materialized:
            Button("打开", action: onOpen)
                .buttonStyle(CampSecondaryButtonStyle(tint: Camp.moss))
        case .failed(_, let retryable):
            if retryable {
                Button("重试", action: onRetry)
                    .buttonStyle(CampSecondaryButtonStyle(tint: Camp.charcoalRed))
            } else {
                Button("查看原文", action: onOpen)
                    .buttonStyle(CampSecondaryButtonStyle())
            }
        case .discarded:
            Button("恢复", action: onRestore)
                .buttonStyle(CampSecondaryButtonStyle())
        }
    }

    @ViewBuilder private var statusChip: some View {
        switch item.status {
        case .queued: CampChip(text: "等待反刍", color: Camp.stone, icon: "clock")
        case .ruminating: CampChip(text: "正在反刍", color: Camp.creek, icon: "arrow.triangle.2.circlepath")
        case .needsReview: CampChip(text: "等你确认", color: Camp.amber, icon: "hand.raised.fill")
        case .materialized: CampChip(text: "已收进营地", color: Camp.moss, icon: "checkmark")
        case .failed: CampChip(text: "反刍失败", color: Camp.charcoalRed, icon: "exclamationmark.triangle.fill")
        case .discarded: CampChip(text: "已忽略", color: Camp.stone, icon: "eye.slash")
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .queued, .discarded: Camp.stone
        case .ruminating: Camp.creek
        case .needsReview: Camp.amber
        case .materialized: Camp.moss
        case .failed: Camp.charcoalRed
        }
    }

    private var sourceIcon: String {
        switch item.sourceKind {
        case .pastedText: "doc.on.clipboard"
        case .directThought: "lightbulb.fill"
        case .url: "link"
        case .file: "doc.fill"
        }
    }
}

struct RuminationProgressView: View {
    let item: RuminationInboxItemViewState
    var onViewSource: () -> Void
    var onCancel: () async throws -> Void
    var onClose: () -> Void

    @State private var cancelState: CodingRanchActionState = .idle

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 20)
            CompanionAvatarView(name: "营地管家", colorName: "amber", state: .thinking, size: 74)
            VStack(spacing: 6) {
                Text(item.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                    .multilineTextAlignment(.center)
                Text("营地管家正在帮基础牛反刍")
                    .font(.callout)
                    .foregroundStyle(Camp.inkSecondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(RuminationStage.allCasesForUI.enumerated()), id: \.offset) { index, stage in
                    RuminationStageRow(stage: stage, position: stagePosition(stage))
                    if index < RuminationStage.allCasesForUI.count - 1 {
                        Rectangle()
                            .fill(stageLineColor(after: stage))
                            .frame(width: 2, height: 18)
                            .padding(.leading, 14)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 440, alignment: .leading)
            .campCard()
            Text("你可以离开此页。完成后，它会在待反刍区显示“等你确认”。")
                .font(.caption)
                .foregroundStyle(Camp.inkSecondary)
                .multilineTextAlignment(.center)
            if case .failed(let message) = cancelState {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Camp.charcoalRed)
            }
            HStack(spacing: 10) {
                Button("查看原文", action: onViewSource)
                    .buttonStyle(CampSecondaryButtonStyle())
                Button("稍后再处理") {
                    Task { await cancel() }
                }
                .buttonStyle(CampSecondaryButtonStyle(tint: Camp.amber))
                .disabled(cancelState == .running)
                Button("离开此页", action: onClose)
                    .buttonStyle(CampPrimaryButtonStyle(size: .small))
                    .keyboardShortcut(.cancelAction)
            }
            Spacer(minLength: 20)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Camp.canvas)
        .accessibilityElement(children: .contain)
    }

    private var currentStage: RuminationStage {
        if case .ruminating(let stage) = item.status { return stage }
        return .saved
    }

    private func stagePosition(_ stage: RuminationStage) -> RuminationStagePosition {
        let stages = RuminationStage.allCasesForUI
        let current = stages.firstIndex(of: currentStage) ?? 0
        let index = stages.firstIndex(of: stage) ?? 0
        if index < current { return .completed }
        if index == current { return .current }
        return .upcoming
    }

    private func stageLineColor(after stage: RuminationStage) -> Color {
        stagePosition(stage) == .completed ? Camp.moss : Camp.line
    }

    @MainActor private func cancel() async {
        cancelState = .running
        do {
            try await onCancel()
            cancelState = .idle
            onClose()
        } catch {
            cancelState = .failed(error.localizedDescription)
        }
    }
}

struct RuminationSourceSheet: View {
    let source: SourceViewState?
    let fallbackTitle: String
    let fallbackSummary: String
    let loadFailed: Bool

    var body: some View {
        Group {
            if let source {
                SourceEvidenceView(source: source)
            } else if loadFailed {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("原文", systemImage: "doc.text.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Camp.ink)
                        Text(fallbackTitle)
                            .font(.headline)
                            .foregroundStyle(Camp.ink)
                        if !fallbackSummary.isEmpty {
                            Text(fallbackSummary)
                                .font(.callout)
                                .foregroundStyle(Camp.inkSecondary)
                        }
                        Text("当前无法读取完整原文，以上仅展示这条材料的标题与摘要。请返回列表刷新后再试。")
                            .font(.caption)
                            .foregroundStyle(Camp.charcoalRed)
                            .campStatusPanel(Camp.charcoalRed)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Camp.surface)
            } else {
                ProgressView("正在读取原文…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Camp.surface)
            }
        }
    }
}

private enum RuminationStagePosition { case completed, current, upcoming }

private struct RuminationStageRow: View {
    let stage: RuminationStage
    let position: RuminationStagePosition

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(position == .upcoming ? 0.08 : 0.15), in: Circle())
            Text(stage.displayText)
                .font(.callout.weight(position == .current ? .semibold : .regular))
                .foregroundStyle(position == .upcoming ? Camp.inkSecondary : Camp.ink)
            Spacer()
            if position == .current {
                ProgressView().controlSize(.small)
            }
        }
        .accessibilityLabel("\(stage.displayText)，\(accessibilityStatus)")
    }

    private var icon: String {
        switch position {
        case .completed: "checkmark"
        case .current: "arrow.triangle.2.circlepath"
        case .upcoming: "circle"
        }
    }
    private var iconColor: Color {
        switch position {
        case .completed: Camp.moss
        case .current: Camp.creek
        case .upcoming: Camp.stone
        }
    }
    private var accessibilityStatus: String {
        switch position { case .completed: "已完成"; case .current: "正在进行"; case .upcoming: "尚未开始" }
    }
}

private extension RuminationStage {
    static let allCasesForUI: [RuminationStage] = [.saved, .reading, .extracting, .organizing]
    var displayText: String {
        switch self {
        case .saved: "保存原文"
        case .reading: "提炼要点"
        case .extracting: "识别需求和待办"
        case .organizing: "准备确认"
        }
    }
}

struct RuminationReviewView: View {
    @State private var review: RuminationReviewViewState
    var onSave: (RuminationReviewViewState) async throws -> Void
    var onMaterialize: (RuminationReviewViewState, MaterializationMode) async throws -> MaterializationResult
    var onDelete: (IngestionDeletionScope) async throws -> Void
    var onMissionDraft: (MissionDraftViewState) -> Void
    var onClose: () -> Void

    @State private var actionState: CodingRanchActionState = .idle
    @State private var sourceVisible = true
    @State private var showDeleteConfirmation = false

    init(
        review: RuminationReviewViewState,
        onSave: @escaping (RuminationReviewViewState) async throws -> Void = { _ in },
        onMaterialize: @escaping (RuminationReviewViewState, MaterializationMode) async throws -> MaterializationResult,
        onDelete: @escaping (IngestionDeletionScope) async throws -> Void = { _ in },
        onMissionDraft: @escaping (MissionDraftViewState) -> Void = { _ in },
        onClose: @escaping () -> Void = {}
    ) {
        _review = State(initialValue: review)
        self.onSave = onSave
        self.onMaterialize = onMaterialize
        self.onDelete = onDelete
        self.onMissionDraft = onMissionDraft
        self.onClose = onClose
    }

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= 900
            let compact = proxy.size.width < CampLayout.compactContentWidth
            VStack(spacing: 0) {
                reviewHeader(compact: compact)
                Divider().overlay(Camp.line)
                if wide {
                    HStack(spacing: 0) {
                        resultScroll
                        if sourceVisible {
                            Divider().overlay(Camp.line)
                            SourceEvidenceView(source: review.source)
                                .frame(width: min(360, proxy.size.width * 0.36))
                        }
                    }
                } else {
                    resultScroll
                        .sheet(isPresented: $sourceVisible) {
                            SourceEvidenceView(source: review.source)
                                .frame(
                                    minWidth: 360,
                                    idealWidth: 520,
                                    maxWidth: 680,
                                    minHeight: 420,
                                    idealHeight: 560,
                                    maxHeight: 700
                                )
                        }
                }
                Divider().overlay(Camp.line)
                reviewFooter(compact: compact)
            }
        }
        .background(Camp.canvas)
        .confirmationDialog("删除这次喂牛？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("删除原文和反刍结果", role: .destructive) {
                Task { await delete() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会删除原始材料和尚未收进营地的结果。已经形成的营地笔记不会被静默删除。")
        }
    }

    @ViewBuilder private func reviewHeader(compact: Bool) -> some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 10) {
                    reviewHeaderIdentity
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        reviewHeaderActions
                    }
                }
            } else {
                HStack(spacing: 12) {
                    reviewHeaderIdentity
                    Spacer(minLength: 8)
                    reviewHeaderActions
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Camp.surface)
    }

    private var reviewHeaderIdentity: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("检查反刍结果")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Camp.ink)
            Text("只把你确认过的内容收进营地。")
                .font(.caption)
                .foregroundStyle(Camp.inkSecondary)
        }
    }

    @ViewBuilder private var reviewHeaderActions: some View {
        Button(sourceVisible ? "收起原文" : "查看原文") { sourceVisible.toggle() }
            .buttonStyle(CampSecondaryButtonStyle())
        Button("关闭", action: onClose)
            .buttonStyle(CampSecondaryButtonStyle())
            .keyboardShortcut(.cancelAction)
    }

    private var resultScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                RuminationSectionCard(title: "一句话摘要", icon: "text.quote", color: Camp.creek) {
                    TextField("摘要", text: $review.summary, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(3...8)
                }
                candidateSection(.keyPoint, title: "关键知识", icon: "book.closed.fill", color: Camp.moss)
                candidateSection(.requirement, title: "需求", icon: "checklist", color: Camp.creek)
                candidateSection(.todo, title: "待办", icon: "calendar.badge.clock", color: Camp.ember)
                missionSection
                if !review.uncertainties.isEmpty {
                    RuminationSectionCard(title: "需要你确认", icon: "questionmark.bubble.fill", color: Camp.amber) {
                        ForEach(review.uncertainties, id: \.self) { uncertainty in
                            Label(uncertainty, systemImage: "questionmark.circle")
                                .font(.callout)
                                .foregroundStyle(Camp.ink)
                        }
                    }
                }
                if let error = currentError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(Camp.charcoalRed)
                        .campStatusPanel(Camp.charcoalRed)
                }
            }
            .padding(20)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
    }

    private func candidateSection(_ kind: CandidateKindViewState, title: String, icon: String, color: Color) -> some View {
        let indices = review.candidates.indices.filter { review.candidates[$0].kind == kind }
        return RuminationSectionCard(title: title, icon: icon, color: color) {
            if indices.isEmpty {
                Text("没有识别出\(title)")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            } else {
                ForEach(indices, id: \.self) { index in
                    EditableCandidateRow(candidate: $review.candidates[index])
                    if index != indices.last { Divider().overlay(Camp.line) }
                }
            }
        }
    }

    private var missionSection: some View {
        RuminationSectionCard(title: "建议放牛任务", icon: "flag.fill", color: Camp.ember) {
            if let draft = review.missionDraft {
                VStack(alignment: .leading, spacing: 8) {
                    Text(draft.goal)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Camp.ink)
                    ForEach(draft.acceptance, id: \.self) { item in
                        Label(item, systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(Camp.inkSecondary)
                    }
                    HStack {
                        CampChip(text: draft.deliverableType, color: Camp.creek, icon: "doc.fill")
                        Spacer()
                        Button("查看放牛草稿") { onMissionDraft(draft) }
                            .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
                    }
                }
            } else {
                Text("这条资料暂时不需要变成任务。你仍然可以只把知识收进营地。")
                    .font(.callout)
                    .foregroundStyle(Camp.inkSecondary)
            }
        }
    }

    @ViewBuilder private func reviewFooter(compact: Bool) -> some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        reviewSecondaryActions
                    }
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        reviewPrimaryActions
                    }
                }
            } else {
                HStack(spacing: 10) {
                    reviewSecondaryActions
                    Spacer(minLength: 8)
                    reviewPrimaryActions
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Camp.surface)
    }

    @ViewBuilder private var reviewSecondaryActions: some View {
        Button("删除原文和结果", role: .destructive) { showDeleteConfirmation = true }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(Camp.charcoalRed)
        Button("暂不处理", action: onClose)
            .buttonStyle(CampSecondaryButtonStyle())
    }

    @ViewBuilder private var reviewPrimaryActions: some View {
        Button("只收进营地") { Task { await materialize(.notesOnly) } }
            .buttonStyle(CampSecondaryButtonStyle(tint: Camp.moss))
            .disabled(!review.canMaterialize || isRunning)
        Button {
            Task { await materialize(.notesAndMission) }
        } label: {
            if isRunning {
                ProgressView().controlSize(.small).tint(.white)
            } else {
                Label("收进营地并放牛", systemImage: "flag.fill")
            }
        }
        .buttonStyle(CampPrimaryButtonStyle())
        .keyboardShortcut(.defaultAction)
        .disabled(!review.canMaterialize || review.missionDraft == nil || isRunning)
    }

    private var isRunning: Bool { actionState == .running }
    private var currentError: String? {
        if case .failed(let message) = actionState { return message }
        return review.error
    }

    @MainActor private func materialize(_ mode: MaterializationMode) async {
        actionState = .running
        do {
            try await onSave(review)
            let result = try await onMaterialize(review, mode)
            actionState = .idle
            if mode == .notesAndMission, let draft = result.missionDraft {
                onMissionDraft(draft)
            } else {
                onClose()
            }
        } catch {
            actionState = .failed(error.localizedDescription)
        }
    }

    @MainActor private func delete() async {
        actionState = .running
        do {
            try await onDelete(.sourceAndResult)
            actionState = .idle
            onClose()
        } catch {
            actionState = .failed(error.localizedDescription)
        }
    }
}

struct RuminationSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            RanchSectionHeader(icon: icon, title: title, tint: color)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .campCard()
    }
}

private struct EditableCandidateRow: View {
    @Binding var candidate: EditableCandidateViewState
    @State private var evidenceExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Button {
                    candidate.disposition = candidate.disposition == .accepted ? .ignored : .accepted
                } label: {
                    Image(systemName: candidate.disposition == .accepted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(candidate.disposition == .accepted ? Camp.moss : Camp.stone)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(candidate.disposition == .accepted ? "已接受，点击忽略" : "已忽略，点击接受")
                TextField("标题", text: $candidate.title)
                    .textFieldStyle(.plain)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                if let origin = candidate.origin {
                    CampChip(text: origin, color: Camp.stone)
                }
            }
            TextField("内容", text: $candidate.detail, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.callout)
                .lineLimit(2...6)
                .foregroundStyle(candidate.disposition == .accepted ? Camp.ink : Camp.inkSecondary)
                .padding(.leading, 28)
            if !candidate.evidence.isEmpty {
                Button(evidenceExpanded ? "收起依据" : "查看依据") { evidenceExpanded.toggle() }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Camp.creek)
                    .padding(.leading, 28)
                if evidenceExpanded {
                    ForEach(candidate.evidence) { evidence in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("“\(evidence.quote)”")
                                .font(.caption)
                                .foregroundStyle(Camp.ink)
                            Text([evidence.originLabel, evidence.locator].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(Camp.inkSecondary)
                        }
                        .padding(.leading, 28)
                    }
                }
            }
        }
        .opacity(candidate.disposition == .accepted ? 1 : 0.62)
    }
}

struct SourceEvidenceView: View {
    let source: SourceViewState

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("原文与来源", systemImage: "doc.text.fill")
                    .font(.headline)
                    .foregroundStyle(Camp.ink)
                Spacer()
            }
            Text(source.title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Camp.ink)
            HStack(spacing: 7) {
                CampChip(text: sourceKindText, color: Camp.creek)
                Text(source.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }
            if let author = source.author, !author.isEmpty {
                Label(author, systemImage: "person")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }
            if let url = source.sourceURL, !url.isEmpty {
                Text(url)
                    .font(.caption.monospaced())
                    .foregroundStyle(Camp.creek)
                    .textSelection(.enabled)
            }
            if let intent = source.userIntent, !intent.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("你希望关注")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Camp.inkSecondary)
                    Text(intent)
                        .font(.callout)
                        .foregroundStyle(Camp.ink)
                }
                .campStatusPanel(Camp.amber)
            }
            Divider().overlay(Camp.line)
            ScrollView {
                Text(source.rawText)
                    .font(.callout)
                    .foregroundStyle(Camp.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Camp.surface)
    }

    private var sourceKindText: String {
        switch source.sourceKind {
        case .pastedText: "粘贴内容"
        case .directThought: "直接想法"
        case .url: "链接"
        case .file: "文件"
        }
    }
}

struct RuminationViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RuminationInboxView(state: CodingRanchPreviewFixtures.inbox, onOpen: { _ in })
                .frame(width: 860, height: 620)
                .previewDisplayName("待反刍")

            RuminationProgressView(
                item: CodingRanchPreviewFixtures.ruminatingItem,
                onViewSource: {}, onCancel: {}, onClose: {}
            )
            .frame(width: 680, height: 650)
            .previewDisplayName("反刍进度")

            RuminationReviewView(
                review: CodingRanchPreviewFixtures.review,
                onMaterialize: { review, mode in
                    MaterializationResult(noteId: "note", missionDraft: mode == .notesAndMission ? review.missionDraft : nil)
                }
            )
            .frame(width: 1120, height: 760)
            .previewDisplayName("反刍结果 · 宽")

            RuminationReviewView(
                review: CodingRanchPreviewFixtures.review,
                onMaterialize: { review, mode in
                    MaterializationResult(noteId: "note", missionDraft: mode == .notesAndMission ? review.missionDraft : nil)
                }
            )
            .frame(width: 640, height: 760)
            .previewDisplayName("反刍结果 · 窄")
        }
    }
}
