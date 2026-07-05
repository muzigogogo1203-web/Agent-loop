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

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("行动") {
                    NavigationLink(value: Destination.newMission) {
                        Label("新行动", systemImage: "flag")
                    }
                    ForEach(store.missionList, id: \.id) { mission in
                        NavigationLink(value: Destination.mission(mission.id)) {
                            HStack {
                                Label(missionTitle(mission), systemImage: missionIcon(mission.status))
                                Spacer()
                                Text(missionStatusText(mission.status))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
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
                }
                Section("伙伴") {
                    ForEach(store.companions, id: \.id) { companion in
                        NavigationLink(value: Destination.chat(companion.id)) {
                            HStack {
                                CompanionAvatarView(
                                    name: companion.name,
                                    colorName: companion.color,
                                    state: .idle,
                                    size: 22
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
                        Label("新伙伴...", systemImage: "plus")
                    }
                }
                Section {
                    NavigationLink(value: Destination.settings) {
                        Label("设置", systemImage: "gearshape")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
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
            switch selection {
            case .newMission, nil:
                TaskRunView(mode: .newMission)
            case .mission(let id):
                TaskRunView(mode: .mission(id))
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
    }

    private func missionTitle(_ mission: MissionRecord) -> String {
        let trimmed = mission.goalRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名行动" : String(trimmed.prefix(28))
    }

    private func missionIcon(_ status: MissionStatus) -> String {
        switch status {
        case .planning: "wand.and.stars"
        case .executing: "bolt.circle"
        case .delivering: "flag.checkered"
        case .accepted: "checkmark.circle"
        case .failed: "xmark.circle"
        }
    }

    private func missionStatusText(_ status: MissionStatus) -> String {
        switch status {
        case .planning: "规划"
        case .executing: "进行"
        case .delivering: "待收"
        case .accepted: "已收"
        case .failed: "已停"
        }
    }
}
