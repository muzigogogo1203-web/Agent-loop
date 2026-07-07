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
    @State private var enabledTools: Set<String> = Set(ToolAccess.builtinCapabilityNames)
    @State private var saveError: String?

    static let colors = ["purple", "teal", "coral", "pink", "blue", "green", "amber"]
    private static let customTag = "__custom__"

    private var resolvedModel: String {
        modelChoice == Self.customTag
            ? customModel.trimmingCharacters(in: .whitespacesAndNewlines)
            : modelChoice
    }

    private var canSave: Bool {
        !name.isEmpty && !rolePrompt.isEmpty && !resolvedModel.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // 头部：实时预览
                HStack(spacing: 16) {
                    CompanionAvatarView(
                        name: name.isEmpty ? "伙" : name,
                        colorName: color,
                        size: 64
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(companionId == nil ? "招募新伙伴" : "编辑伙伴")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(Camp.ink)
                        Text(companionId == nil ? "起个名字、挑个颜色、写清职责，就能一起出发。" : "改动会即时用于之后的行动与私聊。")
                            .font(.callout)
                            .foregroundStyle(Camp.inkSecondary)
                    }
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    CampSectionTitle("名字")
                    TextField("比如：阿规", text: $name)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding(11)
                        .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                                .stroke(Camp.line, lineWidth: 1)
                        )

                    CampSectionTitle("颜色")
                    HStack(spacing: 12) {
                        ForEach(Self.colors, id: \.self) { colorName in
                            colorSwatch(colorName)
                        }
                    }
                }
                .campCard()

                VStack(alignment: .leading, spacing: 12) {
                    CampSectionTitle("模型")
                    Picker("模型", selection: $modelChoice) {
                        ForEach(store.modelChoices, id: \.self) { model in
                            Text(model).tag(model)
                        }
                        Text("自定义…").tag(Self.customTag)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    if modelChoice == Self.customTag {
                        TextField("模型 id（网关提供的名字，如 glm-5.1）", text: $customModel)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .padding(11)
                            .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                                    .stroke(Camp.line, lineWidth: 1)
                            )
                    }
                }
                .campCard()

                VStack(alignment: .leading, spacing: 12) {
                    CampSectionTitle("工具")
                    Text("勾选这位伙伴执行小目标时可用的工具；汇报进展、提问与交接始终可用。")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                    ForEach(ToolAccess.builtinCapabilityNames, id: \.self) { tool in
                        // M6-D8：无 Tavily key 时 web_search 置灰，避免「可勾但运行时静默消失」
                        let searchLocked = tool == "web_search" && !store.searchKeyPresent
                        HStack(spacing: 6) {
                            Toggle(isOn: toolBinding(tool)) {
                                Text(ToolDef.displayName(tool))
                                    .font(.body)
                                    .foregroundStyle(searchLocked ? Camp.inkSecondary : Camp.ink)
                            }
                            .toggleStyle(.checkbox)
                            .disabled(searchLocked)
                            if searchLocked {
                                Text("（先到设置页配置 Tavily key）")
                                    .font(.caption)
                                    .foregroundStyle(Camp.inkSecondary)
                            }
                        }
                    }
                }
                .campCard()

                VStack(alignment: .leading, spacing: 12) {
                    CampSectionTitle("职责")
                    Text("它决定这位伙伴擅长什么、以什么口吻做事（system prompt）。")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                    TextEditor(text: $rolePrompt)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 140)
                        .padding(8)
                        .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                                .stroke(Camp.line, lineWidth: 1)
                        )
                }
                .campCard()

                if let saveError {
                    Label(saveError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Camp.charcoalRed)
                }

                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()
                        Label(companionId == nil ? "入册" : "保存", systemImage: "checkmark")
                        Spacer()
                    }
                }
                .buttonStyle(CampPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
            }
            .frame(maxWidth: 560)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Camp.canvas)
        .task(id: companionId) {
            load()
        }
    }

    private func colorSwatch(_ colorName: String) -> some View {
        let swatch = CompanionAvatarView.palette[colorName] ?? .gray
        return Button {
            color = colorName
        } label: {
            ZStack {
                Circle()
                    .fill(swatch.opacity(0.85))
                    .frame(width: 30, height: 30)
                if color == colorName {
                    Circle()
                        .stroke(Camp.ink, lineWidth: 2)
                        .frame(width: 38, height: 38)
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 40, height: 40)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func toolBinding(_ tool: String) -> Binding<Bool> {
        Binding(
            get: { enabledTools.contains(tool) },
            set: { on in
                if on { enabledTools.insert(tool) } else { enabledTools.remove(tool) }
            }
        )
    }

    private func load() {
        saveError = nil
        guard let companionId else {
            name = ""
            color = "purple"
            rolePrompt = ""
            modelChoice = store.modelChoices.first ?? AppStore.factoryModelChoices[0]
            customModel = ""
            enabledTools = Set(ToolAccess.builtinCapabilityNames)
            return
        }
        guard let companion = try? store.db.companion(id: companionId) else {
            return
        }
        name = companion.name
        color = companion.color
        rolePrompt = companion.rolePrompt
        enabledTools = ToolAccess.parse(toolsJson: companion.toolsJson).capabilities
        if store.modelChoices.contains(companion.model) {
            modelChoice = companion.model
            customModel = ""
        } else {
            modelChoice = Self.customTag
            customModel = companion.model
        }
    }

    private func save() {
        do {
            // M6-D5b：保存永远写显式 v2 列表——打开编辑器保存即视为显式授权
            let toolsJson = ToolAccess.explicitJson(allow: enabledTools)
            if let companionId {
                guard var companion = try store.db.companion(id: companionId) else {
                    saveError = "保存失败：伙伴不存在"
                    return
                }
                companion.name = name
                companion.color = color
                companion.rolePrompt = rolePrompt
                companion.model = resolvedModel
                companion.toolsJson = toolsJson
                try store.db.saveCompanion(companion)
            } else {
                var companion = CompanionRecord.new(
                    name: name,
                    color: color,
                    rolePrompt: rolePrompt,
                    model: resolvedModel
                )
                companion.toolsJson = toolsJson
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
