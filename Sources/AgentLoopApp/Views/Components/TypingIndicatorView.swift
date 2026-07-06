import SwiftUI
import Foundation

struct TypingIndicatorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        if reduceMotion || controlActiveState != .key {
            // 静态替代（Reduce Motion）/ 失焦暂停（不与流式渲染争主线程）
            Text("…")
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
