import SwiftUI
import AgentLoopCore

enum Destination: Hashable {
    case newTask
    case settings
    case chat(String)
    case editCompanion(String?)
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var selection: Destination? = .newTask

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("行动") {
                    NavigationLink(value: Destination.newTask) {
                        Label("单卡试运行", systemImage: "flag")
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
        } detail: {
            switch selection {
            case .newTask, nil:
                TaskRunView()
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
                        selection = .newTask
                    }
                }
            }
        }
    }
}
