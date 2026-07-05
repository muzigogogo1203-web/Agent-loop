import SwiftUI
import AgentLoopCore

struct AskUserPromptView: View {
    let request: UserRequestRecord
    var onAnswer: (AskUserAnswer) -> Void
    @State private var text = ""
    @State private var submitted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(request.prompt)
                .font(.callout.weight(.medium))
            switch request.kind {
            case .choice:
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Button(option) {
                        submit(.choice(index))
                    }
                    .disabled(submitted)
                }
            case .confirm:
                HStack {
                    Button("确认") { submit(.confirm(true)) }
                    Button("取消") { submit(.confirm(false)) }
                }
                .disabled(submitted)
            case .text:
                HStack {
                    TextField("输入回复", text: $text, axis: .vertical)
                        .lineLimit(1...4)
                        .disabled(submitted)
                    Button {
                        submit(.text(text))
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .help("提交回复")
                    .disabled(submitted || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
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
