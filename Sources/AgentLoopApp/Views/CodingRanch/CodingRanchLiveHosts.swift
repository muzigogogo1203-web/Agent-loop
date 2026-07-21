import SwiftUI
import AgentLoopCore

struct CodingRanchHomeHost: View {
    @Environment(AppStore.self) private var store
    let campId: String
    var onOpenInbox: () -> Void
    var onOpenRumination: (String) -> Void
    var onOpenMission: (String) -> Void
    var onOpenNote: (String) -> Void
    var onOpenCowRoster: () -> Void
    var onStartMission: () -> Void
    var onOpenGuide: () -> Void
    var onOpenNotes: () -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        Group {
            if let dashboard = store.dashboard, dashboard.campId == campId {
                CodingRanchHomeView(
                    state: dashboard,
                    modelConnection: modelConnection,
                    onSubmitFeed: { draft, start in
                        try await store.submitFeed(draft, startRumination: start)
                    },
                    onSubmitDuplicate: { draft, start in
                        try await store.submitDuplicateAnyway(draft, startRumination: start)
                    },
                    onSaveFeedDraft: store.saveFeedDraft,
                    onOpenInbox: onOpenInbox,
                    onOpenRumination: onOpenRumination,
                    onOpenMission: onOpenMission,
                    onOpenNote: onOpenNote,
                    onOpenCowRoster: onOpenCowRoster,
                    onStartMission: onStartMission,
                    onOpenGuide: onOpenGuide,
                    onOpenNotes: onOpenNotes,
                    onOpenSettings: onOpenSettings
                )
            } else {
                ProgressView("正在整理营地…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Camp.canvas)
            }
        }
        .task(id: campId) {
            await store.loadDashboard(campId: campId)
        }
    }

    private var modelConnection: ModelConnectionViewState {
        store.apiKeyPresent || store.webCredentialPresent ? .configured : .missing
    }
}

struct RuminationInboxHost: View {
    @Environment(AppStore.self) private var store
    let campId: String
    var onOpen: (String) -> Void
    var onClose: (() -> Void)? = nil
    var onFeed: (() -> Void)? = nil

    var body: some View {
        RuminationInboxView(
            state: store.ruminationInbox,
            onOpen: onOpen,
            onStart: { await store.startRumination(ingestionId: $0) },
            onRetry: { await store.retryRumination(ingestionId: $0) },
            onClose: onClose,
            onFeed: onFeed,
            actionError: store.ruminationActionError,
            onClearActionError: { store.ruminationActionError = nil }
        )
        .task(id: campId) {
            await store.loadRuminationInbox(campId: campId)
        }
    }
}

struct RuminationDetailHost: View {
    @Environment(AppStore.self) private var store
    let ingestionId: String
    var onMissionDraft: (MissionDraftViewState) -> Void
    var onClose: () -> Void

    @State private var review: RuminationReviewViewState?
    @State private var loadState: CodingRanchLoadState = .loading
    @State private var source: SourceViewState?
    @State private var showSource = false
    @State private var sourceLoadFailed = false

