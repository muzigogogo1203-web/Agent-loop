import SwiftUI
import Accessibility
import AgentLoopCore

enum Destination: Hashable {
    case onboarding
    case newMission(campId: String)
    case camp(String)
    case campGuide(String)
    case campNotes(String)
    case ruminationInbox(String)
    case rumination(String)
    case cowRoster(String)
    case missionDraft
    case mission(String)
    case returnSummary(String)
    case trophies
    case settings
    case chat(String)
    case editCompanion(String?)
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var selection: Destination?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showNewCampSheet = false
    @State private var abandonTarget: MissionRecord?
    @State private var showResumeConfirmation = false
    @State private var pendingMissionDraft: MissionDraftViewState?
    @AppStorage("codingRanch.didCompleteOnboarding") private var didCompleteOnboarding = false

    var body: some View {
        VStack(spacing: 0) {
            if store.showsGlobalHaltBanner {
                globalHaltBanner
                Divider().overlay(Camp.charcoalRed.opacity(0.35))
            }

            NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    // 营地=频道（M5-0 C1）：每营地一个分区
                    ForEach(store.camps, id: \.id) { camp in
                        campSection(camp)
                    }

                    Section("归营") {
                        NavigationLink(value: Destination.trophies) {
                            Label("回营成果", systemImage: "shippingbox.fill")
                                .foregroundStyle(selection == .trophies ? Camp.ember : Camp.ink)
                        }
                    }

                    Section("牛群") {
                        ForEach(store.companions, id: \.id) { companion in
                            NavigationLink(value: Destination.chat(companion.id)) {
                                HStack(spacing: 8) {
                                    CompanionAvatarView(
                                        name: companion.name,
                                        colorName: companion.color,
                                        state: .idle,
                                        size: 24
                                    )
                                    Text(companion.name)
                                }
                            }
                            .contextMenu {
                                Button("编辑…") { selection = .editCompanion(companion.id) }
                            }
                        }
                        if let campId = store.campId ?? store.camps.first?.id {
                            NavigationLink(value: Destination.cowRoster(campId)) {
                                Label("牛棚与解锁", systemImage: "building.2")
                                    .foregroundStyle(Camp.inkSecondary)
                            }
                        }
                        NavigationLink(value: Destination.editCompanion(nil)) {
                            Label("新牛…", systemImage: "person.badge.plus")
                                .foregroundStyle(Camp.inkSecondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)

                Divider()
                    .overlay(Camp.line)
                newCampRow
                settingsRow
            }
            .background(Camp.canvas)
            .navigationSplitViewColumnWidth(min: 210, ideal: 240)
            .onAppear {
                store.reload()
                if let previewMission = AppStore.previewMissionId {
                    selection = .mission(previewMission)
                } else if shouldShowOnboarding {
                    selection = .onboarding
                } else if selection == nil, let first = store.camps.first {
                    selection = .camp(first.id)
                }
            }
            .onChange(of: selection) { previous, value in
                if case .mission(let id) = value {
                    store.selectMission(id)
                }
                // 切走 DM 线程 → 未蒸馏增量达阈值时后台自动沉淀（D7）
                if case .chat(let companionId) = previous, previous != value {
                    store.autoDistillOnLeave(companionId: companionId)
                }
            }
            .onChange(of: store.currentMissionId) { _, missionId in
                if let missionId, isOnNewMission || selection == nil {
                    selection = .mission(missionId)
                }
            }
            .onChange(of: store.navigateToMissionId) { _, missionId in
                // 提案确认后直达新行动
                if let missionId {
                    selection = .mission(missionId)
                    store.navigateToMissionId = nil
                }
            }
            .sheet(isPresented: $showNewCampSheet) {
                NewCampSheet { name, guidePrompt in
                    if let camp = store.createCamp(name: name, guidePrompt: guidePrompt) {
                        selection = .camp(camp.id)
                    }
                    showNewCampSheet = false
                } onCancel: {
                    showNewCampSheet = false
                }
            }
        } detail: {
            Group {
                switch selection {
                case .onboarding:
                    CodingRanchOnboardingView(
                        cow: onboardingCow,
                        modelConnection: modelConnection,
                        onEnter: {
                            didCompleteOnboarding = true
                            if let first = store.camps.first { selection = .camp(first.id) }
                        },
                        onOpenSettings: { selection = .settings }
                    )
                case .newMission(let campId):
                    TaskRunView(
                        mode: .newMission(campId: campId),
                        onNewMission: { selection = .newMission(campId: campId) },
                        onOpenSettings: { selection = .settings },
                        onRecruit: { selection = .editCompanion(nil) }
                    )
                case .camp(let campId):
                    CampHomeView(
                        campId: campId,
                        onEditGuide: {
                            if let guideId = store.guideCompanion?.id {
                                selection = .editCompanion(guideId)
                            }
                        },
                        onNewMission: { selection = .newMission(campId: campId) },
                        onOpenMission: { selection = .mission($0) }
                    )
                case .campGuide(let campId):
                    CampHomeView(
                        campId: campId,
                        onEditGuide: {
                            if let guideId = store.guideCompanion?.id {
                                selection = .editCompanion(guideId)
                            }
                        },
                        onNewMission: { selection = .newMission(campId: campId) },
                        onOpenMission: { selection = .mission($0) }
                    )
                case .campNotes(let campId):
                    CampNotesHost(campId: campId)
                case .ruminationInbox(let campId):
                    RuminationInboxHost(campId: campId) { selection = .rumination($0) }
                case .rumination(let ingestionId):
                    RuminationDetailHost(
                        ingestionId: ingestionId,
                        onMissionDraft: { draft in
                            pendingMissionDraft = draft
                            selection = .missionDraft
                        },
                        onClose: {
                            let campId = store.dashboard?.campId ?? store.camps.first?.id
                            if let campId { selection = .ruminationInbox(campId) }
                        }
                    )
                case .cowRoster(let campId):
                    CowRosterHost(
                        campId: campId,
                        onOpenCow: { selection = .chat($0) },
                        onCreateCustomCow: { selection = .editCompanion(nil) }
                    )
                case .missionDraft:
                    if let draft = pendingMissionDraft {
                        MissionDraftConfirmationView(
                            draft: draft,
                            onStart: store.startMission,
                            onStarted: { missionId in
                                pendingMissionDraft = nil
                                selection = .mission(missionId)
                            },
                            onCancel: {
                                if let ingestionId = draft.ingestionId {
                                    selection = .rumination(ingestionId)
                                } else {
                                    selection = .camp(draft.campId)
                                }
                            }
                        )
                    } else {
                        ContentUnavailableView("放牛草稿不在了", systemImage: "doc.badge.ellipsis")
                    }
                case .mission(let id):
                    TaskRunView(mode: .mission(id), onNewMission: {
                        let campId = store.camp(forMission: id) ?? store.camps.first?.id
                        if let campId {
                            selection = .newMission(campId: campId)
                        }
                    }, onReturnSummary: {
                        selection = .returnSummary(id)
                    })
                case .returnSummary(let id):
                    ReturnSummaryHost(
                        missionId: id,
                        onBackToMission: { selection = .mission(id) },
                        onAccepted: { selection = .mission(id) }
                    )
                case .trophies:
                    TrophyCenterView { missionId in
                        selection = .mission(missionId)
                    }
                case .settings:
                    SettingsView()
                case .chat(let id):
                    if let companion = store.companions.first(where: { $0.id == id }) {
                        DMChatView(companion: companion) {
                            selection = .editCompanion(companion.id)
                        }
                    } else {
                        ContentUnavailableView("这只牛不在牛棚里", systemImage: "person.crop.circle.badge.questionmark")
                    }
                case .editCompanion(let id):
                    CompanionEditorView(companionId: id) {
                        if let id, id == store.guideCompanion?.id, let campId = store.campId {
                            selection = .camp(campId)
                        } else if let id {
                            selection = .chat(id)
                        } else if let first = store.camps.first {
                            selection = .camp(first.id)
                        }
                    }
                case nil:
                    ContentUnavailableView("选一个营地开始", systemImage: "tent")
                }
            }
            .background(Camp.canvas)
            // 统一 toast 通道（UX 审计 P2：跨视图反馈不再丢失）
            .campToast(store.knowledgeToast)
            }
        }
        .confirmationDialog(
            "放弃「\(abandonTarget.map(Self.missionTitleStatic) ?? "")」？",
            isPresented: Binding(
                get: { abandonTarget != nil },
                set: { if !$0 { abandonTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("放弃任务", role: .destructive) {
                if let mission = abandonTarget {
                    Task { await store.cancelMission(missionId: mission.id) }
                }
                abandonTarget = nil
            }
            Button("再想想", role: .cancel) { abandonTarget = nil }
        } message: {
            Text("未完成的小目标会作废，已产出的交付物保留。")
        }
        .confirmationDialog(
            "恢复全部行动？",
            isPresented: $showResumeConfirmation,
            titleVisibility: .visible
        ) {
            Button("恢复全部行动") {
                store.resumeCamp()
            }
            Button("继续暂停", role: .cancel) {}
        } message: {
            Text("等待中的规划和小目标可能会立即继续调用模型与工具，并产生新的花销。")
        }
        .onChange(of: haltAccessibilityAnnouncement) { _, announcement in
            AccessibilityNotification.Announcement(announcement).post()
        }
        .onAppear {
            if store.showsGlobalHaltBanner {
                AccessibilityNotification.Announcement(haltAccessibilityAnnouncement).post()
            }
        }
        .fontDesign(.rounded)
        .tint(Camp.ember)
    }

    private var globalHaltBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: store.haltOperationState == .resuming
                  ? "arrow.clockwise.circle.fill"
                  : "hand.raised.slash.fill")
                .font(.title3)
                .foregroundStyle(Camp.charcoalRed)

            VStack(alignment: .leading, spacing: 3) {
                Text(store.haltBannerTitle)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(store.haltBannerMessage)
                    .font(.caption)
                    .foregroundStyle(store.haltErrorMessage == nil ? Camp.inkSecondary : Camp.charcoalRed)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 12)

            switch store.haltOperationState {
            case .stopping, .resuming:
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(store.haltBannerTitle)
            case .idle:
                if store.haltPersistencePending {
                    Button("重试保存停营") {
                        store.emergencyStopCamp()
                    }
                    .buttonStyle(CampPrimaryButtonStyle(size: .small))
                }
                Button("恢复全部…") {
                    showResumeConfirmation = true
                }
                .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Camp.charcoalRed.opacity(0.08))
        .accessibilityElement(children: .contain)
    }

    private var haltAccessibilityAnnouncement: String {
        guard store.showsGlobalHaltBanner else { return "全部行动已恢复" }
        return "\(store.haltBannerTitle)。\(store.haltBannerMessage)"
    }

    static func missionTitleStatic(_ mission: MissionRecord) -> String {
        let refined = mission.goalRefined.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = mission.goalRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = refined.isEmpty ? raw : refined
        let firstLine = base.split(whereSeparator: \.isNewline).first.map(String.init) ?? base
        return firstLine.isEmpty ? "未命名任务" : String(firstLine.prefix(16))
    }

    private var isOnNewMission: Bool {
        if case .newMission = selection { return true }
        return false
    }

    private var shouldShowOnboarding: Bool {
        guard !didCompleteOnboarding else { return false }
        let regular = store.companions.filter { $0.kind == .regular }
        let onlyBaseCow = !regular.isEmpty && regular.allSatisfy { $0.id == CowTemplate.baseCowId }
        return store.missionList.isEmpty && onlyBaseCow
    }

    private var modelConnection: ModelConnectionViewState {
        store.apiKeyPresent || store.webCredentialPresent ? .configured : .missing
    }

    private var onboardingCow: CowSummaryViewState {
        if let dashboardCow = store.dashboard?.activeCow { return dashboardCow }
        if let cow = store.companions.first(where: { $0.id == CowTemplate.baseCowId }) {
            return .init(
                id: cow.id, name: cow.name, role: "教学型 Coding 通才", colorName: cow.color,
                specialties: ["需求整理", "简单网页", "小工具"], status: .idle,
                lastActivity: nil, recentMission: nil, isSystemGuide: false
            )
        }
        return .init(
            id: CowTemplate.baseCowId, name: "基础牛", role: "教学型 Coding 通才", colorName: "amber",
            specialties: ["需求整理", "简单网页", "小工具"], status: .idle,
            lastActivity: nil, recentMission: nil, isSystemGuide: false
        )
    }

    // MARK: - 营地分区

    @ViewBuilder private func campSection(_ camp: CampRecord) -> some View {
        let active = (store.missionsByCamp[camp.id] ?? [])
            .filter { $0.status != .accepted && $0.status != .failed }
        Section {
            NavigationLink(value: Destination.camp(camp.id)) {
                HStack(spacing: 8) {
                    Image(systemName: "tent.fill")
                        .foregroundStyle(Camp.ember)
                    Text(camp.name)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if camp.archived {
                        CampChip(text: "归档", color: Camp.stone, icon: "archivebox")
                    }
                    Spacer()
                }
            }
            .contextMenu {
                if !camp.archived {
                    Button("发起放牛…") {
                        selection = .newMission(campId: camp.id)
                    }
                    .disabled(store.missionStartBlocked)
                    Divider()
                    Button("归档营地") {
                        store.setCampArchived(id: camp.id, archived: true)
                    }
                } else {
                    Button("恢复营地") {
                        store.setCampArchived(id: camp.id, archived: false)
                    }
                }
            }
            ForEach(active, id: \.id) { mission in
                missionRow(mission)
            }
            if !camp.archived {
                NavigationLink(value: Destination.newMission(campId: camp.id)) {
                    Label("发起放牛…", systemImage: "flag")
                        .foregroundStyle(Camp.inkSecondary)
                        .font(.callout)
                }
                .disabled(store.missionStartBlocked)
                .help(store.missionStartBlocked ? store.missionStartBlockMessage : "在这个营地发起放牛任务")
            }
        }
    }

    private var newCampRow: some View {
        Button {
            showNewCampSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("新营地")
                Spacer()
            }
            .font(.callout)
            .foregroundStyle(Camp.ember)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var settingsRow: some View {
        Button {
            selection = .settings
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gearshape")
                Text("设置")
                Spacer()
            }
            .font(.callout)
            .foregroundStyle(selection == .settings ? Camp.ember : Camp.inkSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func missionRow(_ mission: MissionRecord) -> some View {
        NavigationLink(value: Destination.mission(mission.id)) {
            HStack(spacing: 8) {
                Circle()
                    .fill(missionColor(mission.status))
                    .frame(width: 8, height: 8)
                Text(missionTitle(mission))
                    .lineLimit(1)
                Spacer()
                Text(missionStatusText(mission.status))
                    .font(.caption2)
                    .foregroundStyle(missionColor(mission.status))
            }
        }
        .contextMenu {
            if mission.status != .accepted && mission.status != .failed {
                Button("放弃任务…", role: .destructive) {
                    abandonTarget = mission // 二次确认（UX 审计 P1）
                }
            }
        }
    }

    private func missionTitle(_ mission: MissionRecord) -> String {
        let refined = mission.goalRefined.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = mission.goalRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = refined.isEmpty ? raw : refined
        let firstLine = base.split(whereSeparator: \.isNewline).first.map(String.init) ?? base
        return firstLine.isEmpty ? "未命名任务" : String(firstLine.prefix(24))
    }

    private func missionColor(_ status: MissionStatus) -> Color {
        switch status {
        case .planning: Camp.amber
        case .executing: Camp.creek
        case .delivering: Camp.moss
        case .accepted: Camp.stone
        case .failed: Camp.stone
        }
    }

    private func missionStatusText(_ status: MissionStatus) -> String {
        switch status {
        case .planning: "规划中"
        case .executing: "进行中"
        case .delivering: "待回营"
        case .accepted: "已回营"
        case .failed: "已放弃"
        }
    }
}

// MARK: - 新营地弹窗（C2）

private struct NewCampSheet: View {
    var onCreate: (_ name: String, _ guidePrompt: String?) -> Void
    var onCancel: () -> Void
    @State private var name = ""
    @State private var guidePrompt = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("扎一个新营地")
                    .font(.headline)
                    .foregroundStyle(Camp.ink)
                Text("营地就像频道：放牛任务从这里发起，经验沉淀在营地笔记里。")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }

            TextField("营地名字，比如：北岭前哨", text: $name)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .padding(10)
                .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                        .stroke(Camp.line, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text("营地管家人设（可选）")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Camp.inkSecondary)
                TextField("这个营地的管家是什么样的人？留空用默认。", text: $guidePrompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...4)
                    .padding(10)
                    .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                            .stroke(Camp.line, lineWidth: 1)
                    )
            }

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .buttonStyle(CampSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button {
                    onCreate(name, guidePrompt.isEmpty ? nil : guidePrompt)
                } label: {
                    Label("扎营", systemImage: "tent.fill")
                }
                .buttonStyle(CampPrimaryButtonStyle(size: .small))
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
        }
        .padding(18)
        .frame(width: 420)
        .background(Camp.canvas)
    }
}
