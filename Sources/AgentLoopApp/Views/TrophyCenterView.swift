import SwiftUI
import QuickLook
import AgentLoopCore

struct TrophyCenterView: View {
    @Environment(AppStore.self) private var store
    var onOpenMission: (String) -> Void

    @State private var includeArchived = true
    @State private var previewURL: URL?
    @AppStorage("pinnedArtifactIds") private var pinnedArtifactIdsJSON = "[]"

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Camp.line)

            if store.artifactLedgerItems.isEmpty {
                ContentUnavailableView(
                    "还没有回营成果",
                    systemImage: "shippingbox",
                    description: Text("牛完成任务并带回文件后，会在这里按营地和任务归档。")
                )
                .foregroundStyle(Camp.inkSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        if !pinnedItems.isEmpty {
                            pinnedSection
                        }
                        ForEach(campGroups) { campGroup in
                            campSection(campGroup)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 940, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Camp.canvas)
        .quickLookPreview($previewURL)
        .task {
            store.reloadArtifactLedger(includeArchived: includeArchived)
        }
        .onChange(of: includeArchived) { _, value in
            store.reloadArtifactLedger(includeArchived: value)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .foregroundStyle(Camp.ember)
            VStack(alignment: .leading, spacing: 3) {
                Text("回营成果")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Camp.ink)
                Text("跨营地查看、预览和定位基础牛带回的成果")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }
            Spacer()
            if !store.artifactLedgerItems.isEmpty {
                CampChip(
                    text: "\(store.artifactLedgerItems.count) 件",
                    color: Camp.moss,
                    icon: "doc.fill"
                )
            }
            Toggle("包括归档营地", isOn: $includeArchived)
                .toggleStyle(.checkbox)
                .font(.caption)
                .foregroundStyle(Camp.inkSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Camp.surface)
    }

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "pin.fill")
                    .foregroundStyle(Camp.amber)
                CampSectionTitle("钉选")
            }
            VStack(spacing: 0) {
                ForEach(Array(pinnedItems.enumerated()), id: \.element.id) { index, item in
                    artifactRow(item)
                    if index < pinnedItems.count - 1 {
                        Divider().overlay(Camp.line)
                    }
                }
            }
            .background(Camp.surface, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                    .stroke(Camp.line, lineWidth: 1)
            )
        }
    }

    private func campSection(_ group: CampArtifactGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: group.camp.archived ? "archivebox.fill" : "tent.fill")
                    .foregroundStyle(group.camp.archived ? Camp.stone : Camp.ember)
                Text(group.camp.name)
                    .font(.headline)
                    .foregroundStyle(Camp.ink)
                if group.camp.archived {
                    CampChip(text: "归档", color: Camp.stone, icon: "archivebox")
                }
                Spacer()
                Text("\(group.missions.reduce(0) { $0 + $1.items.count }) 件")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }

            ForEach(group.missions) { missionGroup in
                missionSection(missionGroup)
            }
        }
    }

    private func missionSection(_ group: MissionArtifactGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(missionTitle(group.mission))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Camp.ink)
                        .lineLimit(1)
                    Text(group.mission.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(Camp.stone)
                }
                Spacer()
                Button {
                    if let url = store.ensureReport(missionId: group.mission.id) {
                        previewURL = url
                    }
                } label: {
                    Image(systemName: "doc.text")
                }
                .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
                .help("预览回营报告")

                Button {
                    onOpenMission(group.mission.id)
                } label: {
                    Image(systemName: "arrow.right.circle")
                }
                .buttonStyle(CampSecondaryButtonStyle())
                .help("打开放牛任务")
            }
            .padding(12)

            Divider().overlay(Camp.line)

            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                artifactRow(item)
                if index < group.items.count - 1 {
                    Divider().overlay(Camp.line)
                        .padding(.leading, 46)
                }
            }
        }
        .background(Camp.surface, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                .stroke(Camp.line, lineWidth: 1)
        )
    }

    private func artifactRow(_ item: ArtifactLedgerItem) -> some View {
        let url = URL(fileURLWithPath: item.artifact.path)
        let exists = FileManager.default.fileExists(atPath: item.artifact.path)

        return HStack(spacing: 10) {
            Image(systemName: artifactIcon(item.artifact))
                .frame(width: 24, height: 24)
                .foregroundStyle(exists ? Camp.moss : Camp.charcoalRed)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.artifact.label)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Camp.ink)
                    .lineLimit(1)
                Text("\(item.card.title) · \(url.lastPathComponent)")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            if !exists {
                CampChip(text: "文件缺失", color: Camp.charcoalRed, icon: "exclamationmark.triangle.fill")
            }
            Button {
                togglePin(item.id)
            } label: {
                Image(systemName: pinnedIds.contains(item.id) ? "pin.fill" : "pin")
            }
            .buttonStyle(.plain)
            .foregroundStyle(pinnedIds.contains(item.id) ? Camp.amber : Camp.inkSecondary)
            .help(pinnedIds.contains(item.id) ? "取消钉选" : "钉选")

            Button {
                previewURL = url
            } label: {
                Image(systemName: "eye")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Camp.inkSecondary)
            .disabled(!exists)
            .help("快速预览")

            Button {
                store.revealArtifact(item.artifact)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Camp.inkSecondary)
            .disabled(!exists)
            .help("在 Finder 中显示")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
    }

    private var pinnedIds: Set<String> {
        guard let data = pinnedArtifactIdsJSON.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(ids)
    }

    private var pinnedItems: [ArtifactLedgerItem] {
        store.artifactLedgerItems.filter { pinnedIds.contains($0.id) }
    }

    private var campGroups: [CampArtifactGroup] {
        Dictionary(grouping: store.artifactLedgerItems, by: { $0.camp.id })
            .values
            .compactMap { items in
                guard let camp = items.first?.camp else { return nil }
                let missions = Dictionary(grouping: items, by: { $0.mission.id })
                    .values
                    .compactMap { missionItems -> MissionArtifactGroup? in
                        guard let mission = missionItems.first?.mission else { return nil }
                        return MissionArtifactGroup(
                            mission: mission,
                            items: missionItems.sorted { $0.artifact.createdAt > $1.artifact.createdAt }
                        )
                    }
                    .sorted { $0.mission.createdAt > $1.mission.createdAt }
                return CampArtifactGroup(camp: camp, missions: missions)
            }
            .sorted {
                let left = $0.missions.first?.mission.createdAt ?? .distantPast
                let right = $1.missions.first?.mission.createdAt ?? .distantPast
                return left > right
            }
    }

    private func togglePin(_ id: String) {
        var ids = pinnedIds
        if !ids.insert(id).inserted {
            ids.remove(id)
        }
        let sorted = ids.sorted()
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        pinnedArtifactIdsJSON = String(decoding: data, as: UTF8.self)
    }

    private func missionTitle(_ mission: MissionRecord) -> String {
        let refined = mission.goalRefined.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = mission.goalRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = refined.isEmpty ? raw : refined
        return source.split(whereSeparator: \.isNewline).first.map(String.init) ?? "未命名任务"
    }

    private func artifactIcon(_ artifact: ArtifactRecord) -> String {
        switch URL(fileURLWithPath: artifact.path).pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "webp", "heic": return "photo.fill"
        case "pdf": return "doc.richtext.fill"
        case "html", "htm": return "safari.fill"
        case "zip": return "archivebox.fill"
        default: return "doc.fill"
        }
    }
}

private struct CampArtifactGroup: Identifiable {
    var id: String { camp.id }
    let camp: CampRecord
    let missions: [MissionArtifactGroup]
}

private struct MissionArtifactGroup: Identifiable {
    var id: String { mission.id }
    let mission: MissionRecord
    let items: [ArtifactLedgerItem]
}
