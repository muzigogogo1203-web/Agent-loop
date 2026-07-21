import SwiftUI
import AppKit
import AgentLoopCore

/// M10:日程管理(营地内 sheet)——任务模板 + 定时日程 + 立即试跑 + 补跑处理。
struct ScheduleManagerView: View {
    let campId: String
    var onClose: () -> Void

    @Environment(AppStore.self) private var store
    @State private var groups: [ScheduleGroup] = []
    @State private var editingTemplate: TemplateDraft?
    @State private var editingSchedule: ScheduleDraft?
    @State private var deletingTemplate: MissionTemplateRecord?
    @State private var residencyHintVisible = false

    private static let residencyHintShownKey = "scheduleResidencyHintShown"

    struct ScheduleGroup: Identifiable {
        var id: String { template.id }
        let template: MissionTemplateRecord
        let schedules: [ScheduleRecord]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Camp.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    catchupSection
                    if residencyHintVisible { residencyHint }
                    if groups.isEmpty {
                        emptyState
                    } else {
                        ForEach(groups) { group in
                            templateCard(group)
                        }
                    }
                    Text("定时行动仅在 Coding 牧场运行期间生效(包括菜单栏常驻)。")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                }
                .padding(18)
            }
        }
        .frame(minWidth: 560, idealWidth: 640, minHeight: 460, idealHeight: 560)
        .background(Camp.canvas)
        .onAppear(perform: reload)
        .sheet(item: $editingTemplate) { draft in
            TemplateEditorSheet(campId: campId, draft: draft) { record in
                if let record {
                    if let error = store.saveScheduledMissionTemplate(record) {
                        store.showToast("保存模板失败:\(error)")
                    }
                }
                editingTemplate = nil
                reload()
            }
            .environment(store)
        }
        .sheet(item: $editingSchedule) { draft in
            ScheduleEditorSheet(draft: draft) { record in
                if let record {
                    store.saveMissionSchedule(record)
                    if record.enabled { maybeShowResidencyHint() }
                }
                editingSchedule = nil
                scheduleReloadSoon()
            }
        }
        .confirmationDialog(
            "删除模板「\(deletingTemplate?.name ?? "")」?",
            isPresented: Binding(
                get: { deletingTemplate != nil },
                set: { if !$0 { deletingTemplate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除模板与其日程", role: .destructive) {
                if let template = deletingTemplate {
                    store.deleteScheduledMissionTemplate(id: template.id)
                }
                deletingTemplate = nil
                reload()
            }
            Button("再想想", role: .cancel) { deletingTemplate = nil }
        } message: {
            Text("模板下的全部日程会一并删除;已经出发过的行动不受影响。")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(Camp.ember)
            VStack(alignment: .leading, spacing: 2) {
                Text("日程")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                Text("把常干的活存成模板,到点自动放牛")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }
            Spacer()
            Button {
                editingTemplate = TemplateDraft()
            } label: {
                Label("新建模板", systemImage: "plus")
            }
            .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
            Button("完成", action: onClose)
                .buttonStyle(CampPrimaryButtonStyle(size: .small))
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    @ViewBuilder
    private var catchupSection: some View {
        let catchups = store.pendingScheduleCatchups
        if !catchups.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("有日程错过了触发", systemImage: "clock.badge.exclamationmark")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Camp.amber)
                ForEach(catchups) { catchup in
                    HStack(spacing: 8) {
                        Text("\(store.scheduleCatchupTitle(catchup)) · 计划 \(Self.stamp(catchup.fireDate))")
                            .font(.caption)
                            .foregroundStyle(Camp.ink)
                        Spacer()
                        Button("现在补跑") {
                            store.resolveScheduleCatchup(catchup, run: true)
                        }
                        .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
                        Button("跳过") {
                            store.resolveScheduleCatchup(catchup, run: false)
                        }
                        .buttonStyle(CampSecondaryButtonStyle())
                    }
                }
            }
            .campStatusPanel(Camp.amber)
        }
    }

    private var residencyHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "flame")
                .foregroundStyle(Camp.ember)
            Text("想让日程在关窗后也能到点出发?可以开启菜单栏常驻。")
                .font(.caption)
                .foregroundStyle(Camp.ink)
            Spacer()
            Button("开启常驻") {
                (NSApp.delegate as? AppDelegate)?.setMenuBarResidencyEnabled(true)
                dismissResidencyHint()
            }
            .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
            Button("以后再说") { dismissResidencyHint() }
                .buttonStyle(CampSecondaryButtonStyle())
        }
        .campStatusPanel(Camp.ember)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 30))
                .foregroundStyle(Camp.stone)
            Text("还没有任务模板")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Camp.ink)
            Text("先把一件常干的活(比如每日晨报)存成模板,再给它定个时间。")
                .font(.caption)
                .foregroundStyle(Camp.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .campCard()
    }

    private func templateCard(_ group: ScheduleGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.template.name)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Camp.ink)
                    Text(group.template.goal)
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                        .lineLimit(2)
                }
                Spacer()
                CampChip(
                    text: "\((group.template.budgetTokens ?? 0) / 1000)k 预算",
                    color: Camp.moss,
                    icon: "creditcard"
                )
                CampChip(
                    text: group.template.autonomy.displayName,
                    color: Camp.stone,
                    icon: "shield"
                )
            }
            if group.schedules.isEmpty {
                Text("还没有日程——加一个,到点自动出发。")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            } else {
                ForEach(group.schedules, id: \.id) { schedule in
                    scheduleRow(schedule, template: group.template)
                }
            }
            HStack(spacing: 8) {
                Button {
                    editingSchedule = ScheduleDraft(templateId: group.template.id)
                } label: {
                    Label("添加日程", systemImage: "clock.badge.plus")
                }
                .buttonStyle(CampSecondaryButtonStyle())
                Button {
                    editingTemplate = TemplateDraft(record: group.template)
                } label: {
                    Label("编辑模板", systemImage: "square.and.pencil")
                }
                .buttonStyle(CampSecondaryButtonStyle())
                Spacer()
                Button(role: .destructive) {
                    deletingTemplate = group.template
                } label: {
                    Label("删除", systemImage: "trash")
                }
                .buttonStyle(CampSecondaryButtonStyle(tint: Camp.charcoalRed))
            }
        }
        .campCard()
    }

    private func scheduleRow(_ schedule: ScheduleRecord, template: MissionTemplateRecord) -> some View {
        HStack(spacing: 10) {
            Image(systemName: schedule.enabled ? "clock.fill" : "clock")
                .foregroundStyle(schedule.enabled ? Camp.ember : Camp.stone)
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.describe(schedule))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                Text(nextFireText(schedule))
                    .font(.caption2)
                    .foregroundStyle(Camp.inkSecondary)
            }
            Spacer()
            Button("立即试跑") {
                store.runScheduleNow(id: schedule.id)
            }
            .buttonStyle(CampSecondaryButtonStyle())
            .disabled(!schedule.enabled)
            .help(schedule.enabled ? "现在按这个模板出发一次" : "先启用日程才能试跑")
            Toggle("", isOn: Binding(
                get: { schedule.enabled },
                set: { enabled in
                    store.setMissionScheduleEnabled(id: schedule.id, enabled: enabled)
                    if enabled { maybeShowResidencyHint() }
                    scheduleReloadSoon()
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            Button {
                store.deleteMissionSchedule(id: schedule.id)
                reload()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Camp.stone)
            .help("删除这条日程")
        }
        .padding(.vertical, 4)
    }

    private func reload() {
        groups = store.scheduleGroups(campId: campId).map {
            ScheduleGroup(template: $0.template, schedules: $0.schedules)
        }
    }

    /// 门面方法内部是异步落库;稍等一拍再刷新列表,避免读到旧值。
    private func scheduleReloadSoon() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            reload()
        }
    }

    private func maybeShowResidencyHint() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.residencyHintShownKey),
              (NSApp.delegate as? AppDelegate)?.menuBarResidencyEnabled != true else { return }
        residencyHintVisible = true
    }

    private func dismissResidencyHint() {
        UserDefaults.standard.set(true, forKey: Self.residencyHintShownKey)
        residencyHintVisible = false
    }

    private func nextFireText(_ schedule: ScheduleRecord) -> String {
        guard schedule.enabled else { return "已停用" }
        guard let next = ScheduleMath.nextFireDate(
            after: Date(),
            frequency: schedule.frequency,
            hour: schedule.hour,
            minute: schedule.minute,
            weekday: schedule.weekday,
            calendar: Calendar(identifier: .gregorian),
            timeZone: .current
        ) else { return "时间设置无效" }
        return "下次:\(Self.stamp(next))"
    }

    static func describe(_ schedule: ScheduleRecord) -> String {
        let time = String(format: "%02d:%02d", schedule.hour, schedule.minute)
        switch schedule.frequency {
        case .daily: return "每天 \(time)"
        case .weekly: return "每\(weekdayName(schedule.weekday ?? 2)) \(time)"
        }
    }

    static func weekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: "周日"
        case 2: "周一"
        case 3: "周二"
        case 4: "周三"
        case 5: "周四"
        case 6: "周五"
        case 7: "周六"
        default: "周?"
        }
    }

    static func stamp(_ date: Date) -> String {
        date.formatted(date: .numeric, time: .shortened)
    }
}

