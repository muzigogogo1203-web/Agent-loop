import SwiftUI
import Foundation

struct TypingIndicatorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Text("...")
                .foregroundStyle(.secondary)
        } else {
            TimelineView(.animation(minimumInterval: 0.15)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .frame(width: 5, height: 5)
                            .offset(y: sin((t * 5) + Double(index) * 0.9) * 2.5)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}
