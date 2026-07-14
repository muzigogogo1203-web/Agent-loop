import SwiftUI
import AgentLoopCore

/// 营地首页（spec §11 一等界面）：左营地笔记本 + 右向导常驻对话。
struct CampHomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let campId: String
    var onEditGuide: () -> Void = {}
    var onNewMission: () -> Void = {}
    var onOpenMission: (String) -> Void = { _ in }
    @State private var notesPaneVisible = true
    @State private var renaming = false
    @State private var renameText = ""
    @State private var enabledStations: Set<String> = []
    @State private var showingScheduleEditor = false

    var body: some View {
        GeometryReader { proxy in
            // 窄窗口自动收起笔记本（m3.3 宽度自适应规则），用户偏好与自动收起互不覆盖。
            // 量的是 detail 区宽度（不含侧栏）：340 笔记本 + ≥400 向导对话 + 间距。
            let tooNarrowForNotes = proxy.size.width < 780
            let showNotes = notesPaneVisible && !tooNarrowForNotes

            VStack(alignment: .leading, spacing: 12) {
                header(notesVisible: showNotes, notesLocked: tooNarrowForNotes)

                HStack(alignment: .top, spacing: 14) {
                    if showNotes {
                        ScrollView {
                            VStack(spacing: 10) {
                                notesPane
                                    .frame(minHeight: 240, idealHeight: 300, maxHeight: max(260, proxy.size.height * 0.42))
                                schedulesPane
                                stationsPane
                                pastMissionsPane
                            }
                            .padding(.vertical, 1)
                        }
                        .frame(width: 340)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    GuideChatColumn(onEditGuide: onEditGuide)
                        .clipShape(RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                                .stroke(Camp.line, lineWidth: 1)
                        )
                }
            }
            .padding(16)
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: showNotes)
        }
        .background(Camp.canvas)
        .task(id: campId) {
            store.loadCampHome(campId: campId)
        }
        .alert("重命名营地", isPresented: $renaming) {
            TextField("营地名字", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("确定") {
                store.renameCamp(id: campId, name: renameText)
            }
        }
        .sheet(isPresented: $showingScheduleEditor) {
            ScheduleEditorSheet(campId: campId) {
                showingScheduleEditor = false
            }
        }
    }

    private var notesPane: some View {
        NoteListPane(
                            title: "营地笔记",
                            items: store.campNotes.map(NoteItem.init),
                            emptyText: "还没有营地笔记——收营后会自动沉淀，或让向导帮你记。",
                            onSave: { id, title, body in
                                guard var record = store.campNotes.first(where: { $0.id == id }) else { return }
                                record.title = title
                                record.bodyMd = body
                                store.saveCampNoteEdits(record)
                            },
                            onTogglePin: { id in
                                guard let record = store.campNotes.first(where: { $0.id == id }) else { return }
                                store.toggleCampNotePin(record)
                            },
                            onDelete: { store.deleteCampNote(id: $0) }
                        )
        .clipShape(RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .stroke(Camp.line, lineWidth: 1)
        )
    }

    private var schedulesPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.caption)
                    .foregroundStyle(Camp.ember)
                Text("日程")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Camp.inkSecondary)
                Spacer()
                Button {
                    showingScheduleEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(CampSecondaryButtonStyle())
                .help("新增定时行动")
            }

            if store.campSchedules.isEmpty {
                Text("还没有点亮日程")
                    .font(.caption)
                    .foregroundStyle(Camp.stone)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 7) {
                    ForEach(store.campSchedules) { scheduled in
                        scheduleRow(scheduled)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .padding(10)
        .background(Camp.surface, in: RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .stroke(Camp.line, lineWidth: 1)
        )
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: store.campSchedules.count)
    }

    private func scheduleRow(_ scheduled: ScheduledMissionRecord) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { scheduled.schedule.enabled },
                    set: { store.setScheduleEnabled(id: scheduled.schedule.id, enabled: $0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(0.75)

                VStack(alignment: .leading, spacing: 3) {
                    Text(scheduled.template.name)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Camp.ink)
                        .lineLimit(1)
                    Text(scheduled.template.goal)
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                Menu {
                    Button {
                        store.runScheduleNow(id: scheduled.schedule.id)
                    } label: {
                        Label("立即出发", systemImage: "play.fill")
                    }
                    Button(role: .destructive) {
                        store.deleteSchedule(id: scheduled.schedule.id)
                    } label: {
                        Label("删除日程", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Camp.inkSecondary)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                CampChip(text: store.scheduleCaption(scheduled), color: Camp.ember, icon: "clock")
                CampChip(text: "预算 \(Self.compactTokens(scheduled.template.budgetTokens))", color: Camp.stone)
                CampChip(text: scheduled.template.autonomy.displayName, color: Camp.amber, icon: "shield.lefthalf.filled")
            }

            HStack(spacing: 6) {
                HStack(spacing: -6) {
                    ForEach(companions(for: scheduled), id: \.id) { companion in
                        CompanionAvatarView(name: companion.name, colorName: companion.color, size: 20)
                            .background(Circle().fill(Camp.surface).padding(-2))
                    }
                }
                Text("下次 \(store.nextScheduleCaption(scheduled))")
                    .font(.caption2)
                    .foregroundStyle(scheduled.schedule.enabled ? Camp.inkSecondary : Camp.stone)
                    .lineLimit(1)
                Spacer()
            }
        }
        .padding(9)
        .background(
            scheduled.schedule.enabled ? Camp.surfaceRaised : Camp.surfaceRaised.opacity(0.45),
            in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                .stroke(scheduled.schedule.enabled ? Camp.ember.opacity(0.28) : Camp.line, lineWidth: 1)
        )
        .opacity(scheduled.schedule.enabled ? 1 : 0.72)
    }

    private func companions(for scheduled: ScheduledMissionRecord) -> [CompanionRecord] {
        let ids = (try? JSONDecoder().decode([String].self, from: Data(scheduled.template.companionIdsJson.utf8))) ?? []
        return ids.compactMap { id in store.companions.first { $0.id == id } }
    }

    /// 启用的驿站（M8-D7）：全局注册的 MCP server 按营地勾选启用；
    /// 启用只是「本营地行动可见」，伙伴还需在编辑器里显式勾选工具。
    @ViewBuilder private var stationsPane: some View {
        if !store.mcp.servers.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                    Text("驿站")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Camp.inkSecondary)
                    Spacer()
                    Text("\(enabledStations.count)/\(store.mcp.servers.count) 启用")
                        .font(.caption2)
                        .foregroundStyle(Camp.stone)
                }
                ForEach(store.mcp.servers, id: \.id) { server in
                    Toggle(isOn: stationBinding(server.id)) {
                        HStack(spacing: 5) {
                            Text(server.name)
                                .font(.caption.monospaced())
                                .foregroundStyle(Camp.ink)
                            if server.experimental {
                                Image(systemName: "flask")
                                    .font(.caption2)
                                    .foregroundStyle(Camp.amber)
                            }
                        }
                    }
                    .toggleStyle(.checkbox)
                }
                Text("启用后，本营地行动派发时会拉起驿站；工具还需在伙伴编辑器里按人勾选。")
                    .font(.caption2)
                    .foregroundStyle(Camp.stone)
            }
            .padding(10)
            .background(Camp.surface, in: RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                    .stroke(Camp.line, lineWidth: 1)
            )
            .task(id: campId) {
                enabledStations = store.mcp.enabledServerIds(campId: campId)
            }
        }
    }

    private func stationBinding(_ serverId: String) -> Binding<Bool> {
        Binding(
            get: { enabledStations.contains(serverId) },
            set: { enabled in
                store.mcp.setEnabled(campId: campId, serverId: serverId, enabled: enabled)
                enabledStations = store.mcp.enabledServerIds(campId: campId)
            }
        )
    }

    /// 往期行动收进营地首页（C1）：侧栏只留进行中
    @ViewBuilder private var pastMissionsPane: some View {
        let past = (store.missionsByCamp[campId] ?? [])
            .filter { $0.status == .accepted || $0.status == .failed }
        if !past.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "shippingbox")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                    Text("往期行动")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Camp.inkSecondary)
                    Spacer()
                    Text("\(past.count)")
                        .font(.caption2)
                        .foregroundStyle(Camp.stone)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(past, id: \.id) { mission in
                            Button {
                                onOpenMission(mission.id)
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(mission.status == .accepted ? Camp.moss : Camp.stone)
                                        .frame(width: 6, height: 6)
                                    Text(Self.missionLine(mission))
                                        .font(.caption)
                                        .foregroundStyle(Camp.ink)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.vertical, 3)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
            .padding(10)
            .background(Camp.surface, in: RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                    .stroke(Camp.line, lineWidth: 1)
            )
        }
    }

    private static func missionLine(_ mission: MissionRecord) -> String {
        let refined = mission.goalRefined.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = mission.goalRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = refined.isEmpty ? raw : refined
        return String((base.split(whereSeparator: \.isNewline).first.map(String.init) ?? base).prefix(24))
    }

    private static func compactTokens(_ value: Int) -> String {
        value >= 1000 ? "\(value / 1000)k" : "\(value)"
    }

    private func header(notesVisible: Bool, notesLocked: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "tent.fill")
                        .foregroundStyle(Camp.ember)
                    Text(store.campName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Camp.ink)
                }
                .contextMenu {
                    Button("重命名营地…") {
                        renameText = store.campName
                        renaming = true
                    }
                }
                Text("行动的经验和向导都在这儿")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }
            Spacer()
            Button {
                onNewMission()
            } label: {
                Label("新行动", systemImage: "flag.fill")
            }
            .buttonStyle(CampPrimaryButtonStyle(size: .small))

            Button {
                notesPaneVisible.toggle()
            } label: {
                Image(systemName: notesVisible ? "sidebar.leading" : "book.closed")
                    .foregroundStyle(notesVisible ? Camp.inkSecondary : Camp.ember)
            }
            .buttonStyle(CampSecondaryButtonStyle())
            .disabled(notesLocked)
            .help(notesLocked ? "窗口太窄，加宽窗口后可展开笔记本" : (notesVisible ? "收起笔记本" : "展开笔记本"))

            if let guide = store.guideCompanion {
                CompanionAvatarView(
                    name: guide.name,
                    colorName: guide.color,
                    state: guideAnimState,
                    size: 34
                )
                .contextMenu {
                    Button("编辑向导…", action: onEditGuide)
                }
            }
        }
        .campCard(padding: 12)
    }

    private var guideAnimState: CompanionAnimState {
        if store.guideToolActivity != nil { return .working }
        if store.guideStreaming { return .thinking }
        return .idle
    }
}

