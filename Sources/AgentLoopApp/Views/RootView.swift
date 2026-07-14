import SwiftUI
import Accessibility
import AgentLoopCore

enum Destination: Hashable {
    case newMission(campId: String)
    case camp(String)
    case mission(String)
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

                    Section("伙伴") {
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
                                Button("编辑…") {
                                    selection = .editCompanion(companion.id)
                                }
                            }
                        }
                        NavigationLink(value: Destination.editCompanion(nil)) {
                            Label("新伙伴…", systemImage: "person.badge.plus")
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
                case .mission(let id):
                    TaskRunView(mode: .mission(id), onNewMission: {
                        let campId = store.camp(forMission: id) ?? store.camps.first?.id
                        if let campId {
                            selection = .newMission(campId: campId)
                        }
                    })
                case .settings:
                    SettingsView()
                case .chat(let id):
                    if let companion = store.companions.first(where: { $0.id == id }) {
                        DMChatView(companion: companion) {
                            selection = .editCompanion(companion.id)
                        }
                    } else {
                        ContentUnavailableView("伙伴不在名册里", systemImage: "person.crop.circle.badge.questionmark")
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
            Button("放弃行动", role: .destructive) {
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
        return firstLine.isEmpty ? "未命名行动" : String(firstLine.prefix(16))
    }

    private var isOnNewMission: Bool {
        if case .newMission = selection { return true }
        return false
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
                    Spacer()
                }
            }
            .contextMenu {
                Button("新行动…") {
                    selection = .newMission(campId: camp.id)
                }
                .disabled(store.missionStartBlocked)
            }
            ForEach(active, id: \.id) { mission in
                missionRow(mission)
            }
            NavigationLink(value: Destination.newMission(campId: camp.id)) {
                Label("新行动…", systemImage: "flag")
                    .foregroundStyle(Camp.inkSecondary)
                    .font(.callout)
            }
            .disabled(store.missionStartBlocked)
            .help(store.missionStartBlocked ? store.missionStartBlockMessage : "在这个营地开启新行动")
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
                Button("放弃行动…", role: .destructive) {
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
        return firstLine.isEmpty ? "未命名行动" : String(firstLine.prefix(24))
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
        case .delivering: "可收营"
        case .accepted: "已收营"
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
                Text("营地就像频道：行动在营地里发起，经验沉淀在营地的笔记本里。")
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
                Text("向导人设（可选）")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Camp.inkSecondary)
                TextField("这个营地的向导是什么样的人？留空用默认。", text: $guidePrompt, axis: .vertical)
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
