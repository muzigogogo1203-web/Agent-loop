import SwiftUI

struct CodingRanchOnboardingView: View {
    let cow: CowSummaryViewState
    let modelConnection: ModelConnectionViewState
    var onEnter: () -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 20)
                VStack(spacing: 9) {
                    Image(systemName: "tent.2.fill")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(Camp.ember)
                    Text("Coding 牧场")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Camp.ink)
                    Text("把你读到、想到的东西，喂给一群会干活的牛")
                        .font(.title3)
                        .foregroundStyle(Camp.inkSecondary)
                        .multilineTextAlignment(.center)
                }
                CowSummaryCard(cow: cow)
                    .frame(maxWidth: 520)
                HStack(spacing: 12) {
                    step(number: "1", title: "先喂一条信息", detail: "粘贴文章、资料或想法")
                    Image(systemName: "arrow.right").foregroundStyle(Camp.stone)
                    step(number: "2", title: "再完成一个任务", detail: "确认需求后让基础牛开工")
                }
                .frame(maxWidth: 620)
                modelStatus
                    .frame(maxWidth: 520)
                HStack(spacing: 10) {
                    if modelConnection != .configured {
                        Button("先连接模型", action: onOpenSettings)
                            .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
                    }
                    Button("进入我的营地", action: onEnter)
                        .buttonStyle(CampPrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                }
                Spacer(minLength: 20)
            }
            .frame(maxWidth: 680)
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .background(Camp.canvas)
    }

    private func step(number: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Camp.ember, in: Circle())
            Text(title).font(.callout.weight(.semibold)).foregroundStyle(Camp.ink)
            Text(detail).font(.caption).foregroundStyle(Camp.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .campCard()
    }

    private var modelStatus: some View {
        HStack(spacing: 9) {
            Image(systemName: modelConnection == .configured ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(modelConnection == .configured ? Camp.moss : Camp.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text(modelTitle).font(.callout.weight(.semibold)).foregroundStyle(Camp.ink)
                Text(modelDetail).font(.caption).foregroundStyle(Camp.inkSecondary)
            }
            Spacer()
        }
        .campStatusPanel(modelConnection == .configured ? Camp.moss : Camp.amber)
    }

    private var modelTitle: String {
        switch modelConnection {
        case .configured: "模型已经连接"
        case .missing: "还没有连接模型"
        case .checking: "正在检查模型连接"
        case .failed: "模型连接失败"
        }
    }

    private var modelDetail: String {
        switch modelConnection {
        case .configured: "可以直接进入营地开始喂牛。"
        case .missing: "也可以先进入营地保存资料，稍后再设置。"
        case .checking: "检查完成前仍可进入营地。"
        case .failed(let message): "\(message)。营地已经保留，可以稍后重试。"
        }
    }
}

struct CodingRanchOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        CodingRanchOnboardingView(
            cow: CodingRanchPreviewFixtures.baseCow,
            modelConnection: .missing,
            onEnter: {},
            onOpenSettings: {}
        )
        .frame(width: 760, height: 720)
    }
}
