import SwiftUI
import AgentLoopCore

struct CompanionEditorView: View {
    @Environment(AppStore.self) private var store
    let companionId: String?
    var onDone: () -> Void

    @State private var name = ""
    @State private var color = "purple"
    @State private var rolePrompt = ""
    @State private var model = "claude-sonnet-4-6"

    static let colors = ["purple", "teal", "coral", "pink", "blue", "green", "amber"]

    var body: some View {
        Form {
            TextField("名字（比如：阿规）", text: $name)
            Picker("颜色", selection: $color) {
                ForEach(Self.colors, id: \.self) { color in
                    Text(color).tag(color)
                }
            }
            Picker("模型", selection: $model) {
                ForEach(AppStore.modelChoices, id: \.self) { model in
                    Text(model).tag(model)
                }
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
                    model: model
                )
                try? store.db.saveCompanion(companion)
                store.reload()
                onDone()
            }
            .disabled(name.isEmpty || rolePrompt.isEmpty)
        }
        .formStyle(.grouped)
        .navigationTitle(companionId == nil ? "新伙伴" : "编辑伙伴")
    }
}