// MARK: - 长明火日程

private struct ScheduleEditorSheet: View {
    @Environment(AppStore.self) private var store
    let campId: String
    var onClose: () -> Void

    @State private var name = "每日晨报"
    @State private var goal = ""
    @State private var workspacePath = ""
    @State private var budgetText = ""
    @State private var autonomy: MissionAutonomy = .standard
    @State private var frequency: ScheduleFrequency = .daily
    @State private var weekday = Calendar.current.component(.weekday, from: Date())
    @State private var time = Date()
    @State private var selectedCompanionIds: Set<String> = []
    @State private var errorText: String?

    private let allowedAutonomies: [MissionAutonomy] = [.careful, .standard]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            VStack(alignment: .leading, spacing: 12) {
                TextField("日程名", text: $name)
                    .textFieldStyle(.plain)
                    .font(.title3.weight(.semibold))
                    .padding(11)
                    .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                    .overlay(fieldStroke)

                TextEditor(text: $goal)
                    .font(.callout)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 86)
                    .padding(8)
                    .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                    .overlay(fieldStroke)

                TextField("工作目录（可选）", text: $workspacePath)
                    .textFieldStyle(.plain)
                    .font(.body.monospaced())
                    .padding(10)
                    .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                    .overlay(fieldStroke)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    CampSectionTitle("节奏")
                    Picker("频率", selection: $frequency) {
                        ForEach(ScheduleFrequency.allCases, id: \.self) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    if frequency == .weekly {
                        Picker("星期", selection: $weekday) {
                            ForEach(1...7, id: \.self) { day in
                                Text(AppStore.weekdayName(day)).tag(day)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    DatePicker("时间", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 10) {
                    CampSectionTitle("保险")
                    HStack(spacing: 8) {
                        TextField("\(store.defaultMissionBudget)", text: $budgetText)
                            .textFieldStyle(.plain)
                            .font(.body.monospaced())
                            .frame(width: 110)
                            .padding(9)
                            .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                            .overlay(fieldStroke)
                        Text("tokens")
                            .font(.caption)
                            .foregroundStyle(Camp.inkSecondary)
                    }
                    Picker("自主档位", selection: $autonomy) {
                        ForEach(allowedAutonomies, id: \.self) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            companionPicker

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Camp.charcoalRed)
            }

            HStack {
                Spacer()
                Button("取消", action: onClose)
                    .buttonStyle(CampSecondaryButtonStyle())
                Button {
                    save()
                } label: {
                    Label("点亮日程", systemImage: "flame.fill")
                }
                .buttonStyle(CampPrimaryButtonStyle(size: .small))
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
            }
        }
        .padding(20)
        .frame(width: 560)
        .background(Camp.canvas)
        .onAppear {
            if budgetText.isEmpty {
                budgetText = String(store.defaultMissionBudget)
            }
            if selectedCompanionIds.isEmpty, let first = store.companions.first {
                selectedCompanionIds.insert(first.id)
            }
            if goal.isEmpty {
                goal = "整理今天需要关注的进展，产出一份晨报。"
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .foregroundStyle(Camp.ember)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text("点亮日程")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                Text("固定预算、固定小队、固定节奏。")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }
            Spacer()
        }
    }

    private var companionPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            CampSectionTitle("小队")
            if store.companions.isEmpty {
                HStack(spacing: 10) {
                    Text("还没有可派出的伙伴")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                    Spacer()
                    Button {
                        store.seedStarterCompanions(campId: campId)
                        selectedCompanionIds = Set(store.companions.prefix(1).map(\.id))
                    } label: {
                        Label("创建预设伙伴", systemImage: "person.2.badge.plus")
                    }
                    .buttonStyle(CampSecondaryButtonStyle())
                }
                .padding(10)
                .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                .overlay(fieldStroke)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(store.companions, id: \.id) { companion in
                        Toggle(isOn: companionBinding(companion.id)) {
                            HStack(spacing: 8) {
                                CompanionAvatarView(name: companion.name, colorName: companion.color, size: 24)
                                Text(companion.name)
                                    .lineLimit(1)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .padding(8)
                        .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                                .stroke(selectedCompanionIds.contains(companion.id) ? Camp.ember.opacity(0.45) : Camp.line, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private var fieldStroke: some View {
        RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
            .stroke(Camp.line, lineWidth: 1)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedCompanionIds.isEmpty
            && (Int(budgetText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) > 0
    }

    private func companionBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { selectedCompanionIds.contains(id) },
            set: { enabled in
                if enabled {
                    selectedCompanionIds.insert(id)
                } else {
                    selectedCompanionIds.remove(id)
                }
            }
        )
    }

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let budget = Int(budgetText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        errorText = store.createScheduledMission(
            name: name,
            goal: goal,
            companionIds: Array(selectedCompanionIds),
            workspacePath: workspacePath,
            budgetTokens: budget,
            autonomy: autonomy,
            campId: campId,
            frequency: frequency,
            hour: components.hour ?? 8,
            minute: components.minute ?? 0,
            weekday: frequency == .weekly ? weekday : nil
        )
        if errorText == nil {
            onClose()
        }
    }
}

// MARK: - 向导对话列

private struct GuideChatColumn: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onEditGuide: () -> Void
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if store.guideMessages.isEmpty && store.guideStreamingText == nil {
                            emptyOpening
                        }
                        ForEach(store.guideMessages) { message in
                            guideRow(message)
                                .id(message.id)
                        }
                        if let activity = store.guideToolActivity {
                            toolActivityLine(activity)
                                .id("tool-activity")
                        }
                        if let streaming = store.guideStreamingText {
                            streamingBubble(streaming)
                                .id("streaming")
                        }
                    }
                    .padding(14)
                    .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: store.guideMessages.count)
                }
                .onChange(of: scrollAnchor) { _, anchor in
                    proxy.scrollTo(anchor, anchor: .bottom)
                }
                // 流式增量跟随（UX 审计 P2）
                .onChange(of: store.guideStreamingText) { _, _ in
                    if store.guideStreaming {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }

            Divider().overlay(Camp.line)

            HStack(spacing: 8) {
                Button {
                    store.distillGuideChatNow()
                } label: {
                    if store.distillingGuideChat {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("沉淀笔记", systemImage: "sparkles")
                    }
                }
                .buttonStyle(CampSecondaryButtonStyle(tint: Camp.amber))
                .disabled(store.distillingGuideChat)
                .help("把这段对话里值得记的内容沉淀为营地笔记")

                TextField("跟\(store.guideCompanion?.name ?? "向导")说点什么…", text: $input)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                            .stroke(Camp.line, lineWidth: 1)
                    )
                    .onSubmit(send)
                if store.guideStreaming {
                    Button("停止") { store.stopGuideChat() }
                        .buttonStyle(CampSecondaryButtonStyle(tint: Camp.charcoalRed))
                        .keyboardShortcut(.cancelAction)
                } else {
                    Button("发送", action: send)
                        .buttonStyle(CampPrimaryButtonStyle(size: .small))
                        .disabled(input.isEmpty)
                        .opacity(input.isEmpty ? 0.5 : 1)
                }
            }
            .padding(10)
            .background(Camp.surface)
        }
        .background(Camp.surface)
    }

