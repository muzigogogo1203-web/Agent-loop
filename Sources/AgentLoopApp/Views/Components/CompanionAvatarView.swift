import SwiftUI

enum AvatarState {
    case idle
    case thinking
}

struct CompanionAvatarView: View {
    let name: String
    let colorName: String
    var state: AvatarState = .idle
    var size: CGFloat = 26

    private var color: Color {
        switch colorName {
        case "teal": .teal
        case "coral": .orange
        case "pink": .pink
        case "blue": .blue
        case "green": .green
        case "amber": .yellow
        default: .purple
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(color.opacity(0.22))
            Circle()
                .stroke(color.opacity(0.55), lineWidth: 1)
            Text(String(name.prefix(1)))
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(color)
            if state == .thinking {
                Circle()
                    .fill(color)
                    .frame(width: max(4, size * 0.18), height: max(4, size * 0.18))
            }
        }
        .frame(width: size, height: size)
    }
}