    var body: some View {
        VStack(spacing: 0) {
            if let actionError = store.ruminationActionError {
                RuminationActionErrorPanel(
                    message: actionError,
                    onDismiss: { store.ruminationActionError = nil }
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            Group {
                if let review {
                    RuminationReviewView(
                        review: review,
                        onSave: store.saveRuminationReview,
                        onMaterialize: store.materializeRumination,
                        onDelete: { scope in
                            try await store.deleteIngestion(ingestionId: ingestionId, scope: scope)
                        },
                        onMissionDraft: onMissionDraft,
                        onClose: onClose
                    )
                } else if let item = inboxItem, case .ruminating = item.status {
                    RuminationProgressView(
                        item: item,
                        onViewSource: openSource,
                        onCancel: { try await store.cancelRumination(ingestionId: ingestionId) },
                        onClose: onClose
                    )
                } else if let item = inboxItem, item.status == .queued {
                    queuedView(item)
                } else if let item = inboxItem, case .failed(let message, let retryable) = item.status {
                    failedView(item: item, message: message, retryable: retryable)
                } else if let item = inboxItem, case .materialized = item.status {
                    processedView(item)
                } else if let item = inboxItem, item.status == .discarded {
                    discardedView(item)
                } else {
                    loadContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: ingestionId) {
            await load()
        }
        .onChange(of: inboxItem?.status) { _, _ in
            Task { await load() }
        }
        .sheet(isPresented: $showSource) {
            RuminationSourceSheet(
                source: source,
                fallbackTitle: inboxItem?.title ?? "未命名资料",
                fallbackSummary: inboxItem?.resultCountText ?? "",
                loadFailed: sourceLoadFailed
            )
            .frame(
                minWidth: 420,
                idealWidth: 620,
                maxWidth: 760,
                minHeight: 420,
                idealHeight: 600,
                maxHeight: 760
            )
        }
    }

    private var inboxItem: RuminationInboxItemViewState? {
        store.ruminationInbox.items.first { $0.id == ingestionId }
    }

    private func queuedView(_ item: RuminationInboxItemViewState) -> some View {
        CodingRanchEmptyState(
            title: item.title,
            message: "原文已经保存，还没有开始反刍。",
            systemImage: "clock.fill",
            actionTitle: "开始反刍",
            action: { Task { await store.startRumination(ingestionId: ingestionId) } }
        )
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Camp.canvas)
    }

    private func failedView(item: RuminationInboxItemViewState, message: String, retryable: Bool) -> some View {
        VStack(spacing: 14) {
            CodingRanchEmptyState(
                title: "反刍失败",
                message: message,
                systemImage: "exclamationmark.triangle.fill"
            )
            HStack(spacing: 10) {
                Button("查看原文", action: openSource)
                    .buttonStyle(CampSecondaryButtonStyle())
                if retryable {
                    Button("重试") {
                        Task { await store.retryRumination(ingestionId: item.id) }
                    }
                    .buttonStyle(CampPrimaryButtonStyle(size: .small))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Camp.canvas)
    }

    private func processedView(_ item: RuminationInboxItemViewState) -> some View {
        CodingRanchEmptyState(
            title: "这条材料已经处理",
            message: "“\(item.title)”已经收进营地。",
            systemImage: "checkmark.circle.fill",
            actionTitle: "返回",
            action: onClose
        )
        .padding(20)
    }

    private func discardedView(_ item: RuminationInboxItemViewState) -> some View {
        CodingRanchEmptyState(
            title: "这条材料已忽略",
            message: "“\(item.title)”仍保留在待反刍记录中。",
            systemImage: "eye.slash",
            actionTitle: "返回",
            action: onClose
        )
        .padding(20)
    }

    @ViewBuilder private var loadContent: some View {
        switch loadState {
        case .idle, .loading:
            ProgressView("正在打开反刍结果…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            CodingRanchEmptyState(title: "状态已经更新", message: "回到待反刍区查看它的最新状态。", actionTitle: "返回", action: onClose)
                .padding(20)
        case .failed(let message):
            CodingRanchEmptyState(title: "反刍结果暂时打不开", message: message, systemImage: "exclamationmark.triangle.fill", actionTitle: "返回", action: onClose)
                .padding(20)
        }
    }

    @MainActor private func load() async {
        if inboxItem == nil, let campId = store.dashboard?.campId {
            await store.loadRuminationInbox(campId: campId)
        }
        guard let item = inboxItem else {
            loadState = .failed("找不到这条喂入材料")
            return
        }
        review = nil
        guard item.status == .needsReview else {
            loadState = .loaded
            return
        }
        loadState = .loading
        do {
            review = try await store.loadRuminationReview(ingestionId: ingestionId)
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    private func openSource() {
        source = nil
        sourceLoadFailed = false
        showSource = true
        Task {
            do {
                source = try await store.loadRuminationSource(ingestionId: ingestionId)
            } catch {
                sourceLoadFailed = true
            }
        }
    }
}

struct CowRosterHost: View {
    @Environment(AppStore.self) private var store
    let campId: String
    var onOpenCow: (String) -> Void
    var onCreateCustomCow: () -> Void

    var body: some View {
        Group {
            if let dashboard = store.dashboard, dashboard.campId == campId {
                CowRosterView(
                    state: rosterState(dashboard),
                    onOpenCow: onOpenCow,
                    onUnlock: store.unlockTestCow,
                    onCreateCustomCow: onCreateCustomCow
                )
            } else {
                ProgressView("正在打开牛棚…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: campId) {
            await store.loadDashboard(campId: campId)
        }
    }

    private func rosterState(_ dashboard: CampDashboardViewState) -> CowRosterViewState {
        let owned = store.companions
            .filter { ($0.campId == campId || ($0.campId ?? "").isEmpty) && $0.kind == .regular }
            .map { cow in
                CowSummaryViewState(
                    id: cow.id,
                    name: cow.name,
                    role: cow.id == CowTemplate.testCowId ? "验收与测试" : "Coding 通才",
                    colorName: cow.color,
                    specialties: cow.id == CowTemplate.testCowId ? ["测试", "边界检查"] : ["HTML", "小工具", "需求整理"],
                    status: .idle,
                    lastActivity: nil,
                    recentMission: nil,
                    isSystemGuide: false
                )
            }
        return .init(
            loadState: dashboard.loadState,
            owned: owned,
            locked: dashboard.newcomerProgress.isUnlocked ? [] : [dashboard.newcomerProgress.nextCow],
            newcomerProgress: dashboard.newcomerProgress,
            canCreateCustomCow: dashboard.newcomerProgress.isUnlocked
        )
    }
}

struct CampNotesHost: View {
    @Environment(AppStore.self) private var store
    let campId: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "book.closed.fill").foregroundStyle(Camp.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("营地笔记").font(.title2.weight(.bold)).foregroundStyle(Camp.ink)
                    Text("确认后的知识和回营经验都保存在这里。")
                        .font(.caption).foregroundStyle(Camp.inkSecondary)
                }
                Spacer()
            }
            .padding(16)
            .background(Camp.surface)
            Divider().overlay(Camp.line)
            NoteListPane(
                title: "营地笔记",
                items: store.campNotes.map(NoteItem.init),
                emptyText: "还没有营地笔记。先喂基础牛一条信息，确认反刍后就会出现在这里。",
                onSave: { id, title, body in
                    guard var note = store.campNotes.first(where: { $0.id == id }) else { return }
                    note.title = title
                    note.bodyMd = body
                    store.saveCampNoteEdits(note)
                },
                onTogglePin: { id in
                    guard let note = store.campNotes.first(where: { $0.id == id }) else { return }
                    store.toggleCampNotePin(note)
                },
                onDelete: store.deleteCampNote
            )
            .padding(16)
        }
        .background(Camp.canvas)
        .task(id: campId) { store.loadCampHome(campId: campId) }
    }
}

struct ReturnSummaryHost: View {
    @Environment(AppStore.self) private var store
    let missionId: String
    var onBackToMission: () -> Void
    var onAccepted: () -> Void
    var onOpenRoster: () -> Void

    @State private var summary: ReturnSummaryViewState?
    @State private var loadState: CodingRanchLoadState = .loading

    var body: some View {
        Group {
            if let summary {
                ReturnSummaryView(
                    state: summary,
                    onReveal: { store.revealPath($0.path) },
                    onRequestChanges: onBackToMission,
                    onAccept: {
                        store.closeoutCurrentMission()
                        onAccepted()
                    },
                    onAbandon: {
                        Task {
                            await store.cancelMission(missionId: missionId)
                            onBackToMission()
                        }
                    },
                    onOpenRoster: onOpenRoster
                )
            } else {
                switch loadState {
                case .idle, .loading:
                    ProgressView("正在准备回营验收…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .loaded:
                    CodingRanchEmptyState(title: "还不能回营", message: "任务还没有形成可验收的结果。", actionTitle: "返回 Coding 草原", action: onBackToMission)
                        .padding(20)
                case .failed(let message):
                    CodingRanchEmptyState(title: "回营验收暂时打不开", message: message, systemImage: "exclamationmark.triangle.fill", actionTitle: "返回", action: onBackToMission)
                        .padding(20)
                }
            }
        }
        .background(Camp.canvas)
        .task(id: missionId) {
            store.selectMission(missionId)
            do {
                summary = try await store.loadReturnSummary(missionId: missionId)
                loadState = .loaded
            } catch {
                loadState = .failed(error.localizedDescription)
            }
        }
    }
}
