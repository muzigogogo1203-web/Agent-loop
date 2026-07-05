import SwiftUI
import AgentLoopCore

struct CompanionEditorView: View {
    @Environment(AppStore.self) private var store
    let companionId: String?
    var onDone: () -> Void

    @State private var name = ""
    @State private var color = "purple"
    @State private var rolePrompt = ""
    @State private var modelChoice = "claude-sonnet-4-6"
    @State private var customModel = ""

    static let colors = ["purple", "teal", "coral", "pink", "blue", "green", "amber"]
    private static let customTag = "__custom__"

    private var resolvedModel: String {
        modelChoice == Self.customTag
            ? customModel.trimmingCharacters(in: .whitespacesAndNewlines)
            : modelChoice
    }

    var body: some View {
        Form {
            TextField("名字（比如：阿规）", text: $name)
            Picker("颜色", selection: $color) {
                ForEach(Self.colors, id: \.self) { color in
                    Text(color).tag(color)
                }
            }
            Picker("模型", selection: $modelChoice) {
                ForEach(AppStore.modelChoices, id: \.self) { model in
                    Text(model).tag(model)
                }
                Text("自定义…").tag(Self.customTag)
            }
            if modelChoice == Self.customTag {
                TextField("模型 id（网关提供的名字，如 glm-5.1）", text: $customModel)
                    .autocorrectionDisabled()
            }
            Section("职责（system prompt）") {
                TextEditor(text: $rolePrompt)
                    .frame(minHeight: 120)
            }
            Button("保存伙伴") {
                let companion = CompanionRecord.new(
                    name: name,
                    color: color,
                    rolePrompt: rolePrompt,
                    model: resolvedModel
                )
                try? store.db.saveCompanion(companion)
                store.reload()
                onDone()
            }
            .disabled(name.isEmpty || rolePrompt.isEmpty || resolvedModel.isEmpty)
        }
        .formStyle(.grouped)
        .navigationTitle(companionId == nil ? "新伙伴" : "编辑伙伴")
    }
}
