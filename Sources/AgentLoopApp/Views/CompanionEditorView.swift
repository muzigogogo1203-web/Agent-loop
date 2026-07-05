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
    @State private var saveError: String?

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
                save()
            }
            .disabled(name.isEmpty || rolePrompt.isEmpty || resolvedModel.isEmpty)
            if let saveError {
                Text(saveError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(companionId == nil ? "新伙伴" : "编辑伙伴")
        .task(id: companionId) {
            load()
        }
    }

    private func load() {
        saveError = nil
        guard let companionId else {
            name = ""
            color = "purple"
            rolePrompt = ""
            modelChoice = AppStore.modelChoices[0]
            customModel = ""
            return
        }
        guard let companion = try? store.db.companion(id: companionId) else {
            return
        }
        name = companion.name
        color = companion.color
        rolePrompt = companion.rolePrompt
        if AppStore.modelChoices.contains(companion.model) {
            modelChoice = companion.model
            customModel = ""
        } else {
            modelChoice = Self.customTag
            customModel = companion.model
        }
    }

    private func save() {
        do {
            if let companionId {
                guard var companion = try store.db.companion(id: companionId) else {
                    saveError = "保存失败：伙伴不存在"
                    return
                }
                companion.name = name
                companion.color = color
                companion.rolePrompt = rolePrompt
                companion.model = resolvedModel
                try store.db.saveCompanion(companion)
            } else {
                let companion = CompanionRecord.new(
                    name: name,
                    color: color,
                    rolePrompt: rolePrompt,
                    model: resolvedModel
                )
                try store.db.saveCompanion(companion)
            }
            saveError = nil
            store.reload()
            onDone()
        } catch {
            saveError = "保存失败：\(error.localizedDescription)"
        }
    }
}
