import SwiftUI
import AgentLoopCore

enum Destination: Hashable {
    case newMission
    case mission(String)
    case settings
    case chat(String)
    case editCompanion(String?)
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var selection: Destination? = .newMission
    @State private var historyExpanded = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var activeMissions: [MissionRecord] {
        store.missionList.filter { $0.status != .accepted && $0.status != .failed }
    }

    private var historyMissions: [MissionRecord] {
        store.missionList.filter { $0.status == .accepted || $0.status == .failed }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                newMissionButton
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                List(selection: $selection) {
                    if !activeMissions.isEmpty {
                        Section("进行中的行动") {
                            ForEach(activeMissions, id: \.id) { mission in
                                missionRow(mission)
                            }
                        }
                    }
                    if !historyMissions.isEmpty {
                        Section {
                            DisclosureGroup(isExpanded: $historyExpanded) {
                                ForEach(historyMissions, id: \.id) { mission in
                                    missionRow(mission)
                                }
                            } label: {
                                Label("往期行动", systemImage: "shippingbox")
                                    .foregroundStyle(Camp.inkSecondary)
                            }
                        }
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
                settingsRow
            }
            .background(Camp.canvas)
            .navigationSplitViewColumnWidth(min: 200, ideal: 230)
            .onAppear {
                store.reload()
            }
            .onChange(of: selection) { _, value in
                if case .mission(let id) = value {
                    store.selectMission(id)
                }
            }
            .onChange(of: store.currentMissionId) { _, missionId in
                if let missionId, selection == .newMission || selection == nil {
                    selection = .mission(missionId)
                }
            }
        } detail: {
            Group {
                switch selection {
                case .newMission, nil:
                    TaskRunView(mode: .newMission, onNewMission: { selection = .newMission })
                case .mission(let id):
                    TaskRunView(mode: .mission(id), onNewMission: { selection = .newMission })
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
                        if let id {
                            selection = .chat(id)
                        } else {
                            selection = .newMission
                        }
                    }
                }
            }
            .background(Camp.canvas)
        }
        .fontDesign(.rounded)
        .tint(Camp.ember)
    }

    private var newMissionButton: some View {
        Button {
            selection = .newMission
        } label: {
            HStack {
                Image(systemName: "flag.fill")
                Text("新行动")
                    .fontWeight(.semibold)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(CampPrimaryButtonStyle(size: .small))
        .keyboardShortcut("n", modifiers: .command)
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
                Button("放弃行动", role: .destructive) {
                    Task { await store.cancelMission(missionId: mission.id) }
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
