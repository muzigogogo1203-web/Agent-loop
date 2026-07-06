import SwiftUI
import AgentLoopCore

struct AskUserPromptView: View {
    let request: UserRequestRecord
    var onAnswer: (AskUserAnswer) -> Void
    @State private var text = ""
    @State private var submitted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "hand.raised.fill")
                    .font(.caption)
                    .foregroundStyle(Camp.amber)
                Text(request.prompt)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Camp.ink)
            }
            switch request.kind {
            case .choice:
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        Button {
                            submit(.choice(index))
                        } label: {
                            HStack {
                                Text(option)
                                    .foregroundStyle(Camp.ink)
                                Spacer()
                                Image(systemName: "arrow.forward.circle")
                                    .foregroundStyle(Camp.amber)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                                    .stroke(Camp.line, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(submitted)
                    }
                }
            case .confirm:
                HStack(spacing: 8) {
                    Button("确认") { submit(.confirm(true)) }
                        .buttonStyle(CampPrimaryButtonStyle(size: .small))
                    Button("取消") { submit(.confirm(false)) }
                        .buttonStyle(CampSecondaryButtonStyle())
                }
                .disabled(submitted)
            case .text:
                HStack(spacing: 8) {
                    TextField("输入回复…", text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                                .stroke(Camp.line, lineWidth: 1)
                        )
                        .disabled(submitted)
                        .onSubmit {
                            // 回车提交，对齐 DM/向导输入习惯（UX 审计 P3）
                            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !submitted && !trimmed.isEmpty {
                                submit(.text(text))
                            }
                        }
                    Button {
                        submit(.text(text))
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(CampPrimaryButtonStyle(size: .small))
                    .help("提交回复")
                    .accessibilityLabel("提交回复")
                    .disabled(submitted || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if submitted {
                    Label("已答复，伙伴马上继续", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Camp.moss)
                }
            }
        }
        .padding(11)
        .background(Camp.amber.opacity(0.10), in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                .stroke(Camp.amber.opacity(0.45), lineWidth: 1)
        )
    }

    private var options: [String] {
        guard let optionsJson = request.optionsJson,
              let decoded = try? JSONDecoder().decode([String].self, from: Data(optionsJson.utf8)) else {
            return []
        }
        return decoded
    }

    private func submit(_ answer: AskUserAnswer) {
        submitted = true
        onAnswer(answer)
    }
}