    private var scrollAnchor: String {
        if store.guideStreamingText != nil { return "streaming" }
        if store.guideToolActivity != nil { return "tool-activity" }
        return store.guideMessages.last?.id ?? ""
    }

    private func send() {
        guard !input.isEmpty, !store.guideStreaming else { return }
        store.sendGuideChat(text: input)
        input = ""
    }

    private var emptyOpening: some View {
        HStack(alignment: .top, spacing: 8) {
            guideAvatar(state: .idle)
            Text("我是这营地的向导。想了解营地情况、翻往期笔记，或者组队出发，都可以找我。")
                .font(.callout)
                .foregroundStyle(Camp.inkSecondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(Camp.surface, in: guideBubbleShape)
                .overlay(guideBubbleShape.stroke(Camp.line, lineWidth: 1))
            Spacer(minLength: 40)
        }
    }

    @ViewBuilder private func guideRow(_ message: AppStore.GuideMessage) -> some View {
        if let proposal = message.proposal {
            ProposalCardView(
                messageId: message.id,
                proposal: proposal,
                confirming: store.confirmingProposals.contains(message.id)
            )
            .padding(.leading, 34)
        } else if message.role == "user" {
            HStack(alignment: .top, spacing: 8) {
                Spacer(minLength: 40)
                Text(message.text)
                    .textSelection(.enabled)
                    .foregroundStyle(Camp.ink)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Camp.ember.opacity(0.14), in: UnevenRoundedRectangle(
                        topLeadingRadius: 12, bottomLeadingRadius: 12,
                        bottomTrailingRadius: 4, topTrailingRadius: 12, style: .continuous
                    ))
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                guideAvatar(state: .idle)
                Text(message.text)
                    .textSelection(.enabled)
                    .foregroundStyle(Camp.ink)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Camp.surface, in: guideBubbleShape)
                    .overlay(guideBubbleShape.stroke(Camp.line, lineWidth: 1))
                Spacer(minLength: 40)
            }
        }
    }

    private func streamingBubble(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            guideAvatar(state: .thinking)
            Group {
                if text.isEmpty {
                    TypingIndicatorView()
                } else {
                    Text(text)
                        .foregroundStyle(Camp.ink)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Camp.surface, in: guideBubbleShape)
            .overlay(guideBubbleShape.stroke(Camp.line, lineWidth: 1))
            Spacer(minLength: 40)
        }
    }

    private func toolActivityLine(_ activity: String) -> some View {
        HStack(spacing: 6) {
            TypingIndicatorView()
            Text(activity)
                .font(.caption)
                .foregroundStyle(Camp.inkSecondary)
        }
        .padding(.leading, 34)
    }

    private func guideAvatar(state: CompanionAnimState) -> some View {
        CompanionAvatarView(
            name: store.guideCompanion?.name ?? "向导",
            colorName: store.guideCompanion?.color ?? "amber",
            state: state,
            size: 26
        )
    }

    private var guideBubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 4, bottomLeadingRadius: 12,
            bottomTrailingRadius: 12, topTrailingRadius: 12, style: .continuous
        )
    }
}

