import SwiftUI
import Foundation

enum AvatarState {
    case idle
    case thinking
}

struct CompanionAvatarView: View {
    let name: String
    let colorName: String
    var state: AvatarState = .idle
    var size: CGFloat = 26
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let palette: [String: Color] = [
        "purple": Color(red: 0.33, green: 0.29, blue: 0.72),
        "teal": Color(red: 0.11, green: 0.62, blue: 0.46),
        "coral": Color(red: 0.85, green: 0.35, blue: 0.19),
        "pink": Color(red: 0.83, green: 0.33, blue: 0.49),
        "blue": Color(red: 0.22, green: 0.54, blue: 0.87),
        "green": Color(red: 0.39, green: 0.60, blue: 0.13),
        "amber": Color(red: 0.94, green: 0.62, blue: 0.15),
    ]

    private var color: Color { Self.palette[colorName] ?? .gray }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.22))
            Circle()
                .stroke(color.opacity(0.55), lineWidth: 1)
            eyes
            Text(String(name.prefix(1)))
                .font(.system(size: size * 0.38, weight: .medium))
                .foregroundStyle(color)
                .offset(y: size * 0.18)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            if state == .thinking {
                thinkingBubble
            }
        }
    }

    private var eyes: some View {
        TimelineView(.animation(minimumInterval: 0.4, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let blink = !reduceMotion && t.truncatingRemainder(dividingBy: 3.0) < 0.15
            HStack(spacing: size * 0.16) {
                Capsule()
                    .frame(width: size * 0.09, height: blink ? size * 0.02 : size * 0.16)
                Capsule()
                    .frame(width: size * 0.09, height: blink ? size * 0.02 : size * 0.16)
            }
            .foregroundStyle(color)
            .offset(y: -size * 0.12)
        }
    }

    private var thinkingBubble: some View {
        TimelineView(.animation(minimumInterval: 0.25, paused: reduceMotion)) { context in
            let phase = reduceMotion ? 1 : Int(context.date.timeIntervalSinceReferenceDate * 3) % 3
            HStack(spacing: 1.5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .frame(width: 3, height: 3)
                        .opacity(index <= phase ? 1 : 0.25)
                }
            }
            .foregroundStyle(color)
            .offset(x: size * 0.28, y: -size * 0.12)
        }
    }
}
