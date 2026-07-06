import SwiftUI
import AgentLoopCore

/// 笔记/记忆的统一列表模型（营地笔记与伙伴记忆共用一套交互，spec §9-4/§10.1）
struct NoteItem: Identifiable, Equatable {
    enum Source {
        case closeout   // 收营蒸馏
        case manual     // 手记/向导沉淀
        case dm         // 私聊沉淀

        var label: String {
            switch self {
            case .closeout: "收营"
            case .manual: "手记"
            case .dm: "私聊"
            }
        }

        var color: Color {
            switch self {
            case .closeout: Camp.moss
            case .manual: Camp.stone
            case .dm: Camp.amber
            }
        }
    }

    let id: String
    var title: String
    var body: String
    var pinned: Bool
    var source: Source
}

extension NoteItem {
    init(_ record: CampNoteRecord) {
        self.init(
            id: record.id, title: record.title, body: record.bodyMd,
            pinned: record.pinned, source: record.missionId == nil ? .manual : .closeout)
    }

    init(_ record: CompanionNoteRecord) {
        self.init(
            id: record.id, title: record.title, body: record.bodyMd,
            pinned: record.pinned, source: .dm)
    }
}

/// 左笔记本 / 记忆抽屉共用面板：搜索 + 置顶分组 + 行内编辑 + 置顶/删除
struct NoteListPane: View {
    let title: String
    let items: [NoteItem]
    let emptyText: String
    var onSave: (_ id: String, _ title: String, _ body: String) -> Void
    var onTogglePin: (_ id: String) -> Void
    var onDelete: (_ id: String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var query = ""
    @State private var editingItem: NoteItem?
    @State private var pendingDelete: NoteItem?

    private var filtered: [NoteItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(needle)
                || $0.body.localizedCaseInsensitiveContains(needle)
        }
    }

    private var pinnedItems: [NoteItem] { filtered.filter(\.pinned) }
    private var restItems: [NoteItem] { filtered.filter { !$0.pinned } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                Spacer()
                if !items.isEmpty {
                    Text("\(items.count) 条")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().overlay(Camp.line)

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tent")
                        .font(.title2)
                        .foregroundStyle(Camp.stone)
                    Text(emptyText)
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                searchField
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        if !pinnedItems.isEmpty {
                            groupLabel("置顶")
                            ForEach(pinnedItems) { noteRow($0) }
                        }
                        if !restItems.isEmpty {
                            groupLabel(pinnedItems.isEmpty ? "全部" : "其他")
                            ForEach(restItems) { noteRow($0) }
                        }
                        if filtered.isEmpty {
                            Text("没有匹配「\(query)」的笔记")
                                .font(.caption)
                                .foregroundStyle(Camp.inkSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
                    .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: items)
                }
            }
        }
        .background(Camp.surface)
        .confirmationDialog(
            "删除「\(pendingDelete?.title ?? "")」？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let item = pendingDelete { onDelete(item.id) }
                pendingDelete = nil
            }
            Button("再想想", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("删除后不可恢复。")
        }
        .sheet(item: $editingItem) { item in
            NoteEditorSheet(
                item: item,
                onSave: { title, body in
                    onSave(item.id, title, body)
                    editingItem = nil
                },
                onDelete: {
                    onDelete(item.id)
                    editingItem = nil
                },
                onCancel: { editingItem = nil }
            )
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(Camp.inkSecondary)
            TextField("搜索…", text: $query)
                .textFieldStyle(.plain)
                .font(.callout)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Camp.stone)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                .stroke(Camp.line, lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Camp.inkSecondary)
            .padding(.horizontal, 8)
            .padding(.top, 6)
    }

    private func noteRow(_ item: NoteItem) -> some View {
        Button {
            editingItem = item
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if item.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Camp.ember)
                    }
                    Text(item.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Camp.ink)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(item.source.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(item.source.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(item.source.color.opacity(0.13), in: Capsule())
                }
                Text(item.body)
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                .fill(Camp.ember.opacity(editingItem?.id == item.id ? 0.08 : 0))
        )
        .contextMenu {
            Button(item.pinned ? "取消置顶" : "置顶") {
                onTogglePin(item.id)
            }
            Button("编辑…") {
                editingItem = item
            }
            Divider()
            Button("删除…", role: .destructive) {
                pendingDelete = item // 二次确认（UX 审计 P2：沉淀成果不可误删）
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

/// 行内编辑 sheet：标题 + 正文 + 删除
private struct NoteEditorSheet: View {
    let item: NoteItem
    var onSave: (_ title: String, _ body: String) -> Void
    var onDelete: () -> Void
    var onCancel: () -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("编辑笔记")
                    .font(.headline)
                    .foregroundStyle(Camp.ink)
                Spacer()
                Text(item.source.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.source.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(item.source.color.opacity(0.13), in: Capsule())
            }

            TextField("标题", text: $title)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .padding(10)
                .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                        .stroke(Camp.line, lineWidth: 1)
                )

            TextEditor(text: $bodyText)
                .font(.callout)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 180)
                .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                        .stroke(Camp.line, lineWidth: 1)
                )

            HStack {
                if confirmingDelete {
                    Button("确认删除", role: .destructive) {
                        onDelete()
                    }
                    .buttonStyle(CampSecondaryButtonStyle(tint: Camp.charcoalRed))
                    Button("再想想") {
                        confirmingDelete = false
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
                } else {
                    Button("删除") {
                        confirmingDelete = true
                    }
                    .buttonStyle(CampSecondaryButtonStyle(tint: Camp.charcoalRed))
                }
                Spacer()
                Button("取消", action: onCancel)
                    .buttonStyle(CampSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    onSave(title, bodyText)
                }
                .buttonStyle(CampPrimaryButtonStyle(size: .small))
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 460)
        .background(Camp.canvas)
        .onAppear {
            title = item.title
            bodyText = item.body
        }
    }
}
