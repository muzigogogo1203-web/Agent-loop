import SwiftUI

struct TypingIndicatorView: View {
    var body: some View {
        HStack(spacing: 3) {
            Circle().frame(width: 5, height: 5)
            Circle().frame(width: 5, height: 5)
            Circle().frame(width: 5, height: 5)
        }
        .foregroundStyle(.secondary)
    }
}