// MARK: - 模板编辑

struct TemplateDraft: Identifiable {
    var id: String
    var name = ""
    var goal = ""
    var companionId = ""
    var budgetText = "\(KernelDefaults.missionBudget)"
    var autonomy: MissionAutonomy = .standard
    var workspacePath = ""
    var isNew: Bool

    init() {
        id = UUID().uuidString
        isNew = true
    }

    init(record: MissionTemplateRecord) {
        id = record.id
        name = record.name
        goal = record.goal
        companionId = (try? record.companionIds().first) ?? ""
        budgetText = "\(record.budgetTokens ?? KernelDefaults.missionBudget)"
        autonomy = record.autonomy
        workspacePath = record.workspacePath ?? ""
        isNew = false
    }
}

private struct TemplateEditorSheet: View {
    let campId: String
    @State var draft: TemplateDraft
    var onFinish: (MissionTemplateRecord?) -> Void

    @Environment(AppStore.self) private var store
    @State private var validationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(draft.isNew ? "新建任务模板" : "编辑任务模板")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Camp.ink)

            VStack(alignment: .leading, spacing: 6) {
                CampSectionTitle("名字")
                TextField("比如:每日晨报", text: $draft.name)
                    .textFieldStyle(.plain)
                    .campFieldChrome()
            }

            VStack(alignment: .leading, spacing: 6) {
                CampSectionTitle("目标")
                TextEditor(text: $draft.goal)
                    .font(.callout)
                    .frame(minHeight: 84, maxHeight: 140)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                            .stroke(Camp.line, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                CampSectionTitle("负责的牛")
                Picker("负责的牛", selection: $draft.companionId) {
                    ForEach(campCompanions, id: \.id) { companion in
                        Text(companion.name).tag(companion.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    CampSectionTitle("预算(tokens,必填)")
                    TextField("如 200000", text: $draft.budgetText)
                        .textFieldStyle(.plain)
                        .campFieldChrome()
                        .frame(width: 140)
                }
                VStack(alignment: .leading, spacing: 6) {
                    CampSectionTitle("自主档位")
                    Picker("自主档位", selection: $draft.autonomy) {
                        // D2:无人值守双保险——放手档模板不允许
                        Text(MissionAutonomy.careful.displayName).tag(MissionAutonomy.careful)
                        Text(MissionAutonomy.standard.displayName).tag(MissionAutonomy.standard)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 220)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                CampSectionTitle("工作目录(可选)")
                HStack(spacing: 8) {
                    TextField("留空 = 使用暂存区", text: $draft.workspacePath)
                        .textFieldStyle(.plain)
                        .campFieldChrome()
                    Button("选择…") { pickFolder() }
                        .buttonStyle(CampSecondaryButtonStyle())
                }
            }

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Camp.charcoalRed)
            }

            HStack {
                Spacer()
                Button("取消") { onFinish(nil) }
                    .buttonStyle(CampSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .buttonStyle(CampPrimaryButtonStyle(size: .small))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 520, idealWidth: 560)
        .background(Camp.canvas)
        .onAppear {
            if draft.companionId.isEmpty {
                draft.companionId = campCompanions.first?.id ?? ""
            }
        }
    }

    private var campCompanions: [CompanionRecord] {
        store.companions.filter { $0.campId == campId || $0.campId == nil }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            draft.workspacePath = url.path
        }
    }

    private func save() {
        let budget = Int(draft.budgetText.trimmingCharacters(in: .whitespaces))
        do {
            let record: MissionTemplateRecord
            if draft.isNew {
                record = try MissionTemplateRecord.new(
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    goal: draft.goal.trimmingCharacters(in: .whitespacesAndNewlines),
                    companionIds: draft.companionId.isEmpty ? [] : [draft.companionId],
                    workspacePath: draft.workspacePath.isEmpty ? nil : draft.workspacePath,
                    budgetTokens: budget,
                    autonomy: draft.autonomy,
                    campId: campId
                )
            } else {
                record = MissionTemplateRecord(
                    id: draft.id,
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    goal: draft.goal.trimmingCharacters(in: .whitespacesAndNewlines),
                    companionIdsJson: try MissionTemplateRecord.companionIdsJSON(
                        draft.companionId.isEmpty ? [] : [draft.companionId]
                    ),
                    workspacePath: draft.workspacePath.isEmpty ? nil : draft.workspacePath,
                    budgetTokens: budget,
                    autonomy: draft.autonomy,
                    campId: campId,
                    createdAt: Date()
                )
            }
            _ = try record.validateForScheduledMission()
            onFinish(record)
        } catch {
            validationMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}

// MARK: - 日程编辑

struct ScheduleDraft: Identifiable {
    var id: String
    var templateId: String
    var frequency: ScheduleFrequency = .daily
    var weekday = 2
    var time = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    var enabled = true

    init(templateId: String) {
        id = UUID().uuidString
        self.templateId = templateId
    }
}

private struct ScheduleEditorSheet: View {
    @State var draft: ScheduleDraft
    var onFinish: (ScheduleRecord?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("添加日程")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Camp.ink)

            VStack(alignment: .leading, spacing: 6) {
                CampSectionTitle("频率")
                Picker("频率", selection: $draft.frequency) {
                    Text("每天").tag(ScheduleFrequency.daily)
                    Text("每周").tag(ScheduleFrequency.weekly)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 200)
            }

            if draft.frequency == .weekly {
                VStack(alignment: .leading, spacing: 6) {
                    CampSectionTitle("星期几")
                    Picker("星期几", selection: $draft.weekday) {
                        ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                            Text(ScheduleManagerView.weekdayName(day)).tag(day)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 140)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                CampSectionTitle("时间")
                DatePicker("时间", selection: $draft.time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }

            Toggle("立即启用", isOn: $draft.enabled)
                .toggleStyle(.switch)

            HStack {
                Spacer()
                Button("取消") { onFinish(nil) }
                    .buttonStyle(CampSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    let components = Calendar.current.dateComponents([.hour, .minute], from: draft.time)
                    onFinish(ScheduleRecord.new(
                        templateId: draft.templateId,
                        frequency: draft.frequency,
                        hour: components.hour ?? 9,
                        minute: components.minute ?? 0,
                        weekday: draft.frequency == .weekly ? draft.weekday : nil,
                        enabled: draft.enabled
                    ))
                }
                .buttonStyle(CampPrimaryButtonStyle(size: .small))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
        .background(Camp.canvas)
    }
}

private extension View {
    func campFieldChrome() -> some View {
        padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                    .stroke(Camp.line, lineWidth: 1)
            )
    }
}