// MARK: - 组队提案卡片（spec §10.2 确认卡片）

struct ProposalCardView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let messageId: String
    let proposal: SquadProposalBlock
    let confirming: Bool
    @State private var appeared = false

    private var members: [CompanionRecord] {
        proposal.memberIds.compactMap { id in
            store.companions.first { $0.id == id }
        }
    }

    private var hasGhostMembers: Bool {
        members.count != proposal.memberIds.count
    }

    private var borderColor: Color {
        switch proposal.status {
        case .pending: Camp.amber.opacity(0.75)
        case .confirmed: Camp.moss.opacity(0.65)
        case .dismissed: Camp.line
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(Camp.ember)
                Text("组队提案 · \(proposal.name)")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                Spacer()
                statusTag
            }

            Text("目标：\(proposal.goal)")
                .font(.callout)
                .foregroundStyle(Camp.ink)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                HStack(spacing: -6) {
                    ForEach(members, id: \.id) { member in
                        CompanionAvatarView(name: member.name, colorName: member.color, size: 24)
                            .background(Circle().fill(Camp.surface).padding(-2))
                    }
                }
                Text(memberLine)
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
                    .lineLimit(1)
                Spacer()
                if let budget = proposal.budget {
                    CampChip(text: "预算 \(Self.compactTokens(budget))", color: Camp.stone)
                }
            }

            footer
        }
        .padding(13)
        .background(Camp.surface, in: RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Camp.cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: proposal.status == .pending ? 1.5 : 1)
        )
        .opacity(proposal.status == .dismissed ? 0.6 : 1)
        .frame(maxWidth: 460, alignment: .leading)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.96)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
                appeared = true
            }
        }
    }

    @ViewBuilder private var statusTag: some View {
        switch proposal.status {
        case .pending:
            CampChip(text: "等你拿主意", color: Camp.amber)
        case .confirmed:
            CampChip(text: "已开工", color: Camp.moss, icon: "checkmark")
        case .dismissed:
            CampChip(text: "已搁置", color: Camp.stone)
        }
    }

    private var memberLine: String {
        var line = members.map(\.name).joined(separator: "、")
        if hasGhostMembers {
            line += line.isEmpty ? "有成员已不在名册" : "（有成员已不在名册）"
        }
        return line
    }

    @ViewBuilder private var footer: some View {
        switch proposal.status {
        case .pending:
            HStack(spacing: 8) {
                Button {
                    store.confirmProposal(messageId: messageId)
                } label: {
                    if confirming {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Label("就这么办", systemImage: "flame.fill")
                    }
                }
                .buttonStyle(CampPrimaryButtonStyle(size: .small))
                .disabled(confirming || hasGhostMembers)
                .opacity(hasGhostMembers ? 0.5 : 1)
                .help(hasGhostMembers ? "提案里有已删除的伙伴，无法开工" : "确认后立即建队开工")

                Button("先不") {
                    store.dismissProposal(messageId: messageId)
                }
                .buttonStyle(CampSecondaryButtonStyle())
                .disabled(confirming)
            }
        case .confirmed:
            if let missionId = proposal.missionId {
                Button {
                    store.navigateToMissionId = missionId
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                        Text("已开工 · 去看看")
                        Image(systemName: "arrow.right")
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Camp.moss)
                }
                .buttonStyle(.plain)
            } else {
                Text("已开工")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Camp.moss)
            }
        case .dismissed:
            EmptyView()
        }
    }

    private static func compactTokens(_ value: Int) -> String {
        value >= 1000 ? "\(value / 1000)k" : "\(value)"
    }
}
